//
//  UserPreference.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct UserPreference: Identifiable, Equatable, Sendable {
    let id: String
    let preferredCategories: [String]
    let preferredTopics: [String]
    let hiddenSources: [String]
    let favoriteSources: [String]
    let preferredLanguage: String?
    /// Region raw values (`RSSFeedRegion.rawValue`) the user opted in to during
    /// onboarding or via Settings. An empty array means "all regions" — this is
    /// the default and mirrors the pre-onboarding behavior.
    let enabledRegionRawValues: [String]
    /// Whether the user has completed the first-launch onboarding flow.
    let hasCompletedOnboarding: Bool
    let updatedAt: Date

    init(
        id: String,
        preferredCategories: [String],
        preferredTopics: [String],
        hiddenSources: [String],
        favoriteSources: [String],
        preferredLanguage: String?,
        enabledRegionRawValues: [String] = [],
        hasCompletedOnboarding: Bool = false,
        updatedAt: Date
    ) {
        self.id = id
        self.preferredCategories = preferredCategories
        self.preferredTopics = preferredTopics
        self.hiddenSources = hiddenSources
        self.favoriteSources = favoriteSources
        self.preferredLanguage = preferredLanguage
        self.enabledRegionRawValues = enabledRegionRawValues
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.updatedAt = updatedAt
    }
}
