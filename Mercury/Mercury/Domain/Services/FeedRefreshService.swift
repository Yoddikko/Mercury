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
    private let articleContentEnrichmentService: ArticleContentEnrichmentService
    private let logger: AppLogger
    private let maxConcurrentSourceChecks: Int
    private let maxArticlesPerSource: Int

    init(
        feedClient: RSSFeedClient = RSSFeedClient(),
        parser: RSSParser = RSSParser(),
        normalizer: ArticleNormalizer = ArticleNormalizer(),
        articleContentEnrichmentService: ArticleContentEnrichmentService = ArticleContentEnrichmentService(),
        logger: AppLogger = .shared,
        maxConcurrentSourceChecks: Int = 4,
        maxArticlesPerSource: Int = 30
    ) {
        self.feedClient = feedClient
        self.parser = parser
        self.normalizer = normalizer
        self.articleContentEnrichmentService = articleContentEnrichmentService
        self.logger = logger
        self.maxConcurrentSourceChecks = max(1, maxConcurrentSourceChecks)
        self.maxArticlesPerSource = max(1, maxArticlesPerSource)
    }

    // MARK: - Production surface

    /// Production-facing fetch used by the Home feed pipeline. Returns the
    /// same `RSSFeedBatchResult` shape as `runDiagnostics`, but logs at a
    /// level appropriate for normal user-facing refreshes and skips the
    /// developer-only batch summary lines.
    ///
    /// Use this method from view models and use cases that need feed
    /// content. Use `runDiagnostics(...)` only from the Developer
    /// Playground where the extra batch instrumentation is the point.
    func refreshFeed(
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String? = nil
    ) async -> RSSFeedBatchResult {
        let sources = RSSFeedCatalog.sources(for: groupMode, region: selectedRegion)
        return await refreshFeed(
            sources: sources,
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            requestID: requestID
        )
    }

    /// Production fetch overload that lets callers pre-select the
    /// `RSSFeedSource` list. Primarily used by tests so the production
    /// surface can be exercised without spinning up the live RSS stack.
    func refreshFeed(
        sources: [RSSFeedSource],
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String? = nil
    ) async -> RSSFeedBatchResult {
        let resolvedRequestID = requestID ?? "rss-refresh-\(UUID().uuidString.lowercased())"

        logger.info(
            "Starting RSS feed refresh",
            category: .business,
            service: "FeedRefreshService",
            requestID: resolvedRequestID,
            metadata: [
                "group_mode": groupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none",
                "sources_count": "\(sources.count)"
            ]
        )

        let startedAt = DispatchTime.now().uptimeNanoseconds
        let result = await performFetch(
            sources: sources,
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            requestID: resolvedRequestID
        )
        let elapsedMs = elapsedMilliseconds(since: startedAt)

        logger.info(
            "RSS feed refresh completed",
            category: .business,
            service: "FeedRefreshService",
            requestID: resolvedRequestID,
            metadata: [
                "group_mode": groupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none",
                "articles_out": "\(result.deduplicatedArticles.count)",
                "duration_ms": "\(elapsedMs)"
            ]
        )

        return result
    }

    // MARK: - Diagnostics surface

    /// Developer-Playground entrypoint. Performs the same fetch as
    /// `refreshFeed` but emits a richer batch-level summary log with
    /// per-status counts so the diagnostics screen can be reasoned about
    /// from exported logs alone.
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

    /// Developer-Playground entrypoint that lets callers pre-select the
    /// `RSSFeedSource` list (for example to re-run a single failed
    /// outlet). Mirrors `runDiagnostics(groupMode:selectedRegion:)` in
    /// instrumentation.
    func runDiagnostics(
        sources: [RSSFeedSource],
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String? = nil
    ) async -> RSSFeedBatchResult {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let result = await performFetch(
            sources: sources,
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            requestID: requestID
        )
        let elapsedMs = elapsedMilliseconds(since: startedAt)
        let concurrencyLimit = sources.isEmpty ? 0 : min(maxConcurrentSourceChecks, sources.count)

        logger.info(
            "RSS diagnostics batch completed",
            category: .business,
            service: "FeedRefreshService",
            requestID: requestID,
            metadata: [
                "group_mode": groupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none",
                "checks_total": "\(result.checks.count)",
                "checks_success": "\(result.checks.filter { $0.status == .success }.count)",
                "checks_failed": "\(result.checks.filter { $0.status == .requestFailed || $0.status == .parseFailed }.count)",
                "deduplicated_articles": "\(result.deduplicatedArticles.count)",
                "max_concurrent_sources": "\(concurrencyLimit)",
                "max_articles_per_source": "\(maxArticlesPerSource)",
                "duration_ms": "\(elapsedMs)"
            ]
        )

        return result
    }

    // MARK: - Shared fetch core

    /// Shared implementation behind `refreshFeed` and `runDiagnostics`.
    /// Fans out source checks under the configured concurrency cap and
    /// returns the deduplicated batch result. Per-source instrumentation
    /// stays on `checkSource` so both callers benefit from the same
    /// trace-level visibility when investigating a feed.
    private func performFetch(
        sources: [RSSFeedSource],
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String?
    ) async -> RSSFeedBatchResult {
        var checks: [RSSFeedCheckResult] = []
        checks.reserveCapacity(sources.count)
        let concurrencyLimit = sources.isEmpty ? 0 : min(maxConcurrentSourceChecks, sources.count)

        await withTaskGroup(of: RSSFeedCheckResult.self) { group in
            var sourceIterator = sources.makeIterator()

            for _ in 0..<concurrencyLimit {
                guard let source = sourceIterator.next() else { break }
                group.addTask {
                    await checkSource(source, requestID: requestID)
                }
            }

            while let check = await group.next() {
                checks.append(check)
                if let nextSource = sourceIterator.next() {
                    group.addTask {
                        await checkSource(nextSource, requestID: requestID)
                    }
                }
            }
        }

        let orderedChecks = checks.sorted { lhs, rhs in
            if lhs.source.region.rawValue != rhs.source.region.rawValue {
                return lhs.source.region.rawValue < rhs.source.region.rawValue
            }
            return lhs.source.outletName.localizedCaseInsensitiveCompare(rhs.source.outletName) == .orderedAscending
        }

        let deduplicated = deduplicatedArticles(from: orderedChecks, requestID: requestID)

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
            let normalizedArticles = normalizer.normalize(
                items: parsedItems,
                source: source,
                requestID: sourceRequestID
            )
            let articlesForBatch = Array(normalizedArticles.prefix(maxArticlesPerSource))

            if normalizedArticles.count > articlesForBatch.count {
                logger.trace(
                    "Trimmed normalized articles to per-source cap",
                    category: .business,
                    service: "FeedRefreshService",
                    requestID: sourceRequestID,
                    metadata: [
                        "source_id": source.id,
                        "articles_in": "\(normalizedArticles.count)",
                        "articles_kept": "\(articlesForBatch.count)",
                        "articles_dropped": "\(normalizedArticles.count - articlesForBatch.count)"
                    ]
                )
            }

            let enrichedArticles = await articleContentEnrichmentService.enrichArticlesIfNeeded(
                articlesForBatch,
                requestID: sourceRequestID
            )
            let elapsedMs = elapsedMilliseconds(since: start)

            if enrichedArticles.isEmpty {
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
                    "articles_count": "\(enrichedArticles.count)",
                    "elapsed_ms": "\(elapsedMs)"
                ]
            )

            return RSSFeedCheckResult(
                source: source,
                status: .success,
                articles: enrichedArticles,
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
