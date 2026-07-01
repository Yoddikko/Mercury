//
//  ItalianDistillationFixturesTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

/// Parameterized integration test that runs the full distillation
/// pipeline against real HTML fixtures from major Italian outlets
/// (issue #66 / spec PR #65). Each fixture pins:
/// * keywords from the article title that MUST survive distillation,
/// * page-chrome substrings that MUST be absent.
///
/// The fixtures live under `docs/rss/research/distiller-fixtures/` and
/// are fetched offline so the test runs reproducibly without network.
///
/// When this test surfaces a regression on a specific outlet, the
/// remediation lives in one of three places:
/// * `ArticleBoilerplateRemover.negativeRegex` for new class tokens,
/// * `ArticleLocaleBoilerplateStripper.patterns` for text patterns,
/// * `ArticleImageDeduplicator` for image edge cases.
@Suite("Italian distillation fixtures")
struct ItalianDistillationFixturesTests {
    struct FixtureSpec: Sendable, CustomStringConvertible {
        let name: String
        let language: String
        /// At least ONE token from this list must appear in the
        /// distilled plain text — proves the article body survived.
        let mustContainAny: [String]
        /// All of these substrings must be absent — page chrome we
        /// must never surface.
        let bannedSubstrings: [String]

        var description: String { name }
    }

    static let fixtures: [FixtureSpec] = [
        FixtureSpec(
            name: "ansa-papa-conflitti",
            language: "it",
            mustContainAny: ["papa", "conflitti"],
            bannedSubstrings: Self.commonChrome + [
                "riproduzione riservata",
                "abbonamento consentless"
            ]
        ),
        FixtureSpec(
            name: "corriere",
            language: "it",
            mustContainAny: ["codice della strada", "gabanelli"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilfatto",
            language: "it",
            mustContainAny: ["juventus", "uefa"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilmessaggero",
            language: "it",
            mustContainAny: ["bastoni", "inter"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilsole24ore",
            language: "it",
            mustContainAny: ["donnarumma", "dimissioni"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "open",
            language: "it",
            mustContainAny: ["norvegia", "mondiali"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "repubblica",
            language: "it",
            mustContainAny: ["identità e democrazia", "fondi"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "skytg24",
            language: "it",
            mustContainAny: ["superenalotto", "lotto"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "wired",
            language: "it",
            mustContainAny: ["dreame", "essiccare"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilpost",
            language: "it",
            mustContainAny: ["vannacci", "mistero"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilfoglio",
            language: "it",
            mustContainAny: ["corte suprema", "trump"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "tgla7",
            language: "it",
            mustContainAny: ["podcast", "tg la7"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilgiornale",
            language: "it",
            mustContainAny: ["bastoni", "zulu"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "avvenire",
            language: "it",
            mustContainAny: ["ius soli", "corte suprema"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "huffpost",
            language: "it",
            mustContainAny: ["trump", "ius soli"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilgiorno",
            language: "it",
            mustContainAny: ["leonardo", "ospedale"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilmanifesto",
            language: "it",
            mustContainAny: ["melonellum", "vannacci"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "lettera43",
            language: "it",
            mustContainAny: ["papa", "smerilli"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "gazzetta",
            language: "it",
            mustContainAny: ["ouedraogo", "schalke"],
            bannedSubstrings: Self.commonChrome
        )
    ]

    /// Chrome phrases every Italian fixture must be free of.
    static let commonChrome: [String] = [
        "iscriviti alla newsletter",
        "newsletter iscriviti",
        "leggi anche",
        "articoli correlati",
        "tutti i diritti riservati",
        "cookie policy",
        "accetta tutti i cookie",
        "trattamento dei dati personali",
        "seguici su google discover",
        "seguici anche su",
        "google discover",
        "brand connect",
        "cerca il tuo immobile"
    ]

    @Test(arguments: fixtures)
    func articleSurvivesChromeStrip(spec: FixtureSpec) throws {
        let html = try Self.loadFixture(spec.name)

        let sanitizer = ArticleHTMLSanitizer()
        let remover = ArticleBoilerplateRemover()
        let imageDedup = ArticleImageDeduplicator()
        let localeStripper = ArticleLocaleBoilerplateStripper()

        let sanitized = sanitizer.sanitize(html)
        let withoutBoilerplate = remover.cleaning(sanitized)
        let withoutHero = imageDedup.dedupingHero(in: withoutBoilerplate, heroImageURLString: nil)
        let final = localeStripper.stripping(html: withoutHero, language: spec.language)

        let plain = ArticleBoilerplateRemover.plainText(from: final).lowercased()
        let blocks = HTMLArticleBlockParser().parse(final)

        let bodyKeptOne = spec.mustContainAny.contains(where: { plain.contains($0.lowercased()) })
        #expect(
            bodyKeptOne,
            "[\(spec.name)] none of the must-contain tokens \(spec.mustContainAny) survived — distillation likely too aggressive"
        )

        let survivors = spec.bannedSubstrings.filter { plain.contains($0.lowercased()) }
        #expect(
            survivors.isEmpty,
            "[\(spec.name)] page chrome survived distillation: \(survivors)"
        )

        // Diagnostic dump (only fires when the assertions above would
        // otherwise produce a hard-to-debug noise failure): the first
        // 600 chars of the distilled body for the fixture, so
        // regressions surface quickly via `xcresulttool`.
        let wordCount = plain.split { $0.isWhitespace || $0.isNewline }.count
        if wordCount < 60 || survivors.isEmpty == false {
            Issue.record("""
                [\(spec.name)] words=\(wordCount) survivors=\(survivors)
                HEAD: \(String(plain.prefix(800)))
                """)
        }

        // Snapshot the per-fixture profile to disk so the loop can
        // inspect what survives without re-running tests. Writes are
        // best-effort — failures don't break the test.
        let blockTypes = blocks.map { Self.kind(of: $0) }
        let counts: [String: Int] = blockTypes.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        let snapshot = """
        outlet: \(spec.name)
        words: \(wordCount)
        blocks: \(blocks.count)
        block-counts: \(counts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " "))
        survivors: \(survivors)
        head: \(String(plain.prefix(280)))
        tail: \(String(plain.suffix(280)))
        """
        let snapURL = Self.fixturesDirectory
            .appendingPathComponent("_loop-snapshots")
            .appendingPathComponent("\(spec.name).txt")
        try? FileManager.default.createDirectory(
            at: snapURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? snapshot.write(to: snapURL, atomically: true, encoding: .utf8)
    }

    private static func kind(of block: ArticleBlock) -> String {
        switch block {
        case .paragraph: return "paragraph"
        case .heading: return "heading"
        case .image: return "image"
        case .list: return "list"
        case .quote: return "quote"
        case .code: return "code"
        }
    }

    // MARK: - Fixture loader

    static let fixturesDirectory: URL = {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/rss/research/distiller-fixtures")
    }()

    private static func loadFixture(_ name: String) throws -> String {
        let url = fixturesDirectory.appendingPathComponent("\(name).html")
        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        // Italian outlets occasionally serve ISO-8859-1 / Windows-1252.
        // Lossy fall-through so we never block on a single bad byte.
        return String(data: data, encoding: .isoLatin1) ?? ""
    }
}
