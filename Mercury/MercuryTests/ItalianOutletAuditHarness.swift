//
//  ItalianOutletAuditHarness.swift
//  MercuryTests
//
//  Created by Claude on 02/07/26.
//

import Foundation
import Testing
@testable import Mercury

/// Diagnostic harness for the full-catalog Italian outlet audit
/// (issues #89 / #95 / meta #80).
///
/// Unlike `ItalianDistillationFixturesTests` (committed fixtures,
/// pinned assertions) this harness runs the distillation pipeline over
/// **ad-hoc downloaded pages** dropped under
/// `docs/rss/research/distiller-fixtures/_audit/` and dumps a
/// per-page profile (word count, chrome survivors, paywall-marker
/// hits, head/tail excerpt) to `_audit/_snapshots/`. The 2026-07-02
/// full-catalog corpus and its results are committed under `_audit/`
/// (see `_audit/AUDIT-2026-07-02.md`); the harness passes trivially
/// when the directory is absent. It never fails the build: it is an
/// inspection tool, not a gate.
///
/// Naming convention for audit pages: `<slug>__<host>__<lang>.html`
/// (host and language drive the per-outlet rule lookup and the locale
/// stripper, mirroring production).
@Suite("Italian outlet distillation audit harness")
struct ItalianOutletAuditHarness {
    @Test func auditDownloadedPages() throws {
        let auditDirectory = ItalianDistillationFixturesTests.fixturesDirectory
            .appendingPathComponent("_audit")
        guard FileManager.default.fileExists(atPath: auditDirectory.path) else {
            // No audit drop present — nothing to do.
            return
        }

        let pages = (try? FileManager.default.contentsOfDirectory(
            at: auditDirectory,
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "html" }.sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        guard pages.isEmpty == false else { return }

        let snapshotsDirectory = auditDirectory.appendingPathComponent("_snapshots")
        try? FileManager.default.createDirectory(
            at: snapshotsDirectory,
            withIntermediateDirectories: true
        )

        let sanitizer = ArticleHTMLSanitizer()
        let remover = ArticleBoilerplateRemover()
        let imageDedup = ArticleImageDeduplicator()
        let localeStripper = ArticleLocaleBoilerplateStripper()

        for page in pages {
            let parts = page.deletingPathExtension().lastPathComponent
                .components(separatedBy: "__")
            guard parts.count == 3 else { continue }
            let (slug, host, language) = (parts[0], parts[1], parts[2])

            guard let data = try? Data(contentsOf: page) else { continue }
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""

            let sanitized = sanitizer.sanitize(html)
            let ruled: String
            if let rule = ArticleOutletRuleCatalog.bundled.rule(forHost: host) {
                ruled = ArticleOutletRuleApplier().applying(rule, to: sanitized)
            } else {
                ruled = sanitized
            }
            let truncated = ArticleContentEnrichmentService.truncatedAtTerminator(
                html: ruled,
                language: language
            )
            let withoutBoilerplate = remover.cleaning(truncated)
            let withoutHero = imageDedup.dedupingHero(in: withoutBoilerplate, heroImageURLString: nil)
            let final = localeStripper.stripping(html: withoutHero, language: language)

            let plain = ArticleBoilerplateRemover.plainText(from: final)
            let lowered = plain.lowercased()
            let words = plain.split { $0.isWhitespace || $0.isNewline }.count

            let survivors = Self.chromeProbe.filter { lowered.contains($0) }
            let rawLowered = html.lowercased()
            let markers = Self.paywallProbe.filter { rawLowered.contains($0.lowercased()) }

            let snapshot = """
            page: \(slug)
            host: \(host) lang: \(language)
            words: \(words)
            chrome-survivors: \(survivors)
            raw-paywall-markers: \(markers)
            head: \(String(lowered.prefix(320)))
            tail: \(String(lowered.suffix(320)))
            """
            let out = snapshotsDirectory.appendingPathComponent("\(slug).txt")
            try? snapshot.write(to: out, atomically: true, encoding: .utf8)
        }
    }

    /// Chrome phrases the audit scans for in the distilled output —
    /// the fixture suite's common set plus paywall/consent CTA copy.
    private static let chromeProbe: [String] =
        ItalianDistillationFixturesTests.commonChrome + [
            "solo per abbonati",
            "abbonati per continuare",
            "abbonamento consentless",
            "accetta i cookie e continua",
            "contenuto riservato agli abbonati",
            "sei già abbonato",
            "prova gratuita",
            "registrati gratis",
            "accedi per commentare",
            "condividi su facebook",
            "whatsapp twitter",
            "ti potrebbe interessare",
            "potrebbe interessarti",
            "commenta per primo",
            "sign up for",
            "support the guardian",
            "log in or create an account"
        ]

    /// Raw-page paywall markers (issue #95 evidence gathering) —
    /// scanned against the UNdistilled HTML.
    private static let paywallProbe: [String] = [
        "paywall",
        "premium",
        "bt-Subscribe",
        "solo per abbonati",
        "metered",
        "subscription-required"
    ]
}
