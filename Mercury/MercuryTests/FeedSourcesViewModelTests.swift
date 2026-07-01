//
//  FeedSourcesViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 01/07/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Regression coverage for issue #78 — the picker is opt-in, so a fresh
/// install must NOT surface every region as pre-selected, and the
/// persisted `enabledRegionRawValues` must be exactly the user's picks.
@MainActor
@Suite("FeedSourcesViewModel")
struct FeedSourcesViewModelTests {
    @Test
    func freshInstallStartsWithEveryRegionDisabled() throws {
        let (viewModel, _) = try makeViewModel()

        viewModel.load()

        #expect(viewModel.regions.isEmpty == false)
        #expect(viewModel.regions.allSatisfy { $0.isEnabled == false })
        #expect(viewModel.hasAtLeastOneRegionEnabled == false)
    }

    @Test
    func toggleRegionPersistsExplicitOptInAndFlipsRowOptimistically() throws {
        let (viewModel, service) = try makeViewModel()
        viewModel.load()

        viewModel.toggleRegion(.italy)

        let italian = viewModel.regions.first(where: { $0.region == .italy })
        #expect(italian?.isEnabled == true)
        // Only italy is written — no lingering "all regions" magic.
        let stored = try service.loadPreferences()
        #expect(stored.enabledRegionRawValues == [RSSFeedRegion.italy.rawValue])
        #expect(viewModel.hasAtLeastOneRegionEnabled == true)
    }

    @Test
    func toggleRegionOffRemovesItFromExplicitList() throws {
        let (viewModel, service) = try makeViewModel()
        viewModel.load()
        viewModel.toggleRegion(.italy)
        viewModel.toggleRegion(.france)

        viewModel.toggleRegion(.italy)

        let stored = try service.loadPreferences()
        #expect(stored.enabledRegionRawValues == [RSSFeedRegion.france.rawValue])
        let italian = viewModel.regions.first(where: { $0.region == .italy })
        #expect(italian?.isEnabled == false)
    }

    @Test
    func toggleSourceMirrorsHiddenSourcesForImmediateRedraw() throws {
        let (viewModel, service) = try makeViewModel()
        viewModel.load()

        guard let sample = viewModel.outlets(for: .italy).first?.source else {
            Issue.record("Expected at least one Italy outlet in the catalog fixture")
            return
        }

        viewModel.toggleSource(sample)

        #expect(viewModel.hiddenSources.contains(sample.id))
        let outlet = viewModel.outlets(for: .italy).first(where: { $0.source.id == sample.id })
        #expect(outlet?.isEnabled == false)
        let stored = try service.loadPreferences()
        #expect(stored.hiddenSources.contains(sample.id))
    }

    // MARK: - Helpers

    private func makeViewModel() throws -> (FeedSourcesViewModel, UserPreferencesService) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserPreferenceEntity.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let service = UserPreferencesService(modelContext: context)
        return (FeedSourcesViewModel(service: service), service)
    }
}
