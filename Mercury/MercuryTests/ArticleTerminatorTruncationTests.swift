//
//  ArticleTerminatorTruncationTests.swift
//  MercuryTests
//
//  Created by Codex on 01/07/26.
//

import Foundation
import Testing
@testable import Mercury

/// Guards issue #81 — the Italian article terminator ("Riproduzione
/// riservata") should cut everything downstream (newsletter CTAs,
/// related-article grids, subscribe prompts) before the boilerplate
/// remover ever sees them.
@Suite("ArticleContentEnrichmentService.truncatedAtTerminator")
struct ArticleTerminatorTruncationTests {
    @Test
    func italianTerminatorCutsDownstreamChrome() {
        let html = """
        <article>
          <p>Il presidente ha dichiarato oggi che il piano è approvato.</p>
          <p>Riproduzione riservata</p>
          <div class="newsletter"><h3>Iscriviti alla newsletter</h3></div>
          <div class="related"><a href="#">Leggi anche</a></div>
        </article>
        """
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        #expect(out.contains("piano è approvato"))
        #expect(out.contains("Iscriviti alla newsletter") == false)
        #expect(out.contains("Leggi anche") == false)
    }

    @Test
    func italianTerminatorCaseInsensitiveAndCatchesCopyrightGlyph() {
        let html = "<p>Corpo</p><p>© RIPRODUZIONE RISERVATA</p><p>chrome</p>"
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        #expect(out.contains("Corpo"))
        #expect(out.contains("chrome") == false)
    }

    @Test
    func unknownLanguagePassesThrough() {
        let html = "<p>Body</p><p>Riproduzione riservata</p><p>Chrome</p>"
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "fr"
        )
        #expect(out == html)
    }

    @Test
    func nilLanguagePassesThrough() {
        let html = "<p>Body</p><p>Riproduzione riservata</p><p>Chrome</p>"
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: nil
        )
        #expect(out == html)
    }

    @Test
    func noTerminatorPresentPassesThrough() {
        let html = "<p>Un articolo che non termina con la formula standard.</p>"
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        #expect(out == html)
    }

    @Test
    func terminatorInsideScriptBlockIsIgnored() {
        // ANSA embeds "RIPRODUZIONE RISERVATA" inside a JS image-slider
        // config near the top of the page. That MUST NOT trigger the
        // truncation — the real body would be lost.
        let html = """
        <script>
          var caption = "Sinner-Borges <small>RIPRODUZIONE RISERVATA &copy; ANSA/EPA</small>";
        </script>
        <article>
          <p>Il tennista italiano supera l'avversario portoghese in tre set combattuti.</p>
          <p>Riproduzione riservata</p>
          <div class="newsletter">Iscriviti alla newsletter</div>
        </article>
        """
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        // Real body survived, JS-embedded terminator ignored.
        #expect(out.contains("tennista italiano"))
        // Chrome downstream of the visible terminator was cut.
        #expect(out.contains("Iscriviti alla newsletter") == false)
        // Script preserved (we don't strip it here — the boilerplate
        // remover / block parser will).
        #expect(out.contains("Sinner-Borges"))
    }

    @Test
    func terminatorInsideStyleBlockIsIgnored() {
        let html = """
        <style>/* Riproduzione riservata legacy CSS class */</style>
        <p>Body content that must stay in the output completely.</p>
        <p>Riproduzione riservata</p>
        <p>Chrome downstream.</p>
        """
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        #expect(out.contains("Body content"))
        #expect(out.contains("Chrome downstream") == false)
    }
}
