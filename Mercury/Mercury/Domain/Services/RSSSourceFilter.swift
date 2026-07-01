//
//  RSSSourceFilter.swift
//  Mercury
//
//  Created by Codex on 01/07/26.
//

import Foundation

/// Resolves the effective RSS source list from the user's preferences.
///
/// Two knobs govern the resolution:
///
/// * `UserPreference.enabledRegionRawValues` — regions the user opted in to
///   during onboarding or via Settings. Empty means "all regions" so the
///   pre-onboarding default (main outlets across the entire catalog) stays
///   intact.
/// * `UserPreference.hiddenSources` — per-outlet opt-out that the user can
///   toggle from the same UI. Applied last so a hidden source is dropped
///   even if its region is enabled.
///
/// The filter is intentionally pure and stateless so tests can exercise it
/// without any SwiftData or catalog spin-up. See `docs/features/SETTINGS.md`
/// § Feed sources.
nonisolated struct RSSSourceFilter: Sendable {
    private let allSources: [RSSFeedSource]

    init(allSources: [RSSFeedSource] = RSSFeedCatalog.allSources) {
        self.allSources = allSources
    }

    /// Returns the subset of the catalog that should feed the Home refresh
    /// given the supplied preferences.
    ///
    /// When `preferences` is `nil` (no record yet) the filter falls back to
    /// the pre-onboarding behavior (main outlets only), so a user who never
    /// visits Settings still gets a curated stream.
    func resolveSources(for preferences: UserPreference?) -> [RSSFeedSource] {
        guard let preferences else {
            return allSources.filter(\.isMainOutlet)
        }

        let hidden = Set(preferences.hiddenSources)
        let enabledRegionSet: Set<String>? = preferences.enabledRegionRawValues.isEmpty
            ? nil
            : Set(preferences.enabledRegionRawValues)

        return allSources.filter { source in
            if hidden.contains(source.id) { return false }
            guard let enabledRegionSet else { return true }
            return enabledRegionSet.contains(source.region.rawValue)
        }
    }
}
