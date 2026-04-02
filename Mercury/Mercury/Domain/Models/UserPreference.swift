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
    let updatedAt: Date
}
