//
//  EnrichArticleUseCaseTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import Testing
@testable import Mercury

/// Verifies the orchestration contract of `LiveEnrichArticleUseCase`:
///
/// 1. persists the enriched article into the repository when the page
///    fetch produced richer content,
/// 2. returns `nil` and skips persistence when the enrichment seam
///    produced no improvement,
/// 3. returns the enriched article even when the cache write fails
///    (partial success).
@Suite("EnrichArticleUseCase")
struct EnrichArticleUseCaseTests {
    @Test
    func executePersistsEnrichedArticleAndReturnsIt() async {
        let original = Self.makeArticle(
            id: "enrich-improved",
            contentSource: "feed_summary",
            contentWordCount: 12,
            cleanedContent: "Short feed summary only."
        )
        let enriched = original.updatingContent(
            rawContent: "<p>Full body</p>",
            cleanedContent: "Full body text with significantly more words.",
            contentSource: "article_page",
            contentWordCount: 240,
            isContentLikelyComplete: true,
            heroImageURL: nil,
            summaryShort: original.summaryShort,
            updatedAt: .now
        )
        let repository = RecordingArticleRepository()
        let useCase = LiveEnrichArticleUseCase(
            enrichAction: { article, _ in
                #expect(article.id == original.id)
                return enriched
            },
            articleRepository: repository
        )

        let result = await useCase.execute(article: original, requestID: nil)

        #expect(result?.id == enriched.id)
        #expect(result?.contentWordCount == enriched.contentWordCount)
        let recorded = await repository.singleUpsertedArticles
        #expect(recorded.count == 1)
        #expect(recorded.first?.id == enriched.id)
    }

    @Test
    func executeReturnsNilWhenEnrichmentProducesNoImprovement() async {
        let original = Self.makeArticle(
            id: "enrich-no-change",
            contentSource: "article_page",
            contentWordCount: 240,
            cleanedContent: "Already enriched body."
        )
        let repository = RecordingArticleRepository()
        let useCase = LiveEnrichArticleUseCase(
            enrichAction: { article, _ in article },
            articleRepository: repository
        )

        let result = await useCase.execute(article: original, requestID: nil)

        #expect(result == nil)
        let recorded = await repository.singleUpsertedArticles
        #expect(recorded.isEmpty)
    }

    @Test
    func executeReturnsEnrichedArticleEvenWhenPersistenceFails() async {
        let original = Self.makeArticle(
            id: "enrich-persist-fail",
            contentSource: "feed_summary",
            contentWordCount: 12,
            cleanedContent: "Short feed summary only."
        )
        let enriched = original.updatingContent(
            rawContent: "<p>Full body</p>",
            cleanedContent: "Full body text with significantly more words.",
            contentSource: "article_page",
            contentWordCount: 240,
            isContentLikelyComplete: true,
            heroImageURL: nil,
            summaryShort: original.summaryShort,
            updatedAt: .now
        )
        let repository = RecordingArticleRepository(upsertError: SampleRepositoryError.boom)
        let useCase = LiveEnrichArticleUseCase(
            enrichAction: { _, _ in enriched },
            articleRepository: repository
        )

        let result = await useCase.execute(article: original, requestID: nil)

        #expect(result?.id == enriched.id)
        let recorded = await repository.singleUpsertedArticles
        #expect(recorded.count == 1)
    }

    // MARK: - Helpers

    private static func makeArticle(
        id: String,
        contentSource: String,
        contentWordCount: Int,
        cleanedContent: String?
    ) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: "Story \(id)",
            sourceName: "Sample Source",
            sourceURL: URL(string: "https://example.com/source")!,
            articleURL: URL(string: "https://example.com/article/\(id)")!,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            authorName: nil,
            heroImageURL: nil,
            rawContent: cleanedContent,
            cleanedContent: cleanedContent,
            contentSource: contentSource,
            contentWordCount: contentWordCount,
            isContentLikelyComplete: false,
            summaryShort: nil,
            summaryBullets: [],
            category: "General",
            tags: [],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
