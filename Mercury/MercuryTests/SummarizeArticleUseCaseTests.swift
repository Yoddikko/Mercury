//
//  SummarizeArticleUseCaseTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import Testing
@testable import Mercury

/// Verifies the orchestration contract of `LiveSummarizeArticleUseCase`:
///
/// 1. forwards the summarize closure with the supplied article and
///    surfaces the structured `AISummaryResult` it returns,
/// 2. propagates summarizer failures so the caller can render a
///    graceful fallback in the UI.
@Suite("SummarizeArticleUseCase")
struct SummarizeArticleUseCaseTests {
    @Test
    func executeReturnsSummaryFromSummarizer() async throws {
        let article = Self.makeArticle(id: "summarize-success")
        let expectedSummary = AISummaryResult(
            shortSummary: "A short summary.",
            bullets: ["First bullet", "Second bullet"]
        )
        let expectedRequestID = "test-request-summarize"
        let useCase = LiveSummarizeArticleUseCase(
            summarizeAction: { suppliedArticle, requestID in
                #expect(suppliedArticle.id == article.id)
                #expect(requestID == expectedRequestID)
                return expectedSummary
            }
        )

        let result = try await useCase.execute(
            article: article,
            requestID: expectedRequestID
        )

        #expect(result == expectedSummary)
    }

    @Test
    func executePropagatesSummarizerFailures() async {
        let article = Self.makeArticle(id: "summarize-failure")
        let useCase = LiveSummarizeArticleUseCase(
            summarizeAction: { _, _ in
                throw ArticleSummarizationError.emptyContent
            }
        )

        await #expect(throws: ArticleSummarizationError.self) {
            _ = try await useCase.execute(article: article, requestID: nil)
        }
    }

    // MARK: - Helpers

    private static func makeArticle(id: String) -> Article {
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
            rawContent: "Body text",
            cleanedContent: "Body text",
            contentSource: "feed_content",
            contentWordCount: 100,
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
