//
//  ArticleRepository.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Abstraction over local article persistence and the article-scoped
/// interaction history.
///
/// `ArticleRepository` is the domain-facing contract that view models,
/// services, and use cases depend on. The concrete SwiftData-backed
/// implementation lives in `Data/Repositories/SwiftDataArticleRepository`
/// and is the only type that should touch `ArticleLocalStore` /
/// `ModelContext` directly. A future Firebase sync layer (issue #12) can
/// adopt the same protocol without touching consumers.
///
/// The protocol mirrors the public surface of `ArticleLocalStore` 1:1 so
/// repositories can wrap the store today and call-sites can migrate one at
/// a time without behavioral drift. Method parameter shapes intentionally
/// match the store, including the optional `requestID` used for AppLogger
/// trace propagation.
///
/// Implementations are `Sendable` and isolate persistence access however
/// they like (the SwiftData implementation is an actor); callers must
/// `await` every call.
protocol ArticleRepository: Sendable {
    // MARK: - Save / upsert

    /// Insert a new article or update the existing one (matched by `id`).
    @discardableResult
    func upsert(_ article: ArticleEntity, requestID: String?) async throws -> ArticleEntity

    /// Bulk-upsert variant. Returns the number of articles persisted.
    @discardableResult
    func upsertAll(_ articles: [ArticleEntity], requestID: String?) async throws -> Int

    // MARK: - Queries

    /// Fetch articles that match `query`, applying the requested ordering
    /// and optional limit.
    func fetchArticles(_ query: ArticleQuery, requestID: String?) async throws -> [ArticleEntity]

    /// Fetch the single article with the supplied identifier, or `nil`
    /// when no match exists.
    func fetchArticle(id: String, requestID: String?) async throws -> ArticleEntity?

    /// Convenience wrapper for the bookmarked-articles list.
    func fetchFavorites(requestID: String?) async throws -> [ArticleEntity]

    // MARK: - User actions

    /// Toggle `isBookmarked` on the article with `id`. Returns the new
    /// value. Throws `ArticleLocalStoreError.articleNotFound` when the
    /// article cannot be located.
    @discardableResult
    func toggleFavorite(articleID: String, requestID: String?) async throws -> Bool

    /// Mark the article as read (idempotent).
    func markAsRead(articleID: String, requestID: String?) async throws

    /// Record an article-open interaction in the history. Optionally also
    /// flips `isRead` on the article.
    func recordOpen(
        articleID: String,
        markAsRead: Bool,
        timestamp: Date,
        readingDuration: Double?,
        scrollDepth: Double?,
        requestID: String?
    ) async throws

    /// Recent open-history entries, newest first.
    func fetchHistory(limit: Int, requestID: String?) async throws -> [InteractionEntity]

    /// Delete every persisted open-history entry.
    func clearHistory(requestID: String?) async throws
}

// MARK: - Convenience defaults

extension ArticleRepository {
    @discardableResult
    func upsert(_ article: ArticleEntity) async throws -> ArticleEntity {
        try await upsert(article, requestID: nil)
    }

    @discardableResult
    func upsertAll(_ articles: [ArticleEntity]) async throws -> Int {
        try await upsertAll(articles, requestID: nil)
    }

    func fetchArticles(_ query: ArticleQuery = ArticleQuery()) async throws -> [ArticleEntity] {
        try await fetchArticles(query, requestID: nil)
    }

    func fetchArticle(id: String) async throws -> ArticleEntity? {
        try await fetchArticle(id: id, requestID: nil)
    }

    func fetchFavorites() async throws -> [ArticleEntity] {
        try await fetchFavorites(requestID: nil)
    }

    @discardableResult
    func toggleFavorite(articleID: String) async throws -> Bool {
        try await toggleFavorite(articleID: articleID, requestID: nil)
    }

    func markAsRead(articleID: String) async throws {
        try await markAsRead(articleID: articleID, requestID: nil)
    }

    func recordOpen(
        articleID: String,
        markAsRead: Bool = true,
        timestamp: Date = .now,
        readingDuration: Double? = nil,
        scrollDepth: Double? = nil
    ) async throws {
        try await recordOpen(
            articleID: articleID,
            markAsRead: markAsRead,
            timestamp: timestamp,
            readingDuration: readingDuration,
            scrollDepth: scrollDepth,
            requestID: nil
        )
    }

    func fetchHistory(limit: Int = 50) async throws -> [InteractionEntity] {
        try await fetchHistory(limit: limit, requestID: nil)
    }

    func clearHistory() async throws {
        try await clearHistory(requestID: nil)
    }
}
