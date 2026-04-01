//
//  DeveloperPlaygroundScreen.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

#if DEBUG

import SwiftData
import SwiftUI

struct DeveloperPlaygroundScreen: View {
    let viewModel: DeveloperPlaygroundViewModel

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredArticle.createdAt, order: .reverse) private var storedArticles: [StoredArticle]
    @StateObject private var rssDiagnosticsViewModel = DeveloperRSSDiagnosticsViewModel()

    @State private var selectedProviderID = DeveloperPlaygroundViewModel.defaultProviderID
    @State private var promptInput = ""
    @State private var simulationOutput = ""

    var body: some View {
        Form {
            Section {
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("developer.playground.subtitle")
            }

            Section(viewModel.aiSimulationSectionTitle) {
                Picker(viewModel.providerLabel, selection: $selectedProviderID) {
                    ForEach(viewModel.providerOptions) { option in
                        Text(option.displayName).tag(option.id)
                    }
                }
                .accessibilityIdentifier("developer.playground.provider")

                TextField(viewModel.promptInputLabel, text: $promptInput, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("developer.playground.prompt")

                Button(viewModel.runSimulationLabel) {
                    simulationOutput = viewModel.simulatedSummary(
                        prompt: promptInput,
                        providerID: selectedProviderID
                    )
                }
                .accessibilityIdentifier("developer.playground.run")

                if simulationOutput.isEmpty == false {
                    Text(simulationOutput)
                        .font(.callout)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("developer.playground.output")
                }
            }

            Section(viewModel.swiftDataSandboxSectionTitle) {
                Text(viewModel.storedDebugRecordsLabel(count: storedArticles.count))
                    .accessibilityIdentifier("developer.playground.count")

                HStack {
                    Button(viewModel.insertSampleRecordLabel) {
                        modelContext.insert(
                            viewModel.makeSampleStoredArticle(existingCount: storedArticles.count)
                        )
                    }
                    .accessibilityIdentifier("developer.playground.insert")

                    Button(viewModel.clearRecordsLabel, role: .destructive) {
                        clearStoredArticles()
                    }
                    .accessibilityIdentifier("developer.playground.clear")
                }

                if storedArticles.isEmpty == false {
                    ForEach(storedArticles.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.sourceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(viewModel.rssDiagnosticsSectionTitle) {
                Picker(viewModel.rssGroupLabel, selection: $rssDiagnosticsViewModel.selectedGroupMode) {
                    ForEach(RSSFeedGroupMode.allCases) { mode in
                        Text(rssDiagnosticsViewModel.title(for: mode)).tag(mode)
                    }
                }
                .accessibilityIdentifier("developer.playground.rss.group")

                if rssDiagnosticsViewModel.selectedGroupMode == .byRegion {
                    Picker(viewModel.rssRegionLabel, selection: $rssDiagnosticsViewModel.selectedRegion) {
                        ForEach(rssDiagnosticsViewModel.availableRegions) { region in
                            Text(rssDiagnosticsViewModel.title(for: region)).tag(region)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.region")
                }

                Text(viewModel.rssSelectedOutletsLabel(count: rssDiagnosticsViewModel.selectedSourcesCount))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("developer.playground.rss.selected")

                Button(viewModel.runRSSDiagnosticsLabel) {
                    rssDiagnosticsViewModel.runDiagnostics()
                }
                .disabled(
                    rssDiagnosticsViewModel.isRunning ||
                    rssDiagnosticsViewModel.selectedSourcesCount == 0
                )
                .accessibilityIdentifier("developer.playground.rss.run")

                if rssDiagnosticsViewModel.isRunning {
                    ProgressView(viewModel.runningRSSDiagnosticsLabel)
                        .accessibilityIdentifier("developer.playground.rss.running")
                }
            }

            if rssDiagnosticsViewModel.hasResultForCurrentSelection {
                Section(viewModel.rssSummarySectionTitle) {
                    Text(viewModel.rssOutletsCheckedLabel(count: rssDiagnosticsViewModel.checks.count))
                    Text(viewModel.rssSuccessfulFeedsLabel(count: rssDiagnosticsViewModel.successChecks.count))
                    Text(viewModel.rssNoArticlesFeedsLabel(count: rssDiagnosticsViewModel.noArticleChecks.count))
                    Text(viewModel.rssMissingFeedsLabel(count: rssDiagnosticsViewModel.noFeedChecks.count))
                    Text(viewModel.rssFailedFeedsLabel(count: rssDiagnosticsViewModel.failedChecks.count))
                    Text(viewModel.rssDeduplicatedArticlesLabel(count: rssDiagnosticsViewModel.normalizedArticles.count))
                    Text(viewModel.rssDurationLabel(milliseconds: rssDiagnosticsViewModel.lastRunDurationMs))
                }
                .accessibilityIdentifier("developer.playground.rss.summary")

                if rssDiagnosticsViewModel.noFeedChecks.isEmpty == false {
                    Section(viewModel.rssMissingFeedsSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.noFeedChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.noFeed")
                }

                if rssDiagnosticsViewModel.failedChecks.isEmpty == false {
                    Section(viewModel.rssFailedFeedsSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.failedChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.failed")
                }

                if rssDiagnosticsViewModel.noArticleChecks.isEmpty == false {
                    Section(viewModel.rssNoArticlesSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.noArticleChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.noArticles")
                }

                if rssDiagnosticsViewModel.successChecks.isEmpty == false {
                    Section(viewModel.rssSuccessSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.successChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.success")
                }

                if rssDiagnosticsViewModel.normalizedArticles.isEmpty == false {
                    Section(viewModel.rssArticlesSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.normalizedArticles.prefix(80))) { article in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.headline)
                                Text("\(article.sourceName) • \(Self.articleDateFormatter.string(from: article.publishedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(article.articleURL.absoluteString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.articles")
                }
            }
        }
        .navigationTitle(viewModel.title)
        .accessibilityIdentifier("developer.playground.screen")
    }

    private func feedCheckRow(for result: RSSFeedCheckResult) -> some View {
        let statusTitle = rssDiagnosticsViewModel.title(for: result.status)

        return VStack(alignment: .leading, spacing: 4) {
            Text(result.source.outletName)
                .font(.headline)
            Text(rssDiagnosticsViewModel.title(for: result.source.region))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.rssCheckCaption(result: result, statusTitle: statusTitle))
                .font(.caption)
                .foregroundStyle(result.status == .success ? .secondary : .primary)
            if let message = result.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let feedURLString = result.source.feedURLString {
                Text(feedURLString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func clearStoredArticles() {
        for article in storedArticles {
            modelContext.delete(article)
        }
    }

    private static let articleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        DeveloperPlaygroundScreen(viewModel: DeveloperPlaygroundViewModel())
    }
}

#endif
