//
//  FetchHomeFeedUseCaseTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Verifies the orchestration contract of `LiveFetchHomeFeedUseCase`:
///
/// 1. invokes the refresh seam with the supplied parameters and a
///    correlated request id,
/// 2. forwards the deduplicated batch into `ArticleRepository.upsertAll`
///    so the on-device cache stays current,
/// 3. surfaces the refresh result even when the cache write fails
///    (partial success).
@Suite("FetchHomeFeedUseCase")
struct FetchHomeFeedUseCaseTests {
    @Test
    func executePersistsDeduplicatedArticlesAndReturnsBatch() async throws {
        let articles = Self.sampleArticles(count: 2, prefix: "uc-feed")
        let repository = RecordingArticleRepository()
        let expectedRequestID = "test-request-feed"
        let useCase = LiveFetchHomeFeedUseCase(
            refreshAction: { groupMode, region, requestID in
                #expect(groupMode == .mainOutlets)
                #expect(region == nil)
                #expect(requestID == expectedRequestID)
                return RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: groupMode,
                    selectedRegion: region,
                    checks: [],
                    deduplicatedArticles: articles
                )
            },
            articleRepository: repository
        )

        let result = await useCase.execute(
            groupMode: .mainOutlets,
            selectedRegion: nil,
            requestID: expectedRequestID
        )

        #expect(result.deduplicatedArticles.count == articles.count)
        let recorded = await repository.upsertedBatches
        #expect(recorded.count == 1)
        #expect(Set(recorded.first?.map(\.id) ?? []) == Set(articles.map(\.id)))
        let recordedRequestIDs = await repository.upsertRequestIDs
        #expect(recordedRequestIDs == [expectedRequestID])
    }

    @Test
    func executeSkipsPersistenceWhenBatchIsEmpty() async {
        let repository = RecordingArticleRepository()
        let useCase = LiveFetchHomeFeedUseCase(
            refreshAction: { groupMode, region, requestID in
                RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: groupMode,
                    selectedRegion: region,
                    checks: [],
                    deduplicatedArticles: []
                )
            },
            articleRepository: repository
        )

        let result = await useCase.execute(
            groupMode: .mainOutlets,
            selectedRegion: nil,
            requestID: nil
        )

        #expect(result.deduplicatedArticles.isEmpty)
        let recorded = await repository.upsertedBatches
        #expect(recorded.isEmpty)
    }

    @Test
    func executeReturnsBatchEvenWhenPersistenceFails() async {
        let articles = Self.sampleArticles(count: 1, prefix: "uc-persist-fail")
        let repository = RecordingArticleRepository(upsertError: SampleRepositoryError.boom)
        let useCase = LiveFetchHomeFeedUseCase(
            refreshAction: { groupMode, region, _ in
                RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: groupMode,
                    selectedRegion: region,
                    checks: [],
                    deduplicatedArticles: articles
                )
            },
            articleRepository: repository
        )

        let result = await useCase.execute(
            groupMode: .mainOutlets,
            selectedRegion: nil,
            requestID: nil
        )

        #expect(result.deduplicatedArticles.count == articles.count)
        let recorded = await repository.upsertedBatches
        #expect(recorded.count == 1)
    }

    // MARK: - Helpers

    private static func sampleArticles(count: Int, prefix: String) -> [Article] {
        (0..<count).map { index in
            Article(
                id: "\(prefix)-\(index)",
                externalID: nil,
                title: "Sample \(prefix) \(index)",
                sourceName: "Sample Source",
                sourceURL: URL(string: "https://example.com/source")!,
                articleURL: URL(string: "https://example.com/article/\(prefix)-\(index)")!,
                publishedAt: Date(timeIntervalSinceReferenceDate: TimeInterval(1_000 + index)),
                authorName: nil,
                heroImageURL: nil,
                rawContent: nil,
                cleanedContent: nil,
                contentSource: "test",
                contentWordCount: 0,
                isContentLikelyComplete: false,
                summaryShort: nil,
                summaryBullets: [],
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
    }
}

/// Test-only `ArticleRepository` that records every call it receives and
/// can be configured to surface a deterministic error from the upsert
/// surfaces. Lookup-style methods throw because the use-case tests in
/// this suite never exercise them; failing loudly catches accidental new
/// dependencies on the repository contract.
actor RecordingArticleRepository: ArticleRepository {
    private(set) var upsertedBatches: [[ArticleEntity]] = []
    private(set) var upsertRequestIDs: [String?] = []
    private(set) var singleUpsertedArticles: [ArticleEntity] = []
    private(set) var singleUpsertRequestIDs: [String?] = []
    private let upsertError: Error?

    init(upsertError: Error? = nil) {
        self.upsertError = upsertError
    }

    func upsert(_ article: ArticleEntity, requestID: String?) async throws -> ArticleEntity {
        singleUpsertedArticles.append(article)
        singleUpsertRequestIDs.append(requestID)
        if let upsertError {
            throw upsertError
        }
        return article
    }

    func upsertAll(_ articles: [ArticleEntity], requestID: String?) async throws -> Int {
        upsertedBatches.append(articles)
        upsertRequestIDs.append(requestID)
        if let upsertError {
            throw upsertError
        }
        return articles.count
    }

    func fetchArticles(_ query: ArticleQuery, requestID: String?) async throws -> [ArticleEntity] {
        throw SampleRepositoryError.unsupported
    }

    func fetchArticle(id: String, requestID: String?) async throws -> ArticleEntity? {
        throw SampleRepositoryError.unsupported
    }

    func fetchFavorites(requestID: String?) async throws -> [ArticleEntity] {
        throw SampleRepositoryError.unsupported
    }

    func toggleFavorite(articleID: String, requestID: String?) async throws -> Bool {
        throw SampleRepositoryError.unsupported
    }

    func markAsRead(articleID: String, requestID: String?) async throws {
        throw SampleRepositoryError.unsupported
    }

    func recordOpen(
        articleID: String,
        markAsRead: Bool,
        timestamp: Date,
        readingDuration: Double?,
        scrollDepth: Double?,
        requestID: String?
    ) async throws {
        throw SampleRepositoryError.unsupported
    }

    func fetchHistory(limit: Int, requestID: String?) async throws -> [InteractionEntity] {
        throw SampleRepositoryError.unsupported
    }

    func clearHistory(requestID: String?) async throws {
        throw SampleRepositoryError.unsupported
    }
}

enum SampleRepositoryError: Error, Equatable {
    case boom
    case unsupported
}
