//
//  InterestsViewModel.swift
//  Mercury
//
//  Created by Claude on 10/07/26.
//

import Combine
import Foundation

/// Backs the interests step of the onboarding and its Settings mirror
/// (issue #133): suggested chips plus free-text custom interests,
/// persisted to `UserPreferenceEntity.preferredTopics` — the signal the
/// AI-only "Per te" feed ranks against.
@MainActor
final class InterestsViewModel: ObservableObject {
    /// Deliberately broad starter interests; the free-text field covers
    /// specific ones ("vela oceanica", "fusione nucleare").
    static let suggestions = [
        "Italia", "Politica", "Ambiente", "Economia", "Sport",
        "Tecnologia", "Cronaca", "Esteri", "Salute", "Cultura", "Scienza"
    ]

    @Published private(set) var selected: [String] = []
    @Published var customInput = ""
    @Published private(set) var lastErrorMessage: String?

    private var service: UserPreferencesService
    private let logger: AppLogger
    private let forYouCache: ForYouPicksCache

    init(
        service: UserPreferencesService,
        logger: AppLogger = .shared,
        cacheDefaults: UserDefaults = .standard
    ) {
        self.service = service
        self.logger = logger
        self.forYouCache = ForYouPicksCache(defaults: cacheDefaults, logger: logger)
    }

    func replaceService(_ service: UserPreferencesService) {
        self.service = service
    }

    /// Hydrates from the persisted preferences. Idempotent.
    func load() {
        do {
            selected = try service.loadPreferences().preferredTopics
            lastErrorMessage = nil
        } catch {
            logger.error(
                "Failed to load interests",
                category: .ui,
                service: "InterestsViewModel",
                metadata: ["error": String(describing: error)]
            )
            lastErrorMessage = Self.saveErrorLabel
        }
    }

    func isSelected(_ interest: String) -> Bool {
        selected.contains { $0.caseInsensitiveCompare(interest) == .orderedSame }
    }

    func toggle(_ interest: String) {
        if let index = selected.firstIndex(where: { $0.caseInsensitiveCompare(interest) == .orderedSame }) {
            selected.remove(at: index)
        } else {
            selected.append(interest)
        }
        persist()
    }

    /// Adds the free-text interest (trimmed, case-insensitively deduped).
    func addCustomInterest() {
        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        customInput = ""
        guard isSelected(trimmed) == false else { return }
        selected.append(trimmed)
        persist()
    }

    /// Custom interests are the selected ones that are not suggestions —
    /// rendered as removable chips.
    var customInterests: [String] {
        selected.filter { interest in
            Self.suggestions.contains { $0.caseInsensitiveCompare(interest) == .orderedSame } == false
        }
    }

    private func persist() {
        do {
            _ = try service.updatePreferences(UserPreferencePatch(preferredTopics: selected))
            // Stale ranking guard (issue #136): the persisted Per te
            // picks were computed against the old interests — drop them
            // so the next recompute uses the new ones.
            forYouCache.clear()
            lastErrorMessage = nil
            logger.debug(
                "Interests persisted",
                category: .business,
                service: "InterestsViewModel",
                metadata: ["count": "\(selected.count)"]
            )
        } catch {
            logger.error(
                "Failed to persist interests",
                category: .database,
                service: "InterestsViewModel",
                metadata: ["error": String(describing: error)]
            )
            lastErrorMessage = Self.saveErrorLabel
        }
    }

    // MARK: - Localized copy

    static var title: String {
        String(localized: "onboarding.interests.title", defaultValue: "Your interests")
    }

    static var subtitle: String {
        String(
            localized: "onboarding.interests.subtitle",
            defaultValue: "Pick what you care about — the \"For you\" feed is built on these."
        )
    }

    static var customPlaceholder: String {
        String(
            localized: "onboarding.interests.custom_placeholder",
            defaultValue: "Add a specific interest…"
        )
    }

    static var aiNote: String {
        String(
            localized: "onboarding.interests.ai_note",
            defaultValue: "The personalized feed needs the AI provider set up in the next step."
        )
    }

    static var saveErrorLabel: String {
        String(
            localized: "onboarding.interests.save_error",
            defaultValue: "We couldn't save your interests. Try again."
        )
    }
}
