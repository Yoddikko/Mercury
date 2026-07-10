//
//  TopicClusterScreen.swift
//  Mercury
//
//  Created by Claude on 09/07/26.
//

import SwiftUI

/// Detail list for one aggregated story (issue #117): every article of
/// the cluster — lead first — so the user picks which outlet's take to
/// read. Paper design system: serif titles, mono source/time, hairline
/// thumbnails only where the article has one.
struct TopicClusterScreen: View {
    let cluster: TopicCluster
    let viewModel: HomeViewModel
    let destination: (Article) -> ArticleDetailScreen
    @StateObject private var summaryViewModel = ClusterSummaryViewModel()

    private var allArticles: [Article] {
        [cluster.lead] + cluster.members
    }

    var body: some View {
        List {
            storySummarySection
            Section {
                ForEach(allArticles) { article in
                    NavigationLink {
                        destination(article)
                    } label: {
                        row(for: article)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("topics.cluster.article.\(article.id)")
                }
            } header: {
                HStack {
                    Text(Self.articlesCountLabel(allArticles.count).uppercased())
                        .font(.paperBadge)
                        .foregroundStyle(Color.paperRule)
                    Spacer()
                    Text(viewModel.topicsCoverageLabel(sourceCount: cluster.sourceCount))
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                }
            }
        }
        .listStyle(.plain)
        .paperScreen()
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("topics.cluster.screen")
    }

    /// The story-level AI summary (issue #129): one synthesis of every
    /// outlet's take, generated on demand in the user's chosen language.
    @ViewBuilder
    private var storySummarySection: some View {
        Section {
            switch summaryViewModel.state {
            case .idle:
                Button {
                    Task { await summaryViewModel.requestSummary(for: cluster) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(summaryViewModel.buttonLabel)
                    }
                }
                .buttonStyle(.paperPrimary)
                .accessibilityIdentifier("topics.story_summary.generate")

            case .summarizing:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.paperInk)
                    Text(summaryViewModel.loadingLabel)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperRule)
                }
                .accessibilityIdentifier("topics.story_summary.loading")

            case let .ready(summary):
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.shortSummary)
                        .font(.paperBody)
                        .foregroundStyle(Color.paperInk)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(summary.bullets.enumerated()), id: \.offset) { _, bullet in
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
                    Button {
                        Task { await summaryViewModel.requestSummary(for: cluster, force: true) }
                    } label: {
                        Label(summaryViewModel.regenerateLabel, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.paperSecondary)
                    .accessibilityIdentifier("topics.story_summary.regenerate")
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .overlay(Rectangle().stroke(Color.paperRule.opacity(0.35), lineWidth: 0.8))
                .accessibilityIdentifier("topics.story_summary.ready")

            case let .failed(reason):
                VStack(alignment: .leading, spacing: 6) {
                    Text(summaryViewModel.failedLabel)
                        .font(.paperCallout)
                        .foregroundStyle(Color.paperError)
                    Text(reason)
                        .font(.paperMeta)
                        .foregroundStyle(Color.paperRule)
                    Button {
                        Task { await summaryViewModel.requestSummary(for: cluster, force: true) }
                    } label: {
                        Text(summaryViewModel.regenerateLabel)
                    }
                    .buttonStyle(.paperSecondary)
                }
                .accessibilityIdentifier("topics.story_summary.failed")
            }
        }
        .listRowSeparator(.hidden)
    }

    private func row(for article: Article) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.sourceName.uppercased())
                        .font(.paperBadge)
                        .foregroundStyle(Color.paperRule)
                    Text(article.title)
                        .font(.paperHeadline)
                        .foregroundStyle(Color.paperInk)
                    Text(viewModel.articleMetadataLine(
                        sourceName: article.sourceName,
                        publishedAt: article.publishedAt
                    ))
                    .font(.paperMeta)
                    .foregroundStyle(Color.paperRule)
                }
                Spacer(minLength: 0)
                thumbnail(for: article)
            }
            PaperRule()
                .padding(.top, 6)
        }
        .padding(.vertical, 4)
    }

    /// Background-defines-layout (#107): the image can never inflate
    /// the row width.
    @ViewBuilder
    private func thumbnail(for article: Article) -> some View {
        if let url = article.heroImageURL {
            Rectangle()
                .fill(Color.paperRule.opacity(0.12))
                .frame(width: 56, height: 56)
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

    // MARK: - Localized copy

    private static var title: String {
        String(localized: "home.topics.cluster.title", defaultValue: "Story")
    }

    private static func articlesCountLabel(_ count: Int) -> String {
        let format = String(
            localized: "home.topics.cluster.articles_count",
            defaultValue: "%lld articles"
        )
        return String(format: format, locale: .current, count)
    }
}
