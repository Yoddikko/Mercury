//
//  UserPreferencesServiceTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

@MainActor
struct UserPreferencesServiceTests {
    @Test
    func loadPreferencesBootstrapsDefaultsOnFirstLaunch() throws {
        let (service, context) = try makeService()

        let preferences = try service.loadPreferences()

        #expect(preferences.id == UserPreferencesService.singletonRecordID)
        #expect(preferences.preferredCategories.isEmpty)
        #expect(preferences.preferredTopics.isEmpty)
        #expect(preferences.hiddenSources.isEmpty)
        #expect(preferences.favoriteSources.isEmpty)
        #expect(preferences.preferredLanguage == nil)

        let stored = try context.fetch(FetchDescriptor<UserPreferenceEntity>())
        #expect(stored.count == 1)
        #expect(stored.first?.id == UserPreferencesService.singletonRecordID)
    }

    @Test
    func loadPreferencesReusesExistingRecord() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let (service, context) = try makeService(now: { fixedDate })

        _ = try service.loadPreferences()
        _ = try service.loadPreferences()

        let stored = try context.fetch(FetchDescriptor<UserPreferenceEntity>())
        #expect(stored.count == 1)
        #expect(stored.first?.updatedAt == fixedDate)
    }

    @Test
    func updatePreferencesAppliesPartialPatch() throws {
        let bootstrapDate = Date(timeIntervalSince1970: 1_700_000_000)
        let updateDate = bootstrapDate.addingTimeInterval(60)
        var clockTick = 0
        let dates = [bootstrapDate, updateDate]
        let (service, _) = try makeService(now: {
            defer { clockTick = min(clockTick + 1, dates.count - 1) }
            return dates[clockTick]
        })

        _ = try service.loadPreferences()

        let updated = try service.updatePreferences(
            UserPreferencePatch(
                preferredCategories: ["technology", "science"],
                preferredTopics: ["llm", "spaceflight"],
                hiddenSources: ["noisy.example"],
                favoriteSources: ["trusted.example"],
                preferredLanguage: "en"
            )
        )

        #expect(updated.preferredCategories == ["technology", "science"])
        #expect(updated.preferredTopics == ["llm", "spaceflight"])
        #expect(updated.hiddenSources == ["noisy.example"])
        #expect(updated.favoriteSources == ["trusted.example"])
        #expect(updated.preferredLanguage == "en")
        #expect(updated.updatedAt == updateDate)
    }

    @Test
    func updatePreferencesSanitizesAndDeduplicates() throws {
        let (service, _) = try makeService()

        let updated = try service.updatePreferences(
            UserPreferencePatch(
                preferredCategories: ["Technology", "  ", "Technology", "Science"],
                favoriteSources: [" trusted.example ", "trusted.example"],
                preferredLanguage: "  it  "
            )
        )

        #expect(updated.preferredCategories == ["Technology", "Science"])
        #expect(updated.favoriteSources == ["trusted.example"])
        #expect(updated.preferredLanguage == "it")
    }

    @Test
    func updatePreferencesLeavesUntouchedFieldsAlone() throws {
        let (service, _) = try makeService()

        _ = try service.updatePreferences(
            UserPreferencePatch(
                preferredCategories: ["technology"],
                preferredLanguage: "en"
            )
        )

        let afterPartialUpdate = try service.updatePreferences(
            UserPreferencePatch(preferredTopics: ["ai"])
        )

        #expect(afterPartialUpdate.preferredCategories == ["technology"])
        #expect(afterPartialUpdate.preferredTopics == ["ai"])
        #expect(afterPartialUpdate.preferredLanguage == "en")
    }

    @Test
    func updatePreferencesClearsLanguageWhenRequested() throws {
        let (service, _) = try makeService()

        _ = try service.updatePreferences(
            UserPreferencePatch(preferredLanguage: "en")
        )

        let cleared = try service.updatePreferences(
            UserPreferencePatch(clearsPreferredLanguage: true)
        )

        #expect(cleared.preferredLanguage == nil)
    }

    @Test
    func emptyPatchIsNoOp() throws {
        let bootstrapDate = Date(timeIntervalSince1970: 1_700_000_000)
        let (service, _) = try makeService(now: { bootstrapDate })

        let initial = try service.loadPreferences()
        let unchanged = try service.updatePreferences(UserPreferencePatch())

        #expect(unchanged == initial)
        #expect(unchanged.updatedAt == bootstrapDate)
    }

    @Test
    func resetPreferencesRestoresDefaults() throws {
        let (service, _) = try makeService()

        _ = try service.updatePreferences(
            UserPreferencePatch(
                preferredCategories: ["technology"],
                preferredTopics: ["ai"],
                hiddenSources: ["noisy.example"],
                favoriteSources: ["trusted.example"],
                preferredLanguage: "it"
            )
        )

        let reset = try service.resetPreferences()

        #expect(reset.preferredCategories.isEmpty)
        #expect(reset.preferredTopics.isEmpty)
        #expect(reset.hiddenSources.isEmpty)
        #expect(reset.favoriteSources.isEmpty)
        #expect(reset.preferredLanguage == nil)
    }

    // MARK: - Onboarding + region fields

    @Test
    func defaultPreferencesReportOnboardingNotCompleted() throws {
        let (service, _) = try makeService()

        let preferences = try service.loadPreferences()

        #expect(preferences.hasCompletedOnboarding == false)
        #expect(preferences.enabledRegionRawValues.isEmpty)
    }

    @Test
    func updateEnabledRegionsAndOnboardingRoundTrips() throws {
        let (service, _) = try makeService()

        let updated = try service.updatePreferences(
            .init(
                enabledRegionRawValues: [
                    RSSFeedRegion.italy.rawValue,
                    RSSFeedRegion.france.rawValue
                ],
                hasCompletedOnboarding: true
            )
        )

        #expect(Set(updated.enabledRegionRawValues) == [
            RSSFeedRegion.italy.rawValue,
            RSSFeedRegion.france.rawValue
        ])
        #expect(updated.hasCompletedOnboarding == true)

        let reloaded = try service.loadPreferences()
        #expect(Set(reloaded.enabledRegionRawValues) == [
            RSSFeedRegion.italy.rawValue,
            RSSFeedRegion.france.rawValue
        ])
        #expect(reloaded.hasCompletedOnboarding == true)
    }

    @Test
    func resetPreferencesClearsOnboardingAndRegions() throws {
        let (service, _) = try makeService()

        _ = try service.updatePreferences(
            .init(
                enabledRegionRawValues: [RSSFeedRegion.italy.rawValue],
                hasCompletedOnboarding: true
            )
        )
        let reset = try service.resetPreferences()

        #expect(reset.enabledRegionRawValues.isEmpty)
        #expect(reset.hasCompletedOnboarding == false)
    }

    // MARK: - Helpers

    private func makeService(
        now: @escaping @MainActor () -> Date = { Date() }
    ) throws -> (UserPreferencesService, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserPreferenceEntity.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let service = UserPreferencesService(
            modelContext: context,
            now: now
        )
        return (service, context)
    }
}
