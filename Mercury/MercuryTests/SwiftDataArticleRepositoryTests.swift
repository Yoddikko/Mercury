//
//  SwiftDataArticleRepositoryTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Verifies the wrap-via-delegation contract of
/// `SwiftDataArticleRepository`. The repository forwards every call to its
/// backing `ArticleLocalStore`; these tests confirm the protocol surface
/// exposed to consumers behaves the same as the underlying store for the
/// flows view models depend on (upsert + fetch, favorite toggling,
/// open history) and that store errors propagate unchanged.
@Suite("SwiftDataArticleRepository")
struct SwiftDataArticleRepositoryTests {
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

    private static func makeRepository() throws -> SwiftDataArticleRepository {
        let store = ArticleLocalStore(modelContainer: try makeContainer())
        return SwiftDataArticleRepository(store: store)
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

    // MARK: - Happy paths

    @Test
    func upsertPersistsArticleAndFetchReturnsIt() async throws {
        let repository = try Self.makeRepository()
        let article = Self.makeArticle(id: "repo-1", title: "Repository Article")

        _ = try await repository.upsert(article)
        let fetched = try await repository.fetchArticle(id: "repo-1")

        #expect(fetched?.id == "repo-1")
        #expect(fetched?.title == "Repository Article")
    }

    @Test
    func toggleFavoriteFlipsBookmarkState() async throws {
        let repository = try Self.makeRepository()
        _ = try await repository.upsert(Self.makeArticle(id: "repo-fav"))

        let first = try await repository.toggleFavorite(articleID: "repo-fav")
        let second = try await repository.toggleFavorite(articleID: "repo-fav")

        #expect(first == true)
        #expect(second == false)

        let favorites = try await repository.fetchFavorites()
        #expect(favorites.isEmpty)
    }

    @Test
    func recordOpenAppendsHistoryAndMarksRead() async throws {
        let repository = try Self.makeRepository()
        _ = try await repository.upsert(Self.makeArticle(id: "repo-hist"))

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try await repository.recordOpen(articleID: "repo-hist", timestamp: base)
        try await repository.recordOpen(
            articleID: "repo-hist",
            timestamp: base.addingTimeInterval(60)
        )

        let history = try await repository.fetchHistory(limit: 10)
        #expect(history.count == 2)
        #expect(history.first?.timestamp == base.addingTimeInterval(60))

        let article = try await repository.fetchArticle(id: "repo-hist")
        #expect(article?.isRead == true)
    }

    // MARK: - Error path

    @Test
    func toggleFavoriteThrowsWhenArticleMissing() async throws {
        let repository = try Self.makeRepository()

        await #expect(throws: ArticleLocalStoreError.articleNotFound(id: "missing-id")) {
            _ = try await repository.toggleFavorite(articleID: "missing-id")
        }
    }
}
