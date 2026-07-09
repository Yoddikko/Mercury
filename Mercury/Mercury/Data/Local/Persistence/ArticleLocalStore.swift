//
//  ArticleLocalStore.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData

/// Local persistence service for `ArticleEntity` and the article-scoped
/// `InteractionEntity` history.
///
/// `ArticleLocalStore` is the concrete SwiftData-backed service that
/// view models and use cases call to save articles coming from the RSS
/// pipeline, query them for the feed/detail screens, toggle favorites,
/// mark articles as read, and append open-history entries.
///
/// A repository protocol abstraction (issue #29) and use cases (issue #30)
/// will be layered on top of this type; the store deliberately stays
/// concrete and free of higher-level orchestration to keep responsibilities
/// narrow.
@ModelActor
actor ArticleLocalStore {
    private static let serviceName = "ArticleLocalStore"

    // MARK: - Save / upsert

    /// Insert a new article or update the existing one (matched by `id`).
    ///
    /// `updatedAt` is refreshed automatically on every upsert so callers
    /// don't need to track it explicitly.
    @discardableResult
    func upsert(_ article: ArticleEntity, requestID: String? = nil) throws -> ArticleEntity {
        AppLogger.shared.trace(
            "Upserting article",
            category: .database,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["article_id": article.id, "source": article.sourceName]
        )

        let id = article.id
        if let existing = try fetchEntity(id: id) {
            existing.title = article.title
            existing.sourceName = article.sourceName
            // Keep the already-stamped source id when the incoming row does
            // not carry one (issue #94): a legacy in-memory copy must not
            // wipe the ingest-time stamp.
            existing.sourceID = article.sourceID ?? existing.sourceID
            existing.sourceURL = article.sourceURL
            existing.articleURL = article.articleURL
            existing.publishedAt = article.publishedAt
            existing.rawContent = article.rawContent
            existing.cleanedContent = article.cleanedContent
            existing.summaryShort = article.summaryShort
            existing.summaryBullets = article.summaryBullets
            // Keep the user-generated AI summary across RSS refreshes: the
            // incoming ingest row never carries one (issue #100).
            existing.aiSummaryShort = article.aiSummaryShort ?? existing.aiSummaryShort
            existing.aiSummaryBullets = article.aiSummaryBullets ?? existing.aiSummaryBullets
            existing.category = article.category
            existing.tags = article.tags
            existing.language = article.language
            // Preserve the user-controlled flags rather than letting an RSS
            // refresh wipe them out.
            existing.clusterID = article.clusterID ?? existing.clusterID
            existing.updatedAt = .now
            try save(requestID: requestID, op: "upsert.update", articleID: id)
            return existing
        }

        modelContext.insert(article)
        try save(requestID: requestID, op: "upsert.insert", articleID: id)
        return article
    }

    /// Bulk-upsert variant. Returns the number of articles persisted.
    @discardableResult
    func upsertAll(_ articles: [ArticleEntity], requestID: String? = nil) throws -> Int {
        AppLogger.shared.debug(
            "Bulk upserting articles",
            category: .database,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["items_in": "\(articles.count)"]
        )
        for article in articles {
            _ = try upsert(article, requestID: requestID)
        }
        return articles.count
    }

    // MARK: - Queries

    /// Fetch articles that match `query`, applying the requested ordering and
    /// optional limit.
    func fetchArticles(_ query: ArticleQuery = ArticleQuery(), requestID: String? = nil) throws -> [ArticleEntity] {
        AppLogger.shared.trace(
            "Fetching articles",
            category: .database,
            service: Self.serviceName,
            requestID: requestID,
            metadata: [
                "only_bookmarked": "\(query.onlyBookmarked)",
                "only_unread": "\(query.onlyUnread)",
                "has_search_text": "\(query.searchText != nil)",
                "limit": query.limit.map(String.init) ?? "nil"
            ]
        )

        var descriptor = FetchDescriptor<ArticleEntity>(
            predicate: Self.predicate(for: query),
            sortBy: Self.sortDescriptors(for: query.sort)
        )
        // When the query carries a free-text search, the limit is applied
        // *after* the in-memory substring filter below to keep the
        // result count meaningful. Without search, push the limit down
        // to SwiftData so the fetch is cheap.
        if let limit = query.limit, query.searchText == nil {
            descriptor.fetchLimit = limit
        }

        do {
            let fetched = try modelContext.fetch(descriptor)
            guard let searchText = query.searchText else { return fetched }

            let filtered = fetched.filter { article in
                article.title.localizedStandardContains(searchText) ||
                (article.cleanedContent ?? "").localizedStandardContains(searchText)
            }
            if let limit = query.limit {
                return Array(filtered.prefix(limit))
            }
            return filtered
        } catch {
            AppLogger.shared.error(
                "Article fetch failed",
                category: .database,
                service: Self.serviceName,
                requestID: requestID,
                metadata: ["error": String(describing: error)]
            )
            throw ArticleLocalStoreError.persistenceFailure(message: String(describing: error))
        }
    }

    /// Fetch the single article with the supplied identifier, or `nil` if
    /// no match exists.
    /// Feed replay fetch (issue #111): newest-first rows mapped to the
    /// value-type `Article` INSIDE the actor, so the main thread never
    /// touches SwiftData for the launch cache replay (`@Model` entities
    /// are not Sendable and must not cross the actor boundary).
    func fetchRecentFeedArticles(limit: Int, requestID: String? = nil) throws -> [Article] {
        var descriptor = FetchDescriptor<ArticleEntity>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(1, limit)
        let entities = try modelContext.fetch(descriptor)
        let articles = entities.compactMap(ArticleEntityMapper.makeArticle(from:))
        AppLogger.shared.debug(
            "Fetched recent feed articles off-main",
            category: .database,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["entities": "\(entities.count)", "articles": "\(articles.count)"]
        )
        return articles
    }

    func fetchArticle(id: String, requestID: String? = nil) throws -> ArticleEntity? {
        AppLogger.shared.trace(
            "Fetching article by id",
            category: .database,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["article_id": id]
        )
        return try fetchEntity(id: id)
    }

    /// Convenience wrapper for the bookmarked-articles list.
    func fetchFavorites(requestID: String? = nil) throws -> [ArticleEntity] {
        try fetchArticles(
            ArticleQuery(onlyBookmarked: true, sort: .updatedAtDescending),
            requestID: requestID
        )
    }

    // MARK: - AI enrichment

    /// Persist the AI-generated summary on the article identified by
    /// `articleID`, refreshing `updatedAt` accordingly.
    ///
    /// This is the persistence seam used by
    /// `ArticleSummarizationService` so the cached `aiSummaryShort`/
    /// `aiSummaryBullets` survive subsequent app launches and avoid extra
    /// provider calls (see `docs/features/SUMMARIZATION.md`).
    func applySummary(
        articleID: String,
        summary: AISummaryResult,
        requestID: String? = nil
    ) throws {
        let article = try requireArticle(id: articleID, requestID: requestID, op: "applySummary")
        // Dedicated AI fields only (issue #100): `summaryShort` stays the
        // RSS/excerpt text shown on the feed card and must not be replaced,
        // or every fetched article would look like it has a cached summary.
        article.aiSummaryShort = summary.shortSummary
        article.aiSummaryBullets = summary.bullets
        article.updatedAt = .now
        try save(requestID: requestID, op: "applySummary", articleID: articleID)

        AppLogger.shared.info(
            "Persisted AI summary on article",
            category: .business,
            service: Self.serviceName,
            requestID: requestID,
            metadata: [
                "article_id": articleID,
                "bullets": "\(summary.bullets.count)"
            ]
        )
    }

    // MARK: - User actions

    /// Toggle `isBookmarked` on the article with `id`. Returns the new value.
    @discardableResult
    func toggleFavorite(articleID: String, requestID: String? = nil) throws -> Bool {
        let article = try requireArticle(id: articleID, requestID: requestID, op: "toggleFavorite")
        article.isBookmarked.toggle()
        article.updatedAt = .now

        try recordInteraction(
            articleID: articleID,
            type: .bookmarkToggle,
            timestamp: .now,
            requestID: requestID,
            persistImmediately: false
        )
        try save(requestID: requestID, op: "toggleFavorite", articleID: articleID)

        AppLogger.shared.info(
            "Toggled favorite",
            category: .business,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["article_id": articleID, "is_bookmarked": "\(article.isBookmarked)"]
        )
        return article.isBookmarked
    }

    /// Mark the article as read (idempotent). Always logs, but only writes if
    /// the value actually changed.
    func markAsRead(articleID: String, requestID: String? = nil) throws {
        let article = try requireArticle(id: articleID, requestID: requestID, op: "markAsRead")
        guard article.isRead == false else {
            AppLogger.shared.trace(
                "Article already marked as read",
                category: .business,
                service: Self.serviceName,
                requestID: requestID,
                metadata: ["article_id": articleID]
            )
            return
        }
        article.isRead = true
        article.updatedAt = .now

        try recordInteraction(
            articleID: articleID,
            type: .markRead,
            timestamp: .now,
            requestID: requestID,
            persistImmediately: false
        )
        try save(requestID: requestID, op: "markAsRead", articleID: articleID)

        AppLogger.shared.info(
            "Marked article as read",
            category: .business,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["article_id": articleID]
        )
    }

    /// Record an "open" event in the history. The associated article must
    /// exist; passing `markAsRead: true` also flips `isRead` on the article.
    func recordOpen(
        articleID: String,
        markAsRead: Bool = true,
        timestamp: Date = .now,
        readingDuration: Double? = nil,
        scrollDepth: Double? = nil,
        requestID: String? = nil
    ) throws {
        let article = try requireArticle(id: articleID, requestID: requestID, op: "recordOpen")

        try recordInteraction(
            articleID: articleID,
            type: .open,
            timestamp: timestamp,
            readingDuration: readingDuration,
            scrollDepth: scrollDepth,
            requestID: requestID,
            persistImmediately: false
        )

        if markAsRead, article.isRead == false {
            article.isRead = true
            article.updatedAt = .now
        }

        try save(requestID: requestID, op: "recordOpen", articleID: articleID)

        AppLogger.shared.info(
            "Recorded article open",
            category: .business,
            service: Self.serviceName,
            requestID: requestID,
            metadata: [
                "article_id": articleID,
                "marked_read": "\(markAsRead)",
                "reading_duration_ms": readingDuration.map { String(Int($0 * 1_000)) } ?? "nil"
            ]
        )
    }

    /// Recent open-history entries, newest first.
    func fetchHistory(limit: Int = 50, requestID: String? = nil) throws -> [InteractionEntity] {
        AppLogger.shared.trace(
            "Fetching history",
            category: .database,
            service: Self.serviceName,
            requestID: requestID,
            metadata: ["limit": "\(limit)"]
        )
        let openRaw = ArticleInteractionType.open.rawValue
        var descriptor = FetchDescriptor<InteractionEntity>(
            predicate: #Predicate { $0.actionType == openRaw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit)
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.shared.error(
                "History fetch failed",
                category: .database,
                service: Self.serviceName,
                requestID: requestID,
                metadata: ["error": String(describing: error)]
            )
            throw ArticleLocalStoreError.persistenceFailure(message: String(describing: error))
        }
    }

    /// Delete every persisted open-history entry. Useful for the privacy
    /// "clear history" affordance.
    func clearHistory(requestID: String? = nil) throws {
        AppLogger.shared.info(
            "Clearing article history",
            category: .business,
            service: Self.serviceName,
            requestID: requestID
        )
        let openRaw = ArticleInteractionType.open.rawValue
        try modelContext.delete(
            model: InteractionEntity.self,
            where: #Predicate { $0.actionType == openRaw }
        )
        try save(requestID: requestID, op: "clearHistory", articleID: nil)
    }

    // MARK: - Private helpers

    private func fetchEntity(id: String) throws -> ArticleEntity? {
        var descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func requireArticle(
        id: String,
        requestID: String?,
        op: String
    ) throws -> ArticleEntity {
        guard let article = try fetchEntity(id: id) else {
            AppLogger.shared.warn(
                "Article not found",
                category: .database,
                service: Self.serviceName,
                requestID: requestID,
                metadata: ["article_id": id, "op": op]
            )
            throw ArticleLocalStoreError.articleNotFound(id: id)
        }
        return article
    }

    private func recordInteraction(
        articleID: String,
        type: ArticleInteractionType,
        timestamp: Date,
        readingDuration: Double? = nil,
        scrollDepth: Double? = nil,
        requestID: String?,
        persistImmediately: Bool
    ) throws {
        let interaction = InteractionEntity(
            articleID: articleID,
            actionType: type.rawValue,
            timestamp: timestamp,
            readingDuration: readingDuration,
            scrollDepth: scrollDepth
        )
        modelContext.insert(interaction)
        if persistImmediately {
            try save(requestID: requestID, op: "recordInteraction.\(type.rawValue)", articleID: articleID)
        }
    }

    private func save(requestID: String?, op: String, articleID: String?) throws {
        do {
            try modelContext.save()
        } catch {
            AppLogger.shared.error(
                "SwiftData save failed",
                category: .database,
                service: Self.serviceName,
                requestID: requestID,
                metadata: [
                    "op": op,
                    "article_id": articleID ?? "nil",
                    "error": String(describing: error)
                ]
            )
            throw ArticleLocalStoreError.persistenceFailure(message: String(describing: error))
        }
    }

    // MARK: - Predicate builders

    private static func predicate(for query: ArticleQuery) -> Predicate<ArticleEntity>? {
        let publishedAfter = query.publishedAfter
        let publishedBefore = query.publishedBefore
        let sourceNames = query.sourceNames
        let onlyBookmarked = query.onlyBookmarked
        let onlyUnread = query.onlyUnread

        // SwiftData's `#Predicate` macro does not allow conditional
        // composition outside its closure, so every persistent filter is
        // expressed in a single predicate. The optional free-text
        // search (`query.searchText`) is intentionally *not* part of
        // this predicate: lowering `localizedStandardContains` into the
        // SwiftData macro alongside the other clauses either overruns
        // the type-checker or crashes at fetch time via the predicate
        // translator. `fetchArticles(_:requestID:)` applies the
        // search-text filter in-memory after the persistent fetch and
        // enforces `query.limit` after that filter to keep result
        // counts meaningful for the search UI.
        return #Predicate<ArticleEntity> { article in
            (publishedAfter == nil || article.publishedAt >= publishedAfter!) &&
            (publishedBefore == nil || article.publishedAt <= publishedBefore!) &&
            (sourceNames == nil || sourceNames!.contains(article.sourceName)) &&
            (onlyBookmarked == false || article.isBookmarked == true) &&
            (onlyUnread == false || article.isRead == false)
        }
    }

    private static func sortDescriptors(for sort: ArticleSortOrder) -> [SortDescriptor<ArticleEntity>] {
        switch sort {
        case .publishedAtDescending:
            return [SortDescriptor(\.publishedAt, order: .reverse)]
        case .publishedAtAscending:
            return [SortDescriptor(\.publishedAt, order: .forward)]
        case .createdAtDescending:
            return [SortDescriptor(\.createdAt, order: .reverse)]
        case .updatedAtDescending:
            return [SortDescriptor(\.updatedAt, order: .reverse)]
        }
    }
}
