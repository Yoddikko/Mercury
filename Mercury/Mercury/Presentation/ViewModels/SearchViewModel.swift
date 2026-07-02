//
//  SearchViewModel.swift
//  Mercury
//
//  Created by Codex on 26/06/26.
//

import Combine
import Foundation
import SwiftData

/// Presentation-layer view model powering the in-app article search bar
/// surfaced on the Home screen.
///
/// The view model is intentionally thin: it owns the current `query`
/// string and exposes a simple state machine (`idle` → `searching` →
/// `results` | `empty`) backed by `ArticleRepository.fetchArticles`. The
/// data-layer predicate (`ArticleQuery.searchText`) does the actual
/// substring matching across `title` + `cleanedContent`, so this type
/// only orchestrates debouncing, cancellation, and result projection.
///
/// Debouncing lives in the view (`.task(id: query) { ... await
/// viewModel.runSearch() }`) and the view model exposes the debounce
/// duration as a tunable property so unit tests can drive it
/// deterministically.
@MainActor
final class SearchViewModel: ObservableObject {
    /// High-level state observed by the search UI.
    enum SearchState: Equatable {
        /// No search is in flight and no query has been submitted yet.
        case idle
        /// A query is currently being resolved against the repository.
        case searching
        /// The repository returned at least one matching article.
        case results(articles: [Article])
        /// The repository returned zero matches for a non-empty query.
        case empty
    }

    @Published var query: String = ""
    @Published private(set) var state: SearchState = .idle
    @Published private(set) var results: [Article] = []

    /// Debounce window applied before each repository fetch. Exposed so
    /// tests can lower it to zero and drive the pipeline synchronously.
    let debounce: Duration

    private var repository: ArticleRepository?
    private let sourceFilter: RSSSourceFilter
    private var modelContext: ModelContext?
    private let logger: AppLogger
    private let maxResults: Int

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - repository: Article repository used to resolve queries. May be
    ///     `nil` at construction time when the screen needs to defer the
    ///     SwiftData wiring (`attach(repository:)`) until after a
    ///     `ModelContext` becomes available.
    ///   - sourceFilter: resolves the user's Feed sources preferences into
    ///     the allow list applied to search results (issue #94), so cached
    ///     articles from disabled sources never surface through search.
    ///   - debounce: Debounce window applied to user input before a fetch
    ///     is issued. Defaults to 300 ms to match the documented search
    ///     UX guideline.
    ///   - maxResults: Upper bound on the number of returned articles.
    ///   - logger: AppLogger sink used for trace + result-count logging.
    init(
        repository: ArticleRepository? = nil,
        sourceFilter: RSSSourceFilter = RSSSourceFilter(),
        debounce: Duration = .milliseconds(300),
        maxResults: Int = 50,
        logger: AppLogger = .shared
    ) {
        self.repository = repository
        self.sourceFilter = sourceFilter
        self.debounce = debounce
        self.maxResults = max(1, maxResults)
        self.logger = logger
        logger.debug(
            "Initialized Search view model",
            category: .ui,
            service: "SearchViewModel",
            metadata: [
                "debounce_ms": "\(Self.milliseconds(from: debounce))",
                "max_results": "\(self.maxResults)"
            ]
        )
    }

    /// Wire (or replace) the backing article repository. Safe to call
    /// repeatedly; only `nil → non-nil` transitions trigger a log entry.
    func attach(repository: ArticleRepository) {
        let wasUnset = self.repository == nil
        self.repository = repository
        if wasUnset {
            logger.debug(
                "Attached article repository",
                category: .database,
                service: "SearchViewModel"
            )
        }
    }

    /// Wire the SwiftData model context used to read the Feed sources
    /// preferences that gate search results (issue #94). Safe to call
    /// repeatedly: subsequent calls are no-ops unless the underlying
    /// context actually changes. Without a context the search stays
    /// unfiltered, preserving the closure-injected test seam.
    func attach(modelContext: ModelContext) {
        guard self.modelContext !== modelContext else { return }
        self.modelContext = modelContext
        logger.debug(
            "Attached SwiftData model context",
            category: .database,
            service: "SearchViewModel"
        )
    }

    deinit {
        logger.debug(
            "Deinitializing Search view model",
            category: .ui,
            service: "SearchViewModel"
        )
    }

    // MARK: - Public localized copy

    var searchPrompt: String {
        String(
            localized: "home.search.prompt",
            defaultValue: "Search articles"
        )
    }

    var noResultsTitle: String {
        String(
            localized: "home.search.no_results.title",
            defaultValue: "No matching articles"
        )
    }

    func noResultsSubtitle(for query: String) -> String {
        let format = String(
            localized: "home.search.no_results.subtitle",
            defaultValue: "No articles match \"%@\". Try a different keyword."
        )
        return String(format: format, locale: .current, query)
    }

    var searchFieldAccessibilityHint: String {
        String(
            localized: "home.search.field.accessibility_hint",
            defaultValue: "Filters the article list by title and body content."
        )
    }

    var resultsAccessibilityLabel: String {
        String(
            localized: "home.search.results.accessibility_label",
            defaultValue: "Search results"
        )
    }

    // MARK: - Search pipeline

    /// Whether the current query should trigger a repository fetch. A
    /// trimmed, empty value resets state to `.idle` and short-circuits.
    var isQueryActive: Bool {
        normalized(query) != nil
    }

    /// Debounced search entry point. Intended to be driven by a SwiftUI
    /// `.task(id: query)` modifier so each keystroke cancels the in-flight
    /// task automatically.
    func runSearch() async {
        let normalized = normalized(query)
        guard let trimmed = normalized else {
            state = .idle
            results = []
            return
        }

        // Debounce window — cancelled if the surrounding `.task(id:)`
        // restarts on the next keystroke.
        do {
            try await Task.sleep(for: debounce)
        } catch {
            return
        }
        if Task.isCancelled { return }

        await performSearch(trimmed: trimmed)
    }

    /// Synchronous search seam used by tests to bypass the debounce
    /// window. Production code should call `runSearch()` instead.
    func performSearchNow() async {
        guard let trimmed = normalized(query) else {
            state = .idle
            results = []
            return
        }
        await performSearch(trimmed: trimmed)
    }

    // MARK: - Private

    private func performSearch(trimmed: String) async {
        guard let repository else {
            logger.warn(
                "Search query received before repository was attached",
                category: .ui,
                service: "SearchViewModel"
            )
            state = .idle
            results = []
            return
        }

        let requestID = "search-\(UUID().uuidString.lowercased())"
        state = .searching

        logger.trace(
            "Search query triggered",
            category: .ui,
            service: "SearchViewModel",
            requestID: requestID,
            metadata: [
                "query_length": "\(trimmed.count)"
            ]
        )

        let articleQuery = ArticleQuery(
            searchText: trimmed,
            sort: .publishedAtDescending,
            limit: maxResults
        )

        do {
            let entities = try await repository.fetchArticles(
                articleQuery,
                requestID: requestID
            )
            if Task.isCancelled { return }

            var articles = entities.compactMap(ArticleEntityMapper.makeArticle(from:))
            var filteredOut = 0
            if let allowList = sourceFilter.makeArticleAllowList(for: currentPreferences()) {
                let unfilteredCount = articles.count
                articles = articles.filter { article in
                    allowList.allows(sourceID: article.sourceID, sourceName: article.sourceName)
                }
                filteredOut = unfilteredCount - articles.count
            }
            results = articles
            state = articles.isEmpty ? .empty : .results(articles: articles)

            logger.debug(
                "Search query completed",
                category: .ui,
                service: "SearchViewModel",
                requestID: requestID,
                metadata: [
                    "results_count": "\(articles.count)",
                    "filtered_out": "\(filteredOut)",
                    "entities_count": "\(entities.count)"
                ]
            )
        } catch {
            // Search failures fall back to the empty state rather than a
            // dedicated error UI: search is a secondary affordance over
            // already-cached content, so a transient repository error
            // should not block the user from clearing the field.
            results = []
            state = .empty
            logger.error(
                "Search query failed",
                category: .ui,
                service: "SearchViewModel",
                requestID: requestID,
                metadata: ["error": String(describing: error)]
            )
        }
    }

    private func currentPreferences() -> UserPreference? {
        guard let modelContext else { return nil }
        return try? UserPreferencesService(modelContext: modelContext).loadPreferences()
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func milliseconds(from duration: Duration) -> Int {
        let (seconds, attoseconds) = duration.components
        let fromSeconds = seconds * 1_000
        let fromAttos = Int(attoseconds / 1_000_000_000_000_000)
        return Int(fromSeconds) + fromAttos
    }
}
