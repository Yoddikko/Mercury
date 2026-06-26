//
//  SwiftDataPreferenceRepositoryTests.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

/// Verifies the wrap-via-delegation contract of
/// `SwiftDataPreferenceRepository`. The repository forwards every call to
/// `UserPreferencesService`; these tests confirm the protocol surface
/// preserves the same single-document, bootstrap-on-first-load semantics
/// consumers rely on, including the empty-patch no-op path.
@MainActor
@Suite("SwiftDataPreferenceRepository")
struct SwiftDataPreferenceRepositoryTests {
    // MARK: - Happy paths

    @Test
    func loadPreferencesBootstrapsDefaultsOnFirstLaunch() async throws {
        let (repository, context) = try makeRepository()

        let preferences = try await repository.loadPreferences()

        #expect(preferences.id == UserPreferencesService.singletonRecordID)
        #expect(preferences.preferredCategories.isEmpty)
        #expect(preferences.preferredTopics.isEmpty)
        #expect(preferences.hiddenSources.isEmpty)
        #expect(preferences.favoriteSources.isEmpty)
        #expect(preferences.preferredLanguage == nil)

        let stored = try context.fetch(FetchDescriptor<UserPreferenceEntity>())
        #expect(stored.count == 1)
    }

    @Test
    func updatePreferencesAppliesPatchAndPersistsIt() async throws {
        let (repository, _) = try makeRepository()

        _ = try await repository.loadPreferences()

        let updated = try await repository.updatePreferences(
            UserPreferencePatch(
                preferredCategories: ["technology", "science"],
                preferredTopics: ["llm"],
                favoriteSources: ["trusted.example"],
                preferredLanguage: "en"
            )
        )

        #expect(updated.preferredCategories == ["technology", "science"])
        #expect(updated.preferredTopics == ["llm"])
        #expect(updated.favoriteSources == ["trusted.example"])
        #expect(updated.preferredLanguage == "en")

        let reloaded = try await repository.loadPreferences()
        #expect(reloaded == updated)
    }

    @Test
    func resetPreferencesRestoresDefaults() async throws {
        let (repository, _) = try makeRepository()

        _ = try await repository.updatePreferences(
            UserPreferencePatch(
                preferredCategories: ["technology"],
                preferredTopics: ["ai"],
                hiddenSources: ["noisy.example"],
                favoriteSources: ["trusted.example"],
                preferredLanguage: "it"
            )
        )

        let reset = try await repository.resetPreferences()

        #expect(reset.preferredCategories.isEmpty)
        #expect(reset.preferredTopics.isEmpty)
        #expect(reset.hiddenSources.isEmpty)
        #expect(reset.favoriteSources.isEmpty)
        #expect(reset.preferredLanguage == nil)
    }

    // MARK: - No-op patch

    @Test
    func emptyPatchIsNoOpAndDoesNotMutateState() async throws {
        let bootstrapDate = Date(timeIntervalSince1970: 1_700_000_000)
        let (repository, _) = try makeRepository(now: { bootstrapDate })

        let initial = try await repository.loadPreferences()
        let unchanged = try await repository.updatePreferences(UserPreferencePatch())

        #expect(unchanged == initial)
        #expect(unchanged.updatedAt == bootstrapDate)
    }

    // MARK: - Helpers

    private func makeRepository(
        now: @escaping @MainActor () -> Date = { Date() }
    ) throws -> (SwiftDataPreferenceRepository, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserPreferenceEntity.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let service = UserPreferencesService(modelContext: context, now: now)
        let repository = SwiftDataPreferenceRepository(service: service)
        return (repository, context)
    }
}
