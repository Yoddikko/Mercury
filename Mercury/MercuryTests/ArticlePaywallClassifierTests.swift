//
//  ArticlePaywallClassifierTests.swift
//  MercuryTests
//
//  Created by Claude on 02/07/26.
//

import Foundation
import Testing
@testable import Mercury

/// Unit tests for the subscriber-only teaser classifier (issue #95).
/// The load-bearing case is the FREE article that carries paywall
/// markers: live evidence (2026-07-02) showed a free ANSA article
/// with 1 `PAYWALL` + 3 `Premium` tokens in its raw HTML, so a marker
/// alone must never classify — the distilled output must also be
/// teaser-short.
@Suite("Paywall teaser classifier")
struct ArticlePaywallClassifierTests {
    private let classifier = ArticlePaywallClassifier()

    /// Teaser page modeled on the live Repubblica premium pages from
    /// the 2026-07-02 audit: headline + standfirst only, body shipped
    /// truncated in JSON-LD, `isAccessibleForFree: false`.
    private static let premiumTeaserHTML = """
    <html><head>
    <script type="application/ld+json">
    {"@type": "NewsArticle", "isAccessibleForFree": false,
     "articleBody": "La vicenda risale al 2018 ma rischia di mettere…"}
    </script>
    </head><body>
    <h1>La Corte conferma la multa</h1>
    <p>Nel mirino la posizione dominante del motore di ricerca.</p>
    </body></html>
    """

    @Test
    func premiumTeaserIsClassifiedPaywalled() {
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: Self.premiumTeaserHTML,
                distilledWordCount: 44
            )
        )
    }

    @Test
    func freeArticleWithPaywallMarkersIsNotClassifiedPaywalled() {
        // Free page that still ships subscription chrome in the raw
        // HTML (ANSA pattern) — the healthy distilled word count must
        // veto the marker match.
        let freeHTML = """
        <html><body>
        <div class="PAYWALL Premium bt-Subscribe">Solo per abbonati</div>
        <article><p>Corpo dell'articolo interamente leggibile…</p></article>
        </body></html>
        """
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: freeHTML,
                distilledWordCount: 112
            ) == false
        )
    }

    @Test
    func shortArticleWithoutMarkersIsNotClassifiedPaywalled() {
        // Legitimate news brief: teaser-short but no paywall marker
        // anywhere in the page.
        let briefHTML = """
        <html><body><article>
        <p>Breve notizia di agenzia con poche parole ma completa.</p>
        </article></body></html>
        """
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: briefHTML,
                distilledWordCount: 30
            ) == false
        )
    }

    @Test
    func outletSpecificMarkerFromRuleClassifiesTeaser() throws {
        // The Local's membership gate (live fixture evidence) — not a
        // default marker, declared via `paywallMarkers` in the rules
        // JSON.
        let gatedHTML = """
        <html><body>
        <p>Preview paragraph.</p>
        <p id="articleBodyForbidden">Become a member or log in to continue reading</p>
        </body></html>
        """
        let marker = try NSRegularExpression(
            pattern: "\\bbecome\\s+a\\s+member\\s+or\\s+log\\s+in\\b",
            options: [.caseInsensitive]
        )

        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: gatedHTML,
                distilledWordCount: 20,
                outletMarkers: [marker]
            )
        )
        // Same page without the outlet marker: default markers do not
        // match, so it stays unclassified.
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: gatedHTML,
                distilledWordCount: 20
            ) == false
        )
    }

    @Test
    func italianSubscriberCTAIsADefaultMarker() {
        let ansaStyleTeaser = """
        <html><body>
        <p>Prime righe dell'articolo.</p>
        <div class="subscription">Contenuto riservato agli abbonati</div>
        </body></html>
        """
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: ansaStyleTeaser,
                distilledWordCount: 25
            )
        )
    }

    @Test
    func wordCeilingBoundaryIsExclusive() {
        // Exactly at the ceiling → treated as an article.
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: Self.premiumTeaserHTML,
                distilledWordCount: ArticlePaywallClassifier.teaserWordCeiling
            ) == false
        )
        // One below → teaser.
        #expect(
            classifier.isLikelyPaywalledTeaser(
                rawHTML: Self.premiumTeaserHTML,
                distilledWordCount: ArticlePaywallClassifier.teaserWordCeiling - 1
            )
        )
    }
}
