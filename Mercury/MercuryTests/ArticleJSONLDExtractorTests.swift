//
//  ArticleJSONLDExtractorTests.swift
//  MercuryTests
//
//  Created by Claude on 03/07/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("JSON-LD article extraction (issue #98)")
struct ArticleJSONLDExtractorTests {
    private let extractor = ArticleJSONLDExtractor()

    private func page(withJSONLD blocks: String...) -> String {
        let scripts = blocks
            .map { "<script type=\"application/ld+json\">\($0)</script>" }
            .joined(separator: "\n")
        return """
        <html><head>\(scripts)</head>
        <body><article><p>DOM body text</p></article></body></html>
        """
    }

    @Test func extractsNewsArticleBodyFromObjectRoot() {
        let html = page(withJSONLD: """
        {"@context": "https://schema.org", "@type": "NewsArticle",
         "headline": "Titolo di prova",
         "articleBody": "Primo paragrafo del corpo.\\nSecondo paragrafo del corpo."}
        """)
        let node = extractor.articleNode(fromRawHTML: html)
        #expect(node?.articleBody == "Primo paragrafo del corpo.\nSecondo paragrafo del corpo.")
        #expect(node?.headline == "Titolo di prova")
        #expect(node?.isAccessibleForFree == nil)
    }

    @Test func extractsFromGraphAndArrayRoots() {
        let graphHTML = page(withJSONLD: """
        {"@context": "https://schema.org", "@graph": [
          {"@type": "BreadcrumbList", "itemListElement": []},
          {"@type": "ReportageNewsArticle", "articleBody": "Corpo nel graph."}
        ]}
        """)
        #expect(extractor.articleNode(fromRawHTML: graphHTML)?.articleBody == "Corpo nel graph.")

        // RaiNews ships a root-level ARRAY of nodes in one script block.
        let arrayHTML = page(withJSONLD: """
        [{"@type": "NewsArticle", "articleBody": "Corpo nell'array."},
         {"@type": "VideoObject", "name": "clip"}]
        """)
        #expect(extractor.articleNode(fromRawHTML: arrayHTML)?.articleBody == "Corpo nell'array.")
    }

    @Test func acceptsTypeArraysAndArticleFamilySuffix() {
        let html = page(withJSONLD: """
        {"@type": ["Article", "MedicalWebPage"], "articleBody": "Corpo tipizzato in array."}
        """)
        #expect(extractor.articleNode(fromRawHTML: html)?.articleBody == "Corpo tipizzato in array.")
    }

    @Test func skipsNonArticleNodesAndBodylessArticles() {
        let html = page(withJSONLD: """
        {"@type": "BreadcrumbList", "articleBody": "should not match a non-article type"}
        """, """
        {"@type": "NewsArticle", "headline": "Solo titolo, niente corpo"}
        """)
        #expect(extractor.articleNode(fromRawHTML: html) == nil)
    }

    @Test func skipsMalformedBlockAndUsesNextOne() {
        let html = page(withJSONLD: """
        {"@type": "NewsArticle", "articleBody": "trailing garbage"
        """, """
        {"@type": "NewsArticle", "articleBody": "Corpo valido nel secondo blocco."}
        """)
        #expect(extractor.articleNode(fromRawHTML: html)?.articleBody == "Corpo valido nel secondo blocco.")
    }

    @Test func normalizesIsAccessibleForFreeEncodings() {
        // Repubblica: string "False". TGCom24: bare boolean. Others:
        // schema.org URL form.
        let stringFalse = page(withJSONLD: """
        {"@type": "NewsArticle", "articleBody": "x", "isAccessibleForFree": "False"}
        """)
        #expect(extractor.articleNode(fromRawHTML: stringFalse)?.isAccessibleForFree == false)

        let boolTrue = page(withJSONLD: """
        {"@type": "NewsArticle", "articleBody": "x", "isAccessibleForFree": true}
        """)
        #expect(extractor.articleNode(fromRawHTML: boolTrue)?.isAccessibleForFree == true)

        let urlForm = page(withJSONLD: """
        {"@type": "NewsArticle", "articleBody": "x", "isAccessibleForFree": "https://schema.org/False"}
        """)
        #expect(extractor.articleNode(fromRawHTML: urlForm)?.isAccessibleForFree == false)
    }

    // MARK: - Corpus fixtures

    @Test func corpusFixturesWithJSONLDBodyExtract() throws {
        // RaiNews + Il Messaggero both embed the full body in JSON-LD
        // (2026-07-03 corpus survey). Pin them so a regression in the
        // script scan surfaces against real-world markup.
        for (fixture, expectedFragment) in [
            ("rainews", "kallas"),
            ("ilmessaggero", "bastoni")
        ] {
            let html = try Self.loadFixture(fixture)
            let node = extractor.articleNode(fromRawHTML: html)
            #expect(node != nil, "[\(fixture)] expected a JSON-LD article node")
            let words = (node?.articleBody ?? "")
                .split { $0.isWhitespace || $0.isNewline }
                .count
            #expect(words >= 80, "[\(fixture)] JSON-LD body unexpectedly short: \(words) words")
            #expect(
                node?.articleBody.lowercased().contains(expectedFragment) == true,
                "[\(fixture)] JSON-LD body does not mention '\(expectedFragment)'"
            )
        }
    }

    @Test func ansaFixtureHasNoJSONLDBody() throws {
        // ANSA uses microdata (`itemprop="articleBody"`), not JSON-LD —
        // the fast path must return nil so the DOM pipeline (rules +
        // Readability) handles ANSA.
        let html = try Self.loadFixture("ansa-consentless-sinner")
        #expect(extractor.articleNode(fromRawHTML: html) == nil)
    }

    // MARK: - Fast-path building blocks on the enrichment service

    @Test func paragraphsHTMLSplitsOnNewlinesAndEscapes() {
        let html = ArticleContentEnrichmentService.paragraphsHTML(
            fromPlainText: "Primo <b>paragrafo</b> & co.\n\nSecondo paragrafo."
        )
        #expect(html == "<p>Primo &lt;b&gt;paragrafo&lt;/b&gt; &amp; co.</p>\n<p>Secondo paragrafo.</p>")
    }

    @Test func plainTextTerminatorCutRespectsLanguageAndCopyrightGlyph() {
        let body = "Corpo dell'articolo. © RIPRODUZIONE RISERVATA Newsletter iscriviti qui."
        let cutIT = ArticleContentEnrichmentService.truncatedTextAtTerminator(text: body, language: "it")
        #expect(cutIT == "Corpo dell'articolo.")

        // Unknown language passes through.
        let cutDE = ArticleContentEnrichmentService.truncatedTextAtTerminator(text: body, language: "de")
        #expect(cutDE == body)

        // Bare "riproduzione riservata" without the © glyph is an
        // image-credit caption, not a terminator — must not cut.
        let caption = "Papa Leone - RIPRODUZIONE RISERVATA e poi il corpo continua."
        #expect(ArticleContentEnrichmentService.truncatedTextAtTerminator(text: caption, language: "it") == caption)
    }

    // MARK: - Fixture loader

    private static func loadFixture(_ name: String) throws -> String {
        let url = ItalianDistillationFixturesTests.fixturesDirectory
            .appendingPathComponent("\(name).html")
        let data = try Data(contentsOf: url)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}
