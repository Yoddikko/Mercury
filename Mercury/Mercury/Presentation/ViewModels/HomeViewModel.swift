//
//  HomeViewModel.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//  Wired to live RSS feed on 25/06/26.
//

import Combine
import Foundation
import SwiftData

/// Presentation-layer view model that powers the Home screen.
///
/// The view model exposes a simple state machine (`idle` → `loading` →
/// `loaded` | `empty` | `failed`) backed by the `FetchHomeFeedUseCase`
/// orchestration entry-point (issue #30) and persists fetched articles
/// into the SwiftData stack so the app stays usable offline once content
/// has been retrieved.
///
/// In production the view model is wired to `LiveFetchHomeFeedUseCase`,
/// which combines the live RSS pipeline with the article repository
/// cache. Tests can still inject a closure-based refresh action via the
/// designated initializer so every state-machine branch is reachable
/// without spinning up the live stack.
@MainActor
final class HomeViewModel: ObservableObject {
    enum FeedState: Equatable {
        case idle
        case loading
        case loaded(articles: [Article])
        case empty
        case failed(message: String)
    }

    /// Home shows two feeds behind a segmented control (issue #109):
    /// the chronological stream and the last-24h topic aggregation.
    enum FeedDisplayMode: String, CaseIterable {
        case chronological
        case topics
    }

    /// Dedicated state machine for the Topics tab: aggregation runs off
    /// the main actor and the tab shows a "grouping…" state meanwhile.
    enum TopicFeedState: Equatable {
        case idle
        case aggregating
        case ready(clusters: [TopicCluster], method: TopicAggregationMethod)
        case empty
    }

    /// How the current topic clusters were produced (issue #113): the
    /// configured AI provider, or the on-device lexical fallback. The UI
    /// shows a sparkles indicator for AI-made groupings.
    enum TopicAggregationMethod: Equatable {
        case lexical
        case ai
    }

    /// Seam for provider-made grouping (issue #113): takes the last-24h
    /// articles and returns groups of article ids. `nil` or a throw
    /// means "use the lexical aggregation". Production wires
    /// `AIService.groupArticleHeadlines`, which throws when no provider
    /// is configured.
    typealias TopicAIGrouper = @Sendable (_ articles: [Article], _ requestID: String) async throws -> [[String]]

    /// Feed refresh seam. Callers pass the pre-resolved source list they
    /// want the pipeline to hit. Production wraps `FetchHomeFeedUseCase`;
    /// tests inject a stub. `nil` means "use the built-in catalog default"
    /// (main outlets), so pre-onboarding behavior stays intact.
    typealias FeedRefreshAction = @Sendable (_ sources: [RSSFeedSource]?) async -> RSSFeedBatchResult

    @Published private(set) var state: FeedState = .idle
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var displayMode: FeedDisplayMode = .chronological
    @Published private(set) var topicState: TopicFeedState = .idle

    let isDeveloperModeEnabled: Bool

    private let feedRefreshAction: FeedRefreshAction
    private let sourceFilter: RSSSourceFilter
    private let logger: AppLogger
    private let maxDisplayedArticles: Int
    private let ranker = FeedRankingService()
    private let topicAggregator = FeedTopicAggregationService()
    private let topicAIGrouper: TopicAIGrouper?
    private var topicTask: Task<Void, Never>?
    /// Article ids the current `topicState` was computed from — skips
    /// pointless re-aggregation when switching tabs back and forth.
    private var topicInputIDs: [String] = []
    private var modelContext: ModelContext?
    private var activeTask: Task<RSSFeedBatchResult, Never>?
    private var activeRequestID: String?
    private var hasLoadedOnce: Bool = false

    /// Production initializer that wires the supplied
    /// `FetchHomeFeedUseCase` into the refresh pipeline. The use case is
    /// the new orchestration seam (issue #30): it combines
    /// `FeedRefreshService` with the SwiftData-backed
    /// `ArticleRepository`, leaving this view model with only the
    /// presentation state-machine concerns.
    convenience init(
        fetchHomeFeedUseCase: FetchHomeFeedUseCase,
        sourceFilter: RSSSourceFilter = RSSSourceFilter(),
        isDeveloperModeEnabled: Bool = DeveloperMode.isEnabled,
        topicAIGrouper: TopicAIGrouper? = nil
    ) {
        self.init(
            feedRefreshAction: { sources in
                await fetchHomeFeedUseCase.execute(
                    sources: sources,
                    groupMode: .mainOutlets,
                    selectedRegion: nil,
                    requestID: nil
                )
            },
            sourceFilter: sourceFilter,
            isDeveloperModeEnabled: isDeveloperModeEnabled,
            topicAIGrouper: topicAIGrouper
        )
    }

    /// Designated initializer accepting a closure-based fetch seam so
    /// tests can drive every branch of the state machine without
    /// spinning up the live RSS stack.
    init(
        feedRefreshAction: @escaping FeedRefreshAction,
        sourceFilter: RSSSourceFilter = RSSSourceFilter(),
        isDeveloperModeEnabled: Bool = DeveloperMode.isEnabled,
        logger: AppLogger = .shared,
        maxDisplayedArticles: Int = 50,
        topicAIGrouper: TopicAIGrouper? = nil
    ) {
        self.feedRefreshAction = feedRefreshAction
        self.sourceFilter = sourceFilter
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
        self.topicAIGrouper = topicAIGrouper
        self.logger = logger
        self.maxDisplayedArticles = max(1, maxDisplayedArticles)
        logger.debug(
            "Initialized Home view model",
            category: .ui,
            service: "HomeViewModel",
            metadata: [
                "developer_mode": "\(isDeveloperModeEnabled)",
                "max_displayed_articles": "\(self.maxDisplayedArticles)"
            ]
        )
    }

    deinit {
        activeTask?.cancel()
        topicTask?.cancel()
        logger.debug(
            "Deinitializing Home view model",
            category: .ui,
            service: "HomeViewModel"
        )
    }

    // MARK: - Public localized copy

    var title: String {
        String(localized: "home.title", defaultValue: "Mercurio")
    }

    var subtitle: String {
        String(
            localized: "home.subtitle",
            defaultValue: "Mercurio turns Italian RSS into a structured AI-assisted news experience."
        )
    }

    var navigationTitle: String {
        String(localized: "home.navigation.title", defaultValue: "Mercurio")
    }

    var displayModeChronologicalLabel: String {
        String(localized: "home.feed_mode.chronological", defaultValue: "Latest")
    }

    var displayModeTopicsLabel: String {
        String(localized: "home.feed_mode.topics", defaultValue: "Topics")
    }

    var feedModePickerAccessibilityLabel: String {
        String(
            localized: "home.feed_mode.accessibility",
            defaultValue: "Feed display mode"
        )
    }

    var topicsAggregatingLabel: String {
        String(
            localized: "home.topics.aggregating",
            defaultValue: "Grouping the news by topic…"
        )
    }

    var topicsAggregatingHint: String {
        String(
            localized: "home.topics.aggregating.hint",
            defaultValue: "Stories from the last 24 hours"
        )
    }

    var topicsEmptyLabel: String {
        String(
            localized: "home.topics.empty",
            defaultValue: "No stories in the last 24 hours."
        )
    }

    var topicsOthersSectionTitle: String {
        String(localized: "home.topics.others", defaultValue: "More news")
    }

    var topicsAIAggregatedLabel: String {
        String(
            localized: "home.topics.ai_aggregated",
            defaultValue: "Grouped with AI"
        )
    }

    func topicsCoverageLabel(sourceCount: Int) -> String {
        let format = String(
            localized: "home.topics.coverage",
            defaultValue: "%lld outlets on this story"
        )
        return String(format: format, locale: .current, sourceCount)
    }

    func topicsMoreArticlesLabel(count: Int) -> String {
        let format = String(
            localized: "home.topics.more_articles",
            defaultValue: "+ %lld more articles"
        )
        return String(format: format, locale: .current, count)
    }

    var articlesSectionTitle: String {
        String(localized: "home.section.articles", defaultValue: "Latest Articles")
    }

    var loadingLabel: String {
        String(localized: "home.state.loading", defaultValue: "Loading the latest news…")
    }

    var emptyTitle: String {
        String(localized: "home.state.empty.title", defaultValue: "No articles yet")
    }

    var emptySubtitle: String {
        String(
            localized: "home.state.empty.subtitle",
            defaultValue: "Pull to refresh to fetch the latest stories from the configured RSS sources."
        )
    }

    var errorTitle: String {
        String(localized: "home.state.error.title", defaultValue: "We couldn't load the feed")
    }

    var errorRetryLabel: String {
        String(localized: "home.state.error.retry", defaultValue: "Try again")
    }

    var uncategorizedLabel: String {
        String(localized: "home.article.uncategorized", defaultValue: "Uncategorized")
    }

    var developerToolsLabel: String {
        String(localized: "home.developer_tools", defaultValue: "Developer Tools")
    }

    var refreshAccessibilityLabel: String {
        String(
            localized: "home.refresh.accessibility",
            defaultValue: "Refresh the feed"
        )
    }

    func lastUpdatedLabel(for date: Date) -> String {
        let format = String(
            localized: "home.last_updated",
            defaultValue: "Last updated %@"
        )
        return String(
            format: format,
            locale: .current,
            Self.lastUpdatedDateFormatter.string(from: date)
        )
    }

    func articleMetadataLine(sourceName: String, publishedAt: Date) -> String {
        let format = String(
            localized: "home.article.metadata.format",
            defaultValue: "%@ • %@"
        )
        return String(
            format: format,
            locale: .current,
            sourceName,
            Self.articleDateFormatter.localizedString(for: publishedAt, relativeTo: Date())
        )
    }

    // MARK: - Lifecycle hooks

    /// Wire the SwiftData model context once the view becomes available.
    /// Safe to call repeatedly: subsequent calls are no-ops unless the
    /// underlying context actually changes.
    func attach(modelContext: ModelContext) {
        guard self.modelContext !== modelContext else { return }
        self.modelContext = modelContext
        logger.debug(
            "Attached SwiftData model context",
            category: .database,
            service: "HomeViewModel"
        )
    }

    /// Run an initial load: replay cached articles from SwiftData first
    /// (so the UI is not empty offline) and then kick off a network
    /// refresh in the background.
    /// No-op until onboarding completes (issue #87): the first refresh
    /// must run against the source set the user picks during onboarding,
    /// so a pre-onboarding mount of HomeScreen never fires the pipeline.
    /// `hasLoadedOnce` is intentionally not latched on the skip path so
    /// the post-onboarding mount still triggers the initial load.
    /// Missing preferences (no attached context) fail open to preserve
    /// the closure-injected test seam.
    func loadInitialFeedIfNeeded() async {
        guard hasLoadedOnce == false else { return }

        if let preferences = currentPreferences(), preferences.hasCompletedOnboarding == false {
            logger.info(
                "Skipping initial feed load until onboarding completes",
                category: .ui,
                service: "HomeViewModel"
            )
            return
        }

        hasLoadedOnce = true

        state = .loading
        let cached = await loadCachedArticles(requestID: "home-cache-\(UUID().uuidString.lowercased())")
        if cached.isEmpty == false {
            applyArticles(cached, source: "cache")
        }

        await refresh()
    }

    /// Force a refresh from the RSS pipeline. Used by pull-to-refresh and
    /// the error-state retry button.
    func refresh() async {
        activeTask?.cancel()

        let requestID = "home-feed-\(UUID().uuidString.lowercased())"
        activeRequestID = requestID
        isRefreshing = true

        switch state {
        case .loaded:
            // keep showing cached content while refreshing in the background
            break
        case .idle, .empty, .failed, .loading:
            state = .loading
        }

        logger.info(
            "Home feed refresh requested",
            category: .ui,
            service: "HomeViewModel",
            requestID: requestID
        )

        // Cache retention (issue #94): drop stale non-favorite rows before
        // the network round-trip so the cap applies even when the fetch
        // later fails offline.
        runRetentionSweep(requestID: requestID)

        let startedAt = DispatchTime.now().uptimeNanoseconds
        // Resolve the effective source list from the user's onboarding /
        // Settings choices. When the user has opted in to specific regions
        // or hidden specific outlets we pass the filtered list explicitly;
        // otherwise `nil` keeps the pre-onboarding default (main outlets).
        let sources = resolveExplicitSources()
        let task = Task { [feedRefreshAction] in
            await feedRefreshAction(sources)
        }
        activeTask = task

        let result = await task.value
        await handle(result: result, requestID: requestID, startedAt: startedAt)
    }

    private func resolveExplicitSources() -> [RSSFeedSource]? {
        guard let preferences = currentPreferences() else { return nil }
        let hasRegionFilter = preferences.enabledRegionRawValues.isEmpty == false
        let hasHiddenSources = preferences.hiddenSources.isEmpty == false
        guard hasRegionFilter || hasHiddenSources else { return nil }
        return sourceFilter.resolveSources(for: preferences)
    }

    // MARK: - State helpers

    var hasArticles: Bool {
        if case .loaded = state { return true }
        return false
    }

    var displayedArticles: [Article] {
        if case let .loaded(articles) = state { return articles }
        return []
    }

    var errorMessage: String? {
        if case let .failed(message) = state { return message }
        return nil
    }

    // MARK: - Private

    private func handle(
        result: RSSFeedBatchResult,
        requestID: String,
        startedAt: UInt64
    ) async {
        guard activeRequestID == requestID else {
            logger.debug(
                "Discarding outdated feed result",
                category: .ui,
                service: "HomeViewModel",
                requestID: requestID
            )
            return
        }

        defer {
            activeTask = nil
            activeRequestID = nil
            isRefreshing = false
        }

        if Task.isCancelled {
            logger.warn(
                "Home feed refresh was cancelled",
                category: .ui,
                service: "HomeViewModel",
                requestID: requestID
            )
            return
        }

        let ranked = ranker.rank(result.deduplicatedArticles, preferences: currentPreferences())
        let trimmed = Array(ranked.prefix(maxDisplayedArticles))
        let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000)
        let failedChecks = result.checks.filter { $0.status == .requestFailed || $0.status == .parseFailed }
        let successChecks = result.checks.filter { $0.status == .success }

        if trimmed.isEmpty {
            if successChecks.isEmpty && failedChecks.isEmpty == false {
                let message = String(
                    localized: "home.state.error.subtitle",
                    defaultValue: "All RSS sources failed to respond. Check your connection and try again."
                )
                state = .failed(message: message)
                logger.error(
                    "Home feed refresh produced no articles and all sources failed",
                    category: .ui,
                    service: "HomeViewModel",
                    requestID: requestID,
                    metadata: [
                        "failed_checks": "\(failedChecks.count)",
                        "elapsed_ms": "\(elapsedMs)"
                    ]
                )
            } else {
                state = .empty
                logger.info(
                    "Home feed refresh completed with no articles",
                    category: .ui,
                    service: "HomeViewModel",
                    requestID: requestID,
                    metadata: [
                        "checks_total": "\(result.checks.count)",
                        "elapsed_ms": "\(elapsedMs)"
                    ]
                )
            }
            lastUpdatedAt = Date()
            return
        }

        persist(articles: trimmed, requestID: requestID)
        applyArticles(trimmed, source: "network")
        lastUpdatedAt = Date()
        logger.info(
            "Home feed refresh completed",
            category: .ui,
            service: "HomeViewModel",
            requestID: requestID,
            metadata: [
                "articles_out": "\(trimmed.count)",
                "checks_success": "\(successChecks.count)",
                "checks_failed": "\(failedChecks.count)",
                "elapsed_ms": "\(elapsedMs)"
            ]
        )
    }

    private func applyArticles(_ articles: [Article], source: String) {
        if articles.isEmpty {
            state = .empty
        } else {
            state = .loaded(articles: articles)
        }
        // New articles invalidate the topic aggregation; recompute
        // immediately only if the user is looking at the Topics tab.
        if topicInputIDs != articles.map(\.id) {
            topicState = .idle
            topicInputIDs = []
            if displayMode == .topics {
                refreshTopicsIfNeeded()
            }
        }
        logger.debug(
            "Applied articles to Home state",
            category: .ui,
            service: "HomeViewModel",
            metadata: [
                "articles_count": "\(articles.count)",
                "origin": source
            ]
        )
    }

    // MARK: - Topic aggregation (issue #109)

    /// Switches the Home feed between chronological and topics; the
    /// first switch to topics (or after a refresh) kicks aggregation.
    func selectDisplayMode(_ mode: FeedDisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        logger.info(
            "Home feed display mode changed",
            category: .ui,
            service: "HomeViewModel",
            metadata: ["mode": mode.rawValue]
        )
        if mode == .topics {
            refreshTopicsIfNeeded()
        }
    }

    /// Aggregates the loaded articles into topic clusters off the main
    /// actor. Idempotent for an unchanged article set.
    func refreshTopicsIfNeeded() {
        guard case let .loaded(articles) = state else {
            topicState = .empty
            return
        }
        let inputIDs = articles.map(\.id)
        if topicInputIDs == inputIDs, case .ready = topicState { return }
        if case .aggregating = topicState, topicInputIDs == inputIDs { return }

        topicInputIDs = inputIDs
        topicState = .aggregating
        let requestID = "home-topics-\(UUID().uuidString.lowercased())"
        logger.info(
            "Topic aggregation started",
            category: .ui,
            service: "HomeViewModel",
            requestID: requestID,
            metadata: [
                "articles": "\(articles.count)",
                "ai_grouper": "\(topicAIGrouper != nil)"
            ]
        )
        topicTask?.cancel()
        let aggregator = topicAggregator
        let aiGrouper = topicAIGrouper
        topicTask = Task { [weak self, logger] in
            // AI first when wired (issue #113): the grouper throws when
            // no provider is configured or the call fails, and the flow
            // falls back to the on-device lexical clustering — the feed
            // never degrades because of the provider.
            var clusters: [TopicCluster]?
            var method = TopicAggregationMethod.lexical
            if let aiGrouper {
                do {
                    let cutoff = Date().addingTimeInterval(-FeedTopicAggregationService.recencyWindow)
                    let recent = articles.filter { $0.publishedAt >= cutoff }
                    if recent.count >= 2 {
                        let groups = try await aiGrouper(recent, requestID)
                        clusters = aggregator.clusters(
                            fromGroups: groups,
                            articles: articles,
                            requestID: requestID
                        )
                        method = .ai
                    }
                } catch {
                    logger.info(
                        "AI topic grouping unavailable, falling back to lexical",
                        category: .business,
                        service: "HomeViewModel",
                        requestID: requestID,
                        metadata: ["error": String(describing: error)]
                    )
                }
            }
            if clusters == nil {
                clusters = await Task.detached(priority: .userInitiated) {
                    aggregator.aggregate(articles: articles, requestID: requestID)
                }.value
                method = .lexical
            }
            guard let self, Task.isCancelled == false else { return }
            guard self.topicInputIDs == inputIDs else { return }
            let resolved = clusters ?? []
            self.topicState = resolved.isEmpty
                ? .empty
                : .ready(clusters: resolved, method: method)
        }
    }

    private func currentPreferences() -> UserPreference? {
        guard let modelContext else { return nil }
        return try? UserPreferencesService(modelContext: modelContext).loadPreferences()
    }

    /// Replay the SwiftData cache, honoring the user's Feed sources
    /// preferences (issue #94): rows from disabled sources are filtered out
    /// before ranking, matching by `sourceID` when stamped and falling back
    /// to `sourceName` for legacy rows. Without preferences the replay is
    /// unfiltered, preserving pre-onboarding behavior.
    ///
    /// Internal (not private) so unit tests can drive the replay path
    /// directly without racing the network refresh.
    func loadCachedArticles(requestID: String? = nil) async -> [Article] {
        guard let modelContext else {
            logger.debug(
                "No model context attached when loading cached articles",
                category: .database,
                service: "HomeViewModel",
                requestID: requestID
            )
            return []
        }

        do {
            // Fetch + entity mapping run on the store's @ModelActor
            // (issue #111): the main thread only does the cheap in-memory
            // filter + rank on the returned value types.
            // ponytail: fetch 3× the display cap so the ranker has room
            // to reorder; upgrade to a SwiftData-side ranking query when
            // the table grows past a few thousand rows.
            let store = ArticleLocalStore(modelContainer: modelContext.container)
            var articles = try await store.fetchRecentFeedArticles(
                limit: maxDisplayedArticles * 3,
                requestID: requestID
            )
            let fetchedCount = articles.count
            let preferences = currentPreferences()
            var filteredOut = 0
            if let allowList = sourceFilter.makeArticleAllowList(for: preferences) {
                let unfilteredCount = articles.count
                articles = articles.filter { article in
                    allowList.allows(sourceID: article.sourceID, sourceName: article.sourceName)
                }
                filteredOut = unfilteredCount - articles.count
            }
            let ranked = ranker.rank(articles, preferences: preferences)
            let trimmed = Array(ranked.prefix(maxDisplayedArticles))
            logger.debug(
                "Loaded cached articles from SwiftData",
                category: .database,
                service: "HomeViewModel",
                requestID: requestID,
                metadata: [
                    "entities_in": "\(fetchedCount)",
                    "filtered_out": "\(filteredOut)",
                    "articles_out": "\(trimmed.count)"
                ]
            )
            return trimmed
        } catch {
            logger.error(
                "Failed to fetch cached articles",
                category: .database,
                service: "HomeViewModel",
                requestID: requestID,
                metadata: ["error": error.localizedDescription]
            )
            return []
        }
    }

    /// Run the time-based cache retention sweep (issue #94). Failures are
    /// logged and swallowed: cleanup must never block the refresh flow.
    private func runRetentionSweep(requestID: String) {
        guard let container = modelContext?.container else { return }
        // Fire-and-forget on a fresh background context (issue #111):
        // the sweep scans and deletes rows and must never stall the main
        // thread or gate the refresh flow.
        let sourceFilter = sourceFilter
        let logger = logger
        Task.detached(priority: .utility) {
            do {
                let context = ModelContext(container)
                let purged = try ArticleCacheMaintenanceService(
                    modelContext: context,
                    sourceFilter: sourceFilter,
                    logger: logger
                ).enforceRetention(requestID: requestID)
                if purged > 0 {
                    logger.debug(
                        "Cache retention sweep completed",
                        category: .cache,
                        service: "HomeViewModel",
                        requestID: requestID,
                        metadata: ["purged_rows": "\(purged)"]
                    )
                }
            } catch {
                logger.error(
                    "Cache retention sweep failed",
                    category: .cache,
                    service: "HomeViewModel",
                    requestID: requestID,
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    private func persist(articles: [Article], requestID: String) {
        guard let modelContext else {
            logger.debug(
                "No model context attached when persisting articles",
                category: .database,
                service: "HomeViewModel",
                requestID: requestID
            )
            return
        }

        let identifiers = articles.map(\.id)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { entity in
                identifiers.contains(entity.id)
            }
        )

        do {
            let existing = try modelContext.fetch(descriptor)
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

            var inserted = 0
            var updated = 0
            for article in articles {
                if let entity = existingByID[article.id] {
                    ArticleEntityMapper.apply(article, to: entity)
                    updated += 1
                } else {
                    let entity = ArticleEntityMapper.makeEntity(from: article)
                    modelContext.insert(entity)
                    inserted += 1
                }
            }

            try modelContext.save()
            logger.debug(
                "Persisted Home feed articles into SwiftData",
                category: .database,
                service: "HomeViewModel",
                requestID: requestID,
                metadata: [
                    "articles_in": "\(articles.count)",
                    "inserted": "\(inserted)",
                    "updated": "\(updated)"
                ]
            )
        } catch {
            logger.error(
                "Failed to persist Home feed articles",
                category: .database,
                service: "HomeViewModel",
                requestID: requestID,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private static let articleDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let lastUpdatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
