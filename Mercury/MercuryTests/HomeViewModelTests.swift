//
//  HomeViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

@MainActor
struct HomeViewModelTests {
    @Test
    func topicsModeAggregatesLoadedArticles() async throws {
        // Two same-story titles from different outlets published now
        // (inside the 24h window) plus one unrelated: switching to
        // topics must pass through .aggregating and land on .ready.
        let now = Date()
        let articles = [
            Self.recentArticle(id: "a", source: "ansa", title: "Terremoto di magnitudo 5.2 nel centro Italia, scossa avvertita a Roma", publishedAt: now),
            Self.recentArticle(id: "b", source: "repubblica", title: "Forte scossa di terremoto magnitudo 5.2 nel centro Italia", publishedAt: now.addingTimeInterval(-600)),
            Self.recentArticle(id: "c", source: "gazzetta", title: "Calciomercato, rinnovo di contratto per il difensore argentino", publishedAt: now.addingTimeInterval(-1200))
        ]
        let viewModel = makeViewModel(deduplicatedArticles: articles)
        await viewModel.refresh()

        #expect(viewModel.displayMode == .chronological)
        viewModel.selectDisplayMode(.topics)
        #expect(viewModel.displayMode == .topics)

        var ready: [TopicCluster]?
        var readyMethod: HomeViewModel.TopicAggregationMethod?
        for _ in 0..<100 {
            if case let .ready(clusters, method) = viewModel.topicState {
                ready = clusters
                readyMethod = method
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let clusters = ready else {
            Issue.record("Expected .ready topic state, got \(viewModel.topicState)")
            return
        }
        #expect(clusters.count == 2)
        #expect(clusters[0].sourceCount == 2)
        #expect(clusters[0].isAggregated)
        // No AI grouper injected: the method must be lexical.
        #expect(readyMethod == .lexical)
    }

    @Test
    func topicsAggregateFullDayCorpusFromCacheWhenContextAttached() async throws {
        // The displayed feed carries ONE article, but the cache holds a
        // same-story pair inside the 24h window (issue #117): topics
        // must aggregate the cache corpus, not the displayed list.
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        let now = Date()
        let cachedA = ArticleEntity(
            id: "cache-a",
            title: "Terremoto di magnitudo 5.2 nel centro Italia, scossa avvertita a Roma",
            sourceName: "ansa",
            sourceID: "ansa",
            sourceURL: "https://example.com/ansa",
            articleURL: "https://example.com/ansa/cache-a",
            publishedAt: now.addingTimeInterval(-4 * 3600)
        )
        let cachedB = ArticleEntity(
            id: "cache-b",
            title: "Forte scossa di terremoto magnitudo 5.2 nel centro Italia",
            sourceName: "repubblica",
            sourceID: "repubblica",
            sourceURL: "https://example.com/repubblica",
            articleURL: "https://example.com/repubblica/cache-b",
            publishedAt: now.addingTimeInterval(-5 * 3600)
        )
        context.insert(cachedA)
        context.insert(cachedB)
        try context.save()

        let displayed = [
            Self.recentArticle(id: "live", source: "gazzetta", title: "Notizia sportiva del tutto scorrelata dal resto", publishedAt: now)
        ]
        let viewModel = makeViewModel(deduplicatedArticles: displayed)
        viewModel.attach(modelContext: context)
        await viewModel.refresh()
        viewModel.selectDisplayMode(.topics)

        var ready: [TopicCluster]?
        for _ in 0..<100 {
            if case let .ready(clusters, _) = viewModel.topicState {
                ready = clusters
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let clusters = ready else {
            Issue.record("Expected .ready topic state, got \(viewModel.topicState)")
            return
        }
        #expect(clusters.contains { cluster in
            cluster.isAggregated && cluster.sourceCount == 2
        })
    }

    @Test
    func topicsModeUsesAIGrouperWhenAvailable() async throws {
        let now = Date()
        let articles = [
            Self.recentArticle(id: "a", source: "ansa", title: "Prima notizia sul vertice europeo", publishedAt: now),
            Self.recentArticle(id: "b", source: "repubblica", title: "Seconda notizia completamente diversa sul campionato", publishedAt: now.addingTimeInterval(-300)),
            Self.recentArticle(id: "c", source: "tgcom24", title: "Terza notizia su tutt'altro argomento di cronaca", publishedAt: now.addingTimeInterval(-600))
        ]
        let result = RSSFeedBatchResult(
            checkedAt: .now,
            groupMode: .mainOutlets,
            selectedRegion: nil,
            checks: [],
            deduplicatedArticles: articles
        )
        // The AI grouper pairs two lexically-unrelated titles: only the
        // provider path can produce this cluster, proving it was used.
        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in result },
            isDeveloperModeEnabled: false,
            topicAIGrouper: { _, _ in [["a", "b"]] }
        )
        await viewModel.refresh()
        viewModel.selectDisplayMode(.topics)

        var outcome: (clusters: [TopicCluster], method: HomeViewModel.TopicAggregationMethod)?
        for _ in 0..<100 {
            if case let .ready(clusters, method) = viewModel.topicState {
                outcome = (clusters, method)
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let outcome else {
            Issue.record("Expected .ready topic state, got \(viewModel.topicState)")
            return
        }
        #expect(outcome.method == .ai)
        #expect(outcome.clusters.count == 2)
        #expect(outcome.clusters[0].isAggregated)
        #expect(Set([outcome.clusters[0].lead.id] + outcome.clusters[0].members.map(\.id)) == ["a", "b"])
    }

    @Test
    func topicsModeFallsBackToLexicalWhenAIGrouperThrows() async throws {
        let now = Date()
        let articles = [
            Self.recentArticle(id: "a", source: "ansa", title: "Terremoto di magnitudo 5.2 nel centro Italia, scossa avvertita a Roma", publishedAt: now),
            Self.recentArticle(id: "b", source: "repubblica", title: "Forte scossa di terremoto magnitudo 5.2 nel centro Italia", publishedAt: now.addingTimeInterval(-300))
        ]
        let result = RSSFeedBatchResult(
            checkedAt: .now,
            groupMode: .mainOutlets,
            selectedRegion: nil,
            checks: [],
            deduplicatedArticles: articles
        )
        struct NotConfigured: Error {}
        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in result },
            isDeveloperModeEnabled: false,
            topicAIGrouper: { _, _ in throw NotConfigured() }
        )
        await viewModel.refresh()
        viewModel.selectDisplayMode(.topics)

        var outcome: (clusters: [TopicCluster], method: HomeViewModel.TopicAggregationMethod)?
        for _ in 0..<100 {
            if case let .ready(clusters, method) = viewModel.topicState {
                outcome = (clusters, method)
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let outcome else {
            Issue.record("Expected .ready topic state, got \(viewModel.topicState)")
            return
        }
        #expect(outcome.method == .lexical)
        #expect(outcome.clusters.count == 1)
        #expect(outcome.clusters[0].sourceCount == 2)
    }

    private static func recentArticle(
        id: String,
        source: String,
        title: String,
        publishedAt: Date
    ) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: title,
            sourceName: source,
            sourceID: source,
            sourceURL: URL(string: "https://example.com/\(source)")!,
            articleURL: URL(string: "https://example.com/\(source)/\(id)")!,
            publishedAt: publishedAt,
            authorName: nil,
            heroImageURL: nil,
            rawContent: nil,
            cleanedContent: nil,
            contentSource: "test",
            contentWordCount: 0,
            isContentLikelyComplete: false,
            summaryShort: nil,
            summaryBullets: [],
            category: nil,
            tags: [],
            language: "it",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: publishedAt,
            updatedAt: publishedAt
        )
    }

    @Test
    func refreshTransitionsFromIdleToLoaded() async {
        let articles = Self.sampleArticles(count: 3)
        let viewModel = makeViewModel(deduplicatedArticles: articles)

        await viewModel.refresh()

        guard case let .loaded(loadedArticles) = viewModel.state else {
            Issue.record("Expected loaded state, got \(viewModel.state)")
            return
        }
        #expect(loadedArticles.count == articles.count)
        #expect(loadedArticles.first?.id == articles.first?.id)
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.lastUpdatedAt != nil)
        #expect(viewModel.hasArticles == true)
    }

    @Test
    func refreshTransitionsToEmptyWhenNoArticles() async {
        let viewModel = makeViewModel(
            deduplicatedArticles: [],
            checks: [Self.successCheck()]
        )

        await viewModel.refresh()

        #expect(viewModel.state == .empty)
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.lastUpdatedAt != nil)
        #expect(viewModel.hasArticles == false)
    }

    @Test
    func refreshTransitionsToFailedWhenAllSourcesFail() async {
        let viewModel = makeViewModel(
            deduplicatedArticles: [],
            checks: [
                Self.failedCheck(reason: .requestFailed),
                Self.failedCheck(reason: .parseFailed)
            ]
        )

        await viewModel.refresh()

        guard case let .failed(message) = viewModel.state else {
            Issue.record("Expected failed state, got \(viewModel.state)")
            return
        }
        #expect(message.isEmpty == false)
        #expect(viewModel.errorMessage == message)
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.lastUpdatedAt != nil)
    }

    @Test
    func loadInitialFeedUsesCachedArticlesBeforeRefresh() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        // Issue #87: the initial load only runs after onboarding completes.
        _ = try UserPreferencesService(modelContext: context)
            .updatePreferences(.init(hasCompletedOnboarding: true))
        let cachedArticle = Self.sampleArticles(count: 1, prefix: "cached").first!
        context.insert(ArticleEntityMapper.makeEntity(from: cachedArticle))
        try context.save()

        let networkArticles = Self.sampleArticles(count: 2, prefix: "network")
        let viewModel = makeViewModel(deduplicatedArticles: networkArticles)
        viewModel.attach(modelContext: context)

        await viewModel.loadInitialFeedIfNeeded()

        guard case let .loaded(loadedArticles) = viewModel.state else {
            Issue.record("Expected loaded state, got \(viewModel.state)")
            return
        }
        #expect(loadedArticles.contains { $0.id == networkArticles[0].id })
        #expect(loadedArticles.count == networkArticles.count)
    }

    @Test
    func refreshPersistsArticlesIntoSwiftData() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        let networkArticles = Self.sampleArticles(count: 2, prefix: "persisted")
        let viewModel = makeViewModel(deduplicatedArticles: networkArticles)
        viewModel.attach(modelContext: context)

        await viewModel.refresh()

        let stored = try context.fetch(FetchDescriptor<ArticleEntity>())
        #expect(stored.count == networkArticles.count)
        let storedIDs = Set(stored.map(\.id))
        let expectedIDs = Set(networkArticles.map(\.id))
        #expect(storedIDs == expectedIDs)
    }

    @Test
    func refreshForwardsResolvedSourcesWhenPreferencesFilterCatalog() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        // Seed preferences with an enabled region.
        let service = UserPreferencesService(modelContext: context)
        _ = try service.updatePreferences(
            .init(
                enabledRegionRawValues: [RSSFeedRegion.italy.rawValue],
                hasCompletedOnboarding: true
            )
        )

        let capturedSources = SourcesCapture()
        let articles = Self.sampleArticles(count: 1)
        let filter = RSSSourceFilter(allSources: [
            RSSFeedSource(
                id: "it-1",
                outletName: "IT 1",
                region: .italy,
                feedURLString: "https://example.com/it",
                isMainOutlet: true,
                languageCode: "it",
                tags: [],
                note: nil
            ),
            RSSFeedSource(
                id: "fr-1",
                outletName: "FR 1",
                region: .france,
                feedURLString: "https://example.com/fr",
                isMainOutlet: true,
                languageCode: "fr",
                tags: [],
                note: nil
            )
        ])
        let viewModel = HomeViewModel(
            feedRefreshAction: { sources in
                await capturedSources.set(sources)
                return RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: articles
                )
            },
            sourceFilter: filter,
            isDeveloperModeEnabled: false
        )
        viewModel.attach(modelContext: context)

        await viewModel.refresh()

        let captured = await capturedSources.value
        #expect(captured?.map(\.id) == ["it-1"])
    }

    @Test
    func refreshDoesNotForwardExplicitSourcesWhenPreferencesAreEmpty() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        // Bootstrap default preferences (no regions, no hidden sources).
        let service = UserPreferencesService(modelContext: context)
        _ = try service.loadPreferences()

        let capturedSources = SourcesCapture()
        let viewModel = HomeViewModel(
            feedRefreshAction: { sources in
                await capturedSources.set(sources)
                return RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: []
                )
            },
            isDeveloperModeEnabled: false
        )
        viewModel.attach(modelContext: context)

        await viewModel.refresh()

        let captured = await capturedSources.value
        #expect(captured == nil)
    }

    @Test
    func loadInitialFeedIsNoOpBeforeOnboardingCompletes() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        // Bootstrap default preferences: hasCompletedOnboarding == false.
        _ = try UserPreferencesService(modelContext: context).loadPreferences()

        let counter = CallCounter()
        let articles = Self.sampleArticles(count: 1)
        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in
                await counter.increment()
                return RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: articles
                )
            },
            isDeveloperModeEnabled: false
        )
        viewModel.attach(modelContext: context)

        await viewModel.loadInitialFeedIfNeeded()

        #expect(await counter.value == 0)
        #expect(viewModel.state == .idle)

        // After onboarding completes, the same call runs the initial load.
        _ = try UserPreferencesService(modelContext: context)
            .updatePreferences(.init(hasCompletedOnboarding: true))

        await viewModel.loadInitialFeedIfNeeded()

        #expect(await counter.value == 1)
        #expect(viewModel.hasArticles == true)
    }

    private actor SourcesCapture {
        private(set) var value: [RSSFeedSource]?
        func set(_ new: [RSSFeedSource]?) { value = new }
    }

    // MARK: - Cache replay source filtering (issue #94)

    @Test
    func cachedReplayFiltersDisabledSourcesAndKeepsLegacyNameMatches() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        _ = try UserPreferencesService(modelContext: context).updatePreferences(
            .init(
                enabledRegionRawValues: [RSSFeedRegion.italy.rawValue],
                hasCompletedOnboarding: true
            )
        )
        // Stamped rows (post-#94 ingest) + legacy rows without a sourceID.
        context.insert(Self.makeCachedEntity(id: "it-a", sourceID: "it-1", sourceName: "IT 1"))
        context.insert(Self.makeCachedEntity(id: "fr-a", sourceID: "fr-1", sourceName: "FR 1"))
        context.insert(Self.makeCachedEntity(id: "legacy-it", sourceID: nil, sourceName: "IT 1"))
        context.insert(Self.makeCachedEntity(id: "legacy-fr", sourceID: nil, sourceName: "FR 1"))
        try context.save()

        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in
                RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: []
                )
            },
            sourceFilter: RSSSourceFilter(allSources: Self.twoRegionCatalog()),
            isDeveloperModeEnabled: false
        )
        viewModel.attach(modelContext: context)

        let replayed = await viewModel.loadCachedArticles()

        #expect(Set(replayed.map(\.id)) == ["it-a", "legacy-it"])
    }

    @Test
    func cachedReplayIsUnfilteredWhenPreferencesImposeNoFilter() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        // Bootstrap default preferences: no regions, no hidden sources.
        _ = try UserPreferencesService(modelContext: context).loadPreferences()
        context.insert(Self.makeCachedEntity(id: "it-a", sourceID: "it-1", sourceName: "IT 1"))
        context.insert(Self.makeCachedEntity(id: "fr-a", sourceID: "fr-1", sourceName: "FR 1"))
        try context.save()

        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in
                RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: []
                )
            },
            sourceFilter: RSSSourceFilter(allSources: Self.twoRegionCatalog()),
            isDeveloperModeEnabled: false
        )
        viewModel.attach(modelContext: context)

        let replayed = await viewModel.loadCachedArticles()

        #expect(Set(replayed.map(\.id)) == ["it-a", "fr-a"])
    }

    @Test
    func refreshRunsRetentionSweepOnStaleCachedRows() async throws {
        let container = try Self.makeInMemoryContainer()
        let context = ModelContext(container)
        let stale = Self.makeCachedEntity(id: "stale", sourceID: "it-1", sourceName: "IT 1")
        stale.createdAt = Date().addingTimeInterval(-31 * 86_400)
        let staleFavorite = Self.makeCachedEntity(
            id: "stale-fav", sourceID: "it-1", sourceName: "IT 1"
        )
        staleFavorite.createdAt = Date().addingTimeInterval(-31 * 86_400)
        staleFavorite.isBookmarked = true
        context.insert(stale)
        context.insert(staleFavorite)
        try context.save()

        let viewModel = makeViewModel(deduplicatedArticles: [])
        viewModel.attach(modelContext: context)

        await viewModel.refresh()

        // The sweep is fire-and-forget on a background context
        // (issue #111): poll a fresh context until it lands.
        var remainingIDs: [String] = []
        for _ in 0..<100 {
            remainingIDs = try ModelContext(container)
                .fetch(FetchDescriptor<ArticleEntity>())
                .map(\.id)
            if remainingIDs == ["stale-fav"] { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(remainingIDs == ["stale-fav"])
    }

    private static func makeCachedEntity(
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

    private static func twoRegionCatalog() -> [RSSFeedSource] {
        [
            RSSFeedSource(
                id: "it-1",
                outletName: "IT 1",
                region: .italy,
                feedURLString: "https://example.com/it",
                isMainOutlet: true,
                languageCode: "it",
                tags: [],
                note: nil
            ),
            RSSFeedSource(
                id: "fr-1",
                outletName: "FR 1",
                region: .france,
                feedURLString: "https://example.com/fr",
                isMainOutlet: true,
                languageCode: "fr",
                tags: [],
                note: nil
            )
        ]
    }

    @Test
    func loadInitialFeedRunsOnlyOnce() async {
        let counter = CallCounter()
        let articles = Self.sampleArticles(count: 1)
        let viewModel = HomeViewModel(
            feedRefreshAction: { _ in
                await counter.increment()
                return RSSFeedBatchResult(
                    checkedAt: .now,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    checks: [],
                    deduplicatedArticles: articles
                )
            },
            isDeveloperModeEnabled: false
        )

        await viewModel.loadInitialFeedIfNeeded()
        await viewModel.loadInitialFeedIfNeeded()

        let finalCount = await counter.value
        #expect(finalCount == 1)
    }

    private actor CallCounter {
        private(set) var value: Int = 0

        func increment() {
            value += 1
        }
    }

    // MARK: - Helpers

    private func makeViewModel(
        deduplicatedArticles: [Article],
        checks: [RSSFeedCheckResult] = []
    ) -> HomeViewModel {
        let result = RSSFeedBatchResult(
            checkedAt: .now,
            groupMode: .mainOutlets,
            selectedRegion: nil,
            checks: checks,
            deduplicatedArticles: deduplicatedArticles
        )
        return HomeViewModel(
            feedRefreshAction: { _ in result },
            isDeveloperModeEnabled: false
        )
    }

    private static func sampleArticles(count: Int, prefix: String = "article") -> [Article] {
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
                summaryShort: "Summary for \(prefix) \(index)",
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

    private static func successCheck() -> RSSFeedCheckResult {
        RSSFeedCheckResult(
            source: sampleSource(id: "ok"),
            status: .success,
            articles: [],
            elapsedMs: 10,
            message: nil
        )
    }

    private static func failedCheck(reason: RSSFeedCheckStatus) -> RSSFeedCheckResult {
        RSSFeedCheckResult(
            source: sampleSource(id: "fail-\(reason.rawValue)"),
            status: reason,
            articles: [],
            elapsedMs: 10,
            message: "Test failure"
        )
    }

    private static func sampleSource(id: String) -> RSSFeedSource {
        RSSFeedSource(
            id: id,
            outletName: "Sample Outlet \(id)",
            region: .europeWide,
            feedURLString: "https://example.com/feed",
            isMainOutlet: false,
            languageCode: "en",
            tags: [],
            note: nil
        )
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
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
}
