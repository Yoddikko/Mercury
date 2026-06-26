//
//  RSSCatalogValidationHarness.swift
//  MercuryTests
//
//  Created by Codex on 26/06/26.
//
//  Phase 3 validation harness for the expanded RSS catalog (issue #53).
//
//  This test is intentionally NON-asserting: it walks every region in
//  `RSSFeedCatalog`, runs the real `FeedRefreshService.runDiagnostics`
//  pipeline against the live network, then dumps the aggregated batch
//  result as JSON to a stable path under `$TMPDIR` and echoes that path
//  (plus the JSON itself) to stdout.
//
//  The intent is to give a human reviewer an authoritative artifact for
//  classifying each outlet as ✅ ok / 🟡 degraded / ⛔ dead and to
//  produce a snapshot to commit under
//  `docs/rss/research/diagnostics-<date>.json`.
//
//  This test is gated behind the `MERCURY_RUN_RSS_HARNESS=1`
//  environment variable so it stays opt-in. Without that flag the test
//  exits immediately and the regular unit-test suite is not slowed
//  down by 200+ live HTTP fetches.
//
//  DO NOT add `#expect` assertions here. Live feed availability is not
//  something we can pin to a unit test — the harness exists to PRODUCE
//  evidence, not to enforce it.
//

import Foundation
import Testing
@testable import Mercury

struct RSSCatalogValidationHarness {
    /// Entrypoint for the Phase 3 validation harness. Iterates every
    /// region exposed by `RSSFeedCatalog`, runs diagnostics with
    /// `groupMode: .byRegion` so we exercise EVERY outlet (not just the
    /// 25 region picks that `.mainOutlets` would surface), and writes
    /// a combined JSON report to `$TMPDIR`.
    @Test
    func runValidationHarness() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MERCURY_RUN_RSS_HARNESS"] == "1" else {
            print("[rss-harness] Skipped (set MERCURY_RUN_RSS_HARNESS=1 to enable).")
            return
        }

        let service = FeedRefreshService()
        let regions = RSSFeedCatalog.availableRegions

        print("[rss-harness] Starting validation across \(regions.count) regions.")

        var allChecks: [RSSFeedCheckResult] = []
        var allDeduplicated: [Article] = []
        var regionSummaries: [[String: Any]] = []
        let startedAt = Date()

        for region in regions {
            let regionStartedAt = Date()
            let result = await service.runDiagnostics(
                groupMode: .byRegion,
                selectedRegion: region
            )
            allChecks.append(contentsOf: result.checks)
            allDeduplicated.append(contentsOf: result.deduplicatedArticles)

            let success = result.checks.filter { $0.status == .success }.count
            let noArticles = result.checks.filter { $0.status == .noArticles }.count
            let failed = result.checks.filter {
                $0.status == .requestFailed || $0.status == .parseFailed
            }.count
            let invalid = result.checks.filter {
                $0.status == .noFeedURL || $0.status == .invalidFeedURL
            }.count
            let elapsed = Int(Date().timeIntervalSince(regionStartedAt) * 1000)

            print("""
            [rss-harness] region=\(region.rawValue) checked=\(result.checks.count) \
            ok=\(success) no_articles=\(noArticles) invalid=\(invalid) failed=\(failed) \
            elapsed_ms=\(elapsed)
            """)

            regionSummaries.append([
                "region": region.rawValue,
                "checked": result.checks.count,
                "ok": success,
                "no_articles": noArticles,
                "invalid": invalid,
                "failed": failed,
                "elapsed_ms": elapsed
            ])
        }

        let aggregate = RSSFeedBatchResult(
            checkedAt: startedAt,
            groupMode: .allOutlets,
            selectedRegion: nil,
            checks: allChecks,
            deduplicatedArticles: allDeduplicated
        )

        let outletsJSON = RSSDiagnosticsReportExporter.buildJSONReport(from: aggregate)

        // Stitch the per-region summary onto the outlets payload as a
        // separate "regions" block. We hand-roll the merge so we do not
        // need to round-trip through Codable for the existing exporter.
        let regionsPayload: [String: Any] = ["regions": regionSummaries]
        let regionsData = (try? JSONSerialization.data(
            withJSONObject: regionsPayload,
            options: [.prettyPrinted, .sortedKeys]
        )) ?? Data()
        let regionsText = String(data: regionsData, encoding: .utf8) ?? "{}"

        let combinedJSON = """
        {
          "outlets_report": \(outletsJSON),
          "regions_report": \(regionsText)
        }
        """

        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MercuryRSSReports", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: tmpDir,
            withIntermediateDirectories: true
        )
        let outputURL = tmpDir.appendingPathComponent("rss-validation-harness.json")
        try Data(combinedJSON.utf8).write(to: outputURL, options: .atomic)

        let totalElapsed = Int(Date().timeIntervalSince(startedAt))
        print("[rss-harness] Wrote JSON report to: \(outputURL.path)")
        print("[rss-harness] Total outlets checked: \(allChecks.count)")
        print("[rss-harness] Total elapsed: \(totalElapsed)s")

        // Echo the full JSON to stdout in a delimited block so a parent
        // process scraping the xcodebuild log can pull it out without
        // needing to fish files off the simulator.
        print("[rss-harness-json-begin]")
        print(combinedJSON)
        print("[rss-harness-json-end]")
    }
}
