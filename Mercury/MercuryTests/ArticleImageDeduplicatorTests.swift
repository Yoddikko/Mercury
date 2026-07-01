//
//  ArticleImageDeduplicatorTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("ArticleImageDeduplicator")
struct ArticleImageDeduplicatorTests {
    private let dedup = ArticleImageDeduplicator()

    @Test
    func nilHeroReturnsHTMLUntouched() {
        let html = "<p>before</p><img src=\"https://cdn.ex/hero.jpg\"><p>after</p>"
        #expect(dedup.dedupingHero(in: html, heroImageURLString: nil).contains("hero.jpg"))
    }

    @Test
    func dropsBodyImageMatchingHeroBasename() {
        let html = "<p>before</p><img src=\"https://cdn.example.com/path/hero.jpg\"><p>after</p>"
        let output = dedup.dedupingHero(in: html, heroImageURLString: "https://other.com/img/hero.jpg")
        #expect(output.contains("hero.jpg") == false)
        #expect(output.contains("before"))
        #expect(output.contains("after"))
    }

    @Test
    func ignoresQueryStringDifferencesWhenComparing() {
        let html = "<img src=\"https://cdn.ex/img/photo.jpg?w=1024&q=80\">"
        let output = dedup.dedupingHero(in: html, heroImageURLString: "https://cdn.ex/img/photo.jpg?w=320")
        #expect(output.contains("photo.jpg") == false)
    }

    @Test
    func preservesNonHeroImages() {
        let html = """
        <img src="https://cdn.ex/hero.jpg">
        <p>middle</p>
        <img src="https://cdn.ex/inline-other.png">
        """
        let output = dedup.dedupingHero(in: html, heroImageURLString: "https://cdn.ex/hero.jpg")
        #expect(output.contains("hero.jpg") == false)
        #expect(output.contains("inline-other.png"))
    }

    @Test
    func dropsWrappingFigureWhenImageMatches() {
        let html = """
        <figure><img src="https://cdn.ex/hero.jpg"><figcaption>cap</figcaption></figure>
        <p>body</p>
        """
        let output = dedup.dedupingHero(in: html, heroImageURLString: "https://cdn.ex/hero.jpg")
        #expect(output.contains("hero.jpg") == false)
        #expect(output.contains("figcaption") == false)
        #expect(output.contains("body"))
    }

    @Test
    func basenameNormalizationIsCaseInsensitive() {
        let basename = ArticleImageDeduplicator.normalizedBasename(of: "HTTPS://CDN.EX/Path/Hero.JPG?Q=1")
        #expect(basename == "hero.jpg")
    }

    @Test
    func invalidURLReturnsNilBasename() {
        #expect(ArticleImageDeduplicator.normalizedBasename(of: "") == nil)
        // A bare string with no path/last segment can't yield a basename.
        #expect(ArticleImageDeduplicator.normalizedBasename(of: "https://example.com/") == nil)
    }
}
