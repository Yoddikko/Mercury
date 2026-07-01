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
    func normalizedKeyIsCaseInsensitiveAndDropsExtension() {
        // The normalized key is used to compare "same asset across
        // formats" — hero.jpg and hero.webp are the same asset — so
        // the extension is intentionally stripped (issue #81).
        let key = ArticleImageDeduplicator.normalizedKey(of: "HTTPS://CDN.EX/Path/Hero.JPG?Q=1")
        #expect(key == "hero")
    }

    @Test
    func normalizedKeyStripsCommonCDNSizeSuffixes() {
        // CDN-resized variants of the same asset all collapse to the
        // same key so the dedup pass catches them.
        let base = ArticleImageDeduplicator.normalizedKey(of: "https://cdn.ex/hero.jpg")
        #expect(ArticleImageDeduplicator.normalizedKey(of: "https://cdn.ex/hero-1024x768.jpg") == base)
        #expect(ArticleImageDeduplicator.normalizedKey(of: "https://cdn.ex/hero-800w.jpg") == base)
        #expect(ArticleImageDeduplicator.normalizedKey(of: "https://cdn.ex/hero@2x.jpg") == base)
        #expect(ArticleImageDeduplicator.normalizedKey(of: "https://cdn.ex/hero-mobile.jpg") == base)
    }

    @Test
    func normalizedKeyIsNilForEmptyOrTrailingSlash() {
        #expect(ArticleImageDeduplicator.normalizedKey(of: "") == nil)
    }

    @Test
    func dedupCatchesPictureSourceSrcsetVariantsOfTheHero() {
        // <picture> declares the hero as multiple <source srcset>
        // entries — the dedup must nuke the whole <picture> even when
        // none of the <source>s exactly match the hero URL.
        let html = """
        <picture>
          <source srcset="https://cdn.ex/hero-800w.jpg 800w, https://cdn.ex/hero-1600w.jpg 1600w">
          <source srcset="https://cdn.ex/hero@2x.jpg 2x">
          <img src="https://cdn.ex/hero.jpg">
        </picture>
        <p>body content</p>
        """
        let output = dedup.dedupingHero(
            in: html,
            heroImageURLString: "https://other.cdn.ex/promo/hero-1024x768.jpg?crop=1"
        )
        #expect(output.contains("hero-") == false)
        #expect(output.contains("body content"))
    }

    @Test
    func dedupCatchesImgWithSrcsetOnly() {
        let html = "<img srcset=\"https://cdn.ex/hero-800w.jpg 800w, https://cdn.ex/hero-1600w.jpg 1600w\">"
        let output = dedup.dedupingHero(in: html, heroImageURLString: "https://cdn.ex/hero.jpg")
        #expect(output.contains("hero-") == false)
    }
}
