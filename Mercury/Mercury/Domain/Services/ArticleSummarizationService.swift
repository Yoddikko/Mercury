//
//  ArticleSummarizationService.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Domain-layer service that wires the AI summarization pipeline
/// (`AIService` → active provider, Claude by default) to the on-device
/// SwiftData cache (`ArticleLocalStore`).
///
/// `ArticleSummarizationService` is intentionally narrow:
///
/// * it does **not** select the provider — `AIService` already owns that;
/// * it does **not** introduce a repository abstraction — that work is
///   tracked by issue #29 and we keep `ArticleLocalStore` as the persistence
///   seam used today;
/// * it does **not** introduce use cases — that work is tracked by #30.
///
/// All side effects are injected as closures so the service stays trivially
/// testable without dragging in `AIService`, `ModelContext`, or
/// `URLSession`. The production wiring (see `HomeScreen` / DI) builds the
/// closures from the real `AIService` and the live `ArticleLocalStore`.
///
/// Caching contract (see `docs/features/SUMMARIZATION.md`):
/// * if the article already exposes a non-empty `summaryShort`, the service
///   returns the cached result and skips the provider call;
/// * otherwise it invokes the AI provider, persists the result on the
///   matching `ArticleEntity`, and returns the freshly generated summary.
struct ArticleSummarizationService: Sendable {
    /// Closure that sends the cleaned article text to the active AI provider
    /// and returns the structured `AISummaryResult`. In production it wraps
    /// `AIService.summarizeArticle(_:requestID:)`.
    typealias SummarizeAction = @Sendable (_ content: String, _ requestID: String) async throws -> AISummaryResult

    /// Closure that persists the freshly generated summary onto the article
    /// identified by `articleID`. In production it wraps
    /// `ArticleLocalStore.applySummary(articleID:summary:requestID:)`.
    typealias PersistAction = @Sendable (_ articleID: String, _ summary: AISummaryResult, _ requestID: String) async throws -> Void

    private static let serviceName = "ArticleSummarizationService"

    private let summarize: SummarizeAction
    private let persist: PersistAction
    private let logger: AppLogger

    /// Designated initializer used by both production wiring and tests.
    init(
        summarize: @escaping SummarizeAction,
        persist: @escaping PersistAction,
        logger: AppLogger = .shared
    ) {
        self.summarize = summarize
        self.persist = persist
        self.logger = logger
    }

    /// Generate (or reuse the cached) summary for `article`.
    ///
    /// * Reuses any non-empty `summaryShort` already attached to the article
    ///   and returns it without contacting the provider.
    /// * Otherwise calls the active provider, persists the result, and
    ///   returns the structured `AISummaryResult`.
    ///
    /// Failures from the provider or the store propagate as
    /// `ArticleSummarizationError`, leaving the caller free to render a
    /// graceful fallback in the UI (`docs/features/SUMMARIZATION.md` → AI
    /// failure → skip).
    func summarizeIfNeeded(
        _ article: Article,
        requestID: String? = nil
    ) async throws -> AISummaryResult {
        let flowRequestID = requestID ?? Self.generateRequestID()

        if let cached = Self.cachedSummary(for: article) {
            logger.trace(
                "Reusing cached article summary",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "bullets": "\(cached.bullets.count)"
                ]
            )
            return cached
        }

        guard let content = Self.summarizationInput(for: article) else {
            logger.warn(
                "Skipping summarization: article body is empty",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "content_word_count": "\(article.contentWordCount)"
                ]
            )
            throw ArticleSummarizationError.emptyContent
        }

        logger.info(
            "Article summarization requested",
            category: .business,
            service: Self.serviceName,
            requestID: flowRequestID,
            metadata: [
                "article_id": article.id,
                "content_word_count": "\(article.contentWordCount)",
                "source": article.sourceName
            ]
        )

        let summary: AISummaryResult
        do {
            summary = try await summarize(content, flowRequestID)
        } catch {
            logger.warn(
                "Article summarization provider call failed",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "error": String(describing: error)
                ]
            )
            throw ArticleSummarizationError.providerFailure(message: localizedMessage(for: error))
        }

        do {
            try await persist(article.id, summary, flowRequestID)
        } catch {
            logger.error(
                "Article summarization persistence failed",
                category: .database,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "error": String(describing: error)
                ]
            )
            // The summary still reached the caller; surfacing the failure as
            // a persistence error keeps the contract explicit while letting
            // the UI optionally render the freshly generated text.
            throw ArticleSummarizationError.persistenceFailure(message: localizedMessage(for: error))
        }

        logger.info(
            "Article summarization completed and persisted",
            category: .business,
            service: Self.serviceName,
            requestID: flowRequestID,
            metadata: [
                "article_id": article.id,
                "bullets": "\(summary.bullets.count)"
            ]
        )

        return summary
    }

    // MARK: - Helpers

    /// Returns the cached summary already attached to `article`, when the
    /// `summaryShort` field is populated.
    static func cachedSummary(for article: Article) -> AISummaryResult? {
        guard let short = article.summaryShort?.trimmingCharacters(in: .whitespacesAndNewlines),
              short.isEmpty == false else {
            return nil
        }
        return AISummaryResult(shortSummary: short, bullets: article.summaryBullets)
    }

    /// Returns the best body text available for summarization, preferring
    /// `cleanedContent` over `rawContent`. Returns `nil` when both are empty
    /// or whitespace.
    static func summarizationInput(for article: Article) -> String? {
        if let cleaned = article.cleanedContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           cleaned.isEmpty == false {
            return cleaned
        }
        if let raw = article.rawContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           raw.isEmpty == false {
            return raw
        }
        return nil
    }

    private func localizedMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static func generateRequestID() -> String {
        "article-summary-\(UUID().uuidString.lowercased())"
    }
}

/// Error surface returned by `ArticleSummarizationService`.
///
/// Mirrors the failure branches documented in
/// `docs/features/SUMMARIZATION.md` (empty content, AI failure, persistence)
/// so the UI can map each branch to a localized fallback message.
enum ArticleSummarizationError: Error, Sendable, LocalizedError, Equatable {
    case emptyContent
    case providerFailure(message: String)
    case persistenceFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Article body is empty; nothing to summarize."
        case let .providerFailure(message):
            return "AI provider failed to generate the summary: \(message)"
        case let .persistenceFailure(message):
            return "Failed to persist the generated summary: \(message)"
        }
    }
}
