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
/// (issues #89 / #95 / #98, meta #80).
///
/// Unlike `ItalianDistillationFixturesTests` (committed fixtures,
/// pinned assertions) this harness runs the **production
/// `ArticleContentEnrichmentService.distill` pipeline** — including
/// the JSON-LD articleBody fast path and the hidden-WKWebView Mozilla
/// Readability stage (#98) — over ad-hoc downloaded pages dropped
/// under `docs/rss/research/distiller-fixtures/_audit/` and dumps a
/// per-page profile (word count, chrome survivors, paywall verdict,
/// head/tail excerpt) to a `_snapshots/` folder next to the pages.
///
/// Corpora are dated: pages for a new audit go in a
/// `_audit/YYYY-MM-DD/` subdirectory and the harness picks the most
/// recent dated corpus (falling back to loose pages in `_audit/`
/// itself, the 2026-07-02 layout). It passes trivially when no pages
/// are present. It never fails the build: it is an inspection tool,
/// not a gate.
///
/// Naming convention for audit pages: `<slug>__<host>__<lang>.html`
/// (host and language drive the per-outlet rule lookup, the JSON-LD /
/// terminator locale handling and the locale stripper, mirroring
/// production).
@Suite("Italian outlet distillation audit harness")
struct ItalianOutletAuditHarness {
    @Test func auditDownloadedPages() async throws {
        let auditRoot = ItalianDistillationFixturesTests.fixturesDirectory
            .appendingPathComponent("_audit")
        guard let corpusDirectory = Self.latestCorpusDirectory(under: auditRoot) else {
            // No audit drop present — nothing to do.
            return
        }

        let pages = (try? FileManager.default.contentsOfDirectory(
            at: corpusDirectory,
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "html" }.sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        guard pages.isEmpty == false else { return }

        let snapshotsDirectory = corpusDirectory.appendingPathComponent("_snapshots")
        try? FileManager.default.createDirectory(
            at: snapshotsDirectory,
            withIntermediateDirectories: true
        )

        // The real production pipeline (#98): JSON-LD fast path,
        // sanitizer, per-outlet rule, Readability webview stage,
        // terminator truncation, boilerplate remover, hero dedup,
        // locale stripper, paywalled-teaser classifier.
        let service = ArticleContentEnrichmentService()

        for page in pages {
            let parts = page.deletingPathExtension().lastPathComponent
                .components(separatedBy: "__")
            guard parts.count == 3 else { continue }
            let (slug, host, language) = (parts[0], parts[1], parts[2])

            guard let data = try? Data(contentsOf: page) else { continue }
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""

            let output = await service.distill(
                rawHTML: html,
                fallbackCleanedText: "",
                heroURLString: nil,
                language: language,
                host: host,
                requestID: "audit-\(slug)"
            )

            let plain = output.distilledHTML.map {
                ArticleBoilerplateRemover.plainText(from: $0)
            } ?? output.cleanedText
            let lowered = plain.lowercased()
            let words = plain.split { $0.isWhitespace || $0.isNewline }.count

            let survivors = Self.chromeProbe.filter { lowered.contains($0) }
            let rawLowered = html.lowercased()
            let markers = Self.paywallProbe.filter { rawLowered.contains($0.lowercased()) }

            let snapshot = """
            page: \(slug)
            host: \(host) lang: \(language)
            distilled: \(output.distilledHTML == nil ? "NO (fallback)" : "yes")
            paywalled-teaser: \(output.isPaywalledTeaser)
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

    /// Picks the corpus to audit: the lexicographically greatest
    /// `YYYY-MM-DD`-named subdirectory of `_audit/`, or `_audit/`
    /// itself when no dated corpus exists (legacy 2026-07-02 layout).
    /// Returns `nil` when `_audit/` is absent.
    private static func latestCorpusDirectory(under root: URL) -> URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        let dated = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        ))?.filter { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return false
            }
            let name = url.lastPathComponent
            return name.count == 10 && name.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return dated?.last ?? root
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
