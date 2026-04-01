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
    private let logger = AppLogger.shared
    private var activeTask: Task<Void, Never>?
    private var activeRunID: UUID?

    init(feedRefreshService: FeedRefreshService? = nil) {
        self.feedRefreshService = feedRefreshService ?? FeedRefreshService()
        logger.debug(
            "Initialized RSS diagnostics view model",
            category: .ui,
            service: "DeveloperRSSDiagnosticsViewModel"
        )
    }

    deinit {
        logger.debug(
            "Deinitializing RSS diagnostics view model",
            category: .ui,
            service: "DeveloperRSSDiagnosticsViewModel"
        )
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

    var hasResultForCurrentSelection: Bool {
        guard let latestResult else { return false }
        guard latestResult.groupMode == selectedGroupMode else { return false }
        if latestResult.groupMode == .byRegion {
            return latestResult.selectedRegion == selectedRegion
        }
        return true
    }

    func runDiagnostics() {
        activeTask?.cancel()
        isRunning = true
        let startedAt = DispatchTime.now().uptimeNanoseconds

        let selectedGroupMode = selectedGroupMode
        let selectedRegion = selectedGroupMode == .byRegion ? selectedRegion : nil
        let runID = UUID()
        activeRunID = runID
        let requestID = "dev-rss-\(runID.uuidString.lowercased())"

        logger.info(
            "Developer requested RSS diagnostics run",
            category: .ui,
            service: "DeveloperRSSDiagnosticsViewModel",
            requestID: requestID,
            metadata: [
                "group_mode": selectedGroupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none",
                "selected_sources": "\(selectedSourcesCount)"
            ]
        )

        activeTask = Task { [weak self, feedRefreshService] in
            let result = await feedRefreshService.runDiagnostics(
                groupMode: selectedGroupMode,
                selectedRegion: selectedRegion
            )

            let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000)
            await MainActor.run {
                guard let self else { return }
                guard self.activeRunID == runID else { return }
                defer {
                    self.activeTask = nil
                    self.activeRunID = nil
                }

                if Task.isCancelled {
                    self.isRunning = false
                    self.logger.warn(
                        "RSS diagnostics run was cancelled",
                        category: .ui,
                        service: "DeveloperRSSDiagnosticsViewModel",
                        requestID: requestID
                    )
                    return
                }

                self.latestResult = result
                self.lastRunDurationMs = elapsedMs
                self.isRunning = false
                self.logger.info(
                    "RSS diagnostics run completed",
                    category: .ui,
                    service: "DeveloperRSSDiagnosticsViewModel",
                    requestID: requestID,
                    metadata: [
                        "checks_total": "\(result.checks.count)",
                        "articles_out": "\(result.deduplicatedArticles.count)",
                        "elapsed_ms": "\(elapsedMs)"
                    ]
                )
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
