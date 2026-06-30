//
//  ArticleHTMLSanitizerTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("ArticleHTMLSanitizer")
struct ArticleHTMLSanitizerTests {
    private let sanitizer = ArticleHTMLSanitizer()

    @Test
    func stripsInlineEventHandlerAttributes() {
        let input = "<p onclick=\"alert('x')\">hello</p>"
        let output = sanitizer.sanitize(input)
        #expect(output.contains("onclick") == false)
        #expect(output.contains("hello"))
    }

    @Test
    func stripsSingleQuotedEventHandlerAttributes() {
        let input = "<img onerror='steal()' src='real.png'>"
        let output = sanitizer.sanitize(input)
        #expect(output.contains("onerror") == false)
        #expect(output.contains("real.png"))
    }

    @Test
    func dropsJavaScriptURLHrefAttribute() {
        let input = "<a href=\"javascript:alert(1)\">click</a>"
        let output = sanitizer.sanitize(input)
        #expect(output.contains("javascript:") == false)
        #expect(output.contains("click"))
    }

    @Test
    func dropsJavaScriptURLSrcAttribute() {
        let input = "<iframe src='javascript:evil()'></iframe>"
        let output = sanitizer.sanitize(input)
        #expect(output.contains("javascript:") == false)
    }

    @Test
    func removesTrackingPixelsByWidth() {
        let input = "<p>before</p><img src=\"track.gif\" width=\"1\" height=\"1\"><p>after</p>"
        let output = sanitizer.sanitize(input)
        #expect(output.contains("track.gif") == false)
        #expect(output.contains("before"))
        #expect(output.contains("after"))
    }

    @Test
    func preservesLegitimateImages() {
        let input = "<img src=\"hero.jpg\" width=\"800\" height=\"400\" alt=\"hero\">"
        let output = sanitizer.sanitize(input)
        #expect(output.contains("hero.jpg"))
        #expect(output.contains("alt=\"hero\""))
    }

    @Test
    func preservesPlainHTML() {
        let input = "<h2>Title</h2><p>Paragraph with <a href=\"https://example.com\">link</a>.</p>"
        let output = sanitizer.sanitize(input)
        #expect(output == input)
    }
}
