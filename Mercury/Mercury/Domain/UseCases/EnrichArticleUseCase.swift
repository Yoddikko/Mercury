//
//  EnrichArticleUseCase.swift
//  Mercury
//
//  Created by Codex on 26/06/26.
//

import Foundation

/// Orchestration entrypoint for "fetch and persist the full article body".
///
/// The Article Detail screen needs the cleaned text of an article so it
/// can render the long-form body, but the on-device cache often only
/// carries the RSS feed snippet. `EnrichArticleUseCase` is the seam view
/// models depend on so they don't reach down into the page fetcher and
/// `ArticleRepository` directly:
///
/// 1. delegate fetch + HTML extraction to the existing
///    `ArticleContentEnrichmentService` (single-article overload), which
///    drives `ArticlePageClient` + `ArticlePageContentExtractor` under
///    the hood,
/// 2. if the service returned a richer article, persist it via
///    `ArticleRepository.upsert` so the cache reflects the new body and
///    the next launch can render offline.
///
/// When enrichment fails (network error, empty extraction, no improvement
/// over the cached body) the use case logs the outcome and returns `nil`
/// so the caller can surface a graceful fallback in the UI.
protocol EnrichArticleUseCase: Sendable {
    /// Attempt to enrich `article` with the full body extracted from its
    /// article URL and persist the result on success.
    ///
    /// - Parameters:
    ///   - article: the article to enrich (typically the one currently
    ///     displayed in the detail screen).
    ///   - requestID: caller-provided trace id; when `nil` the use case
    ///     mints one so AppLogger entries stay correlatable across layers.
    /// - Returns: the enriched `Article` when a richer body was found and
    ///   persisted; `nil` when enrichment produced no improvement or
    ///   failed (the underlying service handles errors internally).
    func execute(article: Article, requestID: String?) async -> Article?
}

extension EnrichArticleUseCase {
    func execute(article: Article) async -> Article? {
        await execute(article: article, requestID: nil)
    }
}

/// Production `EnrichArticleUseCase` wiring the live page-fetch pipeline
/// and the `ArticleRepository` cache.
struct LiveEnrichArticleUseCase: EnrichArticleUseCase {
    private static let serviceName = "EnrichArticleUseCase"

    private let enrichmentService: ArticleContentEnrichmentService
    private let articleRepository: ArticleRepository
    private let logger: AppLogger

    init(
        enrichmentService: ArticleContentEnrichmentService,
        articleRepository: ArticleRepository,
        logger: AppLogger = .shared
    ) {
        self.enrichmentService = enrichmentService
        self.articleRepository = articleRepository
        self.logger = logger
    }

    func execute(article: Article, requestID: String?) async -> Article? {
        let flowRequestID = requestID ?? "enrich-article-uc-\(UUID().uuidString.lowercased())"

        logger.info(
            "EnrichArticleUseCase started",
            category: .business,
            service: Self.serviceName,
            requestID: flowRequestID,
            metadata: [
                "article_id": article.id,
                "content_word_count": "\(article.contentWordCount)",
                "is_content_complete": "\(article.isContentLikelyComplete)"
            ]
        )

        let enrichedArticles = await enrichmentService.enrichArticlesIfNeeded(
            [article],
            requestID: flowRequestID
        )

        guard let candidate = enrichedArticles.first else {
            logger.warn(
                "EnrichArticleUseCase produced no candidate",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: ["article_id": article.id]
            )
            return nil
        }

        guard candidate.contentWordCount > article.contentWordCount ||
                candidate.contentSource != article.contentSource else {
            logger.debug(
                "EnrichArticleUseCase completed without improvement",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": article.id,
                    "content_word_count": "\(candidate.contentWordCount)"
                ]
            )
            return nil
        }

        do {
            let entity = ArticleEntityMapper.makeEntity(from: candidate)
            _ = try await articleRepository.upsert(entity, requestID: flowRequestID)
            logger.info(
                "EnrichArticleUseCase persisted enriched article",
                category: .business,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": candidate.id,
                    "new_word_count": "\(candidate.contentWordCount)",
                    "is_content_complete": "\(candidate.isContentLikelyComplete)"
                ]
            )
            return candidate
        } catch {
            // Persistence failed but enrichment succeeded — surface the
            // enriched article so the caller can still render it.
            logger.error(
                "EnrichArticleUseCase cache write failed",
                category: .database,
                service: Self.serviceName,
                requestID: flowRequestID,
                metadata: [
                    "article_id": candidate.id,
                    "error": String(describing: error)
                ]
            )
            return candidate
        }
    }
}
