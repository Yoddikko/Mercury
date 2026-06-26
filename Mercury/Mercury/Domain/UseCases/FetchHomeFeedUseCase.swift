//
//  FetchHomeFeedUseCase.swift
//  Mercury
//
//  Created by Codex on 26/06/26.
//

import Foundation

/// Orchestration entrypoint for the Home feed pipeline.
///
/// A use case sits between view models and the underlying services /
/// repositories: the view model knows "give me the latest feed and keep
/// the cache fresh", but does not know that this requires hitting the
/// RSS stack and then writing the result through the article repository.
///
/// `FetchHomeFeedUseCase` orchestrates that two-step flow:
///
/// 1. ask `FeedRefreshService.refreshFeed(...)` for the deduplicated batch
///    of articles produced by the live RSS pipeline,
/// 2. forward the resulting `Article` set into `ArticleRepository.upsertAll`
///    so the on-device cache stays current and the app remains usable
///    offline once content has been retrieved.
///
/// Persistence failures are intentionally non-fatal: the use case logs the
/// error and still returns the freshly fetched `RSSFeedBatchResult` so the
/// UI can render new content even when the cache write fails. This mirrors
/// the partial-success behavior documented in
/// `docs/architecture/ARCHITECTURE.md` (§4.15 Error Handling: "partial
/// success over total failure").
protocol FetchHomeFeedUseCase: Sendable {
    /// Run the full Home-feed refresh pipeline.
    ///
    /// - Parameters:
    ///   - groupMode: which `RSSFeedCatalog` partition to fetch (typically
    ///     `.mainOutlets` for production calls).
    ///   - selectedRegion: optional region filter for region-scoped
    ///     refreshes; `nil` means "all regions in the group".
    ///   - requestID: caller-provided trace id; when `nil` the use case
    ///     mints one so AppLogger entries stay correlatable across layers.
    /// - Returns: the deduplicated `RSSFeedBatchResult` produced by
    ///   `FeedRefreshService`, untouched by the persistence step.
    func execute(
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String?
    ) async -> RSSFeedBatchResult
}

extension FetchHomeFeedUseCase {
    func execute(
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?
    ) async -> RSSFeedBatchResult {
        await execute(
            groupMode: groupMode,
            selectedRegion: selectedRegion,
            requestID: nil
        )
    }
}

/// Production `FetchHomeFeedUseCase` wiring the live RSS pipeline and the
/// `ArticleRepository` cache.
struct LiveFetchHomeFeedUseCase: FetchHomeFeedUseCase {
    private static let serviceName = "FetchHomeFeedUseCase"

    /// Closure that fetches the next deduplicated `RSSFeedBatchResult`.
    /// Production wiring wraps `FeedRefreshService.refreshFeed(...)`;
    /// tests inject a stub so the orchestration can be exercised without
    /// the live RSS stack.
    typealias RefreshAction = @Sendable (
        _ groupMode: RSSFeedGroupMode,
        _ selectedRegion: RSSFeedRegion?,
        _ requestID: String
    ) async -> RSSFeedBatchResult

    private let refreshAction: RefreshAction
    private let articleRepository: ArticleRepository
    private let logger: AppLogger

    /// Production initializer that wraps the live
    /// `FeedRefreshService.refreshFeed(...)` surface.
    init(
        feedRefreshService: FeedRefreshService,
        articleRepository: ArticleRepository,
        logger: AppLogger = .shared
    ) {
        self.init(
            refreshAction: { groupMode, region, requestID in
                await feedRefreshService.refreshFeed(
                    groupMode: groupMode,
                    selectedRegion: region,
                    requestID: requestID
                )
            },
            articleRepository: articleRepository,
            logger: logger
        )
    }

    /// Designated initializer accepting a closure-based refresh seam so
    /// tests can drive every branch of the orchestration without spinning
    /// up the live RSS stack.
    init(
        refreshAction: @escaping RefreshAction,
        articleRepository: ArticleRepository,
        logger: AppLogger = .shared
    ) {
        self.refreshAction = refreshAction
        self.articleRepository = articleRepository
        self.logger = logger
    }

    func execute(
        groupMode: RSSFeedGroupMode,
        selectedRegion: RSSFeedRegion?,
        requestID: String?
    ) async -> RSSFeedBatchResult {
        let flowRequestID = requestID ?? "home-feed-uc-\(UUID().uuidString.lowercased())"

        logger.info(
            "FetchHomeFeedUseCase started",
            category: .business,
            service: Self.serviceName,
            requestID: flowRequestID,
            metadata: [
                "group_mode": groupMode.rawValue,
                "selected_region": selectedRegion?.rawValue ?? "none"
            ]
        )

        let result = await refreshAction(groupMode, selectedRegion, flowRequestID)

        await persistArticles(result.deduplicatedArticles, requestID: flowRequestID)

        logger.info(
            "FetchHomeFeedUseCase completed",
            category: .business,
            service: Self.serviceName,
            requestID: flowRequestID,
            metadata: [
                "articles_out": "\(result.deduplicatedArticles.count)",
                "checks_total": "\(result.checks.count)"
            ]
        )

        return result
    }

    // MARK: - Private

    private func persistArticles(_ articles: [Article], requestID: String) async {
        guard articles.isEmpty == false else {
            logger.trace(
                "Skipping cache write: empty article batch",
                category: .database,
                service: Self.serviceName,
                requestID: requestID
            )
            return
        }

        let entities = articles.map(ArticleEntityMapper.makeEntity(from:))
        do {
            let persisted = try await articleRepository.upsertAll(entities, requestID: requestID)
            logger.debug(
                "FetchHomeFeedUseCase persisted articles",
                category: .database,
                service: Self.serviceName,
                requestID: requestID,
                metadata: [
                    "articles_in": "\(articles.count)",
                    "articles_persisted": "\(persisted)"
                ]
            )
        } catch {
            // Partial success: surface the failure as a log, but still let
            // the UI render the freshly fetched batch.
            logger.error(
                "FetchHomeFeedUseCase cache write failed",
                category: .database,
                service: Self.serviceName,
                requestID: requestID,
                metadata: [
                    "articles_in": "\(articles.count)",
                    "error": String(describing: error)
                ]
            )
        }
    }
}
