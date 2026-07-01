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
          <p>Riproduzione riservata © Copyright</p>
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
        let html = "<p>Body</p><p>Riproduzione riservata © Copyright</p><p>Chrome</p>"
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "fr"
        )
        #expect(out == html)
    }

    @Test
    func nilLanguagePassesThrough() {
        let html = "<p>Body</p><p>Riproduzione riservata © Copyright</p><p>Chrome</p>"
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
    func bareTerminatorInImageCaptionDoesNotCutTheArticle() {
        // Italian outlets (ANSA, Corriere) use "Riproduzione riservata"
        // WITHOUT the copyright glyph as an image-credit caption
        // ("Papa Leone - RIPRODUZIONE RISERVATA") that sits near the
        // TOP of the page. The real article-ending line always carries
        // "©". Truncation must require the glyph so we don't chop the
        // article at the hero image credit.
        let html = """
        <figure>
          <img alt="Papa Leone - RIPRODUZIONE RISERVATA">
          <p class="image-caption">Papa Leone - RIPRODUZIONE RISERVATA</p>
        </figure>
        <p>Corpo dell'articolo che deve rimanere intatto per l'intero contenuto.</p>
        """
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        // Full article body survives — the bare marker in the caption
        // did NOT trigger the truncation.
        #expect(out.contains("Corpo dell'articolo"))
    }

    @Test
    func terminatorInsideFigureBlockIsIgnored() {
        // Even when the caption text technically includes the copyright
        // glyph, if it sits inside a <figure>, we should treat it as
        // image chrome, not the article terminator.
        let html = """
        <figure>
          <img>
          <figcaption>Foto della manifestazione — Riproduzione riservata © Reuters</figcaption>
        </figure>
        <p>Corpo dell'articolo che deve rimanere intatto.</p>
        <p>Riproduzione riservata © Copyright ANSA</p>
        <p>Newsletter chrome</p>
        """
        let out = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: html,
            language: "it"
        )
        #expect(out.contains("Corpo dell'articolo"))
        // The real terminator in the article-copyright <p> did trigger.
        #expect(out.contains("Newsletter chrome") == false)
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
          <p>Riproduzione riservata © Copyright</p>
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
        <style>/* Riproduzione riservata © Copyright legacy CSS class */</style>
        <p>Body content that must stay in the output completely.</p>
        <p>Riproduzione riservata © Copyright</p>
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
