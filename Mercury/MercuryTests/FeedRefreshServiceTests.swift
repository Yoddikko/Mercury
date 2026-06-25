//
//  FeedRefreshServiceTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import Testing
@testable import Mercury

/// Verifies the production (`refreshFeed`) and diagnostics
/// (`runDiagnostics`) surfaces of `FeedRefreshService` stay in sync
/// after issue #33's split.
///
/// We intentionally drive the service with sources that have no
/// documented feed URL or an invalid scheme so the network layer is
/// never hit. This keeps the tests hermetic while still exercising
/// the shared `performFetch` core and dedupe logic.
struct FeedRefreshServiceTests {
    @Test
    func refreshFeedReturnsEmptyResultForEmptySources() async {
        let service = FeedRefreshService()

        let result = await service.refreshFeed(
            sources: [],
            groupMode: .mainOutlets,
            selectedRegion: nil
        )

        #expect(result.checks.isEmpty)
        #expect(result.deduplicatedArticles.isEmpty)
        #expect(result.groupMode == .mainOutlets)
        #expect(result.selectedRegion == nil)
    }

    @Test
    func refreshFeedReportsNoFeedURLChecksWithoutHittingNetwork() async {
        let service = FeedRefreshService()
        let sources = [
            Self.makeSource(id: "no-url-1", feedURLString: nil),
            Self.makeSource(id: "no-url-2", feedURLString: nil)
        ]

        let result = await service.refreshFeed(
            sources: sources,
            groupMode: .allOutlets,
            selectedRegion: nil
        )

        #expect(result.checks.count == sources.count)
        #expect(result.checks.allSatisfy { $0.status == .noFeedURL })
        #expect(result.deduplicatedArticles.isEmpty)
    }

    @Test
    func refreshFeedReportsInvalidFeedURLChecksWithoutHittingNetwork() async {
        let service = FeedRefreshService()
        let sources = [
            Self.makeSource(id: "bad-scheme", feedURLString: "ftp://example.com/feed.xml")
        ]

        let result = await service.refreshFeed(
            sources: sources,
            groupMode: .allOutlets,
            selectedRegion: nil
        )

        #expect(result.checks.count == 1)
        #expect(result.checks.first?.status == .invalidFeedURL)
    }

    @Test
    func refreshFeedPropagatesRegionAndGroupModeIntoResult() async {
        let service = FeedRefreshService()

        let result = await service.refreshFeed(
            sources: [],
            groupMode: .byRegion,
            selectedRegion: .italy
        )

        #expect(result.groupMode == .byRegion)
        #expect(result.selectedRegion == .italy)
    }

    @Test
    func runDiagnosticsReportsSameStatusesAsRefreshFeedForSameSources() async {
        let service = FeedRefreshService()
        let sources = [
            Self.makeSource(id: "no-url", feedURLString: nil),
            Self.makeSource(id: "bad-scheme", feedURLString: "ftp://example.com/feed.xml")
        ]

        let production = await service.refreshFeed(
            sources: sources,
            groupMode: .allOutlets,
            selectedRegion: nil
        )
        let diagnostics = await service.runDiagnostics(
            sources: sources,
            groupMode: .allOutlets,
            selectedRegion: nil
        )

        // Both surfaces must agree on per-source status, otherwise the
        // production fetch and the developer playground would diverge.
        let productionStatuses = production.checks.map { ($0.source.id, $0.status) }
        let diagnosticsStatuses = diagnostics.checks.map { ($0.source.id, $0.status) }
        #expect(productionStatuses.count == diagnosticsStatuses.count)
        for (lhs, rhs) in zip(productionStatuses, diagnosticsStatuses) {
            #expect(lhs.0 == rhs.0)
            #expect(lhs.1 == rhs.1)
        }
        #expect(production.deduplicatedArticles.count == diagnostics.deduplicatedArticles.count)
    }

    // MARK: - Helpers

    private static func makeSource(
        id: String,
        feedURLString: String?
    ) -> RSSFeedSource {
        RSSFeedSource(
            id: id,
            outletName: "Outlet \(id)",
            region: .europeWide,
            feedURLString: feedURLString,
            isMainOutlet: false,
            languageCode: "en",
            tags: [],
            note: nil
        )
    }
}
