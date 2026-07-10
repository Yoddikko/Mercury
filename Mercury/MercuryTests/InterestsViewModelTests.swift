//
//  InterestsViewModelTests.swift
//  MercuryTests
//
//  Created by Claude on 10/07/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

@MainActor
@Suite("InterestsViewModel")
struct InterestsViewModelTests {
    @Test
    func togglePersistsToPreferredTopics() throws {
        let (viewModel, service) = try Self.make()
        viewModel.load()

        viewModel.toggle("Politica")
        viewModel.toggle("Ambiente")

        #expect(try service.loadPreferences().preferredTopics == ["Politica", "Ambiente"])

        viewModel.toggle("Politica")
        #expect(try service.loadPreferences().preferredTopics == ["Ambiente"])
    }

    @Test
    func customInterestsAreTrimmedDedupedAndSeparatedFromSuggestions() throws {
        let (viewModel, service) = try Self.make()
        viewModel.load()
        viewModel.toggle("Sport")

        viewModel.customInput = "  vela oceanica "
        viewModel.addCustomInterest()
        viewModel.customInput = "VELA OCEANICA"
        viewModel.addCustomInterest()

        #expect(viewModel.customInterests == ["vela oceanica"])
        #expect(try service.loadPreferences().preferredTopics == ["Sport", "vela oceanica"])
        #expect(viewModel.customInput.isEmpty)
    }

    @Test
    func loadHydratesFromPersistedPreferences() throws {
        let (first, service) = try Self.make()
        first.load()
        first.toggle("Scienza")

        let second = InterestsViewModel(service: service)
        second.load()
        #expect(second.isSelected("Scienza"))
    }

    @Test
    func persistingAnInterestChangeInvalidatesForYouCache() throws {
        // Issue #136: the persisted Per te picks were ranked against the
        // OLD interests — any edit must drop them.
        let defaults = UserDefaults(suiteName: "test-interests-\(UUID().uuidString)")!
        let cache = ForYouPicksCache(defaults: defaults)
        cache.save(ForYouPicksCacheEntry(
            savedAt: .now,
            picks: [AIHeadlinePick(id: "a", interest: "Sport", relevance: 70)]
        ))
        #expect(cache.loadFresh() != nil)

        let (viewModel, _) = try Self.make(cacheDefaults: defaults)
        viewModel.load()
        viewModel.toggle("Politica")

        #expect(cache.loadFresh() == nil)
    }

    // MARK: - Helpers

    private static func make(
        cacheDefaults: UserDefaults = UserDefaults(suiteName: "test-interests-\(UUID().uuidString)")!
    ) throws -> (InterestsViewModel, UserPreferencesService) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserPreferenceEntity.self, configurations: configuration)
        let service = UserPreferencesService(modelContext: ModelContext(container))
        return (InterestsViewModel(service: service, cacheDefaults: cacheDefaults), service)
    }
}
