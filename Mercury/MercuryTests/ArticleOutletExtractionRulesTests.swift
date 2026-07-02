//
//  ArticleOutletExtractionRulesTests.swift
//  MercuryTests
//
//  Created by Claude on 02/07/26.
//

import Foundation
import Testing
@testable import Mercury

/// Unit tests for the per-outlet extraction rule layer (issue #91):
/// catalog decoding, host matching, and rule application. The seeded
/// outlets (ANSA / Corriere / Repubblica) are exercised end-to-end
/// against real pages by `ItalianDistillationFixturesTests`.
@Suite("Per-outlet extraction rules")
struct ArticleOutletExtractionRulesTests {
    // MARK: - Helpers

    private static func rule(
        id: String = "test",
        hosts: [String],
        bodySelectors: [String] = [],
        stripSelectors: [String] = [],
        stripTextPatterns: [String] = [],
        paywallMarkers: [String] = []
    ) -> ArticleOutletExtractionRule {
        ArticleOutletExtractionRule(
            id: id,
            hosts: hosts,
            bodySelectors: bodySelectors,
            stripSelectors: stripSelectors,
            stripTextPatterns: stripTextPatterns.compactMap {
                try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
            },
            paywallMarkers: paywallMarkers.compactMap {
                try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
            }
        )
    }

    // MARK: - Bundled catalog

    @Test
    func bundledCatalogContainsSeedRules() {
        let catalog = ArticleOutletRuleCatalog.bundled
        let ids = Set(catalog.rules.map(\.id))

        #expect(catalog.rules.count >= 3)
        #expect(ids.isSuperset(of: ["ansa", "corriere", "repubblica"]))
        for rule in catalog.rules {
            #expect(rule.hosts.isEmpty == false, "rule \(rule.id) has no hosts")
            #expect(
                rule.hosts.allSatisfy { $0 == $0.lowercased() },
                "rule \(rule.id) hosts must be normalized lowercase"
            )
            #expect(
                rule.bodySelectors.isEmpty == false
                    || rule.stripSelectors.isEmpty == false
                    || rule.stripTextPatterns.isEmpty == false,
                "rule \(rule.id) is a no-op"
            )
        }
    }

    @Test
    func malformedRulesetDecodesToEmptyCatalog() {
        let data = Data("not json at all".utf8)
        let catalog = ArticleOutletRuleCatalog.decode(data: data)
        #expect(catalog.rules.isEmpty)
    }

    @Test
    func decodeSkipsInvalidPatternsAndHostlessRules() throws {
        let json = """
        {
          "version": 1,
          "rules": [
            { "id": "no-hosts", "hosts": [] },
            {
              "id": "partial",
              "hosts": ["Example.COM"],
              "stripTextPatterns": ["\\\\bvalid\\\\b", "(unclosed"]
            }
          ]
        }
        """
        let catalog = ArticleOutletRuleCatalog.decode(data: Data(json.utf8))

        #expect(catalog.rules.count == 1)
        let rule = try #require(catalog.rules.first)
        #expect(rule.id == "partial")
        #expect(rule.hosts == ["example.com"])
        #expect(rule.stripTextPatterns.count == 1)
    }

    @Test
    func decodePaywallMarkersIsOptionalAndSkipsInvalidPatterns() throws {
        let json = """
        {
          "version": 1,
          "rules": [
            { "id": "no-markers", "hosts": ["a.example"], "stripSelectors": [".x"] },
            {
              "id": "with-markers",
              "hosts": ["b.example"],
              "stripSelectors": [".y"],
              "paywallMarkers": ["\\\\bmembers\\\\s+only\\\\b", "(unclosed"]
            }
          ]
        }
        """
        let catalog = ArticleOutletRuleCatalog.decode(data: Data(json.utf8))

        #expect(catalog.rules.count == 2)
        let plain = try #require(catalog.rules.first(where: { $0.id == "no-markers" }))
        #expect(plain.paywallMarkers.isEmpty)
        let marked = try #require(catalog.rules.first(where: { $0.id == "with-markers" }))
        #expect(marked.paywallMarkers.count == 1)
    }

    @Test
    func bundledTheLocalRuleDeclaresPaywallMarkers() throws {
        // The Local's membership gate is the first outlet-specific
        // marker shipped in the bundled ruleset (#95).
        let rule = try #require(ArticleOutletRuleCatalog.bundled.rule(forHost: "www.thelocal.it"))
        #expect(rule.id == "thelocal")
        #expect(rule.paywallMarkers.isEmpty == false)
    }

    // MARK: - Host matching

    @Test
    func hostMatchingCoversExactAndSubdomains() {
        let catalog = ArticleOutletRuleCatalog(rules: [
            Self.rule(id: "ansa", hosts: ["ansa.it"])
        ])

        #expect(catalog.rule(forHost: "ansa.it")?.id == "ansa")
        #expect(catalog.rule(forHost: "www.ansa.it")?.id == "ansa")
        #expect(catalog.rule(forHost: "sport.ansa.it")?.id == "ansa")
        #expect(catalog.rule(forHost: "WWW.ANSA.IT")?.id == "ansa")
        #expect(catalog.rule(forHost: "www.ansa.it.") != nil, "trailing DNS dot must normalize")
        #expect(catalog.rule(forHost: "www.ansa.it:443") != nil, "port suffix must normalize")
    }

    @Test
    func hostMatchingRejectsLookalikes() {
        let catalog = ArticleOutletRuleCatalog(rules: [
            Self.rule(id: "ansa", hosts: ["ansa.it"])
        ])

        #expect(catalog.rule(forHost: "notansa.it") == nil)
        #expect(catalog.rule(forHost: "ansa.it.evil.com") == nil)
        #expect(catalog.rule(forHost: "ansa.itx") == nil)
        #expect(catalog.rule(forHost: nil) == nil)
        #expect(catalog.rule(forHost: "   ") == nil)
    }

    @Test
    func mostSpecificRuleHostWins() {
        let catalog = ArticleOutletRuleCatalog(rules: [
            Self.rule(id: "generic", hosts: ["example.com"]),
            Self.rule(id: "news", hosts: ["news.example.com"])
        ])

        #expect(catalog.rule(forHost: "www.news.example.com")?.id == "news")
        #expect(catalog.rule(forHost: "news.example.com")?.id == "news")
        #expect(catalog.rule(forHost: "shop.example.com")?.id == "generic")
    }

    // MARK: - Applier: body selector

    @Test
    func bodySelectorNarrowsDocumentToArticleContainer() {
        let html = """
        <div class="site-chrome"><p>Menu, login, subscribe banner chrome.</p></div>
        <div itemprop="articleBody"><p>The real article body text.</p></div>
        <div class="footer-junk"><p>Footer boilerplate lives here.</p></div>
        """
        let rule = Self.rule(hosts: ["example.com"], bodySelectors: ["div[itemprop=articleBody]"])

        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("The real article body text."))
        #expect(output.contains("subscribe banner chrome") == false)
        #expect(output.contains("Footer boilerplate") == false)
    }

    @Test
    func bodySelectorsAreTriedInOrder() {
        let html = """
        <section class="new-template"><p>New template body.</p></section>
        <div class="old-template"><p>Old template body.</p></div>
        """
        let rule = Self.rule(
            hosts: ["example.com"],
            bodySelectors: ["section.new-template", ".old-template"]
        )

        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("New template body."))
        #expect(output.contains("Old template body.") == false)
    }

    @Test
    func unmatchedBodySelectorKeepsFullDocument() {
        let html = "<div class=\"anything\"><p>Article text stays put.</p></div>"
        let rule = Self.rule(hosts: ["example.com"], bodySelectors: ["div[itemprop=articleBody]"])

        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("Article text stays put."))
    }

    // MARK: - Applier: strip selectors

    @Test
    func stripSelectorsRemoveOutletChrome() {
        let html = """
        <div itemprop="articleBody">
          <div class="bt-Subscribe"><a class="bt-abbonati" href="/abbo">ABBONAMENTO CONSENTLESS</a></div>
          <p>Actual paragraph of the article that must survive intact.</p>
          <div id="pno-in-article-abbonato"><p>Paywall promo inside the body.</p></div>
        </div>
        """
        let rule = Self.rule(
            hosts: ["example.com"],
            stripSelectors: [".bt-Subscribe", "[id^=pno-]"]
        )

        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("must survive intact"))
        #expect(output.contains("ABBONAMENTO CONSENTLESS") == false)
        #expect(output.contains("Paywall promo") == false)
    }

    // MARK: - Applier: strip text patterns

    @Test
    func stripTextPatternsDropMatchingParagraphs() {
        let html = """
        <p>Accetta i cookie e continua</p>
        <p>Un paragrafo legittimo dell'articolo che parla di altro.</p>
        """
        let rule = Self.rule(
            hosts: ["example.com"],
            stripTextPatterns: ["\\baccetta\\s+i\\s+cookie\\s+e\\s+continua\\b"]
        )

        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("paragrafo legittimo"))
        #expect(output.lowercased().contains("accetta i cookie e continua") == false)
    }

    @Test
    func stripTextPatternsPreserveLongContainersMentioningPhrase() {
        let longBody = String(repeating: "Testo dell'articolo. ", count: 10)
        let html = """
        <div>\(longBody) In fondo alla pagina compare la frase altri abbonamenti dentro un contesto legittimo.</div>
        <div>altri abbonamenti</div>
        """
        let rule = Self.rule(
            hosts: ["example.com"],
            stripTextPatterns: ["\\baltri\\s+abbonamenti\\b"]
        )

        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("contesto legittimo"), "long container must survive")
        // The standalone short label must be gone; count occurrences.
        let occurrences = output.lowercased()
            .components(separatedBy: "altri abbonamenti").count - 1
        #expect(occurrences == 1, "short standalone label must be stripped")
    }

    @Test
    func emptyInputPassesThroughUntouched() {
        let rule = Self.rule(hosts: ["example.com"], stripSelectors: [".x"])
        #expect(ArticleOutletRuleApplier().applying(rule, to: "   ") == "   ")
    }

    // MARK: - Seeded outlets (synthetic smoke; real pages in fixtures)

    @Test
    func seededANSARuleRemovesConsentlessCTA() throws {
        let catalog = ArticleOutletRuleCatalog.bundled
        let rule = try #require(catalog.rule(forHost: "www.ansa.it"))

        let html = """
        <div class="prompt-to-accept__content"><p>Se hai scelto di non accettare i cookie.</p>
          <div class="bt-Subscribe"><a class="bt-abbonati" href="/x">ABBONAMENTO CONSENTLESS</a></div>
        </div>
        <div class="post-single-text rich-text news-txt" itemprop="articleBody">
          <p>Il corpo dell'articolo ANSA sopravvive alla regola.</p>
        </div>
        """
        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("sopravvive alla regola"))
        #expect(output.contains("ABBONAMENTO CONSENTLESS") == false)
    }

    @Test
    func seededCorriereRuleRemovesPaywallChrome() throws {
        let catalog = ArticleOutletRuleCatalog.bundled
        let rule = try #require(catalog.rule(forHost: "www.corriere.it"))

        let html = """
        <div class="bck-modal-access"><p>Sei già abbonato con un altro account? Accedi.</p></div>
        <section class="body-article">
          <p class="chapter-paragraph">Il corpo dell'articolo Corriere sopravvive alla regola.</p>
          <div id="pno-in-article-abbonato"><p>L'abbonamento permette di leggere Corriere senza limiti.</p></div>
        </section>
        """
        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("sopravvive alla regola"))
        #expect(output.contains("abbonato con un altro account") == false)
        #expect(output.contains("permette di leggere Corriere") == false)
    }

    @Test
    func seededRepubblicaRuleRemovesLinkBlocks() throws {
        let catalog = ArticleOutletRuleCatalog.bundled
        let rule = try #require(catalog.rule(forHost: "www.repubblica.it"))

        // No body container in the markup — mirrors the paywalled
        // preview template where only header/summary are visible; the
        // rule must fall through to strip-only behavior.
        let html = """
        <h1 class="story__title">Titolo dell'articolo Repubblica</h1>
        <div class="story__summary"><p>Sommario che deve sopravvivere.</p></div>
        <article class="aside-story"><h4 class="aside-story__title"><a href="/a">Articolo correlato uno</a></h4></article>
        <article class="aside-story"><h4 class="aside-story__title"><a href="/b">Articolo correlato due</a></h4></article>
        <div class="limio-fr-related"><h3>Abbonati per leggere anche</h3></div>
        """
        let output = ArticleOutletRuleApplier().applying(rule, to: html)

        #expect(output.contains("Titolo dell'articolo Repubblica"))
        #expect(output.contains("Sommario che deve sopravvivere."))
        #expect(output.contains("Articolo correlato") == false)
        #expect(output.lowercased().contains("abbonati per leggere anche") == false)
    }
}
