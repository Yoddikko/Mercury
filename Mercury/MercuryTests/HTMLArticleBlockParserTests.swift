//
//  HTMLArticleBlockParserTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

/// Golden fixtures exercising `HTMLArticleBlockParser` against the
/// structural shapes the native renderer (issue #59) must recognise.
/// Each fixture asserts the *sequence of block kinds* the parser emits;
/// the exact `AttributedString` rendering is intentionally not pinned
/// because inline attribute representation changes across SDK versions
/// and would make these tests brittle.
@Suite("HTMLArticleBlockParser")
struct HTMLArticleBlockParserTests {
    private let parser = HTMLArticleBlockParser()

    @Test
    func emptyInputProducesNoBlocks() {
        #expect(parser.parse("").isEmpty)
        #expect(parser.parse("   ").isEmpty)
    }

    @Test
    func paragraphOnly() {
        let blocks = parser.parse("<p>Hello world.</p>")
        #expect(blocks.count == 1)
        if case let .paragraph(text) = blocks[0] {
            #expect(String(text.characters) == "Hello world.")
        } else {
            Issue.record("Expected paragraph, got \(blocks[0])")
        }
    }

    @Test
    func headingsParagraphList() {
        let html = """
        <h2>Section</h2>
        <p>Intro paragraph.</p>
        <ul>
          <li>First</li>
          <li>Second</li>
        </ul>
        """
        let blocks = parser.parse(html)
        let kinds = blocks.map(Self.kind)
        #expect(kinds == ["heading", "paragraph", "list"])

        if case let .heading(level, _) = blocks[0] {
            #expect(level == 2)
        } else {
            Issue.record("Expected heading, got \(blocks[0])")
        }
        if case let .list(ordered, items) = blocks[2] {
            #expect(ordered == false)
            #expect(items.count == 2)
        } else {
            Issue.record("Expected list, got \(blocks[2])")
        }
    }

    @Test
    func figureWithImageAndCaption() {
        let html = """
        <figure>
          <img src="https://example.com/hero.jpg" alt="hero">
          <figcaption>A picture worth a thousand words.</figcaption>
        </figure>
        """
        let blocks = parser.parse(html)
        #expect(blocks.count == 1)
        if case let .image(url, alt) = blocks[0] {
            #expect(url.absoluteString == "https://example.com/hero.jpg")
            #expect(alt == "hero")
        } else {
            Issue.record("Expected image, got \(blocks[0])")
        }
    }

    @Test
    func blockquoteAndCode() {
        let html = """
        <blockquote>To be, or not to be.</blockquote>
        <pre><code class="language-swift">print("hi")</code></pre>
        """
        let blocks = parser.parse(html)
        #expect(blocks.map(Self.kind) == ["quote", "code"])
        if case let .code(body, lang) = blocks[1] {
            #expect(body == "print(\"hi\")")
            #expect(lang == "swift")
        } else {
            Issue.record("Expected code, got \(blocks[1])")
        }
    }

    @Test
    func inlineLinkSurvivesInsideParagraph() {
        let html = "<p>Visit <a href=\"https://example.com\">our site</a> for details.</p>"
        let blocks = parser.parse(html)
        #expect(blocks.count == 1)
        if case let .paragraph(text) = blocks[0] {
            #expect(String(text.characters).contains("our site"))
            let hasLink = text.runs.contains { run in
                run.link?.absoluteString == "https://example.com"
            }
            #expect(hasLink)
        } else {
            Issue.record("Expected paragraph, got \(blocks[0])")
        }
    }

    @Test
    func nestedContainerContentSurfacesAsBlocks() {
        let html = """
        <article>
          <div class="body">
            <h3>Inner</h3>
            <p>Some text.</p>
          </div>
        </article>
        """
        let blocks = parser.parse(html)
        #expect(blocks.map(Self.kind) == ["heading", "paragraph"])
    }

    @Test
    func brokenHTMLDoesNotCrash() {
        let html = "<p>Half opened <strong>strong"
        let blocks = parser.parse(html)
        // We don't care which exact kind comes out, only that we get at
        // least one block and the parser does not throw or crash.
        #expect(blocks.isEmpty == false)
    }

    @Test
    func relativeImageSrcIsResolvedAgainstBaseURL() {
        let html = "<img src=\"/wp-content/uploads/hero.jpg\" alt=\"h\">"
        let base = URL(string: "https://www.example.com/articles/story-123/")!
        let blocks = parser.parse(html, baseURL: base)
        #expect(blocks.count == 1)
        if case let .image(url, _) = blocks[0] {
            #expect(url.absoluteString == "https://www.example.com/wp-content/uploads/hero.jpg")
        } else {
            Issue.record("Expected image, got \(blocks[0])")
        }
    }

    @Test
    func relativeAnchorHrefIsResolvedAgainstBaseURL() {
        let html = "<p>See <a href=\"/altro/pagina\">altro</a>.</p>"
        let base = URL(string: "https://www.example.com/story/")!
        let blocks = parser.parse(html, baseURL: base)
        guard case let .paragraph(text) = blocks[0] else {
            Issue.record("Expected paragraph, got \(blocks[0])")
            return
        }
        let hasAbsoluteLink = text.runs.contains { run in
            run.link?.absoluteString == "https://www.example.com/altro/pagina"
        }
        #expect(hasAbsoluteLink)
    }

    @Test
    func absoluteImageSrcIsPreserved() {
        let html = "<img src=\"https://cdn.example.com/pic.jpg\" alt=\"p\">"
        let blocks = parser.parse(html, baseURL: URL(string: "https://other.com/")!)
        if case let .image(url, _) = blocks[0] {
            #expect(url.absoluteString == "https://cdn.example.com/pic.jpg")
        } else {
            Issue.record("Expected image, got \(blocks[0])")
        }
    }

    @Test
    func pictureElementSurfacesFallbackImage() {
        // Modern outlets wrap responsive imagery in `<picture>` with
        // `<source>` variants plus a fallback `<img>`. The parser
        // must surface the fallback `<img>` as an image block rather
        // than dropping the whole picture element (which was the
        // silent bug before this test).
        let html = """
        <picture>
          <source srcset="hero.webp" type="image/webp">
          <img src="https://cdn.example.com/hero.jpg" alt="fallback">
        </picture>
        """
        let blocks = parser.parse(html)
        #expect(blocks.count == 1)
        if case let .image(url, alt) = blocks[0] {
            #expect(url.absoluteString == "https://cdn.example.com/hero.jpg")
            #expect(alt == "fallback")
        } else {
            Issue.record("Expected image from <picture>, got \(blocks[0])")
        }
    }

    @Test
    func imageWithOnlySrcsetFallsBackToFirstCandidate() {
        // Modern responsive templates ship <img srcset="…"> with no
        // `src` — the native reader previously dropped these entirely.
        // Take the first URL from the srcset list.
        let html = """
        <p>Article body.</p>
        <img srcset="https://cdn.ex/photo-800w.jpg 800w, https://cdn.ex/photo-1600w.jpg 1600w" alt="lead">
        """
        let blocks = HTMLArticleBlockParser().parse(html)
        let images = blocks.compactMap { block -> URL? in
            if case let .image(url, _) = block { return url }
            return nil
        }
        #expect(images.count == 1)
        #expect(images.first?.absoluteString == "https://cdn.ex/photo-800w.jpg")
    }

    @Test
    func figureWithSourceSrcsetOnlyEmitsImage() {
        // Il Post-style responsive <picture> with no fallback <img>.
        let html = """
        <figure>
          <picture>
            <source srcset="https://cdn.ex/hero-1600w.webp 1600w" type="image/webp">
            <source srcset="https://cdn.ex/hero-800w.jpg 800w" type="image/jpeg">
          </picture>
          <figcaption>La didascalia dell'immagine.</figcaption>
        </figure>
        """
        let blocks = HTMLArticleBlockParser().parse(html)
        let firstImage = blocks.compactMap { block -> (URL, String?)? in
            if case let .image(url, alt) = block { return (url, alt) }
            return nil
        }.first
        #expect(firstImage?.0.absoluteString == "https://cdn.ex/hero-1600w.webp")
        #expect(firstImage?.1 == "La didascalia dell'immagine.")
    }

    // MARK: - Helpers

    private static func kind(_ block: ArticleBlock) -> String {
        switch block {
        case .paragraph: return "paragraph"
        case .heading: return "heading"
        case .image: return "image"
        case .list: return "list"
        case .quote: return "quote"
        case .code: return "code"
        }
    }
}
