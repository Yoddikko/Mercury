//
//  ArticleDetailScreen.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import SwiftUI
import SwiftData

/// Screen rendering a single article's body and metadata.
///
/// The view delegates state, persistence, and enrichment side effects to
/// `ArticleDetailViewModel`. It owns only layout, navigation chrome, the
/// system share sheet, and the lifecycle hook that fires `onAppear` on the
/// view model.
///
/// The body is rendered natively via `ArticleBlockListView` — the
/// legacy `WKWebView` renderer was removed in issue #83.
struct ArticleDetailScreen: View {
    @StateObject private var viewModel: ArticleDetailViewModel
    @State private var isPresentingShareSheet: Bool = false

    init(viewModel: @autoclosure @escaping () -> ArticleDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        content
            .paperScreen()
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
                .font(.paperCallout)
                .foregroundStyle(Color.paperRule)
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
            .buttonStyle(.paperPrimary)
            .accessibilityIdentifier("article.detail.state.error.retry")
        }
        .accessibilityIdentifier("article.detail.state.error")
    }

    private func loadedView(article: Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroImage(for: article)
                titleBlock(for: article)
                if let label = viewModel.readingTimeLabel {
                    Text(label)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                        .accessibilityIdentifier("article.detail.reading_time")
                }
                aiSummarySection
                bodySection(for: article)
                openOriginalButton(for: article)
                Spacer(minLength: 24)
            }
            // Pin the reader column to the container width so no child
            // can inflate it past the screen and eat the gutter
            // (issue #107); the constant padding keeps the gutter
            // identical on every article.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("article.detail.state.loaded")
    }

    @ViewBuilder
    private func heroImage(for article: Article) -> some View {
        if let url = article.heroImageURL {
            // Background-defines-layout: the placeholder rectangle owns
            // the layout size and the image lives in an overlay, so a
            // wide-aspect hero can never propose its intrinsic width and
            // inflate the reader column (issue #107 — `frame(maxWidth:)`
            // does not shrink an oversized `scaledToFill` child).
            Rectangle()
                .fill(Color.paperRule.opacity(0.12))
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(Color.paperRule)
                        @unknown default:
                            Color.clear
                        }
                    }
                }
                .clipped()
                .overlay(Rectangle().stroke(Color.paperRule.opacity(0.35), lineWidth: 0.8))
                .accessibilityLabel(viewModel.heroImageAccessibilityLabel)
                .accessibilityIdentifier("article.detail.hero")
        }
    }

    private func titleBlock(for article: Article) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.paperTitle)
                .foregroundStyle(Color.paperInk)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("article.detail.title")

            Text(viewModel.metadataLine(for: article))
                .font(.paperMeta)
                .foregroundStyle(Color.paperRule)
                .accessibilityIdentifier("article.detail.metadata")

            if let authorLine = viewModel.authorLine(for: article) {
                Text(authorLine)
                    .font(.paperMeta)
                    .foregroundStyle(Color.paperRule)
                    .accessibilityIdentifier("article.detail.author")
            }

            if let category = article.category, category.isEmpty == false {
                PaperBadge(text: category)
                    .accessibilityIdentifier("article.detail.category")
            }

            PaperRule()
                .padding(.top, 4)
        }
    }

    private func openOriginalButton(for article: Article) -> some View {
        Link(destination: article.articleURL) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                Text(viewModel.openOriginalLabel)
            }
        }
        .buttonStyle(.paperSecondary)
        .accessibilityIdentifier("article.detail.actions.open_original")
        .padding(.top, 8)
    }

    @ViewBuilder
    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.aiSummarySectionTitle.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)
                .accessibilityAddTraits(.isHeader)

            switch viewModel.summaryState {
            case .summarizing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.aiSummaryLoadingLabel)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperRule)
                }
                .accessibilityIdentifier("article.detail.ai_summary.loading")

            case let .ready(summary):
                aiSummaryContent(summary)
                if viewModel.canRegenerateAISummary {
                    Button {
                        Task { await viewModel.regenerateSummary() }
                    } label: {
                        Label(
                            viewModel.aiSummaryRegenerateAffordanceLabel,
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.paperSecondary)
                    .accessibilityHint(viewModel.aiSummaryRegenerateAffordanceAccessibilityHint)
                    .accessibilityIdentifier("article.detail.ai_summary.regenerate_affordance")
                }

            case .failed:
                Text(viewModel.aiSummaryFailedLabel)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperError)
                    .accessibilityIdentifier("article.detail.ai_summary.failed")
                if viewModel.canRegenerateAISummary {
                    Button {
                        Task { await viewModel.regenerateSummary() }
                    } label: {
                        Text(viewModel.aiSummaryRegenerateLabel)
                    }
                    .buttonStyle(.paperSecondary)
                    .accessibilityIdentifier("article.detail.ai_summary.regenerate")
                }

            case .idle:
                if viewModel.shouldShowAISummaryGenerateButton {
                    Button {
                        Task { await viewModel.requestSummary() }
                    } label: {
                        Label(
                            viewModel.aiSummaryPrimaryButtonLabel,
                            systemImage: "sparkles"
                        )
                    }
                    .buttonStyle(.paperPrimary)
                    .accessibilityHint(viewModel.aiSummaryGenerateAccessibilityHint)
                    .accessibilityIdentifier("article.detail.ai_summary.generate")
                } else if viewModel.shouldShowAISummaryUnavailable {
                    Text(viewModel.aiSummaryUnavailableLabel)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperRule)
                        .accessibilityIdentifier("article.detail.ai_summary.unavailable")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .overlay(Rectangle().stroke(Color.paperRule.opacity(0.35), lineWidth: 0.8))
        .accessibilityIdentifier("article.detail.ai_summary")
    }

    @ViewBuilder
    private func aiSummaryContent(_ summary: AISummaryResult) -> some View {
        let trimmedShort = summary.shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedShort.isEmpty == false {
            Text(trimmedShort)
                .font(.paperBody)
                .foregroundStyle(Color.paperInk)
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
                            .font(.paperBody.weight(.semibold))
                            .foregroundStyle(Color.paperRule)
                            .accessibilityHidden(true)
                        Text(bullet)
                            .font(.paperCallout)
                            .foregroundStyle(Color.paperInk)
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
            Text(viewModel.bodySectionTitle.uppercased())
                .font(.paperBadge)
                .foregroundStyle(Color.paperRule)

            if viewModel.enrichmentState == .enriching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.enrichingLabel)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperRule)
                }
                .accessibilityIdentifier("article.detail.body.enriching")
            }

            if viewModel.enrichmentState == .failed {
                Text(viewModel.enrichmentFailedLabel)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperError)
                    .accessibilityIdentifier("article.detail.body.enrichment_failed")
            }

            let blocks = viewModel.displayBlocks
            if blocks.isEmpty == false {
                ArticleBlockListView(blocks: blocks)
            } else if let body = viewModel.displayBody {
                Text(body)
                    .font(.paperBody)
                    .foregroundStyle(Color.paperInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("article.detail.body")
            } else if viewModel.shouldShowBodyPlaceholder {
                Text(viewModel.bodyPlaceholderLabel)
                    .font(.paperCallout)
                    .foregroundStyle(Color.paperRule)
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
