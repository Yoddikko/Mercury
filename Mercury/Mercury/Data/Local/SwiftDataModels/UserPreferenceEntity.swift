//
//  UserPreferenceEntity.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation
import SwiftData

@Model
final class UserPreferenceEntity {
    @Attribute(.unique) var id: String
    var preferredCategories: [String]
    var preferredTopics: [String]
    var hiddenSources: [String]
    var favoriteSources: [String]
    var preferredLanguage: String?
    /// Legacy raw value of the removed `ArticleRendererMode` (deprecated
    /// with issue #83). Kept as a nullable field so SwiftData
    /// lightweight migration on installs that pre-date the removal
    /// doesn't need a schema bump. New writes leave it untouched; no
    /// reader consults it.
    ///
    /// ponytail: this column exists purely to keep migrations
    /// zero-cost; delete on the next MAJOR bump that already touches
    /// the preferences schema.
    var articleRendererRawValue: String?
    /// Raw values of `RSSFeedRegion` the user has opted in to. Empty means
    /// "all regions" (backwards compatible with pre-onboarding preferences).
    /// Optional so SwiftData migration stays additive.
    var enabledRegionRawValues: [String]?
    /// Whether the user has completed the first-launch onboarding flow.
    /// Optional so SwiftData migration stays additive — nil is treated as
    /// `false` (onboarding not yet completed) by the mapper.
    var hasCompletedOnboarding: Bool?
    var updatedAt: Date

    init(
        id: String = "default-user-preferences",
        preferredCategories: [String] = [],
        preferredTopics: [String] = [],
        hiddenSources: [String] = [],
        favoriteSources: [String] = [],
        preferredLanguage: String? = nil,
        articleRendererRawValue: String? = nil,
        enabledRegionRawValues: [String]? = nil,
        hasCompletedOnboarding: Bool? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.preferredCategories = preferredCategories
        self.preferredTopics = preferredTopics
        self.hiddenSources = hiddenSources
        self.favoriteSources = favoriteSources
        self.preferredLanguage = preferredLanguage
        self.articleRendererRawValue = articleRendererRawValue
        self.enabledRegionRawValues = enabledRegionRawValues
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.updatedAt = updatedAt
    }
}
