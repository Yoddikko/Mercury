//
//  SummarizeArticleUseCase.swift
//  Mercury
//
//  Created by Codex on 26/06/26.
//

import Foundation

/// Orchestration entrypoint for AI summarization.
///
/// The summarization pipeline already lives in
/// `ArticleSummarizationService` (provider call + persistence + cached
/// reuse), so this use case is a deliberately thin wrapper that gives
/// the view-model layer the same uniform "talk to a use case, not a
/// service" surface as `FetchHomeFeedUseCase` / `EnrichArticleUseCase`.
///
/// ponytail: thin wrapper today, justifies its existence once a 2nd
/// consumer needs the same orchestration step. Until then it pays back
/// in test ergonomics (one fake protocol per view-model dependency) and
/// in the architectural consistency promised by
/// `docs/architecture/ARCHITECTURE.md` (§4.2 Application Layer).
protocol SummarizeArticleUseCase: Sendable {
    /// Generate (or reuse the cached) AI summary for `article`.
    ///
    /// - Parameters:
    ///   - article: the article whose body should be summarized.
    ///   - requestID: caller-provided trace id; forwarded to the
    ///     underlying service so AppLogger entries stay correlatable.
    /// - Returns: the structured `AISummaryResult` (cached when already
    ///   present, freshly generated otherwise).
    /// - Throws: `ArticleSummarizationError` for empty content,
    ///   provider failures, or persistence failures.
    func execute(article: Article, requestID: String?) async throws -> AISummaryResult
}

extension SummarizeArticleUseCase {
    func execute(article: Article) async throws -> AISummaryResult {
        try await execute(article: article, requestID: nil)
    }
}

/// Production `SummarizeArticleUseCase` wrapping
/// `ArticleSummarizationService`.
struct LiveSummarizeArticleUseCase: SummarizeArticleUseCase {
    private static let serviceName = "SummarizeArticleUseCase"

    /// Closure that performs the actual summarization for an article.
    /// Production wiring wraps
    /// `ArticleSummarizationService.summarizeIfNeeded(...)`; tests inject
    /// a stub so the orchestration can be exercised without contacting
    /// any AI provider.
    typealias SummarizeAction = @Sendable (_ article: Article, _ requestID: String) async throws -> AISummaryResult

    private let summarizeAction: SummarizeAction
    private let logger: AppLogger

    /// Production initializer that wraps the live
    /// `ArticleSummarizationService.summarizeIfNeeded(...)` surface.
    init(
        summarizationService: ArticleSummarizationService,
        logger: AppLogger = .shared
    ) {
        self.init(
            summarizeAction: { article, requestID in
                try await summarizationService.summarizeIfNeeded(
                    article,
                    requestID: requestID
                )
            },
            logger: logger
        )
    }

    /// Designated initializer accepting a closure-based summarize seam
    /// so tests can drive every branch of the orchestration without
    /// contacting any AI provider.
    init(
        summarizeAction: @escaping SummarizeAction,
        logger: AppLogger = .shared
    ) {
        self.summarizeAction = summarizeAction
        self.logger = logger
    }

    func execute(article: Article, requestID: String?) async throws -> AISummaryResult {
        let flowRequestID = requestID ?? "summarize-article-uc-\(UUID().uuidString.lowercased())"

        logger.info(
            "SummarizeArticleUseCase started",
            category: .business,
            service: Self.serviceName,
            requestID: flowRequestID,
            metadata: ["article_id": article.id]
        )

        do {
            let summary = try await summarizeAction(article, flowRequestID)
            logger.info(
                "SummarizeArticleUseCase completed",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "bullets": "\(summary.bullets.count)"
                ]
            )
            return summary
        } catch {
            logger.warn(
                "SummarizeArticleUseCase failed",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "error": String(describing: error)
                ]
            )
            throw error
        }
    }
}
