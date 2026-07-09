//
//  FeedSourcesViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 01/07/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Regression coverage for issues #78 and #102 — the persisted
/// `enabledRegionRawValues` must be exactly the explicit opt-in list.
/// With the Italy-only catalog (#102) the picker hides the region row,
/// so `load()` auto-enables the lone region.
@MainActor
@Suite("FeedSourcesViewModel")
struct FeedSourcesViewModelTests {
    @Test
    func singleRegionCatalogAutoEnablesItalyOnLoad() throws {
        // Italy-only scope (issue #102): the catalog exposes one region
        // and the picker hides the region row, so `load()` must enable
        // it automatically and persist the explicit opt-in.
        let (viewModel, service) = try makeViewModel()

        viewModel.load()

        #expect(viewModel.isSingleRegionCatalog == true)
        #expect(viewModel.regions.count == 1)
        #expect(viewModel.regions.first?.region == .italy)
        #expect(viewModel.regions.first?.isEnabled == true)
        #expect(viewModel.hasAtLeastOneRegionEnabled == true)
        let stored = try service.loadPreferences()
        #expect(stored.enabledRegionRawValues == [RSSFeedRegion.italy.rawValue])
    }

    @Test
    func toggleRegionOffRemovesItFromExplicitList() throws {
        let (viewModel, service) = try makeViewModel()
        viewModel.load()

        // Auto-enabled on load; an explicit toggle still removes it from
        // the persisted opt-in list (no "empty = all" magic).
        viewModel.toggleRegion(.italy)

        let stored = try service.loadPreferences()
        #expect(stored.enabledRegionRawValues.isEmpty)
        let italian = viewModel.regions.first(where: { $0.region == .italy })
        #expect(italian?.isEnabled == false)
    }

    @Test
    func toggleSourceMirrorsHiddenSourcesForImmediateRedraw() throws {
        let (viewModel, service) = try makeViewModel()
        viewModel.load()

        guard let sample = viewModel.outlets(for: .italy).first?.source else {
            Issue.record("Expected at least one Italy outlet in the catalog fixture")
            return
        }

        viewModel.toggleSource(sample)

        #expect(viewModel.hiddenSources.contains(sample.id))
        let outlet = viewModel.outlets(for: .italy).first(where: { $0.source.id == sample.id })
        #expect(outlet?.isEnabled == false)
        let stored = try service.loadPreferences()
        #expect(stored.hiddenSources.contains(sample.id))
    }

    // MARK: - Cache purge on preference change (issue #94)

    @Test
    func togglingRegionOffPurgesItsCachedArticlesButKeepsFavorites() throws {
        let (viewModel, service, context) = try makeViewModelWithArticleCache()
        _ = try service.updatePreferences(
            .init(enabledRegionRawValues: [
                RSSFeedRegion.italy.rawValue,
                RSSFeedRegion.france.rawValue
            ])
        )
        context.insert(makeCachedEntity(id: "it-a", sourceID: "it-1", sourceName: "IT 1"))
        context.insert(makeCachedEntity(id: "fr-a", sourceID: "fr-1", sourceName: "FR 1"))
        let favorite = makeCachedEntity(id: "fr-fav", sourceID: "fr-1", sourceName: "FR 1")
        favorite.isBookmarked = true
        context.insert(favorite)
        try context.save()
        viewModel.load()

        viewModel.toggleRegion(.france)

        let stored = try service.loadPreferences()
        #expect(stored.enabledRegionRawValues == [RSSFeedRegion.italy.rawValue])
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(Set(remaining.map(\.id)) == ["it-a", "fr-fav"])
    }

    @Test
    func hidingSourcePurgesItsCachedArticles() throws {
        let (viewModel, service, context) = try makeViewModelWithArticleCache()
        _ = try service.updatePreferences(
            .init(enabledRegionRawValues: [RSSFeedRegion.italy.rawValue])
        )
        context.insert(makeCachedEntity(id: "it-a", sourceID: "it-1", sourceName: "IT 1"))
        context.insert(makeCachedEntity(id: "it-b", sourceID: "it-2", sourceName: "IT 2"))
        try context.save()
        viewModel.load()

        viewModel.toggleSource(fixtureCatalog()[1]) // hide it-2

        let stored = try service.loadPreferences()
        #expect(stored.hiddenSources == ["it-2"])
        let remaining = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(remaining.map(\.id) == ["it-a"])
    }

    // MARK: - Helpers

    private func makeViewModel() throws -> (FeedSourcesViewModel, UserPreferencesService) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserPreferenceEntity.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let service = UserPreferencesService(modelContext: context)
        return (FeedSourcesViewModel(service: service), service)
    }

    /// Full-schema variant for the issue #94 purge tests: the container
    /// also holds `ArticleEntity` rows and the view model carries a live
    /// `ArticleCacheMaintenanceService` bound to a fixture catalog.
    private func makeViewModelWithArticleCache() throws
        -> (FeedSourcesViewModel, UserPreferencesService, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: StoredArticle.self,
            ArticleEntity.self,
            ClusterEntity.self,
            UserPreferenceEntity.self,
            InteractionEntity.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let service = UserPreferencesService(modelContext: context)
        let maintenance = ArticleCacheMaintenanceService(
            modelContext: context,
            sourceFilter: RSSSourceFilter(allSources: fixtureCatalog())
        )
        let viewModel = FeedSourcesViewModel(service: service, cacheMaintenance: maintenance)
        return (viewModel, service, context)
    }

    private func fixtureCatalog() -> [RSSFeedSource] {
        [
            makeSource(id: "it-1", outletName: "IT 1", region: .italy),
            makeSource(id: "it-2", outletName: "IT 2", region: .italy),
            makeSource(id: "fr-1", outletName: "FR 1", region: .france)
        ]
    }

    private func makeSource(
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

    private func makeCachedEntity(
        id: String,
        sourceID: String?,
        sourceName: String
    ) -> ArticleEntity {
        ArticleEntity(
            id: id,
            title: "Cached \(id)",
            sourceName: sourceName,
            sourceID: sourceID,
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/\(id)"
        )
    }
}
