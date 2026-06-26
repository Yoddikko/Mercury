//
//  ArticleDetailScreen.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import SwiftUI

/// Screen rendering a single article's body and metadata.
///
/// The view delegates state, persistence, and enrichment side effects to
/// `ArticleDetailViewModel`. It owns only layout, navigation chrome, the
/// system share sheet, and the lifecycle hook that fires `onAppear` on the
/// view model.
struct ArticleDetailScreen: View {
    @StateObject private var viewModel: ArticleDetailViewModel
    @State private var isPresentingShareSheet: Bool = false

    init(viewModel: @autoclosure @escaping () -> ArticleDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        content
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await viewModel.onAppear() }
            .refreshable { await viewModel.refresh() }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let url = viewModel.currentArticle?.articleURL {
                    ShareSheet(activityItems: [url])
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case let .loaded(article):
            loadedView(article: article)
        case let .error(message):
            errorView(message: message)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(viewModel.loadingLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("article.detail.state.loading")
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
            .accessibilityIdentifier("article.detail.state.error.retry")
        }
        .accessibilityIdentifier("article.detail.state.error")
    }

    private func loadedView(article: Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroImage(for: article)
                titleBlock(for: article)
                if viewModel.shouldShowAISummarySection {
                    aiSummarySection
                } else if let summary = article.summaryShort?.trimmingCharacters(in: .whitespacesAndNewlines),
                          summary.isEmpty == false {
                    summarySection(text: summary)
                }
                bodySection(for: article)
                Spacer(minLength: 24)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("article.detail.state.loaded")
    }

    @ViewBuilder
    private func heroImage(for article: Article) -> some View {
        if let url = article.heroImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(viewModel.heroImageAccessibilityLabel)
            .accessibilityIdentifier("article.detail.hero")
        }
    }

    private func titleBlock(for article: Article) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("article.detail.title")

            Text(viewModel.metadataLine(for: article))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("article.detail.metadata")

            if let authorLine = viewModel.authorLine(for: article) {
                Text(authorLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("article.detail.author")
            }

            if let category = article.category, category.isEmpty == false {
                Text(category)
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .accessibilityIdentifier("article.detail.category")
            }
        }
    }

    private func summarySection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.summarySectionTitle)
                .font(.headline)
            Text(text)
                .font(.body)
                .accessibilityIdentifier("article.detail.summary")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.aiSummarySectionTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            switch viewModel.summaryState {
            case .summarizing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.aiSummaryLoadingLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("article.detail.ai_summary.loading")

            case let .ready(summary):
                aiSummaryContent(summary)

            case .failed:
                Text(viewModel.aiSummaryFailedLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("article.detail.ai_summary.failed")
                if viewModel.canRegenerateAISummary {
                    Button {
                        Task { await viewModel.regenerateSummary() }
                    } label: {
                        Text(viewModel.aiSummaryRegenerateLabel)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("article.detail.ai_summary.regenerate")
                }

            case .idle:
                if viewModel.shouldShowAISummaryUnavailable {
                    Text(viewModel.aiSummaryUnavailableLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("article.detail.ai_summary.unavailable")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("article.detail.ai_summary")
    }

    @ViewBuilder
    private func aiSummaryContent(_ summary: AISummaryResult) -> some View {
        let trimmedShort = summary.shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedShort.isEmpty == false {
            Text(trimmedShort)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("article.detail.ai_summary.short")
        }

        let bullets = summary.bullets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        if bullets.isEmpty == false {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(bullet)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.aiSummaryBulletsAccessibilityLabel)
            .accessibilityIdentifier("article.detail.ai_summary.bullets")
        }
    }

    private func bodySection(for _: Article) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.bodySectionTitle)
                .font(.headline)

            if viewModel.enrichmentState == .enriching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.enrichingLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("article.detail.body.enriching")
            }

            if viewModel.enrichmentState == .failed {
                Text(viewModel.enrichmentFailedLabel)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("article.detail.body.enrichment_failed")
            }

            if let body = viewModel.displayBody {
                Text(body)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("article.detail.body")
            } else if viewModel.shouldShowBodyPlaceholder {
                Text(viewModel.bodyPlaceholderLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("article.detail.body.placeholder")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            bookmarkButton
        }
        ToolbarItem(placement: .topBarTrailing) {
            shareButton
        }
    }

    private var bookmarkButton: some View {
        let isBookmarked = viewModel.currentArticle?.isBookmarked == true
        let symbol = isBookmarked ? "bookmark.fill" : "bookmark"
        let title = isBookmarked ? viewModel.bookmarkRemoveLabel : viewModel.bookmarkAddLabel
        let accessibilityValue = isBookmarked
            ? viewModel.bookmarkedAccessibilityValue
            : viewModel.notBookmarkedAccessibilityValue
        return Button {
            Task { await viewModel.toggleBookmark() }
        } label: {
            Image(systemName: symbol)
        }
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("article.detail.actions.bookmark")
        .disabled(viewModel.currentArticle == nil || viewModel.isTogglingBookmark)
    }

    private var shareButton: some View {
        Button {
            isPresentingShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel(viewModel.shareLabel)
        .accessibilityIdentifier("article.detail.actions.share")
        .disabled(viewModel.currentArticle == nil)
    }
}

/// Lightweight UIKit bridge for the standard activity controller.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Loaded") {
    NavigationStack {
        ArticleDetailScreen(
            viewModel: ArticleDetailViewModel(
                article: Article.previewFeed.first!,
                bookmarkToggle: { _ in true },
                recordOpen: { _ in },
                enrichContent: nil
            )
        )
    }
}
