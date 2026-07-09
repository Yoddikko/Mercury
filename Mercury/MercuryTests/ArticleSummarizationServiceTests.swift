//
//  ArticleSummarizationServiceTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

@Suite("ArticleSummarizationService")
struct ArticleSummarizationServiceTests {
    // MARK: - Happy path

    @Test
    func summarizeIfNeededInvokesProviderAndPersistsResult() async throws {
        let captured = Captures()
        let providerSummary = AISummaryResult(
            shortSummary: "Generated short summary.",
            bullets: ["Bullet one", "Bullet two", "Bullet three"]
        )

        let service = ArticleSummarizationService(
            summarize: { content, requestID in
                await captured.recordSummarize(content: content, requestID: requestID)
                return providerSummary
            },
            persist: { articleID, summary, requestID in
                await captured.recordPersist(articleID: articleID, summary: summary, requestID: requestID)
            }
        )

        let article = Self.sampleArticle(summaryShort: nil)

        let result = try await service.summarizeIfNeeded(article, requestID: "req-success")

        #expect(result == providerSummary)

        let summarizeCalls = await captured.summarizeCalls
        #expect(summarizeCalls.count == 1)
        #expect(summarizeCalls.first?.requestID == "req-success")
        #expect(summarizeCalls.first?.content == article.cleanedContent)

        let persistCalls = await captured.persistCalls
        #expect(persistCalls.count == 1)
        #expect(persistCalls.first?.articleID == article.id)
        #expect(persistCalls.first?.summary == providerSummary)
        #expect(persistCalls.first?.requestID == "req-success")
    }

    // MARK: - RSS excerpt is not an AI cache (issue #100)

    @Test
    func summarizeIfNeededIgnoresRSSExcerptAndCallsProvider() async throws {
        let captured = Captures()
        let providerSummary = AISummaryResult(
            shortSummary: "Real AI summary.",
            bullets: ["Bullet"]
        )

        let service = ArticleSummarizationService(
            summarize: { content, requestID in
                await captured.recordSummarize(content: content, requestID: requestID)
                return providerSummary
            },
            persist: { articleID, summary, requestID in
                await captured.recordPersist(articleID: articleID, summary: summary, requestID: requestID)
            }
        )

        // Ingest/enrichment populate `summaryShort` on every article; that
        // must never masquerade as a cached AI summary.
        let article = Self.sampleArticle(summaryShort: "RSS feed excerpt text.")

        let result = try await service.summarizeIfNeeded(article)

        #expect(result == providerSummary)
        let summarizeCalls = await captured.summarizeCalls
        #expect(summarizeCalls.count == 1)
    }

    // MARK: - Cached reuse

    @Test
    func summarizeIfNeededReusesCachedSummaryWithoutCallingProvider() async throws {
        let captured = Captures()
        let cachedShort = "Already cached short summary."
        let cachedBullets = ["Cached bullet 1", "Cached bullet 2"]

        let service = ArticleSummarizationService(
            summarize: { _, _ in
                await captured.markSummarizeShouldNotBeCalled()
                throw SampleError.boom
            },
            persist: { _, _, _ in
                await captured.markPersistShouldNotBeCalled()
            }
        )

        let article = Self.sampleArticle(
            aiSummaryShort: cachedShort,
            aiSummaryBullets: cachedBullets
        )

        let result = try await service.summarizeIfNeeded(article)

        #expect(result.shortSummary == cachedShort)
        #expect(result.bullets == cachedBullets)

        let summarizeCalls = await captured.summarizeCalls
        let persistCalls = await captured.persistCalls
        #expect(summarizeCalls.isEmpty)
        #expect(persistCalls.isEmpty)
    }

    // MARK: - Empty content (no provider configured / nothing to summarize)

    @Test
    func summarizeIfNeededThrowsEmptyContentWhenBodyIsBlank() async {
        let service = ArticleSummarizationService(
            summarize: { _, _ in
                Issue.record("Summarize should not be invoked when content is empty.")
                throw SampleError.boom
            },
            persist: { _, _, _ in
                Issue.record("Persist should not be invoked when content is empty.")
            }
        )

        let article = Self.sampleArticle(
            cleanedContent: nil,
            rawContent: "   ",
            summaryShort: nil
        )

        await #expect(throws: ArticleSummarizationError.emptyContent) {
            _ = try await service.summarizeIfNeeded(article)
        }
    }

    // MARK: - Provider failure

    @Test
    func summarizeIfNeededWrapsProviderFailure() async {
        let service = ArticleSummarizationService(
            summarize: { _, _ in
                throw SampleError.boom
            },
            persist: { _, _, _ in
                Issue.record("Persist should not be invoked when the provider fails.")
            }
        )

        let article = Self.sampleArticle(summaryShort: nil)

        do {
            _ = try await service.summarizeIfNeeded(article)
            Issue.record("Expected providerFailure to be thrown.")
        } catch let error as ArticleSummarizationError {
            switch error {
            case let .providerFailure(message):
                #expect(message.isEmpty == false)
            default:
                Issue.record("Expected providerFailure, got \(error).")
            }
        } catch {
            Issue.record("Expected ArticleSummarizationError, got \(error).")
        }
    }

    // MARK: - Persistence failure surfaces as persistenceFailure

    @Test
    func summarizeIfNeededWrapsPersistenceFailure() async {
        let providerSummary = AISummaryResult(
            shortSummary: "Generated.",
            bullets: ["A"]
        )
        let service = ArticleSummarizationService(
            summarize: { _, _ in providerSummary },
            persist: { _, _, _ in
                throw SampleError.boom
            }
        )

        let article = Self.sampleArticle(summaryShort: nil)

        do {
            _ = try await service.summarizeIfNeeded(article)
            Issue.record("Expected persistenceFailure to be thrown.")
        } catch let error as ArticleSummarizationError {
            switch error {
            case let .persistenceFailure(message):
                #expect(message.isEmpty == false)
            default:
                Issue.record("Expected persistenceFailure, got \(error).")
            }
        } catch {
            Issue.record("Expected ArticleSummarizationError, got \(error).")
        }
    }

    // MARK: - ArticleLocalStore.applySummary smoke

    @Test
    func applySummaryPersistsSummaryFieldsOnArticleEntity() async throws {
        let container = try Self.makeContainer()
        let store = ArticleLocalStore(modelContainer: container)
        let entity = ArticleEntity(
            id: "summary-smoke",
            title: "Smoke",
            sourceName: "Mercury Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/summary-smoke"
        )
        _ = try await store.upsert(entity)

        let originalUpdatedAt = try await store.fetchArticle(id: "summary-smoke")?.updatedAt

        // Sleep briefly to guarantee the timestamp moves forward.
        try await Task.sleep(nanoseconds: 5_000_000)

        let summary = AISummaryResult(
            shortSummary: "Persisted short summary.",
            bullets: ["Persisted bullet 1", "Persisted bullet 2"]
        )

        try await store.applySummary(
            articleID: "summary-smoke",
            summary: summary,
            requestID: "req-persist"
        )

        let result = try await store.fetchArticle(id: "summary-smoke")
        #expect(result?.aiSummaryShort == "Persisted short summary.")
        #expect(result?.aiSummaryBullets == ["Persisted bullet 1", "Persisted bullet 2"])
        // The RSS/excerpt field must stay untouched (issue #100).
        #expect(result?.summaryShort == nil)
        #expect((result?.updatedAt ?? .distantPast) > (originalUpdatedAt ?? .distantFuture))
    }

    @Test
    func upsertFromRSSRefreshPreservesAISummary() async throws {
        let container = try Self.makeContainer()
        let store = ArticleLocalStore(modelContainer: container)
        _ = try await store.upsert(ArticleEntity(
            id: "preserve-ai",
            title: "Original",
            sourceName: "Mercury Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/preserve-ai"
        ))
        try await store.applySummary(
            articleID: "preserve-ai",
            summary: AISummaryResult(shortSummary: "AI text.", bullets: ["B1"])
        )

        // A refreshed ingest row never carries AI fields — it must not
        // wipe the user-generated summary (issue #100).
        _ = try await store.upsert(ArticleEntity(
            id: "preserve-ai",
            title: "Refreshed",
            sourceName: "Mercury Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/preserve-ai",
            summaryShort: "Fresh RSS excerpt"
        ))

        let result = try await store.fetchArticle(id: "preserve-ai")
        #expect(result?.title == "Refreshed")
        #expect(result?.summaryShort == "Fresh RSS excerpt")
        #expect(result?.aiSummaryShort == "AI text.")
        #expect(result?.aiSummaryBullets == ["B1"])
    }

    @Test
    func applySummaryThrowsWhenArticleMissing() async throws {
        let container = try Self.makeContainer()
        let store = ArticleLocalStore(modelContainer: container)
        let summary = AISummaryResult(shortSummary: "x", bullets: [])

        await #expect(throws: ArticleLocalStoreError.articleNotFound(id: "ghost")) {
            try await store.applySummary(articleID: "ghost", summary: summary)
        }
    }

    // MARK: - Helpers

    private static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: StoredArticle.self,
            ArticleEntity.self,
            ClusterEntity.self,
            UserPreferenceEntity.self,
            InteractionEntity.self,
            configurations: configuration
        )
    }

    private static func sampleArticle(
        id: String = "article-summary-test",
        cleanedContent: String? = "Cleaned article body used as summarization input.",
        rawContent: String? = nil,
        summaryShort: String? = nil,
        summaryBullets: [String] = [],
        aiSummaryShort: String? = nil,
        aiSummaryBullets: [String] = []
    ) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: "Sample Title",
            sourceName: "Sample Source",
            sourceURL: URL(string: "https://example.com/source")!,
            articleURL: URL(string: "https://example.com/article/\(id)")!,
            publishedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            authorName: "Author",
            heroImageURL: nil,
            rawContent: rawContent,
            cleanedContent: cleanedContent,
            contentSource: "feed_content",
            contentWordCount: 50,
            isContentLikelyComplete: false,
            summaryShort: summaryShort,
            summaryBullets: summaryBullets,
            aiSummaryShort: aiSummaryShort,
            aiSummaryBullets: aiSummaryBullets,
            category: "Technology",
            tags: ["test"],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private enum SampleError: Error {
        case boom
    }

    private struct SummarizeCall: Sendable {
        let content: String
        let requestID: String
    }

    private struct PersistCall: Sendable {
        let articleID: String
        let summary: AISummaryResult
        let requestID: String
    }

    private actor Captures {
        private(set) var summarizeCalls: [SummarizeCall] = []
        private(set) var persistCalls: [PersistCall] = []

        func recordSummarize(content: String, requestID: String) {
            summarizeCalls.append(SummarizeCall(content: content, requestID: requestID))
        }

        func recordPersist(articleID: String, summary: AISummaryResult, requestID: String) {
            persistCalls.append(PersistCall(articleID: articleID, summary: summary, requestID: requestID))
        }

        func markSummarizeShouldNotBeCalled() {
            Issue.record("Summarize closure should not be invoked when a cached summary is reused.")
        }

        func markPersistShouldNotBeCalled() {
            Issue.record("Persist closure should not be invoked when a cached summary is reused.")
        }
    }
}
