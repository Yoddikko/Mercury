//
//  ArticleLocaleBoilerplateStripper.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation
import SwiftSoup

/// Removes text-pattern boilerplate that Readability cannot classify by
/// tag, class or id (issue #66 / spec PR #65).
///
/// Outlets embed copyright lines ("Riproduzione riservata"), newsletter
/// CTAs ("Iscriviti alla newsletter") and related-articles intros
/// ("Leggi anche", "Articoli correlati") as ordinary `<p>` text inside
/// the main article container. Readability's class/id scoring keeps
/// these because the surrounding container has positive signals; only a
/// text-pattern pass catches them.
///
/// Patterns are localized — applied only when `Article.language` matches
/// the rule's locale. Unknown languages fall through untouched so the
/// stripper never removes something it doesn't recognise.
struct ArticleLocaleBoilerplateStripper: Sendable {
    /// Returns a copy of `html` with paragraphs (`<p>` and `<li>`) whose
    /// text matches a boilerplate pattern for the given locale removed.
    /// `nil` or unknown `language` returns the input untouched.
    func stripping(html: String, language: String?) -> String {
        guard let normalized = Self.normalizedLanguage(language),
              let patterns = Self.patterns[normalized] else {
            return html
        }

        do {
            let document = try SwiftSoup.parseBodyFragment(html)
            guard let body = document.body() else { return html }

            // Paragraph-level elements (`p, li`): drop whenever the
            // text matches a boilerplate pattern, regardless of length.
            // Container / heading elements (`div, span, h1..h6, header`):
            // only drop when the matching text is short (≤ 80 chars),
            // so a div that legitimately contains an article body which
            // happens to mention a banned phrase is preserved while a
            // standalone "Leggi anche" label divider gets removed.
            let paragraphCandidates = try body.select("p, li")
            for element in paragraphCandidates {
                guard let text = try? element.text() else { continue }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { continue }
                if Self.matches(text: trimmed, patterns: patterns) {
                    try element.remove()
                }
            }

            let containerCandidates = try body.select("div, span, h1, h2, h3, h4, h5, h6, header, aside, a")
            for element in containerCandidates {
                guard let text = try? element.text() else { continue }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { continue }
                // Bail when the text is long — that's a real container,
                // not a boilerplate label.
                guard trimmed.count <= 80 else { continue }
                if Self.matches(text: trimmed, patterns: patterns) {
                    try element.remove()
                }
            }

            return try body.html()
        } catch {
            return html
        }
    }

    /// Lowercases + truncates to the primary subtag so `it-IT`, `it`,
    /// `IT_it` all collapse to `it`.
    static func normalizedLanguage(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.isEmpty == false else { return nil }
        if let dash = trimmed.firstIndex(where: { $0 == "-" || $0 == "_" }) {
            return String(trimmed[..<dash])
        }
        return trimmed
    }

    static func matches(text: String, patterns: [NSRegularExpression]) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return patterns.contains { regex in
            regex.firstMatch(in: text, options: [], range: range) != nil
        }
    }

    /// Per-locale regex tables. Each pattern is anchored loosely (case
    /// insensitive, can appear anywhere in the paragraph) so embedded
    /// phrasing variations still match. Keep patterns narrow to avoid
    /// accidentally dropping legitimate article sentences.
    static let patterns: [String: [NSRegularExpression]] = [
        "it": Self.compile([
            "\\briproduzione\\s+riservata\\b",
            "\\btutti\\s+i\\s+diritti\\s+riservati\\b",
            "^\\s*©\\s*copyright\\b",
            "\\bleggi\\s+anche\\b",
            "\\barticoli\\s+correlati\\b",
            "\\bvedi\\s+anche\\b",
            "\\bapprofondimenti\\b",
            "\\biscriviti\\s+alla\\s+(?:nostra\\s+)?newsletter\\b",
            "\\bnewsletter\\s+iscriviti\\b",
            "\\bresta\\s+aggiornato\\b",
            "\\bcondividi\\s+su\\b",
            "\\baccetta\\s+(?:tutti\\s+i\\s+)?cookie\\b",
            "\\bcookie\\s+policy\\b",
            // Common cookie / consent banner phrasings on Italian outlets.
            "\\bcookie\\s+di\\s+profilazione\\b",
            "\\bse\\s+hai\\s+scelto\\s+di\\s+non\\s+accettare\\b",
            "\\babbonamento\\s+[\"']?consentless\\b",
            "\\btrattamento\\s+dei\\s+dati\\s+personali\\b",
            "\\bcontinua\\s+senza\\s+accettare\\b",
            // "Follow us" widget copy (Google Discover / social).
            "\\bseguici\\s+(?:anche\\s+)?su\\b",
            "\\bgoogle\\s+discover\\b",
            "\\bfonti\\s+preferite\\b",
            // Subscribe / login menu labels (short standalone contexts).
            "\\babbonati\\s+(?:entra|accedi|adesso|ora|per\\b|premium|a\\b)",
            // Sponsored content / dynamic placeholders that survive
            // the class strip on outlets like Il Sole 24 Ore.
            "\\bbrand\\s+connect\\b",
            "\\bloading\\.{2,}",
            // Il Messaggero real-estate ad copy.
            "\\bcerca\\s+il\\s+tuo\\s+immobile\\b",
            "\\bimmobile\\s+all[\"' ]asta\\b"
        ]),
        "en": Self.compile([
            "^\\s*all\\s+rights\\s+reserved\\b",
            "^\\s*©\\s*copyright\\b",
            "\\bread\\s+more\\b",
            "\\brelated\\s+(?:articles|stories|reading)\\b",
            "\\bmore\\s+like\\s+this\\b",
            "\\bsubscribe\\s+to\\s+(?:our\\s+)?newsletter\\b",
            "\\bsign\\s+up\\s+for\\s+(?:our\\s+)?newsletter\\b",
            "\\bshare\\s+this\\s+(?:article|story)\\b",
            "\\baccept\\s+(?:all\\s+)?cookies\\b",
            "\\bcookie\\s+policy\\b"
        ])
    ]

    private static func compile(_ patterns: [String]) -> [NSRegularExpression] {
        patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }
}
