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

    /// Home shows three feeds behind a segmented control (issues #109,
    /// #133): the chronological stream, the last-24h topic aggregation
    /// and the AI-personalized "For You" ranking.
    enum FeedDisplayMode: String, CaseIterable {
        case chronological
        case topics
        case forYou
    }

    /// One personalized entry in the "For You" feed (issue #133): the
    /// article, the user interest the AI matched it to, and a 1-100
    /// relevance driving the order.
    struct ForYouPick: Equatable, Identifiable {
        let article: Article
        let interest: String
        let relevance: Int
        var id: String { article.id }
    }

    /// State machine for the "For You" tab. The feature is AI-only by
    /// design (issue #133): no provider means an honest configure
    /// prompt, never a silent fallback.
    enum ForYouFeedState: Equatable {
        case idle
        case loading
        case ready(picks: [ForYouPick])
        case needsInterests
        case needsProvider
        case empty
        case failed(message: String)
    }

    /// Seam for the provider-made personalization (issue #133): takes
    /// the user's interests and the candidate articles, returns
    /// validated picks. Production wires `AIService.personalizePicks`.
    typealias ForYouAIPicker = @Sendable (_ interests: [String], _ articles: [Article], _ requestID: String) async throws -> [AIHeadlinePick]

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
    /// Why the AI grouping path fell back to lexical, when it did — the
    /// Topics UI surfaces it so the user isn't left guessing why the AI
    /// indicator never appears (issue #119).
    @Published private(set) var topicAIFailureMessage: String?
    /// When the persisted aggregation expires (issue #131): the Topics
    /// footer shows a live countdown and the section recomputes when it
    /// passes. Pull-to-refresh saves a new cache and resets it.
    @Published private(set) var topicsCacheExpiresAt: Date?
    @Published private(set) var forYouState: ForYouFeedState = .idle
    /// When the persisted personalization expires (issue #133): same
    /// countdown + auto-recompute contract as the Topics tab.
    @Published private(set) var forYouCacheExpiresAt: Date?

    let isDeveloperModeEnabled: Bool

    private let feedRefreshAction: FeedRefreshAction
    private let sourceFilter: RSSSourceFilter
    private let logger: AppLogger
    private let maxDisplayedArticles: Int
    private let ranker = FeedRankingService()
    private let topicAggregator = FeedTopicAggregationService()
    private let topicAIGrouper: TopicAIGrouper?
    private let topicsCache: TopicGroupsCache
    private let forYouAIPicker: ForYouAIPicker?
    private let forYouCache: ForYouPicksCache
    private var topicTask: Task<Void, Never>?
    private var forYouTask: Task<Void, Never>?
    /// Identity of the in-flight aggregation run: a superseded run must
    /// not publish over its successor's state.
    private var topicRunToken: UUID?
    private var forYouRunToken: UUID?
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
        topicAIGrouper: TopicAIGrouper? = nil,
        forYouAIPicker: ForYouAIPicker? = nil
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
            topicAIGrouper: topicAIGrouper,
            forYouAIPicker: forYouAIPicker
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
        topicAIGrouper: TopicAIGrouper? = nil,
        forYouAIPicker: ForYouAIPicker? = nil,
        topicsCacheDefaults: UserDefaults = .standard
    ) {
        self.feedRefreshAction = feedRefreshAction
        self.sourceFilter = sourceFilter
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
        self.topicAIGrouper = topicAIGrouper
        self.forYouAIPicker = forYouAIPicker
        self.topicsCache = TopicGroupsCache(defaults: topicsCacheDefaults, logger: logger)
        self.forYouCache = ForYouPicksCache(defaults: topicsCacheDefaults, logger: logger)
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
        forYouTask?.cancel()
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

    var topicsAIUnavailableLabel: String {
        String(
            localized: "home.topics.ai_unavailable",
            defaultValue: "AI grouping unavailable — grouped on device"
        )
    }

    func topicsArticlesCountLabel(count: Int) -> String {
        let format = String(
            localized: "home.topics.articles_count",
            defaultValue: "%lld articles"
        )
        return String(format: format, locale: .current, count)
    }

    func topicsCoverageLabel(sourceCount: Int) -> String {
        let format = String(
            localized: "home.topics.coverage",
            defaultValue: "%lld outlets on this story"
        )
        return String(format: format, locale: .current, sourceCount)
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
        // The topics state is deliberately decoupled from the
        // chronological feed (issues #125, #127): its corpus comes from
        // the cache store, the aggregation persists for 12h, and only
        // pull-to-refresh recomputes it.
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

    /// Rows fetched from the cache for the topics corpus. 42 feeds
    /// produce hundreds of articles per hour, so a small newest-first
    /// fetch silently truncated the 24h window to ~2 hours (issue #119).
    static let topicsCorpusFetchLimit = 800
    /// Per-outlet cap applied after the fetch: prevents a single prolific
    /// wire (ANSA alone can flood 100+ rows) from crowding the window and
    /// keeps the O(n²) lexical pass bounded.
    static let topicsPerSourceCap = 20
    /// Cap on the headlines sent to the AI grouper: keeps the prompt
    /// small enough to avoid truncated JSON and timeouts (issue #117).
    /// The sample is source-balanced, not "newest N" (issue #119).
    static let topicsAIHeadlineLimit = 100

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
        if mode == .forYou {
            refreshForYouIfNeeded()
        }
    }

    /// Pull-to-refresh on the Topics list: bypasses the 12h cache and
    /// recomputes AI-first, awaiting completion so the spinner is honest.
    func forceRefreshTopics() async {
        logger.info(
            "Topics force refresh requested",
            category: .ui,
            service: "HomeViewModel"
        )
        refreshTopicsIfNeeded(force: true)
        await topicTask?.value
    }

    /// Shows the topics: reuses the in-memory state when present, then
    /// the persisted 12h cache (issue #127), and only computes from
    /// scratch when both miss or `force` is set (pull-to-refresh).
    func refreshTopicsIfNeeded(force: Bool = false) {
        guard case let .loaded(articles) = state else {
            topicState = .empty
            return
        }
        if force == false {
            if case .ready = topicState { return }
            if case .aggregating = topicState { return }
        }

        let runToken = UUID()
        topicRunToken = runToken
        topicState = .aggregating
        topicAIFailureMessage = nil
        let requestID = "home-topics-\(UUID().uuidString.lowercased())"

        // Fresh persisted aggregation: rehydrate the saved groups from
        // the article cache instead of recomputing (issue #127).
        if force == false, let cached = topicsCache.loadFresh(requestID: requestID) {
            rehydrateTopics(from: cached, runToken: runToken, requestID: requestID)
            return
        }
        logger.info(
            "Topic aggregation started",
            category: .ui,
            service: "HomeViewModel",
            requestID: requestID,
            metadata: [
                "displayed_articles": "\(articles.count)",
                "ai_grouper": "\(topicAIGrouper != nil)"
            ]
        )
        topicTask?.cancel()
        let aggregator = topicAggregator
        let aiGrouper = topicAIGrouper
        // Corpus inputs resolved on the main actor: the cache container
        // for the last-24h fetch and the source allow-list. Without a
        // context (unit tests) the displayed articles stay the corpus.
        let container = modelContext?.container
        let allowList = sourceFilter.makeArticleAllowList(for: currentPreferences())
        topicTask = Task { [weak self, logger] in
            // The topics corpus is the full last-24h cache window
            // (issue #117), not just the articles displayed in the
            // chronological list — coverage-based importance needs the
            // whole day.
            let cutoff = Date().addingTimeInterval(-FeedTopicAggregationService.recencyWindow)
            var corpus = articles
            if let container {
                let store = ArticleLocalStore(modelContainer: container)
                if let fetched = try? await store.fetchRecentFeedArticles(
                    limit: Self.topicsCorpusFetchLimit,
                    since: cutoff,
                    requestID: requestID
                ), fetched.isEmpty == false {
                    corpus = fetched
                }
            }
            if let allowList {
                corpus = corpus.filter { article in
                    allowList.allows(sourceID: article.sourceID, sourceName: article.sourceName)
                }
            }
            // Per-outlet cap so one prolific wire cannot crowd the 24h
            // window out of the corpus (issue #119).
            corpus = Self.cappingPerSource(corpus, cap: Self.topicsPerSourceCap)

            // AI first when wired (issue #113): the grouper throws when
            // no provider is configured or the call fails, and the flow
            // falls back to the on-device lexical clustering — the feed
            // never degrades because of the provider. The provider sees
            // only the newest headlines (capped) to keep the prompt
            // reliable; ungrouped corpus articles become singletons.
            var clusters: [TopicCluster]?
            var method = TopicAggregationMethod.lexical
            var aiFailure: String?
            if let aiGrouper {
                do {
                    let recent = corpus.filter { $0.publishedAt >= cutoff }
                    // Source-balanced sample: "newest N" collapsed the
                    // AI's view to minutes; round-robin by outlet spans
                    // the whole day (issue #119).
                    let candidates = Self.balancedSample(recent, limit: Self.topicsAIHeadlineLimit)
                    if candidates.count >= 2 {
                        let groups = try await aiGrouper(candidates, requestID)
                        clusters = aggregator.clusters(
                            fromGroups: groups,
                            articles: corpus,
                            requestID: requestID
                        )
                        method = .ai
                    }
                } catch is CancellationError {
                    // Superseded by a newer run (issue #125): exit
                    // silently, the new run owns the state.
                    return
                } catch {
                    aiFailure = error.localizedDescription
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
                let lexicalCorpus = corpus
                clusters = await Task.detached(priority: .userInitiated) {
                    aggregator.aggregate(articles: lexicalCorpus, requestID: requestID)
                }.value
                method = .lexical
            }
            guard let self, Task.isCancelled == false else { return }
            guard self.topicRunToken == runToken else { return }
            self.topicAIFailureMessage = aiFailure
            let resolved = clusters ?? []
            self.topicState = resolved.isEmpty
                ? .empty
                : .ready(clusters: resolved, method: method)
            // Persist the grouping structure for 12h (issue #127): only
            // multi-article groups; singletons rebuild from the corpus.
            if resolved.isEmpty == false {
                let savedAt = Date.now
                self.topicsCache.save(
                    TopicGroupsCacheEntry(
                        savedAt: savedAt,
                        method: method == .ai ? .ai : .lexical,
                        groups: resolved
                            .filter(\.isAggregated)
                            .map { [$0.lead.id] + $0.members.map(\.id) }
                    ),
                    requestID: requestID
                )
                self.topicsCacheExpiresAt = savedAt.addingTimeInterval(TopicGroupsCache.ttl)
            }
        }
    }

    /// Rebuilds the topics state from a persisted aggregation
    /// (issue #127): fetches the corpus around the entry's save time and
    /// reapplies the saved groups — same lead selection and coverage
    /// ordering, no provider call, no lexical pass.
    private func rehydrateTopics(
        from entry: TopicGroupsCacheEntry,
        runToken: UUID,
        requestID: String
    ) {
        guard let container = modelContext?.container else {
            // No store attached (tests / placeholder context): treat the
            // cache as unusable and recompute from scratch.
            refreshTopicsIfNeeded(force: true)
            return
        }
        let allowList = sourceFilter.makeArticleAllowList(for: currentPreferences())
        let aggregator = topicAggregator
        topicTask?.cancel()
        topicTask = Task { [weak self] in
            // The window is anchored to the SAVE time, not to now:
            // otherwise a 10-hour-old aggregation would lose most of its
            // grouped articles to the 24h filter.
            let windowAnchor = entry.savedAt
            let cutoff = windowAnchor.addingTimeInterval(-FeedTopicAggregationService.recencyWindow)
            let store = ArticleLocalStore(modelContainer: container)
            var corpus = (try? await store.fetchRecentFeedArticles(
                limit: Self.topicsCorpusFetchLimit,
                since: cutoff,
                requestID: requestID
            )) ?? []
            if let allowList {
                corpus = corpus.filter { article in
                    allowList.allows(sourceID: article.sourceID, sourceName: article.sourceName)
                }
            }
            let clusters = aggregator.clusters(
                fromGroups: entry.groups,
                articles: corpus,
                now: windowAnchor,
                requestID: requestID
            )
            guard let self, Task.isCancelled == false else { return }
            guard self.topicRunToken == runToken else { return }
            if clusters.isEmpty {
                // Cache no longer maps to stored articles — recompute.
                self.refreshTopicsIfNeeded(force: true)
            } else {
                self.topicState = .ready(
                    clusters: clusters,
                    method: entry.method == .ai ? .ai : .lexical
                )
                self.topicsCacheExpiresAt = entry.savedAt.addingTimeInterval(TopicGroupsCache.ttl)
            }
        }
    }

    // MARK: - For You personalization (issue #133)

    /// Pull-to-refresh on the For You list: bypasses the 12h cache and
    /// re-ranks, awaiting completion so the spinner is honest.
    func forceRefreshForYou() async {
        logger.info(
            "For You force refresh requested",
            category: .ui,
            service: "HomeViewModel"
        )
        refreshForYouIfNeeded(force: true)
        await forYouTask?.value
    }

    /// Shows the personalized feed: in-memory state first, then the
    /// persisted 12h cache, and only calls the provider when both miss
    /// or `force` is set. AI-only by design (issue #133): no provider
    /// or no interests produce dedicated honest states, never a
    /// silent fallback ranking.
    func refreshForYouIfNeeded(force: Bool = false) {
        guard case let .loaded(displayed) = state else {
            forYouState = .empty
            return
        }
        let interests = currentPreferences()?.preferredTopics ?? []
        guard interests.isEmpty == false else {
            forYouState = .needsInterests
            return
        }
        guard let picker = forYouAIPicker else {
            forYouState = .needsProvider
            return
        }
        if force == false {
            if case .ready = forYouState { return }
            if case .loading = forYouState { return }
        }

        let runToken = UUID()
        forYouRunToken = runToken
        forYouState = .loading
        let requestID = "home-foryou-\(UUID().uuidString.lowercased())"

        if force == false, let cached = forYouCache.loadFresh(requestID: requestID) {
            rehydrateForYou(from: cached, runToken: runToken, requestID: requestID)
            return
        }
        logger.info(
            "For You personalization started",
            category: .ui,
            service: "HomeViewModel",
            requestID: requestID,
            metadata: ["interests": "\(interests.count)"]
        )
        forYouTask?.cancel()
        let container = modelContext?.container
        let allowList = sourceFilter.makeArticleAllowList(for: currentPreferences())
        forYouTask = Task { [weak self, logger, forYouCache] in
            // Without a store (unit tests) the displayed articles stay
            // the corpus, mirroring the topics flow.
            let corpus = await Self.loadPersonalizationCorpus(
                container: container,
                allowList: allowList,
                fallback: displayed,
                anchor: .now,
                requestID: requestID
            )
            let candidates = Self.balancedSample(
                corpus.filter { $0.publishedAt >= Date().addingTimeInterval(-FeedTopicAggregationService.recencyWindow) },
                limit: Self.topicsAIHeadlineLimit
            )
            guard candidates.isEmpty == false else {
                guard let self, self.forYouRunToken == runToken else { return }
                self.forYouState = .empty
                return
            }
            do {
                let rawPicks = try await picker(interests, candidates, requestID)
                guard let self, Task.isCancelled == false else { return }
                guard self.forYouRunToken == runToken else { return }
                let picks = Self.resolvePicks(rawPicks, articles: corpus)
                self.forYouState = picks.isEmpty ? .empty : .ready(picks: picks)
                if picks.isEmpty == false {
                    let savedAt = Date.now
                    forYouCache.save(
                        ForYouPicksCacheEntry(savedAt: savedAt, picks: rawPicks),
                        requestID: requestID
                    )
                    self.forYouCacheExpiresAt = savedAt.addingTimeInterval(ForYouPicksCache.ttl)
                }
            } catch is CancellationError {
                // Superseded by a newer run (issue #125 semantics).
                return
            } catch {
                guard let self, self.forYouRunToken == runToken else { return }
                if case AIServiceError.invalidConfiguration = error {
                    self.forYouState = .needsProvider
                } else if case AIServiceError.missingToken = error {
                    self.forYouState = .needsProvider
                } else {
                    self.forYouState = .failed(message: error.localizedDescription)
                }
                logger.warn(
                    "For You personalization failed",
                    category: .business,
                    service: "HomeViewModel",
                    requestID: requestID,
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    /// Rebuilds the For You state from a persisted ranking: fetches the
    /// corpus anchored to the save time and maps the saved picks back to
    /// articles — no provider call.
    private func rehydrateForYou(
        from entry: ForYouPicksCacheEntry,
        runToken: UUID,
        requestID: String
    ) {
        guard let container = modelContext?.container else {
            refreshForYouIfNeeded(force: true)
            return
        }
        let allowList = sourceFilter.makeArticleAllowList(for: currentPreferences())
        forYouTask?.cancel()
        forYouTask = Task { [weak self] in
            let corpus = await Self.loadPersonalizationCorpus(
                container: container,
                allowList: allowList,
                fallback: [],
                anchor: entry.savedAt,
                requestID: requestID
            )
            let picks = Self.resolvePicks(entry.picks, articles: corpus)
            guard let self, Task.isCancelled == false else { return }
            guard self.forYouRunToken == runToken else { return }
            if picks.isEmpty {
                // Cache no longer maps to stored articles — recompute.
                self.refreshForYouIfNeeded(force: true)
            } else {
                self.forYouState = .ready(picks: picks)
                self.forYouCacheExpiresAt = entry.savedAt.addingTimeInterval(ForYouPicksCache.ttl)
            }
        }
    }

    /// Last-24h corpus for the personalization, same shape as the topics
    /// corpus: cache fetch anchored to `anchor`, allow-list filter,
    /// per-outlet cap.
    nonisolated private static func loadPersonalizationCorpus(
        container: ModelContainer?,
        allowList: ArticleSourceAllowList?,
        fallback: [Article],
        anchor: Date,
        requestID: String
    ) async -> [Article] {
        let cutoff = anchor.addingTimeInterval(-FeedTopicAggregationService.recencyWindow)
        var corpus = fallback
        if let container {
            let store = ArticleLocalStore(modelContainer: container)
            if let fetched = try? await store.fetchRecentFeedArticles(
                limit: topicsCorpusFetchLimit,
                since: cutoff,
                requestID: requestID
            ), fetched.isEmpty == false {
                corpus = fetched
            }
        }
        if let allowList {
            corpus = corpus.filter { article in
                allowList.allows(sourceID: article.sourceID, sourceName: article.sourceName)
            }
        }
        return cappingPerSource(corpus, cap: topicsPerSourceCap)
    }

    /// Maps validated AI picks back to articles, preserving the
    /// relevance order; picks whose article left the cache are dropped.
    nonisolated private static func resolvePicks(
        _ picks: [AIHeadlinePick],
        articles: [Article]
    ) -> [ForYouPick] {
        let byID = Dictionary(articles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return picks
            .sorted { $0.relevance > $1.relevance }
            .compactMap { pick in
                guard let article = byID[pick.id] else { return nil }
                return ForYouPick(article: article, interest: pick.interest, relevance: pick.relevance)
            }
    }

    // MARK: - For You localized copy

    var displayModeForYouLabel: String {
        String(localized: "home.feed_mode.for_you", defaultValue: "For You")
    }

    var forYouLoadingLabel: String {
        String(
            localized: "home.for_you.loading",
            defaultValue: "Picking the news for you…"
        )
    }

    var forYouLoadingHint: String {
        String(
            localized: "home.for_you.loading.hint",
            defaultValue: "AI is matching the last 24 hours against your interests"
        )
    }

    var forYouNeedsProviderTitle: String {
        String(
            localized: "home.for_you.needs_provider.title",
            defaultValue: "For You needs an AI provider"
        )
    }

    var forYouNeedsProviderSubtitle: String {
        String(
            localized: "home.for_you.needs_provider.subtitle",
            defaultValue: "This feed is ranked by AI against your interests. Configure a provider in Settings to enable it."
        )
    }

    var forYouNeedsInterestsTitle: String {
        String(
            localized: "home.for_you.needs_interests.title",
            defaultValue: "Tell us what you care about"
        )
    }

    var forYouNeedsInterestsSubtitle: String {
        String(
            localized: "home.for_you.needs_interests.subtitle",
            defaultValue: "Add your interests in Settings and the AI will pick matching stories here."
        )
    }

    var forYouEmptyLabel: String {
        String(
            localized: "home.for_you.empty",
            defaultValue: "No stories matching your interests in the last 24 hours."
        )
    }

    var forYouFailedTitle: String {
        String(
            localized: "home.for_you.failed.title",
            defaultValue: "Personalization failed"
        )
    }

    var forYouRetryLabel: String {
        String(localized: "home.for_you.retry", defaultValue: "Try again")
    }

    /// Countdown copy for the Topics footer (issue #131).
    var topicsAutoRefreshLabel: String {
        String(
            localized: "home.topics.auto_refresh",
            defaultValue: "Refreshes automatically in"
        )
    }

    /// Keeps at most `cap` articles per outlet, preserving order.
    nonisolated private static func cappingPerSource(_ articles: [Article], cap: Int) -> [Article] {
        var counts: [String: Int] = [:]
        return articles.filter { article in
            let key = article.sourceID ?? article.sourceName
            let count = counts[key, default: 0]
            guard count < cap else { return false }
            counts[key] = count + 1
            return true
        }
    }

    /// Round-robin sample across outlets up to `limit`: every source
    /// contributes its newest article before any source contributes its
    /// second, so the sample spans the whole window.
    nonisolated private static func balancedSample(_ articles: [Article], limit: Int) -> [Article] {
        guard articles.count > limit else { return articles }
        var bySource: [String: [Article]] = [:]
        var sourceOrder: [String] = []
        for article in articles {
            let key = article.sourceID ?? article.sourceName
            if bySource[key] == nil { sourceOrder.append(key) }
            bySource[key, default: []].append(article)
        }
        var sample: [Article] = []
        var round = 0
        while sample.count < limit {
            var added = false
            for key in sourceOrder where sample.count < limit {
                if let sourceArticles = bySource[key], round < sourceArticles.count {
                    sample.append(sourceArticles[round])
                    added = true
                }
            }
            if added == false { break }
            round += 1
        }
        return sample
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
