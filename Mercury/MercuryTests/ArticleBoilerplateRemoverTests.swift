//
//  ArticleBoilerplateRemoverTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("ArticleBoilerplateRemover")
struct ArticleBoilerplateRemoverTests {
    private let remover = ArticleBoilerplateRemover()

    @Test
    func emptyInputPassesThrough() {
        #expect(remover.cleaning("") == "")
    }

    @Test
    func plainArticleParagraphsArePreserved() {
        let html = """
        <article>
          <p>Roma è la capitale d'Italia. Una giornata qualunque.</p>
          <p>Il primo paragrafo continua qui con altre informazioni rilevanti.</p>
        </article>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("Roma è la capitale"))
        #expect(output.contains("primo paragrafo"))
    }

    @Test
    func stripsCookieConsentContainer() {
        let html = """
        <div class="cookie-banner gdpr-consent"><p>Accept cookies to continue</p></div>
        <p>Real article paragraph that is long enough to survive.</p>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("Accept cookies") == false)
        #expect(output.contains("Real article paragraph"))
    }

    @Test
    func stripsShareAndRelatedContainers() {
        let html = """
        <article>
          <div class="article-share article-widget"><a href="#">Tweet</a><a href="#">Share</a></div>
          <p>Article body sentence one with enough length here.</p>
          <aside class="article-related article-widget"><a href="/x">related 1</a><a href="/y">related 2</a></aside>
        </article>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("article-share") == false)
        #expect(output.contains("article-related") == false)
        #expect(output.contains("Article body sentence one"))
    }

    @Test
    func stripsNewsletterAndFooter() {
        let html = """
        <div class="newsletter-section">
          <p>Iscriviti alla newsletter</p>
        </div>
        <p>Body paragraph kept here with sufficient length.</p>
        <div class="wall-footer">
          <p>Footer content removed</p>
        </div>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("newsletter-section") == false)
        #expect(output.contains("wall-footer") == false)
        #expect(output.contains("Footer content removed") == false)
        #expect(output.contains("Body paragraph kept"))
    }

    @Test
    func stripsOutbrainTaboolaWidgets() {
        let html = """
        <div class="article-outbrain"><a href="/a">x</a><a href="/b">y</a></div>
        <p>Article paragraph that we want to keep here.</p>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("article-outbrain") == false)
        #expect(output.contains("Article paragraph"))
    }

    @Test
    func stripsHighLinkDensityContainer() {
        let html = """
        <ul>
          <li><a href="/1">First link</a></li>
          <li><a href="/2">Second link</a></li>
          <li><a href="/3">Third link</a></li>
        </ul>
        <p>Article body paragraph with enough length to survive the floor.</p>
        """
        let output = remover.cleaning(html)
        // Without negative class match, the <ul> survives the class
        // strip but is killed by the link-density filter.
        #expect(output.contains("First link") == false)
        #expect(output.contains("Article body paragraph"))
    }

    @Test
    func keepsContainerWithModerateLinkDensity() {
        let html = """
        <div>
          <p>Substantial paragraph with mostly plain text and only one inline <a href="/x">link</a> in it. Plenty of words remain after the link to keep the ratio low.</p>
        </div>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("Substantial paragraph"))
        #expect(output.contains("link"))
    }

    @Test
    func dropsShortPunctuationlessParagraph() {
        let html = """
        <p>Condividi</p>
        <p>Real article sentence with proper punctuation here.</p>
        """
        let output = remover.cleaning(html)
        #expect(output.contains("Condividi") == false)
        #expect(output.contains("Real article sentence"))
    }

    @Test
    func keepsShortParagraphWithPunctuation() {
        let html = "<p>Sì.</p><p>Body paragraph that is long enough on its own.</p>"
        let output = remover.cleaning(html)
        // "Sì." survives because it has terminal punctuation.
        #expect(output.contains("Sì."))
    }

    @Test
    func brokenHTMLDoesNotCrash() {
        // The remover must recover gracefully on malformed input. The
        // specific surviving content is not pinned — only that the call
        // does not throw and produces a string. SwiftSoup auto-closes
        // tags, then the heuristics may legitimately strip everything.
        let html = "<p>Half opened tag with enough words to survive the length floor for sure.<strong>strong"
        let output = remover.cleaning(html)
        #expect(output.contains("Half opened tag"))
    }
}
