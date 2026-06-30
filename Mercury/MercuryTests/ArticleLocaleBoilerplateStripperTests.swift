//
//  ArticleLocaleBoilerplateStripperTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("ArticleLocaleBoilerplateStripper")
struct ArticleLocaleBoilerplateStripperTests {
    private let stripper = ArticleLocaleBoilerplateStripper()

    @Test
    func unknownLanguageLeavesHTMLUntouched() {
        let html = "<p>Riproduzione riservata</p><p>real article</p>"
        #expect(stripper.stripping(html: html, language: nil).contains("Riproduzione"))
        #expect(stripper.stripping(html: html, language: "ja").contains("Riproduzione"))
    }

    @Test
    func italianStripsCopyrightAndRelatedAndNewsletter() {
        let html = """
        <p>Roma è la capitale.</p>
        <p>Leggi anche: altro articolo</p>
        <p>Iscriviti alla nostra newsletter</p>
        <p>Riproduzione riservata © Copyright ANSA</p>
        """
        let output = stripper.stripping(html: html, language: "it")
        #expect(output.contains("Roma è la capitale"))
        #expect(output.contains("Leggi anche") == false)
        #expect(output.contains("newsletter") == false)
        #expect(output.contains("Riproduzione") == false)
    }

    @Test
    func englishStripsAllRightsReservedAndShare() {
        let html = """
        <p>Real article paragraph.</p>
        <p>Share this article on Twitter</p>
        <p>All rights reserved</p>
        <p>Subscribe to our newsletter for daily updates</p>
        """
        let output = stripper.stripping(html: html, language: "en")
        #expect(output.contains("Real article"))
        #expect(output.contains("Share this article") == false)
        #expect(output.contains("All rights reserved") == false)
        #expect(output.contains("Subscribe to our newsletter") == false)
    }

    @Test
    func localeNormalizationCollapsesRegionTags() {
        let html = "<p>Leggi anche: altro</p><p>real</p>"
        // it-IT and IT_it should both behave like "it".
        #expect(stripper.stripping(html: html, language: "it-IT").contains("Leggi") == false)
        #expect(stripper.stripping(html: html, language: "IT_it").contains("Leggi") == false)
    }

    @Test
    func articlesWithoutPatternsPassThroughUnchanged() {
        let html = "<p>Una giornata qualunque a Roma.</p>"
        let output = stripper.stripping(html: html, language: "it")
        #expect(output.contains("Una giornata qualunque a Roma"))
    }

    @Test
    func patternsAreCaseInsensitive() {
        let html = "<p>LEGGI ANCHE: pezzo correlato</p><p>real</p>"
        let output = stripper.stripping(html: html, language: "it")
        #expect(output.contains("LEGGI ANCHE") == false)
        #expect(output.contains("real"))
    }
}
