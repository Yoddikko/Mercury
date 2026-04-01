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
    private let logger: AppLogger

    init(
        feedClient: RSSFeedClient = RSSFeedClient(),
        parser: RSSParser = RSSParser(),
        normalizer: ArticleNormalizer = ArticleNormalizer(),
        logger: AppLogger = .shared
    ) {
        self.feedClient = feedClient
        self.parser = parser
        self.normalizer = normalizer
        self.logger = logger
    }

    func runDiagnostics(
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?
    ) async -> RSSFeedBatchResult {
        let requestID = "rss-batch-\(UUID().uuidString.lowercased())"
        let sources = RSSFeedCatalog.sources(for: groupMode, region: selectedRegion)

        logger.info(
            "Starting RSS diagnostics batch",
            category: .business,
            service: "FeedRefreshService",
            requestID: requestID,
            metadata: [
                "group_mode": groupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none",
                "sources_count": "\(sources.count)"
            ]
        )

        return await runDiagnostics(
            sources: sources,
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            requestID: requestID
        )
    }

    func runDiagnostics(
        sources: [RSSFeedSource],
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String? = nil
    ) async -> RSSFeedBatchResult {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var checks: [RSSFeedCheckResult] = []
        checks.reserveCapacity(sources.count)

        await withTaskGroup(of: RSSFeedCheckResult.self) { group in
            for source in sources {
                group.addTask {
                    await checkSource(source, requestID: requestID)
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

        let deduplicated = deduplicatedArticles(from: orderedChecks, requestID: requestID)
        let elapsedMs = elapsedMilliseconds(since: startedAt)

        logger.info(
            "RSS diagnostics batch completed",
            category: .business,
            service: "FeedRefreshService",
            requestID: requestID,
            metadata: [
                "group_mode": groupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none",
                "checks_total": "\(orderedChecks.count)",
                "checks_success": "\(orderedChecks.filter { $0.status == .success }.count)",
                "checks_failed": "\(orderedChecks.filter { $0.status == .requestFailed || $0.status == .parseFailed }.count)",
                "deduplicated_articles": "\(deduplicated.count)",
                "duration_ms": "\(elapsedMs)"
            ]
        )

        return RSSFeedBatchResult(
            checkedAt: Date(),
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            checks: orderedChecks,
            deduplicatedArticles: deduplicated
        )
    }

    private func checkSource(_ source: RSSFeedSource, requestID: String?) async -> RSSFeedCheckResult {
        let start = DispatchTime.now().uptimeNanoseconds
        let sourceRequestID = sourceRequestID(for: source, parentRequestID: requestID)

        logger.trace(
            "Checking RSS source",
            category: .business,
            service: "FeedRefreshService",
            requestID: sourceRequestID,
            metadata: [
                "source_id": source.id,
                "outlet": source.outletName,
                "region": source.region.rawValue
            ]
        )

        guard source.feedURLString != nil else {
            logger.warn(
                "Source has no documented feed URL",
                category: .business,
                service: "FeedRefreshService",
                requestID: sourceRequestID,
                metadata: ["source_id": source.id]
            )
            return RSSFeedCheckResult(
                source: source,
                status: .noFeedURL,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: source.note ?? "No feed URL was documented for this outlet."
            )
        }

        guard let url = source.resolvedURL else {
            logger.warn(
                "Source has invalid feed URL format",
                category: .business,
                service: "FeedRefreshService",
                requestID: sourceRequestID,
                metadata: [
                    "source_id": source.id,
                    "feed_url": source.feedURLString ?? "missing"
                ]
            )
            return RSSFeedCheckResult(
                source: source,
                status: .invalidFeedURL,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: "Feed URL format is invalid: \(source.feedURLString ?? "")"
            )
        }

        do {
            let data = try await feedClient.fetchFeedData(from: url, requestID: sourceRequestID)
            let parsedItems = try parser.parse(data: data, requestID: sourceRequestID)
            let articles = normalizer.normalize(
                items: parsedItems,
                source: source,
                requestID: sourceRequestID
            )
            let elapsedMs = elapsedMilliseconds(since: start)

            if articles.isEmpty {
                logger.info(
                    "Feed parsed with no normalized articles",
                    category: .business,
                    service: "FeedRefreshService",
                    requestID: sourceRequestID,
                    metadata: [
                        "source_id": source.id,
                        "elapsed_ms": "\(elapsedMs)"
                    ]
                )
                return RSSFeedCheckResult(
                    source: source,
                    status: .noArticles,
                    articles: [],
                    elapsedMs: elapsedMs,
                    message: "Feed parsed but no valid articles were normalized."
                )
            }

            logger.debug(
                "Source check completed successfully",
                category: .business,
                service: "FeedRefreshService",
                requestID: sourceRequestID,
                metadata: [
                    "source_id": source.id,
                    "articles_count": "\(articles.count)",
                    "elapsed_ms": "\(elapsedMs)"
                ]
            )

            return RSSFeedCheckResult(
                source: source,
                status: .success,
                articles: articles,
                elapsedMs: elapsedMs,
                message: nil
            )
        } catch let error as RSSFeedClientError {
            logger.error(
                "Source check failed during feed request",
                category: .api,
                service: "FeedRefreshService",
                requestID: sourceRequestID,
                metadata: [
                    "source_id": source.id,
                    "error": "\(error)"
                ]
            )
            return RSSFeedCheckResult(
                source: source,
                status: .requestFailed,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: requestFailureMessage(error)
            )
        } catch let error as RSSParserError {
            logger.error(
                "Source check failed during feed parsing",
                category: .business,
                service: "FeedRefreshService",
                requestID: sourceRequestID,
                metadata: [
                    "source_id": source.id,
                    "error": "\(error)"
                ]
            )
            return RSSFeedCheckResult(
                source: source,
                status: .parseFailed,
                articles: [],
                elapsedMs: elapsedMilliseconds(since: start),
                message: parseFailureMessage(error)
            )
        } catch {
            logger.error(
                "Source check failed with unexpected error",
                category: .business,
                service: "FeedRefreshService",
                requestID: sourceRequestID,
                metadata: [
                    "source_id": source.id,
                    "error": error.localizedDescription
                ]
            )
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
        case .insecureTransport:
            return "Feed URL must use HTTPS transport."
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

    private func deduplicatedArticles(
        from checks: [RSSFeedCheckResult],
        requestID: String?
    ) -> [Article] {
        var deduplicatedByKey: [String: Article] = [:]

        for check in checks {
            for article in check.articles {
                let key = normalizer.dedupeKey(for: article)
                if let existing = deduplicatedByKey[key] {
                    if article.publishedAt > existing.publishedAt {
                        deduplicatedByKey[key] = article
                    }
                    continue
                }
                deduplicatedByKey[key] = article
            }
        }

        let sortedArticles = deduplicatedByKey.values.sorted { lhs, rhs in
            lhs.publishedAt > rhs.publishedAt
        }

        logger.debug(
            "Deduplicated batch articles",
            category: .business,
            service: "FeedRefreshService",
            requestID: requestID,
            metadata: [
                "checks_count": "\(checks.count)",
                "articles_out": "\(sortedArticles.count)"
            ]
        )

        return sortedArticles
    }

    private func elapsedMilliseconds(since start: UInt64) -> Int {
        let now = DispatchTime.now().uptimeNanoseconds
        return Int((now - start) / 1_000_000)
    }

    private func sourceRequestID(for source: RSSFeedSource, parentRequestID: String?) -> String {
        if let parentRequestID {
            return "\(parentRequestID):\(source.id)"
        }
        return "rss-source-\(source.id)-\(UUID().uuidString.lowercased())"
    }
}
