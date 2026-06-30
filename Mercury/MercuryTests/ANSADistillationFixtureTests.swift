//
//  ANSADistillationFixtureTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

/// Integration test for the full distillation pipeline against the
/// real ANSA article HTML the user surfaced as the canonical failing
/// case in issue #66.
///
/// The fixture lives outside the test target (it's a research artifact
/// under `docs/rss/research/distiller-fixtures/`) so we resolve its
/// path via `#file` rather than `Bundle.module` — that keeps the
/// fixture co-located with the rest of the research material without
/// pbxproj changes to include it as a test resource.
@Suite("ANSA distillation fixture")
struct ANSADistillationFixtureTests {
    @Test
    func ansaArticleIsStrippedOfChrome() throws {
        let html = try Self.loadFixture()

        let sanitizer = ArticleHTMLSanitizer()
        let remover = ArticleBoilerplateRemover()
        let imageDedup = ArticleImageDeduplicator()
        let localeStripper = ArticleLocaleBoilerplateStripper()

        // Mirrors `ArticleContentEnrichmentService.distill` — the
        // pipeline runs on the FULL fetched page; the extractor is no
        // longer the selector. Readability-style heuristics in the
        // boilerplate remover find the article inside the noise.
        let sanitized = sanitizer.sanitize(html)
        let withoutBoilerplate = remover.cleaning(sanitized)
        let withoutHero = imageDedup.dedupingHero(
            in: withoutBoilerplate,
            heroImageURLString: nil  // hero fed in production from RSS/og:image
        )
        let final = localeStripper.stripping(html: withoutHero, language: "it")

        let plain = ArticleBoilerplateRemover.plainText(from: final).lowercased()

        // The article body must survive — Pope quote and key context.
        #expect(plain.contains("papa"))
        #expect(plain.contains("conflitti"))

        // Page chrome the user complained about must be gone.
        let bannedSubstrings = [
            "iscriviti alla newsletter",
            "leggi anche",
            "articoli correlati",
            "riproduzione riservata",
            "tutti i diritti riservati",
            "accetta tutti i cookie",
            "cookie policy"
        ]
        let survivors = bannedSubstrings.filter { plain.contains($0) }
        if survivors.isEmpty == false {
            // Write a debug dump next to the fixture (host filesystem is
            // visible to xctest running in the iOS simulator because the
            // test bundle reads from there via #file already).
            let debugURL = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("docs/rss/research/distiller-fixtures/_debug.txt")
            let debug = """
            survivors=\(survivors)
            ---PLAIN_HEAD---
            \(String(plain.prefix(2000)))
            ---PLAIN_TAIL---
            \(String(plain.suffix(2000)))
            """
            try? debug.write(to: debugURL, atomically: true, encoding: .utf8)
        }
        #expect(survivors.isEmpty, "ANSA distilled body still contains: \(survivors)")

        // The cleaned output should be a meaningful fraction of the
        // original — never zero, never the entire page either.
        let originalWordCount = html
            .split { $0.isWhitespace || $0.isNewline }
            .count
        let distilledWordCount = plain
            .split { $0.isWhitespace || $0.isNewline }
            .count
        #expect(distilledWordCount > 30)
        #expect(distilledWordCount < originalWordCount)
    }

    // MARK: - Fixture loader

    private static func loadFixture() throws -> String {
        let fixtureURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // MercuryTests/
            .deletingLastPathComponent() // Mercury/
            .deletingLastPathComponent() // Mercury (project root in repo layout)
            .appendingPathComponent("docs/rss/research/distiller-fixtures/ansa-papa-conflitti.html")

        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }
}
