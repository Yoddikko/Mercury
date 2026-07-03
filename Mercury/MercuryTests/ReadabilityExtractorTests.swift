//
//  ReadabilityExtractorTests.swift
//  MercuryTests
//
//  Created by Claude on 03/07/26.
//

import Foundation
import Testing
import WebKit
@testable import Mercury

/// Exercises the hidden-webview Readability stage (issue #98).
/// WKWebView requires the simulator test host, which is already how
/// this suite runs.
@Suite("Readability extractor")
struct ReadabilityExtractorTests {
    /// A minimal but realistic article page: header/nav chrome, a long
    /// multi-paragraph body, and footer junk. Readability must return
    /// the body paragraphs and drop the chrome.
    private static let articleHTML: String = {
        let paragraphs = (1...8).map { index in
            """
            <p>Paragrafo \(index) del corpo articolo. Questa frase esiste per dare
            a Readability abbastanza testo da riconoscere il contenuto principale
            della pagina come un vero articolo di giornale con più periodi.</p>
            """
        }.joined(separator: "\n")
        return """
        <html><head><title>Titolo di prova</title></head><body>
        <nav><ul><li><a href="/home">Home</a></li><li><a href="/sport">Sport</a></li></ul></nav>
        <header><div class="menu">Menu principale del sito</div></header>
        <article>
        <h1>Titolo di prova dell'articolo</h1>
        \(paragraphs)
        </article>
        <footer><div>Contatti | Privacy | Cookie policy</div></footer>
        </body></html>
        """
    }()

    @Test @MainActor
    func extractsBodyAndDropsChrome() async {
        let extractor = ReadabilityExtractor()
        let content = await extractor.extractContent(fromHTML: Self.articleHTML)

        let plain = ArticleBoilerplateRemover.plainText(from: content ?? "").lowercased()
        #expect(content != nil)
        #expect(plain.contains("paragrafo 8 del corpo articolo"))
        #expect(plain.contains("menu principale del sito") == false)
        #expect(plain.contains("cookie policy") == false)
    }

    @Test @MainActor
    func returnsNilOnGarbageInput() async {
        let extractor = ReadabilityExtractor()
        let content = await extractor.extractContent(fromHTML: "<div>ciao</div>")
        #expect(content == nil)
    }

    @Test @MainActor
    func returnsNilOnEmptyInput() async {
        let extractor = ReadabilityExtractor()
        let content = await extractor.extractContent(fromHTML: "   ")
        #expect(content == nil)
    }

    @Test
    func stripsExecutableBlocks() {
        let html = """
        <p>ok</p><script>alert(1)</script><noscript>no js</noscript>
        <iframe src="https://example.com/embed"></iframe><p>fine</p>
        """
        let cleaned = ReadabilityExtractor.strippingExecutableBlocks(from: html)
        #expect(cleaned.contains("<script") == false)
        #expect(cleaned.contains("<noscript") == false)
        #expect(cleaned.contains("<iframe") == false)
        #expect(cleaned.contains("<p>ok</p>"))
        #expect(cleaned.contains("<p>fine</p>"))
    }

    @Test
    func disabledStageIsNoOp() async {
        let stage = ReadabilityStage(isEnabled: false)
        let result = await stage.extract(html: Self.articleHTML, requestID: nil)
        #expect(result == nil)
    }
}
