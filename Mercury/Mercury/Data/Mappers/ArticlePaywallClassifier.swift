//
//  ArticlePaywallClassifier.swift
//  Mercury
//
//  Created by Claude on 02/07/26.
//

import Foundation

/// Classifies a fetched article page as a subscriber-only teaser
/// (issue #95 / meta #80).
///
/// Some outlets (Repubblica premium, The Local members-only, ANSA
/// "solo per abbonati") ship pages whose readable body simply is not
/// in the HTML: a headline, a one-paragraph teaser, and a
/// subscription CTA. No amount of chrome-stripping produces an
/// article from those pages — the pipeline used to fall back to the
/// extractor text, which IS the teaser + CTA, and render that as the
/// body.
///
/// Classification requires BOTH conditions (live evidence from
/// 2026-07-02: a *free* ANSA article carries 1 `PAYWALL` and 3
/// `Premium` markers, so a marker alone must never be enough):
/// 1. the distilled output is teaser-short
///    (`distilledWordCount < teaserWordCeiling`), AND
/// 2. the RAW page HTML matches a paywall marker — either a default
///    marker (schema.org `isAccessibleForFree: false`, Italian
///    subscriber-CTA copy) or an outlet-specific one from the rule's
///    `paywallMarkers` (`ArticleOutletExtractionRules.json`).
///
/// Callers react by keeping the article un-enriched, so the reader
/// shows the RSS item summary instead of subscription copy.
struct ArticlePaywallClassifier: Sendable {
    /// Distilled outputs at or above this word count are articles, not
    /// teasers, regardless of raw-page markers. Aligned with the
    /// enrichment service's minimum-distilled-words threshold so
    /// classification only ever fires where distillation already
    /// failed to produce a usable body.
    static let teaserWordCeiling = 80

    /// Markers checked on every page regardless of outlet.
    /// * schema.org `isAccessibleForFree: false` — Repubblica (and
    ///   most subscription CMSes) stamp premium articles with it in
    ///   JSON-LD; observed live on 2026-07-02.
    /// * Italian subscriber-CTA copy variants.
    static let defaultMarkers: [NSRegularExpression] = [
        "\"isAccessibleForFree\"\\s*:\\s*\"?false",
        "\\bsolo\\s+per\\s+(gli\\s+)?abbonati\\b",
        "\\briservat[oa]\\s+agli\\s+abbonati\\b",
        "\\babbonati\\s+per\\s+continuare\\b"
    ].compactMap {
        try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }

    private let logger: AppLogger

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    /// Returns `true` when the page is a subscriber-only teaser:
    /// teaser-short distilled output AND a paywall marker in the raw
    /// HTML. `outletMarkers` come from the matched extraction rule
    /// (empty when the host has no rule or the rule declares none).
    func isLikelyPaywalledTeaser(
        rawHTML: String,
        distilledWordCount: Int,
        outletMarkers: [NSRegularExpression] = [],
        requestID: String? = nil
    ) -> Bool {
        guard distilledWordCount < Self.teaserWordCeiling else { return false }

        let range = NSRange(rawHTML.startIndex..., in: rawHTML)
        let matched = (Self.defaultMarkers + outletMarkers).first {
            $0.firstMatch(in: rawHTML, options: [], range: range) != nil
        }
        guard let matched else { return false }

        logger.info(
            "Article page classified as paywalled teaser",
            category: .business,
            service: "ArticlePaywallClassifier",
            requestID: requestID,
            metadata: [
                "distilled_word_count": "\(distilledWordCount)",
                "teaser_word_ceiling": "\(Self.teaserWordCeiling)",
                "marker": matched.pattern
            ]
        )
        return true
    }
}
