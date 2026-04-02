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
    var updatedAt: Date

    init(
        id: String = "default-user-preferences",
        preferredCategories: [String] = [],
        preferredTopics: [String] = [],
        hiddenSources: [String] = [],
        favoriteSources: [String] = [],
        preferredLanguage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.preferredCategories = preferredCategories
        self.preferredTopics = preferredTopics
        self.hiddenSources = hiddenSources
        self.favoriteSources = favoriteSources
        self.preferredLanguage = preferredLanguage
        self.updatedAt = updatedAt
    }
}
