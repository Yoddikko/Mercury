//
//  FeedSourcesViewModel.swift
//  Mercury
//
//  Created by Codex on 01/07/26.
//

import Combine
import Foundation
import SwiftData

/// View model backing the region + per-source feed picker (issues #75, #78).
///
/// Consumed by both the first-launch onboarding flow and the Settings
/// screen so users can revisit the same choices without duplicated code.
///
/// * Regions come from `RSSFeedCatalog.availableRegions`.
/// * Outlets for a region come from `RSSFeedCatalog.sources(for:.byRegion, region:)`.
/// * Persistence goes through the shared `UserPreferencesService`.
///
/// UX semantics (issue #78): the picker is **opt-in**. A fresh install
/// shows every region toggled OFF; the persisted `enabledRegionRawValues`
/// is the exact set of regions the user opted in to. The Continue button
/// stays disabled until at least one region is enabled. `RSSSourceFilter`
/// still keeps the "empty = fallback to mainOutlets" contract so
/// pre-onboarding installs remain browsable — but the picker itself never
/// surfaces that fallback as "all selected".
///
/// Perf (issue #78): the region -> [source] projection is built once
/// eagerly (`outletsByRegion`) and reused for both `outletCount` reads
/// and per-region outlet listings. Toggles mutate the single affected
/// row instead of remapping the entire regions array.
@MainActor
final class FeedSourcesViewModel: ObservableObject {
    /// Region choice mirrored to the UI. `isEnabled` reflects the current
    /// state; toggling it updates the underlying preferences.
    struct RegionSelection: Identifiable, Equatable {
        let region: RSSFeedRegion
        var isEnabled: Bool
        var outletCount: Int

        var id: String { region.rawValue }
    }

    /// Outlet-level selection surfaced when a region is expanded.
    struct SourceSelection: Identifiable, Equatable {
        let source: RSSFeedSource
        var isEnabled: Bool

        var id: String { source.id }
    }

    @Published private(set) var regions: [RegionSelection] = []
    /// Published mirror of `UserPreference.hiddenSources` so SwiftUI
    /// re-renders the disclosure rows when the user toggles an outlet.
    /// Without this, the `Toggle`'s `Binding.get` closure keeps returning
    /// the stale `preference` snapshot until the whole parent view
    /// rebuilds for another reason.
    @Published private(set) var hiddenSources: Set<String> = []
    @Published private(set) var lastErrorMessage: String?

    private var service: UserPreferencesService
    /// Optional cache cleanup seam (issue #94). When present, every
    /// persisted region/outlet toggle triggers a purge of cached articles
    /// from now-disabled sources (favorites are always preserved). `nil`
    /// keeps previews and lightweight tests free of the article schema.
    private var cacheMaintenance: ArticleCacheMaintenanceService?
    private let logger: AppLogger
    private var preference: UserPreference?
    /// Precomputed region -> outlets memo (issue #78). Built once from
    /// `RSSFeedCatalog` at first `load()` so toggles avoid the O(N x R)
    /// re-scan that used to fire on every keystroke.
    private var outletsByRegion: [RSSFeedRegion: [RSSFeedSource]] = [:]
    /// Cached available regions (in the order `RSSFeedCatalog` publishes).
    private var availableRegions: [RSSFeedRegion] = []

    init(
        service: UserPreferencesService,
        cacheMaintenance: ArticleCacheMaintenanceService? = nil,
        logger: AppLogger = .shared
    ) {
        self.service = service
        self.cacheMaintenance = cacheMaintenance
        self.logger = logger
    }

    func replaceService(
        _ service: UserPreferencesService,
        cacheMaintenance: ArticleCacheMaintenanceService? = nil
    ) {
        self.service = service
        self.cacheMaintenance = cacheMaintenance
    }

    /// Hydrate the picker from the persisted preferences. Safe to call
    /// multiple times (idempotent).
    func load() {
        if availableRegions.isEmpty {
            let regions = RSSFeedCatalog.availableRegions
            self.availableRegions = regions
            var memo: [RSSFeedRegion: [RSSFeedSource]] = [:]
            memo.reserveCapacity(regions.count)
            for region in regions {
                memo[region] = RSSFeedCatalog.sources(for: .byRegion, region: region)
            }
            self.outletsByRegion = memo
        }
        do {
            let preference = try service.loadPreferences()
            self.preference = preference
            self.hiddenSources = Set(preference.hiddenSources)
            let enabledRegionSet = Set(preference.enabledRegionRawValues)
            regions = availableRegions.map { region in
                RegionSelection(
                    region: region,
                    isEnabled: enabledRegionSet.contains(region.rawValue),
                    outletCount: outletsByRegion[region]?.count ?? 0
                )
            }
            lastErrorMessage = nil
        } catch {
            logger.error(
                "Failed to load feed source preferences",
                category: .ui,
                service: "FeedSourcesViewModel",
                metadata: ["error": String(describing: error)]
            )
            lastErrorMessage = String(
                localized: "feed_sources.error.load",
                defaultValue: "We couldn't read your feed source preferences."
            )
        }
    }

    /// Outlet selections for the specified region, backed by the memo
    /// and the published `hiddenSources` mirror.
    func outlets(for region: RSSFeedRegion) -> [SourceSelection] {
        let sources = outletsByRegion[region] ?? []
        return sources.map { source in
            SourceSelection(
                source: source,
                isEnabled: hiddenSources.contains(source.id) == false
            )
        }
    }

    /// Flip a region on/off. The picker is opt-in, so writes always
    /// materialize the explicit list — no more "empty = all" magic behind
    /// the toggle.
    func toggleRegion(_ region: RSSFeedRegion) {
        guard let preference else { return }
        var next = Set(preference.enabledRegionRawValues)
        let isTurningOn: Bool
        if next.contains(region.rawValue) {
            next.remove(region.rawValue)
            isTurningOn = false
        } else {
            next.insert(region.rawValue)
            isTurningOn = true
        }
        applyPatch(
            .init(enabledRegionRawValues: Array(next)),
            optimistic: .region(region.rawValue, isEnabled: isTurningOn)
        )
    }

    /// Flip a source on/off. When flipping OFF, add to `hiddenSources`;
    /// when flipping ON, remove from `hiddenSources`. We also mirror the
    /// change into the published `hiddenSources` set so the row's Toggle
    /// re-renders immediately.
    func toggleSource(_ source: RSSFeedSource) {
        guard preference != nil else { return }
        var next = hiddenSources
        let wasHidden = next.contains(source.id)
        if wasHidden {
            next.remove(source.id)
        } else {
            next.insert(source.id)
        }
        let previous = hiddenSources
        hiddenSources = next
        applyPatch(
            .init(hiddenSources: Array(next)),
            optimistic: .source(previousHidden: previous)
        )
    }

    /// Whether the user has expressed at least one region choice — used
    /// by the onboarding "Continue" button gate.
    var hasAtLeastOneRegionEnabled: Bool {
        regions.contains(where: \.isEnabled)
    }

    // MARK: - Private

    private enum OptimisticUpdate {
        case region(String, isEnabled: Bool)
        case source(previousHidden: Set<String>)
    }

    private func applyPatch(_ patch: UserPreferencePatch, optimistic: OptimisticUpdate?) {
        // Flip the visible row immediately for a snappy tap; roll back on
        // persistence failure. Prior implementation rebuilt the entire
        // regions array on every toggle, which was the primary source of
        // the perceived "fetching" lag.
        var previousRegion: RegionSelection?
        if case let .region(rawValue, isEnabled) = optimistic,
           let idx = regions.firstIndex(where: { $0.region.rawValue == rawValue }) {
            previousRegion = regions[idx]
            regions[idx].isEnabled = isEnabled
        }

        do {
            let updated = try service.updatePreferences(patch)
            preference = updated
            lastErrorMessage = nil
        } catch {
            switch optimistic {
            case let .region(rawValue, _):
                if let idx = regions.firstIndex(where: { $0.region.rawValue == rawValue }),
                   let previous = previousRegion {
                    regions[idx] = previous
                }
            case let .source(previousHidden):
                hiddenSources = previousHidden
            case .none:
                break
            }
            logger.error(
                "Failed to persist feed source preferences",
                category: .ui,
                service: "FeedSourcesViewModel",
                metadata: ["error": String(describing: error)]
            )
            lastErrorMessage = String(
                localized: "feed_sources.error.save",
                defaultValue: "We couldn't save that change. Try again."
            )
        }
    }
}
