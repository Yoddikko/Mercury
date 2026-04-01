//
//  DeveloperRSSDiagnosticsViewModel.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Combine
import Foundation

@MainActor
final class DeveloperRSSDiagnosticsViewModel: ObservableObject {
    @Published var selectedGroupMode: RSSFeedGroupMode = .allOutlets
    @Published var selectedRegion: RSSFeedRegion = .europeWide
    @Published private(set) var isRunning = false
    @Published private(set) var latestResult: RSSFeedBatchResult?
    @Published private(set) var lastRunDurationMs: Int?

    private let feedRefreshService: FeedRefreshService
    private var activeTask: Task<Void, Never>?

    init(feedRefreshService: FeedRefreshService? = nil) {
        self.feedRefreshService = feedRefreshService ?? FeedRefreshService()
    }

    deinit {
        activeTask?.cancel()
    }

    var availableRegions: [RSSFeedRegion] {
        RSSFeedCatalog.availableRegions
    }

    var selectedSources: [RSSFeedSource] {
        RSSFeedCatalog.sources(
            for: selectedGroupMode,
            region: selectedGroupMode == .byRegion ? selectedRegion : nil
        )
    }

    var selectedSourcesCount: Int {
        selectedSources.count
    }

    var checks: [RSSFeedCheckResult] {
        latestResult?.checks ?? []
    }

    var successChecks: [RSSFeedCheckResult] {
        checks.filter { $0.status == .success }
    }

    var noArticleChecks: [RSSFeedCheckResult] {
        checks.filter { $0.status == .noArticles }
    }

    var noFeedChecks: [RSSFeedCheckResult] {
        checks.filter { $0.status == .noFeedURL || $0.status == .invalidFeedURL }
    }

    var failedChecks: [RSSFeedCheckResult] {
        checks.filter { $0.status == .requestFailed || $0.status == .parseFailed }
    }

    var normalizedArticles: [Article] {
        latestResult?.deduplicatedArticles ?? []
    }

    func runDiagnostics() {
        activeTask?.cancel()
        isRunning = true
        let startedAt = DispatchTime.now().uptimeNanoseconds

        let selectedGroupMode = selectedGroupMode
        let selectedRegion = selectedGroupMode == .byRegion ? selectedRegion : nil

        activeTask = Task { [feedRefreshService] in
            let result = await feedRefreshService.runDiagnostics(
                groupMode: selectedGroupMode,
                selectedRegion: selectedRegion
            )

            let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000)
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                self.latestResult = result
                self.lastRunDurationMs = elapsedMs
                self.isRunning = false
            }
        }
    }

    func title(for groupMode: RSSFeedGroupMode) -> String {
        switch groupMode {
        case .allOutlets:
            return String(localized: "developer.rss.group.all", defaultValue: "All Outlets")
        case .mainOutlets:
            return String(localized: "developer.rss.group.main", defaultValue: "Main Outlets")
        case .byRegion:
            return String(localized: "developer.rss.group.region", defaultValue: "By Region")
        }
    }

    func title(for region: RSSFeedRegion) -> String {
        region.fallbackDisplayName
    }

    func title(for status: RSSFeedCheckStatus) -> String {
        switch status {
        case .success:
            return String(localized: "developer.rss.status.success", defaultValue: "Success")
        case .noArticles:
            return String(localized: "developer.rss.status.no_articles", defaultValue: "No Articles")
        case .noFeedURL:
            return String(localized: "developer.rss.status.no_feed", defaultValue: "No Feed URL")
        case .invalidFeedURL:
            return String(localized: "developer.rss.status.invalid_url", defaultValue: "Invalid Feed URL")
        case .requestFailed:
            return String(localized: "developer.rss.status.request_failed", defaultValue: "Request Failed")
        case .parseFailed:
            return String(localized: "developer.rss.status.parse_failed", defaultValue: "Parse Failed")
        }
    }
}
