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
    @ObservedObject var viewModel: HomeViewModel
    @StateObject private var searchViewModel: SearchViewModel
#if DEBUG
    let developerPlaygroundViewModel: DeveloperPlaygroundViewModel
#endif

    @Environment(\.modelContext) private var modelContext

#if DEBUG
    init(
        viewModel: HomeViewModel,
        developerPlaygroundViewModel: DeveloperPlaygroundViewModel,
        searchViewModel: SearchViewModel? = nil
    ) {
        self.viewModel = viewModel
        self.developerPlaygroundViewModel = developerPlaygroundViewModel
        _searchViewModel = StateObject(
            wrappedValue: searchViewModel ?? SearchViewModel()
        )
    }
#else
    init(
        viewModel: HomeViewModel,
        searchViewModel: SearchViewModel? = nil
    ) {
        self.viewModel = viewModel
        _searchViewModel = StateObject(
            wrappedValue: searchViewModel ?? SearchViewModel()
        )
    }
#endif

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(viewModel.navigationTitle)
                .refreshable {
                    await viewModel.refresh()
                }
                .task {
                    viewModel.attach(modelContext: modelContext)
                    searchViewModel.attach(
                        repository: SwiftDataArticleRepository(modelContainer: modelContext.container)
                    )
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
            loadedList(articles: articles)
        }
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
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("home.state.error.retry")
        }
        .accessibilityIdentifier("home.state.error")
    }

    private func loadedList(articles: [Article]) -> some View {
        List {
            Section {
                ForEach(articles) { article in
                    NavigationLink {
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
                                }
                            )
                        )
                    } label: {
                        ArticleCard(article: article, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.articlesSectionTitle)
                        .font(.headline)
                    Spacer()
                    if let lastUpdatedAt = viewModel.lastUpdatedAt {
                        Text(viewModel.lastUpdatedLabel(for: lastUpdatedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("home.last_updated")
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("home.state.loaded")
    }
}

private struct ArticleCard: View {
    let article: Article
    let viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
                .accessibilityIdentifier("home.article.title")

            Text(viewModel.articleMetadataLine(
                sourceName: article.sourceName,
                publishedAt: article.publishedAt
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("home.article.metadata")

            if let summary = article.summaryShort, summary.isEmpty == false {
                Text(summary)
                    .font(.body)
                    .lineLimit(3)
                    .accessibilityIdentifier("home.article.summary")
            }

            if let category = article.category, category.isEmpty == false {
                Text(category)
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .accessibilityIdentifier("home.article.category")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ArticleCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 18)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 160, height: 12)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 12)
        }
        .padding(.vertical, 6)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

#Preview("Loaded") {
    let viewModel = HomeViewModel(
        feedRefreshAction: {
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
        feedRefreshAction: {
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
