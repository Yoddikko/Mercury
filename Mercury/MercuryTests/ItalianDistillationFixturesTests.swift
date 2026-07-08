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
/// remediation lives in one of four places (prefer the first — rules
/// are data, not code, per #91):
/// * `ArticleOutletExtractionRules.json` for outlet-specific selectors
///   and text patterns,
/// * `ArticleBoilerplateRemover.negativeRegex` for new class tokens,
/// * `ArticleLocaleBoilerplateStripper.patterns` for text patterns,
/// * `ArticleImageDeduplicator` for image edge cases.
@Suite("Italian distillation fixtures")
struct ItalianDistillationFixturesTests {
    struct FixtureSpec: Sendable, CustomStringConvertible {
        let name: String
        let language: String
        /// Host the fixture was fetched from — drives the per-outlet
        /// extraction rule lookup (#91). Hosts without a rule exercise
        /// the generic-pipeline passthrough.
        let host: String
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
            host: "www.ansa.it",
            mustContainAny: ["papa", "conflitti"],
            bannedSubstrings: Self.commonChrome + [
                "riproduzione riservata",
                "abbonamento consentless"
            ]
        ),
        FixtureSpec(
            // Second ANSA fixture (issue #81) — the July 2026
            // Sinner-Borges Wimbledon article. It carries the full
            // iubenda Consentless subscription CTA that motivated
            // the boilerplate-remover class updates in #84 and the
            // article-terminator truncation. Pin the specific CTA
            // strings so a regression that lets Consentless leak
            // back through fails loud.
            name: "ansa-consentless-sinner",
            language: "it",
            host: "www.ansa.it",
            mustContainAny: ["sinner", "borges", "wimbledon"],
            bannedSubstrings: Self.commonChrome + [
                "abbonamento consentless",
                "accetta i cookie e continua",
                "altri abbonamenti",
                "iscrizione alle newsletter tematiche"
            ]
        ),
        FixtureSpec(
            // Fresh Corriere article covering the metered-paywall
            // chrome pattern (issue #81). The page carries a
            // `.Paywall` container and "abbonamento permette di
            // leggere Corriere" CTA copy that must not leak.
            name: "corriere-toti-spinelli",
            language: "it",
            host: "www.corriere.it",
            mustContainAny: ["toti", "spinelli"],
            bannedSubstrings: Self.commonChrome + [
                "abbonato con un altro account",
                "abbonamento permette di leggere corriere"
            ]
        ),
        FixtureSpec(
            name: "corriere",
            language: "it",
            host: "www.corriere.it",
            mustContainAny: ["codice della strada", "gabanelli"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilfatto",
            language: "it",
            host: "www.ilfattoquotidiano.it",
            mustContainAny: ["juventus", "uefa"],
            bannedSubstrings: Self.commonChrome + [
                // Community CTA rail — leaked on the live audit
                // (2026-07-02) until the ilfatto rule stripped
                // `.ifq-news-comments`.
                "resta in contatto con la community"
            ]
        ),
        FixtureSpec(
            name: "ilmessaggero",
            language: "it",
            host: "www.ilmessaggero.it",
            mustContainAny: ["bastoni", "inter"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilsole24ore",
            language: "it",
            host: "www.ilsole24ore.com",
            mustContainAny: ["donnarumma", "dimissioni"],
            bannedSubstrings: Self.commonChrome + [
                // Article-footer author card + related-links block —
                // leaked on the live audit (2026-07-02) until the
                // ilsole24ore rule stripped `.afoot`/`.minibio`/
                // `.acor--moreon`.
                "per approfondire",
                "lingue parlate"
            ]
        ),
        FixtureSpec(
            name: "open",
            language: "it",
            host: "www.open.online",
            mustContainAny: ["norvegia", "mondiali"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "repubblica",
            language: "it",
            host: "www.repubblica.it",
            mustContainAny: ["identità e democrazia", "fondi"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "skytg24",
            language: "it",
            host: "tg24.sky.it",
            mustContainAny: ["superenalotto", "lotto"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "wired",
            language: "it",
            host: "www.wired.it",
            mustContainAny: ["dreame", "essiccare"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilpost",
            language: "it",
            host: "www.ilpost.it",
            mustContainAny: ["vannacci", "mistero"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilfoglio",
            language: "it",
            host: "www.ilfoglio.it",
            mustContainAny: ["corte suprema", "trump"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "tgla7",
            language: "it",
            host: "tg.la7.it",
            mustContainAny: ["podcast", "tg la7"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilgiornale",
            language: "it",
            host: "www.ilgiornale.it",
            mustContainAny: ["bastoni", "zulu"],
            bannedSubstrings: Self.commonChrome + [
                // Comment-form chrome — leaked on the live audit
                // (2026-07-02) until the ilgiornale rule stripped
                // `#ilg_comments`.
                "pubblica un commento",
                "scegli il giornale come fonte preferita"
            ]
        ),
        FixtureSpec(
            name: "avvenire",
            language: "it",
            host: "www.avvenire.it",
            mustContainAny: ["ius soli", "corte suprema"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "huffpost",
            language: "it",
            host: "www.huffingtonpost.it",
            mustContainAny: ["trump", "ius soli"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilgiorno",
            language: "it",
            host: "www.ilgiorno.it",
            mustContainAny: ["leonardo", "ospedale"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilmanifesto",
            language: "it",
            host: "ilmanifesto.it",
            mustContainAny: ["melonellum", "vannacci"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "lettera43",
            language: "it",
            host: "www.lettera43.it",
            mustContainAny: ["papa", "smerilli"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "gazzetta",
            language: "it",
            host: "www.gazzetta.it",
            mustContainAny: ["ouedraogo", "schalke"],
            // "leggi anche" itself is in `commonChrome`; the gazzetta
            // rule additionally strips the `.bck-tile-slider`
            // related-article rail that leaked headline links on the
            // live audit (2026-07-02).
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "ilrestodelcarlino",
            language: "it",
            host: "www.ilrestodelcarlino.it",
            mustContainAny: ["stazione", "trenino"],
            bannedSubstrings: Self.commonChrome
        ),
        // MARK: Fixture-fill wave (issue #89) — one pinned fixture per
        // previously uncovered Italian outlet host.
        FixtureSpec(
            name: "adnkronos",
            language: "it",
            host: "www.adnkronos.com",
            mustContainAny: ["palio", "contrade"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "fanpage",
            language: "it",
            host: "www.fanpage.it",
            mustContainAny: ["nascondi la mia mail", "indirizzi"],
            bannedSubstrings: Self.commonChrome + [
                // Continue-read promo + autopromo banner — leaked on
                // the live audit (2026-07-02) until the fanpage rule
                // stripped `.cr`/`.bnr`.
                "continua a leggere su fanpage.it",
                "più che un giornale"
            ]
        ),
        FixtureSpec(
            name: "internazionale",
            language: "it",
            host: "www.internazionale.it",
            mustContainAny: ["venezuela", "washington"],
            bannedSubstrings: Self.commonChrome + [
                // Letters-page CTA (`.item_note2`) — leaked on the
                // live audit (2026-07-02).
                "pagina di lettere"
            ]
        ),
        FixtureSpec(
            name: "liberoquotidiano",
            language: "it",
            host: "www.liberoquotidiano.it",
            mustContainAny: ["gemelle", "intercettate"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "linkiesta",
            language: "it",
            host: "www.linkiesta.it",
            mustContainAny: ["kyjiv", "bombardamento"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "thelocal",
            language: "en",
            host: "www.thelocal.it",
            mustContainAny: ["heatwave", "storm"],
            bannedSubstrings: Self.commonChrome + [
                "membership",
                "log in"
            ]
        ),
        FixtureSpec(
            name: "milannews",
            language: "it",
            host: "www.milannews.it",
            mustContainAny: ["ramos", "vieri"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "panorama",
            language: "it",
            host: "www.panorama.it",
            mustContainAny: ["vaticano", "cattolici"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            name: "tgcom24",
            language: "it",
            host: "www.tgcom24.mediaset.it",
            mustContainAny: ["corte", "android"],
            bannedSubstrings: Self.commonChrome + [
                // Next.js related-content rail — leaked on the live
                // audit (2026-07-02) until the tgcom24 rule stripped it.
                "ti potrebbe interessare"
            ]
        ),
        FixtureSpec(
            name: "guardianitaly",
            language: "en",
            host: "www.theguardian.com",
            mustContainAny: ["albania", "detention"],
            bannedSubstrings: Self.commonChrome + [
                "support the guardian",
                "sign up for"
            ]
        ),
        FixtureSpec(
            name: "rainews",
            language: "it",
            host: "www.rainews.it",
            mustContainAny: ["kallas", "sanzioni"],
            bannedSubstrings: Self.commonChrome
        ),
        FixtureSpec(
            // TGCom24 VIDEO page (live audit 2026-07-07, #98). Video
            // pages have no article container, so the Tailwind site
            // header (`data-testid="header-container"`: date bar,
            // meteo.it weather chip, section menus) leaked into the
            // distilled head until the tgcom24 rule stripped it.
            name: "tgcom24-video-trump-meloni",
            language: "it",
            host: "www.tgcom24.mediaset.it",
            mustContainAny: ["trump", "meloni"],
            bannedSubstrings: Self.commonChrome + [
                // header date bar copy
                "aggiornato alle",
                // second-level-menu / profile-menu copy
                "area personale",
                "ti potrebbe interessare"
            ]
        ),
        FixtureSpec(
            // Linkiesta advertorial-style article (live audit
            // 2026-07-07, #98). The login nav ("Accedi"), the
            // `.article-datetime` date, the `.post-categories` list
            // and the trailing `.article-tags`/`.sharedaddy` widgets
            // leaked around the body until the linkiesta rule
            // stripped them.
            name: "linkiesta-gwm-ora5",
            language: "it",
            host: "www.linkiesta.it",
            mustContainAny: ["gwm", "mobilità"],
            bannedSubstrings: Self.commonChrome + [
                "accedi",
                "tags:",
                "condividi:"
            ]
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
        // Mirror the production pipeline order (#91) — the per-outlet
        // extraction rule runs right after sanitization, BEFORE the
        // generic passes. Fixtures whose host has no rule exercise the
        // unchanged generic pipeline.
        let ruled: String
        if let rule = ArticleOutletRuleCatalog.bundled.rule(forHost: spec.host) {
            ruled = ArticleOutletRuleApplier().applying(rule, to: sanitized)
        } else {
            ruled = sanitized
        }
        // Terminator truncation (#81) runs before the boilerplate
        // remover, so downstream chrome that appears after
        // "Riproduzione riservata" never reaches the fixture assertions.
        let truncated = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: ruled,
            language: spec.language
        )
        let withoutBoilerplate = remover.cleaning(truncated)
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
