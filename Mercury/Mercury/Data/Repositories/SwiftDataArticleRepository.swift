//
//  SwiftDataArticleRepository.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData

/// SwiftData-backed concrete `ArticleRepository`.
///
/// The repository owns a private `ArticleLocalStore` and forwards every
/// call to it. Keeping the store as the single point of SwiftData access
/// avoids duplicating the predicate, sort, and logging logic that already
/// lives there; the repository's job is purely to expose that surface
/// through the domain-level protocol.
///
/// The actor isolation is provided by the wrapped store (`@ModelActor`),
/// so this repository is itself `Sendable` and lock-free. Every method
/// awaits the store and propagates the supplied `requestID` so the
/// store's existing AppLogger traces stay end-to-end without the
/// repository duplicating them.
final class SwiftDataArticleRepository: ArticleRepository {
    private let store: ArticleLocalStore

    /// Convenience initializer that constructs the backing
    /// `ArticleLocalStore` from a shared `ModelContainer`.
    init(modelContainer: ModelContainer) {
        self.store = ArticleLocalStore(modelContainer: modelContainer)
    }

    /// Test seam: inject a pre-built store (used by repository unit tests
    /// to share an in-memory container across calls).
    init(store: ArticleLocalStore) {
        self.store = store
    }

    // MARK: - Save / upsert

    @discardableResult
    func upsert(_ article: ArticleEntity, requestID: String?) async throws -> ArticleEntity {
        try await store.upsert(article, requestID: requestID)
    }

    @discardableResult
    func upsertAll(_ articles: [ArticleEntity], requestID: String?) async throws -> Int {
        try await store.upsertAll(articles, requestID: requestID)
    }

    // MARK: - Queries

    func fetchArticles(_ query: ArticleQuery, requestID: String?) async throws -> [ArticleEntity] {
        try await store.fetchArticles(query, requestID: requestID)
    }

    func fetchArticle(id: String, requestID: String?) async throws -> ArticleEntity? {
        try await store.fetchArticle(id: id, requestID: requestID)
    }

    func fetchFavorites(requestID: String?) async throws -> [ArticleEntity] {
        try await store.fetchFavorites(requestID: requestID)
    }

    // MARK: - User actions

    @discardableResult
    func toggleFavorite(articleID: String, requestID: String?) async throws -> Bool {
        try await store.toggleFavorite(articleID: articleID, requestID: requestID)
    }

    func markAsRead(articleID: String, requestID: String?) async throws {
        try await store.markAsRead(articleID: articleID, requestID: requestID)
    }

    func recordOpen(
        articleID: String,
        markAsRead: Bool,
        timestamp: Date,
        readingDuration: Double?,
        scrollDepth: Double?,
        requestID: String?
    ) async throws {
        try await store.recordOpen(
            articleID: articleID,
            markAsRead: markAsRead,
            timestamp: timestamp,
            readingDuration: readingDuration,
            scrollDepth: scrollDepth,
            requestID: requestID
        )
    }

    func fetchHistory(limit: Int, requestID: String?) async throws -> [InteractionEntity] {
        try await store.fetchHistory(limit: limit, requestID: requestID)
    }

    func clearHistory(requestID: String?) async throws {
        try await store.clearHistory(requestID: requestID)
    }
}
