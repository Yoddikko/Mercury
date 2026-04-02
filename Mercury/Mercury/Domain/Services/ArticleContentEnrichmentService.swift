//
//  ArticleContentEnrichmentService.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct ArticleContentEnrichmentService: Sendable {
    private let pageClient: ArticlePageClient
    private let extractor: ArticlePageContentExtractor
    private let logger: AppLogger
    private let maxFetchesPerSource: Int

    init(
        pageClient: ArticlePageClient = ArticlePageClient(),
        extractor: ArticlePageContentExtractor = ArticlePageContentExtractor(),
        logger: AppLogger = .shared,
        maxFetchesPerSource: Int = 6
    ) {
        self.pageClient = pageClient
        self.extractor = extractor
        self.logger = logger
        self.maxFetchesPerSource = maxFetchesPerSource
    }

    func enrichArticlesIfNeeded(
        _ articles: [Article],
        requestID: String? = nil
    ) async -> [Article] {
        guard articles.isEmpty == false else { return articles }

        logger.debug(
            "Starting article page enrichment",
            category: .business,
            service: "ArticleContentEnrichmentService",
            requestID: requestID,
            metadata: [
                "articles_in": "\(articles.count)",
                "max_fetches_per_source": "\(maxFetchesPerSource)"
            ]
        )

        var remainingFetchBudget = maxFetchesPerSource
        var attempts = 0
        var upgraded = 0
        var output: [Article] = []
        output.reserveCapacity(articles.count)

        for article in articles {
            guard shouldAttemptEnrichment(for: article) else {
                output.append(article)
                continue
            }

            guard remainingFetchBudget > 0 else {
                output.append(article)
                continue
            }

            remainingFetchBudget -= 1
            attempts += 1
            let enriched = await enrichSingleArticle(article, requestID: requestID)
            if enriched.contentSource == "article_page", enriched.contentWordCount > article.contentWordCount {
                upgraded += 1
            }
            output.append(enriched)
        }

        logger.debug(
            "Article page enrichment completed",
            category: .business,
            service: "ArticleContentEnrichmentService",
            requestID: requestID,
            metadata: [
                "articles_in": "\(articles.count)",
                "attempts": "\(attempts)",
                "upgraded": "\(upgraded)",
                "articles_out": "\(output.count)"
            ]
        )

        return output
    }

    private func shouldAttemptEnrichment(for article: Article) -> Bool {
        guard article.articleURL.scheme?.lowercased() == "https" else { return false }

        if article.contentSource == "article_page", article.contentWordCount >= 180 {
            return false
        }

        if article.isContentLikelyComplete, article.contentWordCount >= 220 {
            return false
        }

        if article.contentSource == "feed_content", article.contentWordCount >= 350 {
            return false
        }

        return true
    }

    private func enrichSingleArticle(_ article: Article, requestID: String?) async -> Article {
        do {
            let html = try await pageClient.fetchPageHTML(from: article.articleURL, requestID: requestID)
            guard let extraction = extractor.extract(from: html, requestID: requestID) else {
                return article
            }

            guard shouldReplaceContent(existingArticle: article, extraction: extraction) else {
                return article
            }

            let resolvedImageURL = article.heroImageURL ?? resolvedImageURLString(
                extraction.heroImageURLString,
                fallback: article.articleURL
            )
            let summary = resolvedSummary(existing: article.summaryShort, cleanedContent: extraction.cleanedText)

            logger.trace(
                "Article content upgraded from page extraction",
                category: .business,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "old_word_count": "\(article.contentWordCount)",
                    "new_word_count": "\(extraction.wordCount)"
                ]
            )

            return article.updatingContent(
                rawContent: extraction.rawHTML,
                cleanedContent: extraction.cleanedText,
                contentSource: "article_page",
                contentWordCount: extraction.wordCount,
                isContentLikelyComplete: extraction.isLikelyComplete,
                heroImageURL: resolvedImageURL,
                summaryShort: summary,
                updatedAt: .now
            )
        } catch {
            logger.trace(
                "Article page enrichment failed and fell back to feed content",
                category: .api,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "url": article.articleURL.absoluteString,
                    "error": String(describing: error)
                ]
            )
            return article
        }
    }

    private func shouldReplaceContent(
        existingArticle: Article,
        extraction: ArticlePageExtractionResult
    ) -> Bool {
        let newWords = extraction.wordCount
        let oldWords = existingArticle.contentWordCount

        guard newWords > 0 else { return false }
        if oldWords == 0 { return true }

        if existingArticle.contentSource == "feed_summary" {
            return newWords >= oldWords + 15
        }

        if existingArticle.isContentLikelyComplete {
            return newWords >= oldWords + 80
        }

        if oldWords < 120 {
            return newWords >= oldWords + 20
        }

        return newWords >= oldWords + 35 || newWords >= 180
    }

    private func resolvedImageURLString(_ value: String?, fallback: URL) -> URL? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let absolute = URL(string: trimmed),
           let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absolute
        }

        if trimmed.hasPrefix("//"), let protocolRelative = URL(string: "https:\(trimmed)") {
            return protocolRelative
        }

        if trimmed.lowercased().hasPrefix("www."),
           let normalized = URL(string: "https://\(trimmed)") {
            return normalized
        }

        if let relative = URL(string: trimmed, relativeTo: fallback)?.absoluteURL,
           let scheme = relative.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return relative
        }

        return nil
    }

    private func resolvedSummary(existing: String?, cleanedContent: String) -> String? {
        if let existing, existing.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 {
            return existing
        }

        let trimmed = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return existing }

        if trimmed.count <= 280 {
            return trimmed
        }

        let snippet = String(trimmed.prefix(280)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard snippet.isEmpty == false else { return existing }
        return "\(snippet)..."
    }
}
