//
//  SearchViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Behavioural coverage for `SearchViewModel`. The tests rely on an
/// in-memory `SwiftDataArticleRepository` because the production code
/// path (predicate + sort) lives in `ArticleLocalStore`, and exercising
/// the real store keeps the view-model contract honest end-to-end
/// without recreating predicate-matching logic in a fake.
@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {
    @Test
    func emptyQueryKeepsStateIdle() async throws {
        let viewModel = try await Self.makeViewModel(seedArticles: [
            Self.makeArticle(id: "a", title: "Aurora unveils new AI chip")
        ])

        await viewModel.runSearch()

        #expect(viewModel.state == .idle)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    func nonEmptyQueryDebouncesAndReturnsResults() async throws {
        let viewModel = try await Self.makeViewModel(
            seedArticles: [
                Self.makeArticle(id: "a", title: "Aurora unveils new AI chip"),
                Self.makeArticle(id: "b", title: "Election debate dominates news cycle"),
                Self.makeArticle(id: "c", title: "Researchers publish climate framework")
            ],
            debounce: .milliseconds(10)
        )
        viewModel.query = "AI"

        await viewModel.runSearch()

        guard case let .results(articles) = viewModel.state else {
            Issue.record("Expected results state, got \(viewModel.state)")
            return
        }
        #expect(articles.count == 1)
        #expect(articles.first?.id == "a")
        #expect(viewModel.results.count == 1)
    }

    @Test
    func nonMatchingQueryProducesEmptyState() async throws {
        let viewModel = try await Self.makeViewModel(
            seedArticles: [
                Self.makeArticle(id: "a", title: "Aurora unveils new AI chip")
            ],
            debounce: .milliseconds(10)
        )
        viewModel.query = "zzz-no-match"

        await viewModel.runSearch()

        #expect(viewModel.state == .empty)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    func queryChangeReplacesPreviousResults() async throws {
        let viewModel = try await Self.makeViewModel(
            seedArticles: [
                Self.makeArticle(id: "a", title: "Aurora unveils new AI chip"),
                Self.makeArticle(id: "b", title: "Election debate dominates news cycle")
            ],
            debounce: .milliseconds(10)
        )

        viewModel.query = "AI"
        await viewModel.runSearch()
        guard case let .results(first) = viewModel.state else {
            Issue.record("Expected first results state, got \(viewModel.state)")
            return
        }
        #expect(first.first?.id == "a")

        viewModel.query = "election"
        await viewModel.runSearch()
        guard case let .results(second) = viewModel.state else {
            Issue.record("Expected second results state, got \(viewModel.state)")
            return
        }
        #expect(second.count == 1)
        #expect(second.first?.id == "b")
    }

    // MARK: - Source preference filtering (issue #94)

    @Test
    func searchFiltersResultsFromDisabledSources() async throws {
        let (viewModel, container) = try await Self.makeFilteredViewModel(seedArticles: [
            Self.makeArticle(
                id: "it-a", title: "Aurora unveils new AI chip",
                sourceID: "it-1", sourceName: "IT 1"
            ),
            Self.makeArticle(
                id: "fr-a", title: "AI chip startup raises funding",
                sourceID: "fr-1", sourceName: "FR 1"
            ),
            Self.makeArticle(
                id: "legacy-fr", title: "Legacy AI chip coverage",
                sourceID: nil, sourceName: "FR 1"
            )
        ])
        let context = ModelContext(container)
        _ = try UserPreferencesService(modelContext: context).updatePreferences(
            .init(
                enabledRegionRawValues: [RSSFeedRegion.italy.rawValue],
                hasCompletedOnboarding: true
            )
        )
        viewModel.attach(modelContext: context)
        viewModel.query = "AI chip"

        await viewModel.runSearch()

        guard case let .results(articles) = viewModel.state else {
            Issue.record("Expected results state, got \(viewModel.state)")
            return
        }
        #expect(articles.map(\.id) == ["it-a"])
    }

    @Test
    func searchStaysUnfilteredWithoutAttachedModelContext() async throws {
        let (viewModel, _) = try await Self.makeFilteredViewModel(seedArticles: [
            Self.makeArticle(
                id: "it-a", title: "Aurora unveils new AI chip",
                sourceID: "it-1", sourceName: "IT 1"
            ),
            Self.makeArticle(
                id: "fr-a", title: "AI chip startup raises funding",
                sourceID: "fr-1", sourceName: "FR 1"
            )
        ])
        viewModel.query = "AI chip"

        await viewModel.runSearch()

        guard case let .results(articles) = viewModel.state else {
            Issue.record("Expected results state, got \(viewModel.state)")
            return
        }
        #expect(Set(articles.map(\.id)) == ["it-a", "fr-a"])
    }

    // MARK: - Helpers

    private static func makeViewModel(
        seedArticles: [ArticleEntity],
        debounce: Duration = .zero
    ) async throws -> SearchViewModel {
        let container = try makeInMemoryContainer()
        let store = ArticleLocalStore(modelContainer: container)
        let repository = SwiftDataArticleRepository(store: store)

        for article in seedArticles {
            _ = try await repository.upsert(article)
        }

        return SearchViewModel(
            repository: repository,
            debounce: debounce
        )
    }

    /// Variant that hands back the container too, so tests can attach a
    /// preferences `ModelContext` and exercise the issue #94 source filter
    /// against a fixture catalog (italy `it-1` + france `fr-1`).
    private static func makeFilteredViewModel(
        seedArticles: [ArticleEntity]
    ) async throws -> (SearchViewModel, ModelContainer) {
        let container = try makeInMemoryContainer()
        let store = ArticleLocalStore(modelContainer: container)
        let repository = SwiftDataArticleRepository(store: store)

        for article in seedArticles {
            _ = try await repository.upsert(article)
        }

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
        let viewModel = SearchViewModel(
            repository: repository,
            sourceFilter: filter,
            debounce: .zero
        )
        return (viewModel, container)
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

    private static func makeArticle(
        id: String,
        title: String,
        cleanedContent: String? = nil,
        sourceID: String? = nil,
        sourceName: String = "Test Source",
        publishedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ArticleEntity {
        let entity = ArticleEntity(
            id: id,
            title: title,
            sourceName: sourceName,
            sourceID: sourceID,
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article/\(id)",
            publishedAt: publishedAt
        )
        entity.cleanedContent = cleanedContent
        return entity
    }
}

