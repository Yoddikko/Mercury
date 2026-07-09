//
//  HomeScreen.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//  Wired to live RSS feed on 25/06/26.
//

import SwiftData
import SwiftUI

struct HomeScreen: View {
    typealias ArticleSummarize = @Sendable (Article) async throws -> AISummaryResult

    @ObservedObject var viewModel: HomeViewModel
    @StateObject private var searchViewModel: SearchViewModel
    private let articleSummarize: ArticleSummarize?
#if DEBUG
    let developerPlaygroundViewModel: DeveloperPlaygroundViewModel
#endif

    @Environment(\.modelContext) private var modelContext

#if DEBUG
    init(
        viewModel: HomeViewModel,
        developerPlaygroundViewModel: DeveloperPlaygroundViewModel,
        searchViewModel: SearchViewModel? = nil,
        articleSummarize: ArticleSummarize? = nil
    ) {
        self.viewModel = viewModel
        self.developerPlaygroundViewModel = developerPlaygroundViewModel
        self.articleSummarize = articleSummarize
        _searchViewModel = StateObject(
            wrappedValue: searchViewModel ?? SearchViewModel()
        )
    }
#else
    init(
        viewModel: HomeViewModel,
        searchViewModel: SearchViewModel? = nil,
        articleSummarize: ArticleSummarize? = nil
    ) {
        self.viewModel = viewModel
        self.articleSummarize = articleSummarize
        _searchViewModel = StateObject(
            wrappedValue: searchViewModel ?? SearchViewModel()
        )
    }
#endif

    var body: some View {
        NavigationStack {
            content
                .paperScreen()
                .navigationTitle(viewModel.navigationTitle)
                .refreshable {
                    await viewModel.refresh()
                }
                .task {
                    viewModel.attach(modelContext: modelContext)
                    searchViewModel.attach(
                        repository: SwiftDataArticleRepository(modelContainer: modelContext.container)
                    )
                    // Feed sources preferences gate search results too
                    // (issue #94): without the context the search would
                    // surface cached articles from disabled sources.
                    searchViewModel.attach(modelContext: modelContext)
                    await viewModel.loadInitialFeedIfNeeded()
                }
                .searchable(
                    text: $searchViewModel.query,
                    prompt: Text(searchViewModel.searchPrompt)
                )
                .task(id: searchViewModel.query) {
                    await searchViewModel.runSearch()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsScreen()
                        } label: {
                            Label(
                                String(
                                    localized: "home.settings.label",
                                    defaultValue: "Settings"
                                ),
                                systemImage: "gearshape"
                            )
                        }
                        .accessibilityIdentifier("home.settings")
                    }
#if DEBUG
                    if viewModel.isDeveloperModeEnabled {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                DeveloperPlaygroundScreen(viewModel: developerPlaygroundViewModel)
                            } label: {
                                Label(viewModel.developerToolsLabel, systemImage: "ladybug.fill")
                            }
                            .accessibilityIdentifier("home.developerTools")
                        }
                    }
#endif
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if searchViewModel.isQueryActive {
            searchContent
        } else {
            feedContent
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .empty:
            emptyView
        case let .failed(message):
            errorView(message: message)
        case let .loaded(articles):
            VStack(spacing: 0) {
                feedModePicker
                switch viewModel.displayMode {
                case .chronological:
                    loadedList(articles: articles)
                case .topics:
                    topicsContent
                }
            }
        }
    }

    /// Paper-styled two-way segmented control (issue #109): the
    /// selected mode is an ink-filled block, the other a hairline box —
    /// printed tabs, per the design system.
    private var feedModePicker: some View {
        HStack(spacing: 0) {
            feedModeButton(.chronological, label: viewModel.displayModeChronologicalLabel)
            feedModeButton(.topics, label: viewModel.displayModeTopicsLabel)
        }
        .overlay(Rectangle().stroke(Color.paperInk, lineWidth: 0.8))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(viewModel.feedModePickerAccessibilityLabel)
    }

    private func feedModeButton(
        _ mode: HomeViewModel.FeedDisplayMode,
        label: String
    ) -> some View {
        let isSelected = viewModel.displayMode == mode
        return Button {
            viewModel.selectDisplayMode(mode)
        } label: {
            Text(label)
                .font(.paperBadge)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.paperBackground : Color.paperInk)
                .background(isSelected ? Color.paperInk : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("home.feed_mode.\(mode.rawValue)")
    }

    @ViewBuilder
    private var topicsContent: some View {
        switch viewModel.topicState {
        case .idle, .aggregating:
            topicsAggregatingView
        case .empty:
            ContentUnavailableView {
                Label(viewModel.topicsEmptyLabel, systemImage: "newspaper")
            }
            .accessibilityIdentifier("home.topics.empty")
        case let .ready(clusters, method):
            topicsList(clusters: clusters, method: method)
        }
    }

    /// Dedicated "grouping…" state: aggregation runs off-main and the
    /// user asked to see clearly that the news are being grouped.
    private var topicsAggregatingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.paperInk)
            Text(viewModel.topicsAggregatingLabel)
                .font(.paperHeadline)
                .foregroundStyle(Color.paperInk)
                .multilineTextAlignment(.center)
            Text(viewModel.topicsAggregatingHint.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .accessibilityIdentifier("home.topics.aggregating")
        .task { viewModel.refreshTopicsIfNeeded() }
    }

    private func topicsList(
        clusters: [TopicCluster],
        method: HomeViewModel.TopicAggregationMethod
    ) -> some View {
        let aggregated = clusters.filter(\.isAggregated)
        let singles = clusters.filter { $0.isAggregated == false }
        return List {
            // Small AI indicator (issue #113): tells the user the
            // grouping came from the configured provider.
            if method == .ai {
                Section {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text(viewModel.topicsAIAggregatedLabel.uppercased())
                            .font(.paperBadge)
                    }
                    .foregroundStyle(Color.paperRule)
                    .listRowSeparator(.hidden)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(viewModel.topicsAIAggregatedLabel)
                    .accessibilityIdentifier("home.topics.ai_badge")
                }
            }
            Section {
                ForEach(aggregated) { cluster in
                    TopicClusterCard(
                        cluster: cluster,
                        viewModel: viewModel,
                        destination: { article in articleDestination(article) }
                    )
                    .listRowSeparator(.hidden)
                }
            }
            if singles.isEmpty == false {
                Section {
                    ForEach(singles) { cluster in
                        articleLink(cluster.lead) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cluster.lead.title)
                                    .font(.paperCallout)
                                    .foregroundStyle(Color.paperInk)
                                    .lineLimit(2)
                                Text(viewModel.articleMetadataLine(
                                    sourceName: cluster.lead.sourceName,
                                    publishedAt: cluster.lead.publishedAt
                                ))
                                .font(.paperMeta)
                                .foregroundStyle(Color.paperRule)
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(viewModel.topicsOthersSectionTitle.uppercased())
                        .font(.paperBadge)
                        .foregroundStyle(Color.paperRule)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            // Re-aggregates from scratch (issue #117): also retries the
            // AI path after the user configures a provider.
            await viewModel.forceRefreshTopics()
        }
        .accessibilityIdentifier("home.topics.loaded")
    }

    @ViewBuilder
    private var searchContent: some View {
        switch searchViewModel.state {
        case .idle, .searching:
            loadingView
        case .empty:
            ContentUnavailableView {
                Label(searchViewModel.noResultsTitle, systemImage: "magnifyingglass")
            } description: {
                Text(searchViewModel.noResultsSubtitle(for: searchViewModel.query))
            }
            .accessibilityIdentifier("home.search.empty")
        case let .results(articles):
            loadedList(articles: articles)
                .accessibilityLabel(searchViewModel.resultsAccessibilityLabel)
                .accessibilityIdentifier("home.search.results")
        }
    }

    private var loadingView: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                ArticleCardSkeleton()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .accessibilityLabel(viewModel.loadingLabel)
        .accessibilityIdentifier("home.state.loading")
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label(viewModel.emptyTitle, systemImage: "newspaper")
        } description: {
            Text(viewModel.emptySubtitle)
        }
        .accessibilityIdentifier("home.state.empty")
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label(viewModel.errorTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text(viewModel.errorRetryLabel)
            }
            .buttonStyle(.paperPrimary)
            .accessibilityIdentifier("home.state.error.retry")
        }
        .accessibilityIdentifier("home.state.error")
    }

    /// Shared destination for every article tap in Home — the
    /// chronological list, topic cluster leads and member rows all
    /// route to the same detail stack.
    private func articleDestination(_ article: Article) -> ArticleDetailScreen {
        ArticleDetailScreen(
            viewModel: ArticleDetailViewModel(
                article: article,
                bookmarkToggle: { [modelContext] id in
                    let store = ArticleLocalStore(modelContainer: modelContext.container)
                    return try await store.toggleFavorite(articleID: id)
                },
                recordOpen: { [modelContext] id in
                    let store = ArticleLocalStore(modelContainer: modelContext.container)
                    try await store.recordOpen(articleID: id, markAsRead: true)
                },
                summarize: articleSummarize
            )
        )
    }

    private func articleLink<Label: View>(
        _ article: Article,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            articleDestination(article)
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    private func loadedList(articles: [Article]) -> some View {
        List {
            Section {
                ForEach(articles) { article in
                    articleLink(article) {
                        ArticleCard(article: article, viewModel: viewModel)
                    }
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.articlesSectionTitle)
                        .font(.paperHeadline)
                        .foregroundStyle(Color.paperInk)
                    Spacer()
                    if let lastUpdatedAt = viewModel.lastUpdatedAt {
                        Text(viewModel.lastUpdatedLabel(for: lastUpdatedAt))
                            .font(.paperMeta)
                            .foregroundStyle(Color.paperRule)
                            .accessibilityIdentifier("home.last_updated")
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("home.state.loaded")
    }
}

/// One aggregated story (issue #109/#117): coverage badge, lead with
/// the only thumbnail, member titles as a preview. The whole card is a
/// single tap target opening `TopicClusterScreen`, where the user picks
/// which outlet's article to read.
private struct TopicClusterCard: View {
    let cluster: TopicCluster
    let viewModel: HomeViewModel
    let destination: (Article) -> ArticleDetailScreen

    /// Space management: at most this many member titles per card.
    private static let maxVisibleMembers = 3

    var body: some View {
        NavigationLink {
            TopicClusterScreen(
                cluster: cluster,
                viewModel: viewModel,
                destination: destination
            )
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.topics.cluster.\(cluster.id)")
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaperBadge(text: viewModel.topicsCoverageLabel(sourceCount: cluster.sourceCount))
                .accessibilityIdentifier("home.topics.coverage")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.lead.title)
                        .font(.paperHeadline)
                        .foregroundStyle(Color.paperInk)
                    Text(viewModel.articleMetadataLine(
                        sourceName: cluster.lead.sourceName,
                        publishedAt: cluster.lead.publishedAt
                    ))
                    .font(.paperMeta)
                    .foregroundStyle(Color.paperRule)
                }
                Spacer(minLength: 0)
                leadThumbnail
            }

            ForEach(cluster.members.prefix(Self.maxVisibleMembers)) { member in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(member.sourceName.uppercased())
                        .font(.paperBadge)
                        .foregroundStyle(Color.paperRule)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Text(member.title)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperInk)
                        .lineLimit(2)
                }
                .padding(.leading, 12)
            }

            if cluster.members.count > Self.maxVisibleMembers {
                Text(viewModel.topicsMoreArticlesLabel(
                    count: cluster.members.count - Self.maxVisibleMembers
                ))
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
                .padding(.leading, 12)
            }

            PaperRule()
                .padding(.top, 8)
        }
        .padding(.vertical, 6)
    }

    /// Thumbnail for the lead only — background-defines-layout so the
    /// image can never inflate the row (design system rule, #107).
    @ViewBuilder
    private var leadThumbnail: some View {
        if let url = cluster.lead.heroImageURL {
            Rectangle()
                .fill(Color.paperRule.opacity(0.12))
                .frame(width: 64, height: 64)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
                .clipped()
                .overlay(Rectangle().stroke(Color.paperRule.opacity(0.35), lineWidth: 0.8))
                .accessibilityHidden(true)
        }
    }
}

private struct ArticleCard: View {
    let article: Article
    let viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.paperHeadline)
                .foregroundStyle(Color.paperInk)
                .accessibilityIdentifier("home.article.title")

            Text(viewModel.articleMetadataLine(
                sourceName: article.sourceName,
                publishedAt: article.publishedAt
            ))
            .font(.paperMeta)
            .foregroundStyle(Color.paperRule)
            .accessibilityIdentifier("home.article.metadata")

            if let summary = article.summaryShort, summary.isEmpty == false {
                Text(summary)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperInk)
                    .lineLimit(3)
                    .accessibilityIdentifier("home.article.summary")
            }

            if let category = article.category, category.isEmpty == false {
                PaperBadge(text: category)
                    .accessibilityIdentifier("home.article.category")
            }

            PaperRule()
                .padding(.top, 8)
        }
        .padding(.vertical, 6)
    }
}

private struct ArticleCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color.paperRule.opacity(0.2))
                .frame(height: 18)
            Rectangle()
                .fill(Color.paperRule.opacity(0.15))
                .frame(width: 160, height: 12)
            Rectangle()
                .fill(Color.paperRule.opacity(0.1))
                .frame(height: 12)
            Rectangle()
                .fill(Color.paperRule.opacity(0.1))
                .frame(height: 12)
        }
        .padding(.vertical, 6)
        .paperShimmer()
        .accessibilityHidden(true)
    }
}

#Preview("Loaded") {
    let viewModel = HomeViewModel(
        feedRefreshAction: { _ in
            RSSFeedBatchResult(
                checkedAt: Date(),
                groupMode: .mainOutlets,
                selectedRegion: nil,
                checks: [],
                deduplicatedArticles: Article.previewFeed
            )
        },
        isDeveloperModeEnabled: false
    )
#if DEBUG
    return HomeScreen(
        viewModel: viewModel,
        developerPlaygroundViewModel: DeveloperPlaygroundViewModel()
    )
#else
    return HomeScreen(viewModel: viewModel)
#endif
}

#Preview("Empty") {
    let viewModel = HomeViewModel(
        feedRefreshAction: { _ in
            RSSFeedBatchResult(
                checkedAt: Date(),
                groupMode: .mainOutlets,
                selectedRegion: nil,
                checks: [],
                deduplicatedArticles: []
            )
        },
        isDeveloperModeEnabled: false
    )
#if DEBUG
    return HomeScreen(
        viewModel: viewModel,
        developerPlaygroundViewModel: DeveloperPlaygroundViewModel()
    )
#else
    return HomeScreen(viewModel: viewModel)
#endif
}
