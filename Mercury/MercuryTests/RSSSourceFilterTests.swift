//
//  RSSSourceFilterTests.swift
//  MercuryTests
//
//  Created by Codex on 01/07/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("RSSSourceFilter")
struct RSSSourceFilterTests {
    private func makeSource(
        id: String,
        region: RSSFeedRegion,
        isMain: Bool = true
    ) -> RSSFeedSource {
        RSSFeedSource(
            id: id,
            outletName: "Outlet \(id)",
            region: region,
            feedURLString: "https://example.com/\(id)",
            isMainOutlet: isMain,
            languageCode: "en",
            tags: [],
            note: nil
        )
    }

    private func makePreference(
        enabled: [String] = [],
        hidden: [String] = []
    ) -> UserPreference {
        UserPreference(
            id: "test",
            preferredCategories: [],
            preferredTopics: [],
            hiddenSources: hidden,
            favoriteSources: [],
            preferredLanguage: nil,
            enabledRegionRawValues: enabled,
            hasCompletedOnboarding: true,
            updatedAt: .now
        )
    }

    @Test
    func nilPreferencesFallsBackToMainOutlets() {
        let sources = [
            makeSource(id: "main-1", region: .italy, isMain: true),
            makeSource(id: "sub-1", region: .italy, isMain: false)
        ]
        let filter = RSSSourceFilter(allSources: sources)

        let resolved = filter.resolveSources(for: nil)

        #expect(resolved.map(\.id) == ["main-1"])
    }

    @Test
    func emptyEnabledRegionsMeansAllRegions() {
        let sources = [
            makeSource(id: "it-1", region: .italy),
            makeSource(id: "fr-1", region: .france)
        ]
        let filter = RSSSourceFilter(allSources: sources)

        let resolved = filter.resolveSources(for: makePreference())

        #expect(Set(resolved.map(\.id)) == ["it-1", "fr-1"])
    }

    @Test
    func nonEmptyEnabledRegionsFiltersOutOthers() {
        let sources = [
            makeSource(id: "it-1", region: .italy),
            makeSource(id: "fr-1", region: .france),
            makeSource(id: "de-1", region: .germany)
        ]
        let filter = RSSSourceFilter(allSources: sources)

        let resolved = filter.resolveSources(
            for: makePreference(enabled: [RSSFeedRegion.italy.rawValue])
        )

        #expect(resolved.map(\.id) == ["it-1"])
    }

    @Test
    func hiddenSourcesAreDroppedEvenInEnabledRegion() {
        let sources = [
            makeSource(id: "it-1", region: .italy),
            makeSource(id: "it-2", region: .italy)
        ]
        let filter = RSSSourceFilter(allSources: sources)

        let resolved = filter.resolveSources(
            for: makePreference(
                enabled: [RSSFeedRegion.italy.rawValue],
                hidden: ["it-2"]
            )
        )

        #expect(resolved.map(\.id) == ["it-1"])
    }
}
