//
//  FeedRefreshService.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

struct FeedRefreshService: Sendable {
    private let feedClient: RSSFeedClient
    private let parser: RSSParser
    private let normalizer: ArticleNormalizer

    init(
        feedClient: RSSFeedClient = RSSFeedClient(),
        parser: RSSParser = RSSParser(),
        normalizer: ArticleNormalizer = ArticleNormalizer()
    ) {
        self.feedClient = feedClient
        self.parser = parser
        self.normalizer = normalizer
    }

    func runDiagnostics(
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?
    ) async -> RSSFeedBatchResult {
        let sources = RSSFeedCatalog.sources(for: groupMode, region: selectedRegion)
        return await runDiagnostics(
            sources: sources,
            groupMode: groupMode,
            selectedRegion: selectedRegion
        )
    }

    func runDiagnostics(
        sources: [RSSFeedSource],
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?
    ) async -> RSSFeedBatchResult {
        var checks: [RSSFeedCheckResult] = []
        checks.reserveCapacity(sources.count)

        await withTaskGroup(of: RSSFeedCheckResult.self) { group in
            for source in sources {
                group.addTask {
                    await checkSource(source)
                }
            }

            for await check in group {
                checks.append(check)
            }
        }

        let orderedChecks = checks.sorted { lhs, rhs in
            if lhs.source.region.rawValue != rhs.source.region.rawValue {
                return lhs.source.region.rawValue < rhs.source.region.rawValue
            }
            return lhs.source.outletName.localizedCaseInsensitiveCompare(rhs.source.outletName) == .orderedAscending
        }

        return RSSFeedBatchResult(
            checkedAt: Date(),
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            checks: orderedChecks,
            deduplicatedArticles: deduplicatedArticles(from: orderedChecks)
        )
    }

    private func checkSource(_ source: RSSFeedSource) async -> RSSFeedCheckResult {
        let start = DispatchTime.now().uptimeNanoseconds

        guard source.feedURLString != nil else {
            return RSSFeedCheckResult(
                source: source,
                status: .noFeedURL,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: source.note ?? "No feed URL was documented for this outlet."
            )
        }

        guard let url = source.resolvedURL else {
            return RSSFeedCheckResult(
                source: source,
                status: .invalidFeedURL,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: "Feed URL format is invalid: \(source.feedURLString ?? "")"
            )
        }

        do {
            let data = try await feedClient.fetchFeedData(from: url)
            let parsedItems = try parser.parse(data: data)
            let articles = normalizer.normalize(items: parsedItems, source: source)

            if articles.isEmpty {
                return RSSFeedCheckResult(
                    source: source,
                    status: .noArticles,
                    articles: [],
                    elapsedMs: elapsedMilliseconds(since: start),
                    message: "Feed parsed but no valid articles were normalized."
                )
            }

            return RSSFeedCheckResult(
                source: source,
                status: .success,
                articles: articles,
                elapsedMs: elapsedMilliseconds(since: start),
                message: nil
            )
        } catch let error as RSSFeedClientError {
            return RSSFeedCheckResult(
                source: source,
                status: .requestFailed,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: requestFailureMessage(error)
            )
        } catch let error as RSSParserError {
            return RSSFeedCheckResult(
                source: source,
                status: .parseFailed,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: parseFailureMessage(error)
            )
        } catch {
            return RSSFeedCheckResult(
                source: source,
                status: .requestFailed,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: error.localizedDescription
            )
        }
    }

    private func requestFailureMessage(_ error: RSSFeedClientError) -> String {
        switch error {
        case .invalidResponse:
            return "The feed response was not an HTTP response."
        case let .httpStatusCode(code):
            return "Feed request failed with HTTP status \(code)."
        case .emptyResponseData:
            return "The feed returned an empty payload."
        }
    }

    private func parseFailureMessage(_ error: RSSParserError) -> String {
        switch error {
        case .invalidXML:
            return "Feed payload is not valid XML."
        }
    }

    private func deduplicatedArticles(from checks: [RSSFeedCheckResult]) -> [Article] {
        var seenKeys = Set<String>()
        var deduplicated: [Article] = []

        for check in checks {
            for article in check.articles {
                let key = normalizer.dedupeKey(for: article)
                guard seenKeys.insert(key).inserted else { continue }
                deduplicated.append(article)
            }
        }

        return deduplicated.sorted { lhs, rhs in
            lhs.publishedAt > rhs.publishedAt
        }
    }

    private func elapsedMilliseconds(since start: UInt64) -> Int {
        let now = DispatchTime.now().uptimeNanoseconds
        return Int((now - start) / 1_000_000)
    }
}
