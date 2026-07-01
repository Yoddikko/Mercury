//
//  FeedSourcesViewModel.swift
//  Mercury
//
//  Created by Codex on 01/07/26.
//

import Combine
import Foundation
import SwiftData

/// View model backing the region + per-source feed picker (issue #75).
///
/// Consumed by both the first-launch onboarding flow and the Settings
/// screen so users can revisit the same choices without duplicated code.
///
/// * Regions come from `RSSFeedCatalog.availableRegions`.
/// * Outlets for a region come from `RSSFeedCatalog.sources(for:.byRegion, region:)`.
/// * Persistence goes through the shared `UserPreferencesService`.
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
    @Published private(set) var lastErrorMessage: String?

    private var service: UserPreferencesService
    private let logger: AppLogger
    private var preference: UserPreference?

    init(service: UserPreferencesService, logger: AppLogger = .shared) {
        self.service = service
        self.logger = logger
    }

    func replaceService(_ service: UserPreferencesService) {
        self.service = service
    }

    /// Hydrate the picker from the persisted preferences. Safe to call
    /// multiple times (idempotent).
    func load() {
        do {
            let preference = try service.loadPreferences()
            self.preference = preference
            let enabledRegionSet = Set(preference.enabledRegionRawValues)
            let treatAllAsEnabled = enabledRegionSet.isEmpty
            regions = RSSFeedCatalog.availableRegions.map { region in
                RegionSelection(
                    region: region,
                    isEnabled: treatAllAsEnabled || enabledRegionSet.contains(region.rawValue),
                    outletCount: RSSFeedCatalog.sources(for: .byRegion, region: region).count
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

    /// Outlet selections for the specified region — always sourced fresh
    /// so a toggle change in one region does not stale-cache the other.
    func outlets(for region: RSSFeedRegion) -> [SourceSelection] {
        let hidden = Set(preference?.hiddenSources ?? [])
        return RSSFeedCatalog.sources(for: .byRegion, region: region).map { source in
            SourceSelection(source: source, isEnabled: hidden.contains(source.id) == false)
        }
    }

    /// Flip a region on/off. When flipping OFF and the current stored
    /// state was "all regions" (empty list), we expand it into an
    /// explicit list first so the toggle is stable across writes.
    func toggleRegion(_ region: RSSFeedRegion) {
        guard let preference else { return }
        let currentEnabled = Set(effectiveEnabledRegions(from: preference))
        var next = currentEnabled
        if currentEnabled.contains(region.rawValue) {
            next.remove(region.rawValue)
        } else {
            next.insert(region.rawValue)
        }
        applyPatch(.init(enabledRegionRawValues: Array(next)))
    }

    /// Flip a source on/off. When flipping OFF, add to `hiddenSources`;
    /// when flipping ON, remove from `hiddenSources`.
    func toggleSource(_ source: RSSFeedSource) {
        guard let preference else { return }
        var hidden = Set(preference.hiddenSources)
        if hidden.contains(source.id) {
            hidden.remove(source.id)
        } else {
            hidden.insert(source.id)
        }
        applyPatch(.init(hiddenSources: Array(hidden)))
    }

    /// Whether the user has expressed at least one region choice — used
    /// by the onboarding "Continue" button gate.
    var hasAtLeastOneRegionEnabled: Bool {
        regions.contains(where: \.isEnabled)
    }

    // MARK: - Private

    private func effectiveEnabledRegions(from preference: UserPreference) -> [String] {
        if preference.enabledRegionRawValues.isEmpty {
            return RSSFeedCatalog.availableRegions.map(\.rawValue)
        }
        return preference.enabledRegionRawValues
    }

    private func applyPatch(_ patch: UserPreferencePatch) {
        do {
            let updated = try service.updatePreferences(patch)
            preference = updated
            let enabledRegionSet = Set(updated.enabledRegionRawValues)
            let treatAllAsEnabled = enabledRegionSet.isEmpty
            regions = RSSFeedCatalog.availableRegions.map { region in
                RegionSelection(
                    region: region,
                    isEnabled: treatAllAsEnabled || enabledRegionSet.contains(region.rawValue),
                    outletCount: RSSFeedCatalog.sources(for: .byRegion, region: region).count
                )
            }
            lastErrorMessage = nil
        } catch {
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
