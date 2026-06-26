//
//  ArticleDetailViewModel.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Combine
import Foundation

/// Presentation-layer view model driving `ArticleDetailScreen`.
///
/// The view model is a small state machine:
///
/// `idle → loading → loaded(article)` (with `error(message)` as a terminal
/// failure branch).
///
/// All persistence and network side effects are injected as closures so the
/// view model stays trivially testable without dragging in `ModelContext`,
/// `URLSession`, or any concrete service. The factory provided by
/// `DependencyContainer` wires the production seams (the
/// `ArticleLocalStore` for favorites/history and
/// `ArticleContentEnrichmentService` for full-body extraction).
///
/// The repository/use-case layers are tracked by issues #29 and #30; this
/// view model intentionally talks to the existing services directly without
/// introducing new abstractions.
@MainActor
final class ArticleDetailViewModel: ObservableObject {
    enum DetailState: Equatable {
        case idle
        case loading
        case loaded(article: Article)
        case error(message: String)
    }

    enum EnrichmentState: Equatable {
        case idle
        case enriching
        case failed
    }

    /// State machine for the on-screen AI summary section.
    ///
    /// * `idle` — no provider configured (no summarize slot wired) or no
    ///   summary attempted yet.
    /// * `summarizing` — provider call in flight.
    /// * `ready(summary)` — short summary + bullets available for the UI.
    /// * `failed(message)` — provider/persistence failure, message ready for
    ///   localized fallback rendering.
    enum SummaryState: Equatable {
        case idle
        case summarizing
        case ready(summary: AISummaryResult)
        case failed(message: String)
    }

    typealias BookmarkToggle = @Sendable (String) async throws -> Bool
    typealias RecordOpen = @Sendable (String) async throws -> Void
    typealias EnrichContent = @Sendable (Article) async -> Article?
    typealias Summarize = @Sendable (Article) async throws -> AISummaryResult

    @Published private(set) var state: DetailState
    @Published private(set) var enrichmentState: EnrichmentState = .idle
    @Published private(set) var summaryState: SummaryState = .idle
    @Published private(set) var isTogglingBookmark: Bool = false

    private let initialArticle: Article
    private let bookmarkToggle: BookmarkToggle
    private let recordOpen: RecordOpen
    private let enrichContent: EnrichContent?
    private let summarize: Summarize?
    private let logger: AppLogger
    private var hasRecordedOpen: Bool = false
    private var enrichmentTask: Task<Void, Never>?
    private var summaryTask: Task<Void, Never>?

    init(
        article: Article,
        bookmarkToggle: @escaping BookmarkToggle,
        recordOpen: @escaping RecordOpen,
        enrichContent: EnrichContent? = nil,
        summarize: Summarize? = nil,
        logger: AppLogger = .shared
    ) {
        self.initialArticle = article
        self.bookmarkToggle = bookmarkToggle
        self.recordOpen = recordOpen
        self.enrichContent = enrichContent
        self.summarize = summarize
        self.logger = logger
        self.state = .loaded(article: article)
        if let cached = ArticleSummarizationService.cachedSummary(for: article) {
            self.summaryState = .ready(summary: cached)
        }
        logger.debug(
            "Initialized Article detail view model",
            category: .ui,
            service: "ArticleDetailViewModel",
            metadata: [
                "article_id": article.id,
                "source": article.sourceName,
                "is_content_complete": "\(article.isContentLikelyComplete)",
                "content_word_count": "\(article.contentWordCount)"
            ]
        )
    }

    deinit {
        enrichmentTask?.cancel()
        summaryTask?.cancel()
        logger.debug(
            "Deinitializing Article detail view model",
            category: .ui,
            service: "ArticleDetailViewModel"
        )
    }

    // MARK: - Localized copy

    var navigationTitle: String {
        String(localized: "article.detail.navigation.title", defaultValue: "Article")
    }

    var loadingLabel: String {
        String(localized: "article.detail.state.loading", defaultValue: "Loading the article…")
    }

    var emptyTitle: String {
        String(localized: "article.detail.state.empty.title", defaultValue: "Nothing to show")
    }

    var emptySubtitle: String {
        String(
            localized: "article.detail.state.empty.subtitle",
            defaultValue: "We couldn't find the body of this article."
        )
    }

    var errorTitle: String {
        String(localized: "article.detail.state.error.title", defaultValue: "We couldn't load the article")
    }

    var errorRetryLabel: String {
        String(localized: "article.detail.state.error.retry", defaultValue: "Try again")
    }

    var bodyPlaceholderLabel: String {
        String(
            localized: "article.detail.body.placeholder",
            defaultValue: "Full article body isn't available yet. Pull to refresh to fetch it."
        )
    }

    var enrichingLabel: String {
        String(
            localized: "article.detail.body.enriching",
            defaultValue: "Fetching the full article text…"
        )
    }

    var enrichmentFailedLabel: String {
        String(
            localized: "article.detail.body.enrichment_failed",
            defaultValue: "We couldn't fetch the full article text. You can still read what's available."
        )
    }

    var bookmarkAddLabel: String {
        String(localized: "article.detail.actions.bookmark.add", defaultValue: "Save article")
    }

    var bookmarkRemoveLabel: String {
        String(localized: "article.detail.actions.bookmark.remove", defaultValue: "Remove from saved")
    }

    var shareLabel: String {
        String(localized: "article.detail.actions.share", defaultValue: "Share article")
    }

    var openInSafariLabel: String {
        String(localized: "article.detail.actions.open_in_safari", defaultValue: "Open in Safari")
    }

    var summarySectionTitle: String {
        String(localized: "article.detail.section.summary", defaultValue: "Summary")
    }

    var aiSummarySectionTitle: String {
        String(localized: "article.detail.section.ai_summary", defaultValue: "AI Summary")
    }

    var aiSummaryLoadingLabel: String {
        String(
            localized: "article.detail.ai_summary.loading",
            defaultValue: "Generating AI summary…"
        )
    }

    var aiSummaryUnavailableLabel: String {
        String(
            localized: "article.detail.ai_summary.unavailable",
            defaultValue: "AI summary is not available. Configure an AI provider in Developer Tools to enable it."
        )
    }

    var aiSummaryFailedLabel: String {
        String(
            localized: "article.detail.ai_summary.failed",
            defaultValue: "We couldn't generate an AI summary right now. You can still read the article body below."
        )
    }

    var aiSummaryRegenerateLabel: String {
        String(
            localized: "article.detail.ai_summary.regenerate",
            defaultValue: "Try again"
        )
    }

    var aiSummaryGenerateLabel: String {
        String(
            localized: "article.detail.ai_summary.generate",
            defaultValue: "Generate AI summary"
        )
    }

    var aiSummaryGenerateAccessibilityHint: String {
        String(
            localized: "article.detail.ai_summary.generate.accessibility_hint",
            defaultValue: "Generates an AI summary of the article on demand."
        )
    }

    var aiSummaryRegenerateAffordanceLabel: String {
        String(
            localized: "article.detail.ai_summary.regenerate_affordance",
            defaultValue: "Regenerate"
        )
    }

    var aiSummaryRegenerateAffordanceAccessibilityHint: String {
        String(
            localized: "article.detail.ai_summary.regenerate_affordance.accessibility_hint",
            defaultValue: "Discards the cached AI summary and generates a new one."
        )
    }

    var aiSummaryBulletsAccessibilityLabel: String {
        String(
            localized: "article.detail.ai_summary.bullets.accessibility",
            defaultValue: "Key points"
        )
    }

    var bodySectionTitle: String {
        String(localized: "article.detail.section.body", defaultValue: "Article")
    }

    var heroImageAccessibilityLabel: String {
        String(localized: "article.detail.hero.accessibility", defaultValue: "Article hero image")
    }

    var bookmarkedAccessibilityValue: String {
        String(localized: "article.detail.bookmarked.accessibility", defaultValue: "Bookmarked")
    }

    var notBookmarkedAccessibilityValue: String {
        String(localized: "article.detail.not_bookmarked.accessibility", defaultValue: "Not bookmarked")
    }

    func metadataLine(for article: Article) -> String {
        let format = String(
            localized: "article.detail.metadata.format",
            defaultValue: "%@ • %@"
        )
        return String(
            format: format,
            locale: .current,
            article.sourceName,
            Self.dateFormatter.string(from: article.publishedAt)
        )
    }

    func authorLine(for article: Article) -> String? {
        guard let author = article.authorName?.trimmingCharacters(in: .whitespacesAndNewlines),
              author.isEmpty == false else {
            return nil
        }
        let format = String(localized: "article.detail.author.format", defaultValue: "By %@")
        return String(format: format, locale: .current, author)
    }

    // MARK: - State helpers

    var currentArticle: Article? {
        if case let .loaded(article) = state { return article }
        return nil
    }

    var displayBody: String? {
        guard let article = currentArticle else { return nil }
        if let cleaned = article.cleanedContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           cleaned.isEmpty == false {
            return cleaned
        }
        if let raw = article.rawContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           raw.isEmpty == false {
            return raw
        }
        return nil
    }

    var shouldShowBodyPlaceholder: Bool {
        guard currentArticle != nil else { return false }
        return displayBody == nil && enrichmentState != .enriching
    }

    var shouldAttemptEnrichment: Bool {
        guard let article = currentArticle else { return false }
        guard enrichContent != nil else { return false }
        if article.isContentLikelyComplete && article.contentWordCount >= 220 {
            return false
        }
        return true
    }

    /// Whether a summary section should be rendered at all.
    /// True when either a summary is cached, a provider closure is wired,
    /// or a previous attempt left the state in `summarizing`/`failed`.
    var shouldShowAISummarySection: Bool {
        if case .ready = summaryState { return true }
        if case .summarizing = summaryState { return true }
        if case .failed = summaryState { return true }
        return summarize != nil
    }

    /// Whether the "AI provider not configured" fallback should be shown.
    var shouldShowAISummaryUnavailable: Bool {
        guard summarize == nil else { return false }
        if case .ready = summaryState { return false }
        return true
    }

    /// Whether the on-demand "Generate AI summary" button should be exposed
    /// in the idle, no-cached-summary state.
    var shouldShowAISummaryGenerateButton: Bool {
        guard summarize != nil else { return false }
        if case .idle = summaryState { return true }
        return false
    }

    /// Whether a manual regenerate affordance should be exposed.
    /// Surfaced both after a failure (as a retry) and alongside a cached
    /// summary (as the "Regenerate" button).
    var canRegenerateAISummary: Bool {
        guard summarize != nil else { return false }
        switch summaryState {
        case .failed, .ready:
            return true
        case .idle, .summarizing:
            return false
        }
    }

    // MARK: - Lifecycle hooks

    /// Invoked when the screen appears: marks the article as opened in the
    /// local history (idempotent) and, if needed, fires off background
    /// enrichment of the body. AI summarization is NOT triggered here — it
    /// only runs when the user taps the "Generate AI summary" button (see
    /// `requestSummary()`), per `docs/features/SUMMARIZATION.md`.
    func onAppear() async {
        await recordOpenIfNeeded()
        if shouldAttemptEnrichment {
            startEnrichmentIfNeeded()
        }
    }

    /// User-initiated request to generate an AI summary. Reuses the cached
    /// summary if available; otherwise calls the configured `summarize`
    /// closure. Triggered exclusively by the "Generate AI summary" button on
    /// the article detail screen — never automatically.
    func requestSummary() async {
        guard summarize != nil else { return }
        if case .summarizing = summaryState { return }
        let requestID = "article-detail-summary-tap-\(UUID().uuidString.lowercased())"
        logger.info(
            "Article AI summary requested by user tap",
            category: .ui,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: [
                "article_id": currentArticle?.id ?? "<unknown>",
                "has_cached_summary": "\(currentArticle.flatMap(ArticleSummarizationService.cachedSummary(for:)) != nil)"
            ]
        )
        summaryTask?.cancel()
        await runSummarization(force: false)
    }

    /// Force a fresh AI summary generation, bypassing any cached result.
    /// Used by the "Regenerate" affordance when a cached summary already
    /// exists and by the retry button after a failure.
    func regenerateSummary() async {
        guard summarize != nil else { return }
        if case .summarizing = summaryState { return }
        let requestID = "article-detail-summary-regenerate-\(UUID().uuidString.lowercased())"
        logger.info(
            "Article AI summary regenerate requested by user tap",
            category: .ui,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: [
                "article_id": currentArticle?.id ?? "<unknown>"
            ]
        )
        summaryTask?.cancel()
        await runSummarization(force: true)
    }

    /// Trigger a manual refresh of the body content. Re-runs enrichment
    /// regardless of completeness so the user can retry after a failure.
    func refresh() async {
        guard enrichContent != nil else { return }
        enrichmentTask?.cancel()
        await runEnrichment(force: true)
    }

    // MARK: - Actions

    /// Toggle the bookmark on the current article. Updates the local state
    /// optimistically when the underlying store succeeds.
    func toggleBookmark() async {
        guard let article = currentArticle else { return }
        guard isTogglingBookmark == false else { return }
        isTogglingBookmark = true
        defer { isTogglingBookmark = false }

        let requestID = "article-detail-bookmark-\(UUID().uuidString.lowercased())"
        logger.info(
            "Article bookmark toggle requested",
            category: .ui,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: [
                "article_id": article.id,
                "current_state": "\(article.isBookmarked)"
            ]
        )

        do {
            let newValue = try await bookmarkToggle(article.id)
            updateArticle(setBookmarked: newValue)
            logger.info(
                "Article bookmark toggle completed",
                category: .ui,
                service: "ArticleDetailViewModel",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "new_state": "\(newValue)"
                ]
            )
        } catch {
            logger.error(
                "Article bookmark toggle failed",
                category: .ui,
                service: "ArticleDetailViewModel",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "error": String(describing: error)
                ]
            )
        }
    }

    // MARK: - Private

    private func recordOpenIfNeeded() async {
        guard hasRecordedOpen == false else { return }
        hasRecordedOpen = true

        guard let article = currentArticle else { return }
        let requestID = "article-detail-open-\(UUID().uuidString.lowercased())"
        logger.info(
            "Article open recorded",
            category: .business,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: ["article_id": article.id]
        )

        do {
            try await recordOpen(article.id)
            updateArticle(markRead: true)
        } catch {
            // Record-open is best-effort: failure should not prevent the
            // user from reading the article.
            logger.warn(
                "Article open recording failed",
                category: .business,
                service: "ArticleDetailViewModel",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "error": String(describing: error)
                ]
            )
        }
    }

    private func startEnrichmentIfNeeded() {
        guard enrichmentTask == nil else { return }
        enrichmentTask = Task { [weak self] in
            await self?.runEnrichment(force: false)
        }
    }

    private func runEnrichment(force: Bool) async {
        defer { enrichmentTask = nil }
        guard let enrichContent else { return }
        guard let article = currentArticle else { return }
        if force == false, article.isContentLikelyComplete, article.contentWordCount >= 220 {
            return
        }

        let requestID = "article-detail-enrich-\(UUID().uuidString.lowercased())"
        enrichmentState = .enriching
        logger.info(
            "Article body enrichment requested",
            category: .business,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: [
                "article_id": article.id,
                "force": "\(force)",
                "content_word_count": "\(article.contentWordCount)"
            ]
        )

        let enriched = await enrichContent(article)

        if Task.isCancelled {
            enrichmentState = .idle
            logger.debug(
                "Article body enrichment cancelled",
                category: .business,
                service: "ArticleDetailViewModel",
                requestID: requestID
            )
            return
        }

        guard let enriched else {
            enrichmentState = .failed
            logger.warn(
                "Article body enrichment failed",
                category: .business,
                service: "ArticleDetailViewModel",
                requestID: requestID,
                metadata: ["article_id": article.id]
            )
            return
        }

        replaceArticle(with: enriched)
        enrichmentState = .idle
        logger.info(
            "Article body enrichment completed",
            category: .business,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: [
                "article_id": enriched.id,
                "new_word_count": "\(enriched.contentWordCount)",
                "is_content_complete": "\(enriched.isContentLikelyComplete)"
            ]
        )
    }

    private func updateArticle(
        setBookmarked: Bool? = nil,
        markRead: Bool? = nil
    ) {
        guard let current = currentArticle else { return }
        var newBookmarked = current.isBookmarked
        var newRead = current.isRead
        if let value = setBookmarked {
            newBookmarked = value
        }
        if let value = markRead {
            newRead = value
        }
        let updated = Article(
            id: current.id,
            externalID: current.externalID,
            title: current.title,
            sourceName: current.sourceName,
            sourceURL: current.sourceURL,
            articleURL: current.articleURL,
            publishedAt: current.publishedAt,
            authorName: current.authorName,
            heroImageURL: current.heroImageURL,
            rawContent: current.rawContent,
            cleanedContent: current.cleanedContent,
            contentSource: current.contentSource,
            contentWordCount: current.contentWordCount,
            isContentLikelyComplete: current.isContentLikelyComplete,
            summaryShort: current.summaryShort,
            summaryBullets: current.summaryBullets,
            category: current.category,
            tags: current.tags,
            language: current.language,
            isBookmarked: newBookmarked,
            isRead: newRead,
            clusterID: current.clusterID,
            createdAt: current.createdAt,
            updatedAt: .now
        )
        state = .loaded(article: updated)
    }

    private func replaceArticle(with newArticle: Article) {
        state = .loaded(article: newArticle)
        // If the freshly loaded article carries a cached summary, surface it
        // immediately so the UI can render without waiting for another pass.
        if case .ready = summaryState {
            return
        }
        if let cached = ArticleSummarizationService.cachedSummary(for: newArticle) {
            summaryState = .ready(summary: cached)
        }
    }

    private func runSummarization(force: Bool) async {
        defer { summaryTask = nil }
        guard let summarize else { return }
        guard let article = currentArticle else { return }

        if force == false, let cached = ArticleSummarizationService.cachedSummary(for: article) {
            summaryState = .ready(summary: cached)
            return
        }

        let requestID = "article-detail-summary-\(UUID().uuidString.lowercased())"
        summaryState = .summarizing
        logger.info(
            "Article AI summary requested",
            category: .business,
            service: "ArticleDetailViewModel",
            requestID: requestID,
            metadata: [
                "article_id": article.id,
                "force": "\(force)",
                "content_word_count": "\(article.contentWordCount)"
            ]
        )

        do {
            let summary = try await summarize(article)
            if Task.isCancelled {
                summaryState = .idle
                logger.debug(
                    "Article AI summary cancelled",
                    category: .business,
                    service: "ArticleDetailViewModel",
                    requestID: requestID
                )
                return
            }
            applySummaryToArticle(summary)
            summaryState = .ready(summary: summary)
            logger.info(
                "Article AI summary completed",
                category: .business,
                service: "ArticleDetailViewModel",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "bullets": "\(summary.bullets.count)"
                ]
            )
        } catch {
            if Task.isCancelled {
                summaryState = .idle
                return
            }
            let message: String
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                message = description
            } else {
                message = error.localizedDescription
            }
            summaryState = .failed(message: message)
            logger.warn(
                "Article AI summary failed",
                category: .business,
                service: "ArticleDetailViewModel",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "error": String(describing: error)
                ]
            )
        }
    }

    private func applySummaryToArticle(_ summary: AISummaryResult) {
        guard let current = currentArticle else { return }
        let updated = Article(
            id: current.id,
            externalID: current.externalID,
            title: current.title,
            sourceName: current.sourceName,
            sourceURL: current.sourceURL,
            articleURL: current.articleURL,
            publishedAt: current.publishedAt,
            authorName: current.authorName,
            heroImageURL: current.heroImageURL,
            rawContent: current.rawContent,
            cleanedContent: current.cleanedContent,
            contentSource: current.contentSource,
            contentWordCount: current.contentWordCount,
            isContentLikelyComplete: current.isContentLikelyComplete,
            summaryShort: summary.shortSummary,
            summaryBullets: summary.bullets,
            category: current.category,
            tags: current.tags,
            language: current.language,
            isBookmarked: current.isBookmarked,
            isRead: current.isRead,
            clusterID: current.clusterID,
            createdAt: current.createdAt,
            updatedAt: .now
        )
        state = .loaded(article: updated)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
