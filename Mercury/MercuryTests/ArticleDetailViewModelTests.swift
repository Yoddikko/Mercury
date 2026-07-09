//
//  ArticleDetailViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import Testing
@testable import Mercury

@MainActor
struct ArticleDetailViewModelTests {
    // MARK: - Initial state

    @Test
    func initialStateContainsSeededArticle() {
        let article = Self.sampleArticle()
        let viewModel = Self.makeViewModel(article: article)

        guard case let .loaded(loaded) = viewModel.state else {
            Issue.record("Expected loaded state on init, got \(viewModel.state)")
            return
        }
        #expect(loaded.id == article.id)
        #expect(viewModel.currentArticle?.id == article.id)
        #expect(viewModel.enrichmentState == .idle)
        #expect(viewModel.isTogglingBookmark == false)
    }

    // MARK: - Open recording

    @Test
    func onAppearRecordsOpenViaInjectedClosure() async {
        let recordedIDs = Recorder<String>()
        let article = Self.sampleArticle()
        let viewModel = Self.makeViewModel(
            article: article,
            recordOpen: { id in await recordedIDs.append(id) }
        )

        await viewModel.onAppear()

        let captured = await recordedIDs.values
        #expect(captured == [article.id])
        // The view model also flips `isRead` after a successful record.
        #expect(viewModel.currentArticle?.isRead == true)
    }

    @Test
    func onAppearRecordsOpenOnlyOnce() async {
        let recordedIDs = Recorder<String>()
        let viewModel = Self.makeViewModel(
            recordOpen: { id in await recordedIDs.append(id) }
        )

        await viewModel.onAppear()
        await viewModel.onAppear()

        let captured = await recordedIDs.values
        #expect(captured.count == 1)
    }

    @Test
    func onAppearTreatsRecordOpenFailureAsBestEffort() async {
        let article = Self.sampleArticle(isRead: false)
        let viewModel = Self.makeViewModel(
            article: article,
            recordOpen: { _ in throw SampleError.boom }
        )

        await viewModel.onAppear()

        // State stays loaded with the original article; isRead stays false
        // because the write failed — but the view model does not transition
        // into a failure state for a best-effort hook.
        guard case let .loaded(loaded) = viewModel.state else {
            Issue.record("Expected loaded state after best-effort failure, got \(viewModel.state)")
            return
        }
        #expect(loaded.id == article.id)
        #expect(loaded.isRead == false)
    }

    // MARK: - Bookmark toggle

    @Test
    func toggleBookmarkFlipsStateWithReturnedValue() async {
        let article = Self.sampleArticle(isBookmarked: false)
        let viewModel = Self.makeViewModel(
            article: article,
            bookmarkToggle: { _ in true }
        )

        await viewModel.toggleBookmark()

        #expect(viewModel.currentArticle?.isBookmarked == true)
        #expect(viewModel.isTogglingBookmark == false)
    }

    @Test
    func toggleBookmarkPropagatesReturnedValueWhenItDiffersFromOptimisticGuess() async {
        // Even if the article is currently bookmarked, the store may decide
        // to keep it bookmarked (e.g. concurrent device sync). The view
        // model trusts the returned value rather than flipping locally.
        let article = Self.sampleArticle(isBookmarked: true)
        let viewModel = Self.makeViewModel(
            article: article,
            bookmarkToggle: { _ in true }
        )

        await viewModel.toggleBookmark()

        #expect(viewModel.currentArticle?.isBookmarked == true)
    }

    @Test
    func toggleBookmarkFailurePreservesState() async {
        let article = Self.sampleArticle(isBookmarked: false)
        let viewModel = Self.makeViewModel(
            article: article,
            bookmarkToggle: { _ in throw SampleError.boom }
        )

        await viewModel.toggleBookmark()

        // Failure must NOT flip the local bookmark flag and must not leave
        // the view model stuck in a "toggling" state.
        #expect(viewModel.currentArticle?.isBookmarked == false)
        #expect(viewModel.isTogglingBookmark == false)
        guard case .loaded = viewModel.state else {
            Issue.record("Expected loaded state after bookmark failure, got \(viewModel.state)")
            return
        }
    }

    // MARK: - Enrichment

    @Test
    func enrichmentReplacesArticleWhenClosureReturnsEnrichedCopy() async {
        let article = Self.sampleArticle(
            cleanedContent: "short",
            contentWordCount: 1,
            isContentLikelyComplete: false
        )
        let enriched = article.updatingContent(
            rawContent: "full raw body",
            cleanedContent: "full cleaned body",
            contentSource: "page_extract",
            contentWordCount: 500,
            isContentLikelyComplete: true,
            heroImageURL: article.heroImageURL,
            summaryShort: article.summaryShort,
            updatedAt: .now
        )

        let viewModel = Self.makeViewModel(
            article: article,
            enrichContent: { _ in enriched }
        )

        await viewModel.refresh()

        #expect(viewModel.enrichmentState == .idle)
        #expect(viewModel.currentArticle?.contentWordCount == 500)
        #expect(viewModel.currentArticle?.cleanedContent == "full cleaned body")
        #expect(viewModel.currentArticle?.isContentLikelyComplete == true)
    }

    @Test
    func enrichmentNilReturnTransitionsToFailedAndKeepsOriginalArticle() async {
        let article = Self.sampleArticle(
            cleanedContent: nil,
            contentWordCount: 0,
            isContentLikelyComplete: false
        )
        let viewModel = Self.makeViewModel(
            article: article,
            enrichContent: { _ in nil }
        )

        await viewModel.refresh()

        #expect(viewModel.enrichmentState == .failed)
        #expect(viewModel.currentArticle?.id == article.id)
        #expect(viewModel.currentArticle?.contentWordCount == 0)
        // After a failure with no body content, the placeholder should not
        // be suppressed by a stale enriching indicator.
        #expect(viewModel.shouldShowBodyPlaceholder == true)
    }

    @Test
    func onAppearSkipsEnrichmentForCompleteArticles() async {
        // Articles that are already complete with enough words must not
        // trigger an enrichment call from the appearance hook.
        let article = Self.sampleArticle(
            cleanedContent: String(repeating: "word ", count: 400),
            contentWordCount: 400,
            isContentLikelyComplete: true
        )
        let enrichCalls = Recorder<String>()
        let viewModel = Self.makeViewModel(
            article: article,
            enrichContent: { article in
                await enrichCalls.append(article.id)
                return nil
            }
        )

        await viewModel.onAppear()

        let captured = await enrichCalls.values
        #expect(captured.isEmpty)
        #expect(viewModel.shouldAttemptEnrichment == false)
    }

    // MARK: - Summary (on-demand only)

    @Test
    func onAppearDoesNotTriggerSummaryAutomatically() async {
        // Per docs/features/SUMMARIZATION.md, AI summarization is exclusively
        // user-initiated via the "Generate AI summary" button. The appearance
        // hook must never invoke the summarize closure.
        let article = Self.sampleArticle(summaryShort: nil, summaryBullets: [])
        let summarizeCalls = Recorder<String>()
        let viewModel = Self.makeViewModel(
            article: article,
            summarize: { article in
                await summarizeCalls.append(article.id)
                return AISummaryResult(shortSummary: "auto", bullets: [])
            }
        )

        await viewModel.onAppear()

        let captured = await summarizeCalls.values
        #expect(captured.isEmpty)
        #expect(viewModel.summaryState == .idle)
        #expect(viewModel.shouldShowAISummaryGenerateButton == true)
    }

    @Test
    func requestSummaryInvokesSummarizeClosureAndTransitionsToReady() async {
        let article = Self.sampleArticle(summaryShort: nil, summaryBullets: [])
        let summarizeCalls = Recorder<String>()
        let summary = AISummaryResult(
            shortSummary: "Short summary",
            bullets: ["First bullet", "Second bullet"]
        )
        let viewModel = Self.makeViewModel(
            article: article,
            summarize: { article in
                await summarizeCalls.append(article.id)
                return summary
            }
        )

        await viewModel.requestSummary()

        let captured = await summarizeCalls.values
        #expect(captured == [article.id])
        guard case let .ready(produced) = viewModel.summaryState else {
            Issue.record("Expected ready summary state, got \(viewModel.summaryState)")
            return
        }
        #expect(produced.shortSummary == "Short summary")
        #expect(produced.bullets == ["First bullet", "Second bullet"])
        // The cached summary should now be reflected on the article so the
        // detail screen can render it from the model on a future reload.
        #expect(viewModel.currentArticle?.summaryShort == "Short summary")
        // "Generate" button should disappear; "Regenerate" affordance is now
        // the active action.
        #expect(viewModel.shouldShowAISummaryGenerateButton == false)
        #expect(viewModel.canRegenerateAISummary == true)
    }

    @Test
    func requestSummaryDoesNothingWhenNoSummarizeClosureWired() async {
        let article = Self.sampleArticle(summaryShort: nil, summaryBullets: [])
        let viewModel = Self.makeViewModel(article: article, summarize: nil)

        await viewModel.requestSummary()

        #expect(viewModel.summaryState == .idle)
        #expect(viewModel.shouldShowAISummaryGenerateButton == false)
        #expect(viewModel.shouldShowAISummaryUnavailable == true)
    }

    @Test
    func initDoesNotAutoSurfaceCachedSummary() {
        // Article already carries a cached summary — VM init must NOT
        // transition to `.ready`; user must tap to display.
        let article = Self.sampleArticle(
            aiSummaryShort: "Cached short summary",
            aiSummaryBullets: ["Cached bullet"]
        )
        let viewModel = Self.makeViewModel(
            article: article,
            summarize: { _ in
                AISummaryResult(shortSummary: "fresh", bullets: [])
            }
        )

        #expect(viewModel.summaryState == .idle)
        #expect(viewModel.hasCachedSummary == true)
        #expect(viewModel.aiSummaryPrimaryButtonLabel == viewModel.aiSummaryShowLabel)
        #expect(viewModel.shouldShowAISummaryGenerateButton == true)
    }

    @Test
    func requestSummaryWithCacheShowsInstantlyWithoutCallingSummarize() async {
        let article = Self.sampleArticle(
            aiSummaryShort: "Cached short summary",
            aiSummaryBullets: ["Cached bullet one", "Cached bullet two"]
        )
        let summarizeCalls = Recorder<String>()
        let viewModel = Self.makeViewModel(
            article: article,
            summarize: { article in
                await summarizeCalls.append(article.id)
                return AISummaryResult(shortSummary: "should-not-be-used", bullets: [])
            }
        )

        await viewModel.requestSummary()

        let captured = await summarizeCalls.values
        #expect(captured.isEmpty, "Provider must not be called when a cache exists")
        guard case let .ready(produced) = viewModel.summaryState else {
            Issue.record("Expected .ready, got \(viewModel.summaryState)")
            return
        }
        #expect(produced.shortSummary == "Cached short summary")
        #expect(produced.bullets == ["Cached bullet one", "Cached bullet two"])
    }

    @Test
    func aiSummarySectionIsAlwaysRendered() {
        // The AI Summary section is always shown on the detail screen: the
        // section either exposes the generate/show button, the ready summary,
        // or the "AI unavailable" fallback. Nothing on the article body ever
        // renders automatically as a summary. See docs/features/SUMMARIZATION.md.
        let noProvider = Self.makeViewModel(
            article: Self.sampleArticle(summaryShort: "should-not-auto-show", summaryBullets: []),
            summarize: nil
        )
        #expect(noProvider.shouldShowAISummarySection == true)
        #expect(noProvider.shouldShowAISummaryUnavailable == true)

        let withProvider = Self.makeViewModel(
            article: Self.sampleArticle(summaryShort: nil, summaryBullets: []),
            summarize: { _ in AISummaryResult(shortSummary: "x", bullets: []) }
        )
        #expect(withProvider.shouldShowAISummarySection == true)
        #expect(withProvider.shouldShowAISummaryGenerateButton == true)
    }

    @Test
    func primaryButtonLabelSwitchesByCachePresence() {
        let cached = Self.sampleArticle(
            aiSummaryShort: "Cached",
            aiSummaryBullets: ["A"]
        )
        let cachedVM = Self.makeViewModel(article: cached, summarize: { _ in
            AISummaryResult(shortSummary: "x", bullets: [])
        })
        #expect(cachedVM.aiSummaryPrimaryButtonLabel == cachedVM.aiSummaryShowLabel)

        let empty = Self.sampleArticle(summaryShort: nil, summaryBullets: [])
        let emptyVM = Self.makeViewModel(article: empty, summarize: { _ in
            AISummaryResult(shortSummary: "x", bullets: [])
        })
        #expect(emptyVM.aiSummaryPrimaryButtonLabel == emptyVM.aiSummaryGenerateLabel)

        // An RSS excerpt in `summaryShort` is NOT a cached AI summary: the
        // button must read "Generate", not "Show" (issue #100).
        let rssOnly = Self.sampleArticle(summaryShort: "RSS excerpt", summaryBullets: [])
        let rssOnlyVM = Self.makeViewModel(article: rssOnly, summarize: { _ in
            AISummaryResult(shortSummary: "x", bullets: [])
        })
        #expect(rssOnlyVM.hasCachedSummary == false)
        #expect(rssOnlyVM.aiSummaryPrimaryButtonLabel == rssOnlyVM.aiSummaryGenerateLabel)
    }

    // MARK: - Deinit

    @Test
    func deinitDoesNotCrashAfterEnrichmentRuns() async {
        // Smoke-level check: the deinit calls `enrichmentTask?.cancel()`. As
        // long as a completed (or in-flight) enrichment task exists when the
        // view model is released, deinit must run cleanly with no crash.
        // We can't reliably observe cancellation propagation here because
        // the enrichment closure retains `self` for the duration of the
        // suspended call (so the VM only deinits after the task settles).
        weak var weakRef: ArticleDetailViewModel?

        await {
            let viewModel = Self.makeViewModel(
                article: Self.sampleArticle(
                    cleanedContent: nil,
                    contentWordCount: 0,
                    isContentLikelyComplete: false
                ),
                enrichContent: { _ in nil }
            )
            weakRef = viewModel
            // Drive an enrichment so `enrichmentTask` becomes non-nil at
            // some point during the lifecycle. After this hop the defer in
            // `runEnrichment` resets the task to nil and deinit becomes a
            // straightforward no-op cancel.
            await viewModel.refresh()
        }()

        // Allow the autorelease pool / ARC to drop the view model.
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(weakRef == nil)
    }

    // MARK: - Helpers

    private static func makeViewModel(
        article: Article? = nil,
        bookmarkToggle: @escaping ArticleDetailViewModel.BookmarkToggle = { _ in false },
        recordOpen: @escaping ArticleDetailViewModel.RecordOpen = { _ in },
        enrichContent: ArticleDetailViewModel.EnrichContent? = nil,
        summarize: ArticleDetailViewModel.Summarize? = nil
    ) -> ArticleDetailViewModel {
        ArticleDetailViewModel(
            article: article ?? sampleArticle(),
            bookmarkToggle: bookmarkToggle,
            recordOpen: recordOpen,
            enrichContent: enrichContent,
            summarize: summarize
        )
    }

    private static func sampleArticle(
        id: String = "article-detail-test",
        isBookmarked: Bool = false,
        isRead: Bool = false,
        cleanedContent: String? = "Base body",
        contentWordCount: Int = 2,
        isContentLikelyComplete: Bool = false,
        summaryShort: String? = "Summary",
        summaryBullets: [String] = [],
        aiSummaryShort: String? = nil,
        aiSummaryBullets: [String] = []
    ) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: "Sample Title",
            sourceName: "Sample Source",
            sourceURL: URL(string: "https://example.com/source")!,
            articleURL: URL(string: "https://example.com/article/\(id)")!,
            publishedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            authorName: "Author",
            heroImageURL: URL(string: "https://example.com/hero.jpg"),
            rawContent: nil,
            cleanedContent: cleanedContent,
            contentSource: "feed_content",
            contentWordCount: contentWordCount,
            isContentLikelyComplete: isContentLikelyComplete,
            summaryShort: summaryShort,
            summaryBullets: summaryBullets,
            aiSummaryShort: aiSummaryShort,
            aiSummaryBullets: aiSummaryBullets,
            category: "Technology",
            tags: ["test"],
            language: "en",
            isBookmarked: isBookmarked,
            isRead: isRead,
            clusterID: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private enum SampleError: Error {
        case boom
    }

    private actor Recorder<Value: Sendable> {
        private(set) var values: [Value] = []

        func append(_ value: Value) {
            values.append(value)
        }
    }
}
