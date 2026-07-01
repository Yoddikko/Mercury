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

    private actor SourcesCapture {
        private(set) var value: [RSSFeedSource]?
        func set(_ new: [RSSFeedSource]?) { value = new }
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
