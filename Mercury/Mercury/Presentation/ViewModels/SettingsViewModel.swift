//
//  SettingsViewModel.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Combine
import Foundation
import SwiftData

/// View model backing `SettingsScreen` (issue #58).
///
/// Owns the read+write loop against `UserPreferencesService` for the
/// app-behavior toggles documented in `docs/features/SETTINGS.md`. The
/// only field exposed today is the article body rendering mode; the
/// view model is structured so future toggles (theme, refresh cadence,
/// …) can land without re-shaping the screen.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var articleRenderer: ArticleRendererMode = .default
    @Published private(set) var lastErrorMessage: String?

    private var service: UserPreferencesService
    private let logger: AppLogger

    init(service: UserPreferencesService, logger: AppLogger = .shared) {
        self.service = service
        self.logger = logger
    }

    /// Swap the underlying service. Used by `SettingsScreen` to switch
    /// from the placeholder context to the live environment context once
    /// the SwiftUI environment is available.
    func replaceService(_ service: UserPreferencesService) {
        self.service = service
    }

    /// Hydrate the published state from persisted preferences. Safe to
    /// call multiple times; treated as idempotent.
    func load() {
        do {
            let preferences = try service.loadPreferences()
            articleRenderer = preferences.articleRenderer
            lastErrorMessage = nil
        } catch {
            logger.error(
                "Failed to load settings",
                category: .ui,
                service: "SettingsViewModel",
                metadata: ["error": String(describing: error)]
            )
            lastErrorMessage = String(
                localized: "settings.error.load",
                defaultValue: "We couldn't read your settings."
            )
        }
    }

    /// Apply a new article renderer choice. No-op when unchanged.
    func updateArticleRenderer(_ mode: ArticleRendererMode) {
        guard mode != articleRenderer else { return }
        let previous = articleRenderer
        articleRenderer = mode
        do {
            try service.updatePreferences(.init(articleRenderer: mode))
            lastErrorMessage = nil
            logger.info(
                "Updated article renderer mode",
                category: .ui,
                service: "SettingsViewModel",
                metadata: ["mode": mode.rawValue]
            )
        } catch {
            // Roll back the visible selection so the UI mirrors what is
            // actually persisted.
            articleRenderer = previous
            lastErrorMessage = String(
                localized: "settings.error.save",
                defaultValue: "We couldn't save that change. Try again."
            )
            logger.error(
                "Failed to persist article renderer mode",
                category: .ui,
                service: "SettingsViewModel",
                metadata: [
                    "attempted": mode.rawValue,
                    "reverted_to": previous.rawValue,
                    "error": String(describing: error)
                ]
            )
        }
    }
}

extension ArticleRendererMode {
    var localizedTitle: String {
        switch self {
        case .web:
            return String(
                localized: "settings.renderer.web.title",
                defaultValue: "Web"
            )
        case .native:
            return String(
                localized: "settings.renderer.native.title",
                defaultValue: "Native"
            )
        }
    }

    var localizedDescription: String {
        switch self {
        case .web:
            return String(
                localized: "settings.renderer.web.description",
                defaultValue: "Render the article in a web view with the original layout."
            )
        case .native:
            return String(
                localized: "settings.renderer.native.description",
                defaultValue: "Render the article using native SwiftUI blocks (still being rolled out)."
            )
        }
    }
}
