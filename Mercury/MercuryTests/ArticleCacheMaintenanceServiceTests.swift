//
//  ArticleCacheMaintenanceServiceTests.swift
//  MercuryTests
//
//  Created by Claude on 02/07/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Coverage for the cache cleanup introduced by issue #94: purging cached
/// articles from now-disabled sources on preference change, and the
/// time-based retention sweep. Both must NEVER delete favorited rows.
@MainActor
@Suite("ArticleCacheMaintenanceService")
struct ArticleCacheMaintenanceServiceTests {
    // MARK: - purgeDisabledSources

    @Test
    func purgeDeletesRowsFromDisabledSourcesAndKeepsEnabledOnes() throws {
        let context = try Self.makeContext()
        context.insert(Self.makeEntity(id: "it-a", sourceID: "it-1", sourceName: "IT 1"))
        context.insert(Self.makeEntity(id: "fr-a", sourceID: "fr-1", sourceName: "FR 1"))
        try context.save()

        let service = Self.makeService(context: context)
        let purged = try service.purgeDisabledSources(preferences: Self.italyOnlyPreferences())

        #expect(purged == 1)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["it-a"])
    }

    @Test
    func purgeNeverDeletesFavoritedRows() throws {
        let context = try Self.makeContext()
        let favorite = Self.makeEntity(id: "fr-fav", sourceID: "fr-1", sourceName: "FR 1")
        favorite.isBookmarked = true
        context.insert(favorite)
        context.insert(Self.makeEntity(id: "fr-plain", sourceID: "fr-1", sourceName: "FR 1"))
        try context.save()

        let service = Self.makeService(context: context)
        let purged = try service.purgeDisabledSources(preferences: Self.italyOnlyPreferences())

        #expect(purged == 1)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["fr-fav"])
        #expect(remaining.first?.isBookmarked == true)
    }

    @Test
    func purgeMatchesLegacyRowsBySourceNameFallback() throws {
        let context = try Self.makeContext()
        // Legacy rows: persisted before `sourceID` existed.
        context.insert(Self.makeEntity(id: "legacy-it", sourceID: nil, sourceName: "IT 1"))
        context.insert(Self.makeEntity(id: "legacy-fr", sourceID: nil, sourceName: "FR 1"))
        try context.save()

        let service = Self.makeService(context: context)
        let purged = try service.purgeDisabledSources(preferences: Self.italyOnlyPreferences())

        #expect(purged == 1)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["legacy-it"])
    }

    @Test
    func purgeRespectsHiddenSourcesWithinEnabledRegion() throws {
        let context = try Self.makeContext()
        context.insert(Self.makeEntity(id: "it-a", sourceID: "it-1", sourceName: "IT 1"))
        context.insert(Self.makeEntity(id: "it-b", sourceID: "it-2", sourceName: "IT 2"))
        try context.save()

        let preferences = Self.makePreferences(
            enabledRegionRawValues: [RSSFeedRegion.italy.rawValue],
            hiddenSources: ["it-2"]
        )
        let service = Self.makeService(context: context)
        let purged = try service.purgeDisabledSources(preferences: preferences)

        #expect(purged == 1)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["it-a"])
    }

    @Test
    func purgeIsNoOpWhenPreferencesImposeNoFilter() throws {
        let context = try Self.makeContext()
        context.insert(Self.makeEntity(id: "fr-a", sourceID: "fr-1", sourceName: "FR 1"))
        try context.save()

        let service = Self.makeService(context: context)
        let purged = try service.purgeDisabledSources(
            preferences: Self.makePreferences(enabledRegionRawValues: [], hiddenSources: [])
        )

        #expect(purged == 0)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.count == 1)
    }

    // MARK: - enforceRetention

    @Test
    func retentionDeletesRowsOlderThanCutoffAndKeepsRecentOnes() throws {
        let context = try Self.makeContext()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let stale = Self.makeEntity(id: "stale", sourceID: "it-1", sourceName: "IT 1")
        stale.createdAt = now.addingTimeInterval(-31 * 86_400)
        let fresh = Self.makeEntity(id: "fresh", sourceID: "it-1", sourceName: "IT 1")
        fresh.createdAt = now.addingTimeInterval(-1 * 86_400)
        context.insert(stale)
        context.insert(fresh)
        try context.save()

        let service = Self.makeService(context: context, now: now)
        let purged = try service.enforceRetention()

        #expect(purged == 1)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["fresh"])
    }

    @Test
    func retentionNeverDeletesFavoritedRows() throws {
        let context = try Self.makeContext()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let staleFavorite = Self.makeEntity(id: "stale-fav", sourceID: "it-1", sourceName: "IT 1")
        staleFavorite.createdAt = now.addingTimeInterval(-90 * 86_400)
        staleFavorite.isBookmarked = true
        context.insert(staleFavorite)
        try context.save()

        let service = Self.makeService(context: context, now: now)
        let purged = try service.enforceRetention()

        #expect(purged == 0)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["stale-fav"])
    }

    @Test
    func retentionHonorsCustomMaxAge() throws {
        let context = try Self.makeContext()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let entity = Self.makeEntity(id: "seven-days-old", sourceID: "it-1", sourceName: "IT 1")
        entity.createdAt = now.addingTimeInterval(-8 * 86_400)
        context.insert(entity)
        try context.save()

        let service = Self.makeService(context: context, now: now)
        // Default window (30 days) keeps the row...
        #expect(try service.enforceRetention() == 0)
        // ...a tighter 7-day window purges it.
        #expect(try service.enforceRetention(maxAgeDays: 7) == 1)
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.isEmpty)
    }

    // MARK: - Helpers

    private static func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: StoredArticle.self,
            ArticleEntity.self,
            ClusterEntity.self,
            UserPreferenceEntity.self,
            InteractionEntity.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private static func makeService(
        context: ModelContext,
        now: Date = .now
    ) -> ArticleCacheMaintenanceService {
        ArticleCacheMaintenanceService(
            modelContext: context,
            sourceFilter: RSSSourceFilter(allSources: sampleCatalog()),
            now: { now }
        )
    }

    /// Two-region fixture catalog so the tests never depend on the real
    /// `RSSFeedCatalog` contents.
    private static func sampleCatalog() -> [RSSFeedSource] {
        [
            makeSource(id: "it-1", outletName: "IT 1", region: .italy),
            makeSource(id: "it-2", outletName: "IT 2", region: .italy),
            makeSource(id: "fr-1", outletName: "FR 1", region: .france)
        ]
    }

    private static func makeSource(
        id: String,
        outletName: String,
        region: RSSFeedRegion
    ) -> RSSFeedSource {
        RSSFeedSource(
            id: id,
            outletName: outletName,
            region: region,
            feedURLString: "https://example.com/\(id)",
            isMainOutlet: true,
            languageCode: "en",
            tags: [],
            note: nil
        )
    }

    private static func italyOnlyPreferences() -> UserPreference {
        makePreferences(
            enabledRegionRawValues: [RSSFeedRegion.italy.rawValue],
            hiddenSources: []
        )
    }

    private static func makePreferences(
        enabledRegionRawValues: [String],
        hiddenSources: [String]
    ) -> UserPreference {
        UserPreference(
            id: "test-preferences",
            preferredCategories: [],
            preferredTopics: [],
            hiddenSources: hiddenSources,
            favoriteSources: [],
            preferredLanguage: nil,
            enabledRegionRawValues: enabledRegionRawValues,
            hasCompletedOnboarding: true,
            updatedAt: .now
        )
    }

    private static func makeEntity(
        id: String,
        sourceID: String?,
        sourceName: String
    ) -> ArticleEntity {
        ArticleEntity(
            id: id,
            title: "Article \(id)",
            sourceName: sourceName,
            sourceID: sourceID,
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/\(id)"
        )
    }
}
