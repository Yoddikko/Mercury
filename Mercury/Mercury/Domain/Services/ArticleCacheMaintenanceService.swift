//
//  ArticleCacheMaintenanceService.swift
//  Mercury
//
//  Created by Claude on 02/07/26.
//

import Foundation
import SwiftData

/// Owns cleanup of the on-device `ArticleEntity` cache (issue #94).
///
/// Two responsibilities:
///
/// * **Purge on preference change** — when the user toggles Feed sources
///   (Settings or onboarding), cached articles from now-disabled sources are
///   deleted so they can never resurface through the cold-start replay.
/// * **Retention sweep** — a time-based cap that deletes stale cached rows
///   at refresh time so the cache cannot grow unbounded.
///
/// Both operations NEVER delete favorited articles (`isBookmarked == true`):
/// bookmarking is the user's explicit "keep this" signal
/// (`ArticleLocalStore.toggleFavorite`), so favorites survive source
/// disabling and retention alike.
///
/// The service is `@MainActor` because it works on the SwiftUI-provided
/// `ModelContext`, matching the `UserPreferencesService` pattern.
@MainActor
final class ArticleCacheMaintenanceService {
    private static let serviceName = "ArticleCacheMaintenanceService"

    /// Retention policy: non-favorite cached articles older than this many
    /// days are deleted by `enforceRetention`. Age is measured on
    /// `createdAt` (ingest time) rather than `publishedAt`, because feeds
    /// with unparsable dates persist `publishedAt == .distantPast` and
    /// would otherwise be purged immediately.
    static let defaultRetentionDays = 30

    private let modelContext: ModelContext
    private let sourceFilter: RSSSourceFilter
    private let logger: AppLogger
    private let now: @MainActor () -> Date

    init(
        modelContext: ModelContext,
        sourceFilter: RSSSourceFilter = RSSSourceFilter(),
        logger: AppLogger = .shared,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.sourceFilter = sourceFilter
        self.logger = logger
        self.now = now
    }

    /// Delete cached articles whose source is no longer enabled by the
    /// supplied preferences. Favorited articles are always preserved.
    ///
    /// Matching mirrors the cache replay filter: rows stamped with a
    /// `sourceID` are compared against the resolved outlet ids; legacy rows
    /// fall back to `sourceName` vs. outlet display names. When the
    /// preferences impose no filter (pre-onboarding record) the purge is a
    /// no-op.
    ///
    /// - Returns: the number of deleted rows.
    @discardableResult
    func purgeDisabledSources(
        preferences: UserPreference,
        requestID: String? = nil
    ) throws -> Int {
        let traceID = requestID ?? makeRequestID(prefix: "cache-purge")

        guard let allowList = sourceFilter.makeArticleAllowList(for: preferences) else {
            logger.debug(
                "Skipping source purge: preferences impose no filter",
                category: .cache,
                service: Self.serviceName,
                requestID: traceID
            )
            return 0
        }

        logger.info(
            "Purging cached articles from disabled sources",
            category: .cache,
            service: Self.serviceName,
            requestID: traceID,
            metadata: [
                "allowed_source_ids": "\(allowList.sourceIDs.count)",
                "enabled_regions": "\(preferences.enabledRegionRawValues.count)",
                "hidden_sources": "\(preferences.hiddenSources.count)"
            ]
        )

        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.isBookmarked == false }
        )
        let candidates = try fetch(descriptor, requestID: traceID, op: "purgeDisabledSources")
        let disallowed = candidates.filter { entity in
            allowList.allows(sourceID: entity.sourceID, sourceName: entity.sourceName) == false
        }

        guard disallowed.isEmpty == false else {
            logger.debug(
                "Source purge found nothing to delete",
                category: .cache,
                service: Self.serviceName,
                requestID: traceID,
                metadata: ["candidates_in": "\(candidates.count)"]
            )
            return 0
        }

        for entity in disallowed {
            modelContext.delete(entity)
        }
        try save(requestID: traceID, op: "purgeDisabledSources")

        logger.info(
            "Purged cached articles from disabled sources",
            category: .cache,
            service: Self.serviceName,
            requestID: traceID,
            metadata: [
                "candidates_in": "\(candidates.count)",
                "purged_rows": "\(disallowed.count)"
            ]
        )
        return disallowed.count
    }

    /// Delete non-favorite cached articles ingested more than
    /// `maxAgeDays` days ago (default: 30, see `defaultRetentionDays`).
    /// Runs at feed refresh time from `HomeViewModel`.
    ///
    /// - Returns: the number of deleted rows.
    @discardableResult
    func enforceRetention(
        maxAgeDays: Int = ArticleCacheMaintenanceService.defaultRetentionDays,
        requestID: String? = nil
    ) throws -> Int {
        let traceID = requestID ?? makeRequestID(prefix: "cache-retention")
        let cutoff = now().addingTimeInterval(-TimeInterval(max(1, maxAgeDays)) * 86_400)

        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.isBookmarked == false && $0.createdAt < cutoff }
        )
        let expired = try fetch(descriptor, requestID: traceID, op: "enforceRetention")

        guard expired.isEmpty == false else {
            logger.trace(
                "Retention sweep found nothing to delete",
                category: .cache,
                service: Self.serviceName,
                requestID: traceID,
                metadata: ["max_age_days": "\(maxAgeDays)"]
            )
            return 0
        }

        for entity in expired {
            modelContext.delete(entity)
        }
        try save(requestID: traceID, op: "enforceRetention")

        logger.info(
            "Retention sweep purged stale cached articles",
            category: .cache,
            service: Self.serviceName,
            requestID: traceID,
            metadata: [
                "max_age_days": "\(maxAgeDays)",
                "purged_rows": "\(expired.count)"
            ]
        )
        return expired.count
    }

    // MARK: - Private helpers

    private func fetch(
        _ descriptor: FetchDescriptor<ArticleEntity>,
        requestID: String,
        op: String
    ) throws -> [ArticleEntity] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error(
                "Cache maintenance fetch failed",
                category: .cache,
                service: Self.serviceName,
                requestID: requestID,
                metadata: ["op": op, "error": String(describing: error)]
            )
            throw error
        }
    }

    private func save(requestID: String, op: String) throws {
        do {
            try modelContext.save()
        } catch {
            logger.error(
                "Cache maintenance save failed",
                category: .cache,
                service: Self.serviceName,
                requestID: requestID,
                metadata: ["op": op, "error": String(describing: error)]
            )
            throw error
        }
    }

    private func makeRequestID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.lowercased())"
    }
}
