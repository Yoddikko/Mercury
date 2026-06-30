//
//  UserPreferencePatch.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Partial update payload for `UserPreference`.
///
/// Every property is optional so callers can update one field at a time
/// without having to pass the full preferences object back to the service.
/// `preferredLanguage` uses `clearsPreferredLanguage` to differentiate
/// "leave untouched" (`nil`) from "explicitly reset to no language".
struct UserPreferencePatch: Equatable, Sendable {
    var preferredCategories: [String]?
    var preferredTopics: [String]?
    var hiddenSources: [String]?
    var favoriteSources: [String]?
    var preferredLanguage: String?
    var clearsPreferredLanguage: Bool
    var articleRenderer: ArticleRendererMode?

    init(
        preferredCategories: [String]? = nil,
        preferredTopics: [String]? = nil,
        hiddenSources: [String]? = nil,
        favoriteSources: [String]? = nil,
        preferredLanguage: String? = nil,
        clearsPreferredLanguage: Bool = false,
        articleRenderer: ArticleRendererMode? = nil
    ) {
        self.preferredCategories = preferredCategories
        self.preferredTopics = preferredTopics
        self.hiddenSources = hiddenSources
        self.favoriteSources = favoriteSources
        self.preferredLanguage = preferredLanguage
        self.clearsPreferredLanguage = clearsPreferredLanguage
        self.articleRenderer = articleRenderer
    }

    /// Returns true when the patch carries no actionable change.
    var isEmpty: Bool {
        preferredCategories == nil
            && preferredTopics == nil
            && hiddenSources == nil
            && favoriteSources == nil
            && preferredLanguage == nil
            && clearsPreferredLanguage == false
            && articleRenderer == nil
    }
}
