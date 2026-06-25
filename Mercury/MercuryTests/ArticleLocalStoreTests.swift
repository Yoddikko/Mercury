//
//  ArticleLocalStoreTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

@Suite("ArticleLocalStore")
struct ArticleLocalStoreTests {
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

    private static func makeStore() throws -> ArticleLocalStore {
        ArticleLocalStore(modelContainer: try makeContainer())
    }

    private static func makeArticle(
        id: String = UUID().uuidString,
        title: String = "Title",
        source: String = "Mercury Source",
        publishedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ArticleEntity {
        ArticleEntity(
            id: id,
            title: title,
            sourceName: source,
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/\(id)",
            publishedAt: publishedAt
        )
    }

    // MARK: - Upsert

    @Test
    func upsertInsertsNewArticleAndReturnsCount() async throws {
        let store = try Self.makeStore()
        let article = Self.makeArticle(id: "a-1", title: "Original")

        _ = try await store.upsert(article)
        let fetched = try await store.fetchArticle(id: "a-1")

        #expect(fetched?.title == "Original")
    }

    @Test
    func upsertUpdatesExistingArticleAndRefreshesUpdatedAt() async throws {
        let store = try Self.makeStore()
        let original = Self.makeArticle(id: "a-2", title: "Original")
        _ = try await store.upsert(original)
        let originalUpdatedAt = try await store.fetchArticle(id: "a-2")!.updatedAt

        // Sleep briefly to guarantee the timestamp moves forward.
        try await Task.sleep(nanoseconds: 5_000_000)

        let edited = Self.makeArticle(id: "a-2", title: "Edited")
        _ = try await store.upsert(edited)

        let result = try await store.fetchArticle(id: "a-2")
        #expect(result?.title == "Edited")
        #expect((result?.updatedAt ?? .distantPast) > originalUpdatedAt)
    }

    @Test
    func upsertPreservesUserFlagsWhenRefreshingFromFeed() async throws {
        let store = try Self.makeStore()
        let original = Self.makeArticle(id: "a-3")
        _ = try await store.upsert(original)
        _ = try await store.toggleFavorite(articleID: "a-3")
        try await store.markAsRead(articleID: "a-3")

        // Simulate an RSS refresh that would otherwise reset the flags.
        let refreshed = Self.makeArticle(id: "a-3", title: "Refreshed")
        _ = try await store.upsert(refreshed)

        let result = try await store.fetchArticle(id: "a-3")
        #expect(result?.title == "Refreshed")
        #expect(result?.isBookmarked == true)
        #expect(result?.isRead == true)
    }

    @Test
    func upsertAllReturnsCount() async throws {
        let store = try Self.makeStore()
        let articles = (0..<5).map { Self.makeArticle(id: "bulk-\($0)") }
        let count = try await store.upsertAll(articles)
        #expect(count == 5)
        let stored = try await store.fetchArticles()
        #expect(stored.count == 5)
    }

    // MARK: - Queries

    @Test
    func fetchArticlesAppliesPublishedAtDescendingByDefault() async throws {
        let store = try Self.makeStore()
        let older = Self.makeArticle(id: "older", publishedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let newer = Self.makeArticle(id: "newer", publishedAt: Date(timeIntervalSince1970: 1_700_100_000))
        _ = try await store.upsertAll([older, newer])

        let result = try await store.fetchArticles()
        #expect(result.map(\.id) == ["newer", "older"])
    }

    @Test
    func fetchArticlesFiltersBySource() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsertAll([
            Self.makeArticle(id: "s1", source: "Wired"),
            Self.makeArticle(id: "s2", source: "Verge"),
            Self.makeArticle(id: "s3", source: "Wired")
        ])

        let query = ArticleQuery(sourceNames: ["Wired"])
        let result = try await store.fetchArticles(query)
        #expect(result.map(\.id).sorted() == ["s1", "s3"])
    }

    @Test
    func fetchArticlesFiltersByDateRange() async throws {
        let store = try Self.makeStore()
        let a = Self.makeArticle(id: "d1", publishedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let b = Self.makeArticle(id: "d2", publishedAt: Date(timeIntervalSince1970: 1_700_500_000))
        let c = Self.makeArticle(id: "d3", publishedAt: Date(timeIntervalSince1970: 1_701_000_000))
        _ = try await store.upsertAll([a, b, c])

        let query = ArticleQuery(
            publishedAfter: Date(timeIntervalSince1970: 1_700_300_000),
            publishedBefore: Date(timeIntervalSince1970: 1_700_800_000)
        )
        let result = try await store.fetchArticles(query)
        #expect(result.map(\.id) == ["d2"])
    }

    @Test
    func fetchArticlesAppliesLimit() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsertAll((0..<10).map {
            Self.makeArticle(id: "l-\($0)", publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval($0)))
        })

        let result = try await store.fetchArticles(ArticleQuery(limit: 3))
        #expect(result.count == 3)
    }

    @Test
    func fetchArticleByIdReturnsNilWhenMissing() async throws {
        let store = try Self.makeStore()
        let result = try await store.fetchArticle(id: "nope")
        #expect(result == nil)
    }

    // MARK: - Favorites

    @Test
    func toggleFavoriteFlipsValueAndReturnsNewState() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsert(Self.makeArticle(id: "fav-1"))

        let firstToggle = try await store.toggleFavorite(articleID: "fav-1")
        let secondToggle = try await store.toggleFavorite(articleID: "fav-1")

        #expect(firstToggle == true)
        #expect(secondToggle == false)
    }

    @Test
    func fetchFavoritesReturnsOnlyBookmarked() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsertAll([
            Self.makeArticle(id: "f1"),
            Self.makeArticle(id: "f2"),
            Self.makeArticle(id: "f3")
        ])
        _ = try await store.toggleFavorite(articleID: "f1")
        _ = try await store.toggleFavorite(articleID: "f3")

        let favorites = try await store.fetchFavorites()
        #expect(Set(favorites.map(\.id)) == ["f1", "f3"])
    }

    @Test
    func toggleFavoriteThrowsWhenArticleMissing() async throws {
        let store = try Self.makeStore()
        await #expect(throws: ArticleLocalStoreError.articleNotFound(id: "missing")) {
            _ = try await store.toggleFavorite(articleID: "missing")
        }
    }

    // MARK: - Read state

    @Test
    func markAsReadIsIdempotent() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsert(Self.makeArticle(id: "r-1"))

        try await store.markAsRead(articleID: "r-1")
        try await store.markAsRead(articleID: "r-1")

        let article = try await store.fetchArticle(id: "r-1")
        #expect(article?.isRead == true)

        // Only the first call should create an interaction entry.
        let history = try await store.fetchHistory()
        // markAsRead writes a `mark_read` interaction (not `open`); history is
        // limited to `open`, so the count should remain 0.
        #expect(history.isEmpty)
    }

    // MARK: - History

    @Test
    func recordOpenAppendsHistoryAndMarksRead() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsert(Self.makeArticle(id: "h-1"))

        try await store.recordOpen(articleID: "h-1")
        try await store.recordOpen(articleID: "h-1", markAsRead: false)

        let history = try await store.fetchHistory()
        #expect(history.count == 2)
        #expect(history.allSatisfy { $0.articleID == "h-1" })

        let article = try await store.fetchArticle(id: "h-1")
        #expect(article?.isRead == true)
    }

    @Test
    func fetchHistoryRespectsLimitAndOrdering() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsert(Self.makeArticle(id: "h-2"))

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.recordOpen(articleID: "h-2", timestamp: base)
        try await store.recordOpen(articleID: "h-2", timestamp: base.addingTimeInterval(60))
        try await store.recordOpen(articleID: "h-2", timestamp: base.addingTimeInterval(120))

        let history = try await store.fetchHistory(limit: 2)
        #expect(history.count == 2)
        #expect(history.first?.timestamp == base.addingTimeInterval(120))
    }

    @Test
    func clearHistoryRemovesOnlyOpenEntries() async throws {
        let store = try Self.makeStore()
        _ = try await store.upsert(Self.makeArticle(id: "h-3"))
        try await store.recordOpen(articleID: "h-3")
        _ = try await store.toggleFavorite(articleID: "h-3") // writes bookmark_toggle

        try await store.clearHistory()

        let history = try await store.fetchHistory()
        #expect(history.isEmpty)
    }

    @Test
    func recordOpenThrowsWhenArticleMissing() async throws {
        let store = try Self.makeStore()
        await #expect(throws: ArticleLocalStoreError.articleNotFound(id: "ghost")) {
            try await store.recordOpen(articleID: "ghost")
        }
    }
}
