//
//  RSSDiagnosticsReportExporterTests.swift
//  MercuryTests
//
//  Created by Codex on 01/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct RSSDiagnosticsReportExporterTests {
    @Test
    func reportContainsOutletStatusLines() {
        let result = makeBatchResult()
        let report = RSSDiagnosticsReportExporter.buildReport(from: result)

        #expect(report.contains("Mercury RSS Outlets Report"))
        #expect(report.contains("outlets_checked=2"))
        #expect(report.contains("successful=1"))
        #expect(report.contains("failed=1"))
        #expect(report.contains("[SUCCESS] outlet=\"Outlet One\""))
        #expect(report.contains("[REQUESTFAILED] outlet=\"Outlet Two\""))
    }

    @Test
    func exportWritesReportToTemporaryFile() throws {
        let result = makeBatchResult()
        let fixedDate = Date(timeIntervalSince1970: 1_775_000_000)
        let fileURL = try RSSDiagnosticsReportExporter.exportReport(from: result, now: fixedDate)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(fileURL.lastPathComponent.contains("rss-outlets-report-"))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let data = try Data(contentsOf: fileURL)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("Outlet One"))
        #expect(text.contains("Outlet Two"))
    }

    private func makeBatchResult() -> RSSFeedBatchResult {
        let sourceOne = RSSFeedSource(
            id: "outlet-one",
            outletName: "Outlet One",
            region: .italy,
            feedURLString: "https://example.com/feed-1.xml",
            isMainOutlet: true,
            languageCode: "it",
            tags: [],
            note: nil
        )
        let sourceTwo = RSSFeedSource(
            id: "outlet-two",
            outletName: "Outlet Two",
            region: .france,
            feedURLString: "https://example.com/feed-2.xml",
            isMainOutlet: false,
            languageCode: "fr",
            tags: [],
            note: nil
        )
        let article = Article(
            id: "article-1",
            externalID: "guid-article-1",
            title: "Test Article",
            sourceName: "Outlet One",
            sourceURL: URL(string: "https://example.com/source")!,
            articleURL: URL(string: "https://example.com/articles/1")!,
            publishedAt: Date(timeIntervalSince1970: 1_775_000_000),
            authorName: "Reporter One",
            heroImageURL: URL(string: "https://example.com/images/1.jpg"),
            rawContent: "raw",
            cleanedContent: "clean",
            contentSource: "feed_content",
            contentWordCount: 180,
            isContentLikelyComplete: true,
            summaryShort: "short summary",
            summaryBullets: [],
            category: nil,
            tags: [],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: Date(timeIntervalSince1970: 1_775_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_775_000_000)
        )

        let checkOne = RSSFeedCheckResult(
            source: sourceOne,
            status: .success,
            articles: [article],
            elapsedMs: 120,
            message: nil
        )
        let checkTwo = RSSFeedCheckResult(
            source: sourceTwo,
            status: .requestFailed,
            articles: [],
            elapsedMs: 220,
            message: "HTTP 500"
        )

        return RSSFeedBatchResult(
            checkedAt: Date(timeIntervalSince1970: 1_775_000_000),
            groupMode: .allOutlets,
            selectedRegion: nil,
            checks: [checkOne, checkTwo],
            deduplicatedArticles: [article]
        )
    }
}
