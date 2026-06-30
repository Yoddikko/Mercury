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
    let articleRenderer: ArticleRendererMode
    let updatedAt: Date

    init(
        id: String,
        preferredCategories: [String],
        preferredTopics: [String],
        hiddenSources: [String],
        favoriteSources: [String],
        preferredLanguage: String?,
        articleRenderer: ArticleRendererMode = .default,
        updatedAt: Date
    ) {
        self.id = id
        self.preferredCategories = preferredCategories
        self.preferredTopics = preferredTopics
        self.hiddenSources = hiddenSources
        self.favoriteSources = favoriteSources
        self.preferredLanguage = preferredLanguage
        self.articleRenderer = articleRenderer
        self.updatedAt = updatedAt
    }
}
