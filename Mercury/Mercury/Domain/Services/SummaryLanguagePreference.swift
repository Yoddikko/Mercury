//
//  SummaryLanguagePreference.swift
//  Mercury
//
//  Created by Claude on 10/07/26.
//

import Foundation

/// The language AI summaries are written in (issue #129). Defaults to
/// the device language; the user can pin Italian or English from
/// Settings → AI provider → Summaries.
nonisolated enum SummaryLanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case italian = "it"
    case english = "en"

    private static let key = "mercury.summaries.language.v1"

    nonisolated var id: String { rawValue }

    static func load(defaults: UserDefaults = .standard) -> SummaryLanguagePreference {
        guard let raw = defaults.string(forKey: key),
              let preference = SummaryLanguagePreference(rawValue: raw) else {
            return .system
        }
        return preference
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.key)
    }

    /// English language name injected into the summarization prompt
    /// ("Italian", "English", …). For `.system` it resolves the device
    /// language; unknown codes fall back to English.
    func promptLanguageName(locale: Locale = .current) -> String {
        let code: String
        switch self {
        case .system:
            code = locale.language.languageCode?.identifier ?? "en"
        case .italian, .english:
            code = rawValue
        }
        let english = Locale(identifier: "en")
        return english.localizedString(forLanguageCode: code) ?? "English"
    }

    /// Label shown in Settings, localized.
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "settings.ai.summary_language.system", defaultValue: "System language")
        case .italian:
            return String(localized: "settings.ai.summary_language.italian", defaultValue: "Italiano")
        case .english:
            return String(localized: "settings.ai.summary_language.english", defaultValue: "English")
        }
    }
}
