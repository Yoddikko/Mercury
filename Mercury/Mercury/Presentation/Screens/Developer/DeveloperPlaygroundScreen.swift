//
//  DeveloperPlaygroundScreen.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

#if DEBUG

import SwiftData
import SwiftUI
import UIKit

struct DeveloperPlaygroundScreen: View {
    private enum ActiveSheet: Identifiable {
        case logExport(URL)
        case rssReport(URL)
        case articleInspection(Article)

        var id: String {
            switch self {
            case let .logExport(url):
                return "log:\(url.absoluteString)"
            case let .rssReport(url):
                return "rss-report:\(url.absoluteString)"
            case let .articleInspection(article):
                return "article:\(article.id)"
            }
        }
    }

    let viewModel: DeveloperPlaygroundViewModel

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredArticle.createdAt, order: .reverse) private var storedArticles: [StoredArticle]
    @StateObject private var rssDiagnosticsViewModel = DeveloperRSSDiagnosticsViewModel()
    private let logger = AppLogger.shared

    @State private var selectedProviderID = DeveloperPlaygroundViewModel.defaultProviderID
    @State private var promptInput = ""
    @State private var simulationOutput = ""
    @State private var storedLogEntries = 0
    @State private var isExportingLogs = false
    @State private var exportedLogURL: URL?
    @State private var logExportError: String?
    @State private var isExportingRSSReport = false
    @State private var exportedRSSReportURL: URL?
    @State private var rssReportExportError: String?
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        Form {
            Section {
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("developer.playground.subtitle")
            }

            Section(viewModel.aiSimulationSectionTitle) {
                Picker(viewModel.providerLabel, selection: $selectedProviderID) {
                    ForEach(viewModel.providerOptions) { option in
                        Text(option.displayName).tag(option.id)
                    }
                }
                .accessibilityIdentifier("developer.playground.provider")

                TextField(viewModel.promptInputLabel, text: $promptInput, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("developer.playground.prompt")

                Button(viewModel.runSimulationLabel) {
                    simulationOutput = viewModel.simulatedSummary(
                        prompt: promptInput,
                        providerID: selectedProviderID
                    )
                    logger.debug(
                        "Ran local AI simulation",
                        category: .ui,
                        service: "DeveloperPlaygroundScreen",
                        metadata: [
                            "provider_id": selectedProviderID,
                            "prompt_length": "\(promptInput.count)"
                        ]
                    )
                    Task {
                        await refreshLogEntryCount()
                    }
                }
                .accessibilityIdentifier("developer.playground.run")

                if simulationOutput.isEmpty == false {
                    Text(simulationOutput)
                        .font(.callout)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("developer.playground.output")
                }
            }

            Section(viewModel.swiftDataSandboxSectionTitle) {
                Text(viewModel.storedDebugRecordsLabel(count: storedArticles.count))
                    .accessibilityIdentifier("developer.playground.count")

                HStack {
                    Button(viewModel.insertSampleRecordLabel) {
                        modelContext.insert(
                            viewModel.makeSampleStoredArticle(existingCount: storedArticles.count)
                        )
                        logger.debug(
                            "Inserted debug sample record",
                            category: .database,
                            service: "DeveloperPlaygroundScreen",
                            metadata: ["records_before_insert": "\(storedArticles.count)"]
                        )
                        Task {
                            await refreshLogEntryCount()
                        }
                    }
                    .accessibilityIdentifier("developer.playground.insert")

                    Button(viewModel.clearRecordsLabel, role: .destructive) {
                        clearStoredArticles()
                    }
                    .accessibilityIdentifier("developer.playground.clear")
                }

                if storedArticles.isEmpty == false {
                    ForEach(storedArticles.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.sourceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(viewModel.loggingSectionTitle) {
                Text(viewModel.logEntriesLabel(count: storedLogEntries))
                    .accessibilityIdentifier("developer.playground.logging.count")

                HStack {
                    Button(viewModel.exportLogsLabel) {
                        Task {
                            await exportLogs()
                        }
                    }
                    .disabled(isExportingLogs)
                    .accessibilityIdentifier("developer.playground.logging.export")

                    Button(viewModel.clearLogsLabel, role: .destructive) {
                        Task {
                            await clearLogs()
                        }
                    }
                    .accessibilityIdentifier("developer.playground.logging.clear")
                }

                if isExportingLogs {
                    ProgressView(viewModel.exportingLogsLabel)
                        .accessibilityIdentifier("developer.playground.logging.exporting")
                }

                if exportedLogURL != nil {
                    Text(viewModel.logExportReadyLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("developer.playground.logging.ready")
                }

                if let logExportError {
                    Text(logExportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("developer.playground.logging.error")
                }
            }

            Section(viewModel.rssDiagnosticsSectionTitle) {
                Picker(viewModel.rssGroupLabel, selection: $rssDiagnosticsViewModel.selectedGroupMode) {
                    ForEach(RSSFeedGroupMode.allCases) { mode in
                        Text(rssDiagnosticsViewModel.title(for: mode)).tag(mode)
                    }
                }
                .accessibilityIdentifier("developer.playground.rss.group")

                if rssDiagnosticsViewModel.selectedGroupMode == .byRegion {
                    Picker(viewModel.rssRegionLabel, selection: $rssDiagnosticsViewModel.selectedRegion) {
                        ForEach(rssDiagnosticsViewModel.availableRegions) { region in
                            Text(rssDiagnosticsViewModel.title(for: region)).tag(region)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.region")
                }

                Text(viewModel.rssSelectedOutletsLabel(count: rssDiagnosticsViewModel.selectedSourcesCount))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("developer.playground.rss.selected")

                Button(viewModel.runRSSDiagnosticsLabel) {
                    rssDiagnosticsViewModel.runDiagnostics()
                }
                .disabled(
                    rssDiagnosticsViewModel.isRunning ||
                    rssDiagnosticsViewModel.selectedSourcesCount == 0
                )
                .accessibilityIdentifier("developer.playground.rss.run")

                if rssDiagnosticsViewModel.isRunning {
                    ProgressView(viewModel.runningRSSDiagnosticsLabel)
                        .accessibilityIdentifier("developer.playground.rss.running")
                }
            }

            if rssDiagnosticsViewModel.hasResultForCurrentSelection {
                Section(viewModel.rssSummarySectionTitle) {
                    Text(viewModel.rssOutletsCheckedLabel(count: rssDiagnosticsViewModel.checks.count))
                    Text(viewModel.rssSuccessfulFeedsLabel(count: rssDiagnosticsViewModel.successChecks.count))
                    Text(viewModel.rssNoArticlesFeedsLabel(count: rssDiagnosticsViewModel.noArticleChecks.count))
                    Text(viewModel.rssMissingFeedsLabel(count: rssDiagnosticsViewModel.noFeedChecks.count))
                    Text(viewModel.rssFailedFeedsLabel(count: rssDiagnosticsViewModel.failedChecks.count))
                    Text(viewModel.rssDeduplicatedArticlesLabel(count: rssDiagnosticsViewModel.normalizedArticles.count))
                    Text(viewModel.rssDurationLabel(milliseconds: rssDiagnosticsViewModel.lastRunDurationMs))

                    Button(viewModel.rssExportOutletsReportLabel) {
                        Task {
                            await exportRSSOutletsReport()
                        }
                    }
                    .disabled(isExportingRSSReport)
                    .accessibilityIdentifier("developer.playground.rss.exportReport")

                    if isExportingRSSReport {
                        ProgressView(viewModel.rssExportingOutletsReportLabel)
                            .accessibilityIdentifier("developer.playground.rss.exportingReport")
                    }

                    if exportedRSSReportURL != nil {
                        Text(viewModel.rssOutletsReportReadyLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("developer.playground.rss.reportReady")
                    }

                    if let rssReportExportError {
                        Text(rssReportExportError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("developer.playground.rss.reportError")
                    }
                }
                .accessibilityIdentifier("developer.playground.rss.summary")

                if rssDiagnosticsViewModel.noFeedChecks.isEmpty == false {
                    Section(viewModel.rssMissingFeedsSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.noFeedChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.noFeed")
                }

                if rssDiagnosticsViewModel.failedChecks.isEmpty == false {
                    Section(viewModel.rssFailedFeedsSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.failedChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.failed")
                }

                if rssDiagnosticsViewModel.noArticleChecks.isEmpty == false {
                    Section(viewModel.rssNoArticlesSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.noArticleChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.noArticles")
                }

                if rssDiagnosticsViewModel.successChecks.isEmpty == false {
                    Section(viewModel.rssSuccessSectionTitle) {
                        ForEach(Array(rssDiagnosticsViewModel.successChecks.prefix(50))) { result in
                            feedCheckRow(for: result)
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.success")
                }

                if rssDiagnosticsViewModel.normalizedArticles.isEmpty == false {
                    Section(viewModel.rssArticlesSectionTitle) {
                        Text(viewModel.rssTapArticleToInspectLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(Array(rssDiagnosticsViewModel.normalizedArticles.prefix(80))) { article in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(article.title)
                                        .font(.headline)
                                    Text("\(article.sourceName) • \(Self.articleDateFormatter.string(from: article.publishedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(article.articleURL.absoluteString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openArticleInspection(article)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("developer.playground.rss.article.row.\(article.id)")
                        }
                    }
                    .accessibilityIdentifier("developer.playground.rss.articles")
                }
            }
        }
        .navigationTitle(viewModel.title)
        .accessibilityIdentifier("developer.playground.screen")
        .task {
            await refreshLogEntryCount()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .logExport(url):
                ActivityViewController(activityItems: [url])
            case let .rssReport(url):
                ActivityViewController(activityItems: [url])
            case let .articleInspection(article):
                DeveloperRSSArticleInspectionScreen(article: article, viewModel: viewModel)
            }
        }
    }

    private func openArticleInspection(_ article: Article) {
        activeSheet = .articleInspection(article)
        logger.debug(
            "Opened RSS article inspection",
            category: .ui,
            service: "DeveloperPlaygroundScreen",
            metadata: [
                "article_id": article.id,
                "source_name": article.sourceName
            ]
        )
    }

    private func feedCheckRow(for result: RSSFeedCheckResult) -> some View {
        let statusTitle = rssDiagnosticsViewModel.title(for: result.status)

        return VStack(alignment: .leading, spacing: 4) {
            Text(result.source.outletName)
                .font(.headline)
            Text(rssDiagnosticsViewModel.title(for: result.source.region))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.rssCheckCaption(result: result, statusTitle: statusTitle))
                .font(.caption)
                .foregroundStyle(result.status == .success ? .secondary : .primary)
            if let message = result.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let feedURLString = result.source.feedURLString {
                Text(feedURLString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func clearStoredArticles() {
        logger.warn(
            "Clearing debug SwiftData records",
            category: .database,
            service: "DeveloperPlaygroundScreen",
            metadata: ["records_count": "\(storedArticles.count)"]
        )

        for article in storedArticles {
            modelContext.delete(article)
        }

        Task {
            await refreshLogEntryCount()
        }
    }

    private func refreshLogEntryCount() async {
        storedLogEntries = await logger.entryCount()
    }

    private func exportLogs() async {
        isExportingLogs = true
        logExportError = nil

        logger.info(
            "Preparing log export from developer playground",
            category: .filesystem,
            service: "DeveloperPlaygroundScreen"
        )

        defer { isExportingLogs = false }

        do {
            let fileURL = try await logger.exportToTemporaryFile()
            exportedLogURL = fileURL
            activeSheet = .logExport(fileURL)
            await refreshLogEntryCount()
        } catch {
            logExportError = error.localizedDescription
            logger.error(
                "Failed to export logs from developer playground",
                category: .filesystem,
                service: "DeveloperPlaygroundScreen",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func exportRSSOutletsReport() async {
        guard let result = rssDiagnosticsViewModel.latestResult else { return }
        isExportingRSSReport = true
        rssReportExportError = nil

        logger.info(
            "Preparing RSS outlets report export",
            category: .filesystem,
            service: "DeveloperPlaygroundScreen",
            metadata: [
                "checks_count": "\(result.checks.count)",
                "group_mode": result.groupMode.rawValue
            ]
        )

        defer { isExportingRSSReport = false }

        do {
            let fileURL = try RSSDiagnosticsReportExporter.exportReport(from: result)
            exportedRSSReportURL = fileURL
            activeSheet = .rssReport(fileURL)
            logger.info(
                "RSS outlets report export completed",
                category: .filesystem,
                service: "DeveloperPlaygroundScreen",
                metadata: ["file_path": fileURL.path]
            )
        } catch {
            rssReportExportError = error.localizedDescription
            logger.error(
                "RSS outlets report export failed",
                category: .filesystem,
                service: "DeveloperPlaygroundScreen",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func clearLogs() async {
        logger.warn(
            "Developer requested in-memory log clear",
            category: .filesystem,
            service: "DeveloperPlaygroundScreen"
        )
        logExportError = nil
        exportedLogURL = nil
        await logger.clear()
        await refreshLogEntryCount()
    }

    private static let articleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct DeveloperRSSArticleInspectionScreen: View {
    let article: Article
    let viewModel: DeveloperPlaygroundViewModel

    @State private var pageExtraction: ArticlePageExtractionResult?
    @State private var isFetchingFullText = false
    @State private var fullTextFetchError: String?

    private let pageClient = ArticlePageClient()
    private let extractor = ArticlePageContentExtractor()
    private let logger = AppLogger.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: viewModel.rssArticleInspectorOverviewSectionTitle) {
                        infoRow(label: viewModel.rssArticleInspectorFieldID, value: article.id)
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldExternalID,
                            value: article.externalID ?? viewModel.rssArticleInspectorEmptyValue
                        )
                        infoRow(label: viewModel.rssArticleInspectorFieldSource, value: article.sourceName)
                        infoRow(label: viewModel.rssArticleInspectorFieldSourceURL, value: article.sourceURL.absoluteString)
                        infoRow(label: viewModel.rssArticleInspectorFieldArticleURL, value: article.articleURL.absoluteString)
                        Link(destination: article.articleURL) {
                            Text(article.articleURL.absoluteString)
                                .font(.footnote)
                                .foregroundStyle(.blue)
                                .underline()
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .accessibilityIdentifier("developer.playground.rss.article.link")
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldPublishedAt,
                            value: viewModel.formattedRSSInspectionDate(article.publishedAt)
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldAuthor,
                            value: article.authorName ?? viewModel.rssArticleInspectorEmptyValue
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldImageURL,
                            value: article.heroImageURL?.absoluteString ?? viewModel.rssArticleInspectorEmptyValue
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldLanguage,
                            value: article.language ?? viewModel.rssArticleInspectorEmptyValue
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldCategory,
                            value: article.category ?? viewModel.rssArticleInspectorEmptyValue
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldTags,
                            value: article.tags.isEmpty
                                ? viewModel.rssArticleInspectorEmptyValue
                                : article.tags.joined(separator: ", ")
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldContentSource,
                            value: viewModel.rssContentSourceLabel(displayedContentSource)
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldWordCount,
                            value: "\(displayedWordCount)"
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldLikelyComplete,
                            value: displayedLikelyComplete
                                ? viewModel.rssArticleInspectorBooleanYes
                                : viewModel.rssArticleInspectorBooleanNo
                        )
                        infoRow(
                            label: viewModel.rssArticleInspectorFieldDisplayedContent,
                            value: viewModel.rssDisplayedContentLabel(
                                isUsingArticlePageFetch: pageExtraction != nil
                            )
                        )

                        if let heroImageURL = displayedHeroImageURL {
                            AsyncImage(url: heroImageURL) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .empty:
                                    ProgressView()
                                case .failure:
                                    Color.gray.opacity(0.15)
                                @unknown default:
                                    Color.gray.opacity(0.15)
                                }
                            }
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    section(title: viewModel.rssArticleInspectorPageFetchSectionTitle) {
                        Button(pageExtraction == nil
                            ? viewModel.rssArticleInspectorFetchFullTextLabel
                            : viewModel.rssArticleInspectorRefetchFullTextLabel
                        ) {
                            Task {
                                await fetchFullArticleText(force: true)
                            }
                        }
                        .disabled(isFetchingFullText)
                        .accessibilityIdentifier("developer.playground.rss.article.fetchFullText")

                        if isFetchingFullText {
                            ProgressView(viewModel.rssArticleInspectorFetchingFullTextLabel)
                        }

                        if pageExtraction != nil {
                            Text(viewModel.rssArticleInspectorFullTextReadyLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let fullTextFetchError {
                            Text(fullTextFetchError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    section(title: viewModel.rssArticleInspectorChecksSectionTitle) {
                        ForEach(dataChecks, id: \.label) { check in
                            Label {
                                Text(check.label)
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: check.isPassing ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(check.isPassing ? .green : .red)
                            }
                        }
                    }

                    section(title: viewModel.rssArticleInspectorContentSectionTitle) {
                        contentBlock(
                            label: viewModel.rssArticleInspectorFieldRawContent,
                            value: displayedRawContent
                        )
                        contentBlock(
                            label: viewModel.rssArticleInspectorFieldCleanedContent,
                            value: displayedCleanedContent
                        )
                        contentBlock(
                            label: viewModel.rssArticleInspectorFieldSummaryShort,
                            value: article.summaryShort ?? viewModel.rssArticleInspectorNoContentValue
                        )
                        contentBlock(
                            label: viewModel.rssArticleInspectorFieldSummaryBullets,
                            value: article.summaryBullets.isEmpty
                                ? viewModel.rssArticleInspectorNoBulletsValue
                                : "• " + article.summaryBullets.joined(separator: "\n• ")
                        )
                    }
                }
                .padding(16)
            }
            .navigationTitle(viewModel.rssArticleInspectorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: article.id) {
                await fetchFullArticleText()
            }
        }
    }

    private var displayedRawContent: String {
        pageExtraction?.rawHTML ?? article.rawContent ?? viewModel.rssArticleInspectorNoContentValue
    }

    private var displayedCleanedContent: String {
        pageExtraction?.cleanedText ?? article.cleanedContent ?? viewModel.rssArticleInspectorNoContentValue
    }

    private var displayedContentSource: String {
        pageExtraction == nil ? article.contentSource : "article_page"
    }

    private var displayedWordCount: Int {
        pageExtraction?.wordCount ?? article.contentWordCount
    }

    private var displayedLikelyComplete: Bool {
        pageExtraction?.isLikelyComplete ?? article.isContentLikelyComplete
    }

    private var displayedHeroImageURL: URL? {
        if let heroImageURL = article.heroImageURL {
            return heroImageURL
        }

        guard let heroImageURLString = pageExtraction?.heroImageURLString else {
            return nil
        }

        let trimmed = heroImageURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let absolute = URL(string: trimmed),
           let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absolute
        }

        if trimmed.hasPrefix("//"), let protocolRelative = URL(string: "https:\(trimmed)") {
            return protocolRelative
        }

        return URL(string: trimmed, relativeTo: article.articleURL)?.absoluteURL
    }

    private var dataChecks: [(label: String, isPassing: Bool)] {
        let hasTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasArticleURL = article.articleURL.absoluteString.isEmpty == false
        let hasPublishedDate = article.publishedAt != .distantPast
        let hasContentPayload = [pageExtraction?.rawHTML, pageExtraction?.cleanedText, article.summaryShort]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .contains { value in
                value.isEmpty == false
            }
        let hasLanguage = article.language?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasImage = displayedHeroImageURL != nil
        let hasAuthor = article.authorName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        return [
            (viewModel.rssArticleInspectorCheckHasTitle, hasTitle),
            (viewModel.rssArticleInspectorCheckHasArticleURL, hasArticleURL),
            (viewModel.rssArticleInspectorCheckHasPublishedDate, hasPublishedDate),
            (viewModel.rssArticleInspectorCheckHasContent, hasContentPayload),
            (viewModel.rssArticleInspectorCheckHasLanguage, hasLanguage),
            (viewModel.rssArticleInspectorCheckHasImage, hasImage),
            (viewModel.rssArticleInspectorCheckHasAuthor, hasAuthor),
            (viewModel.rssArticleInspectorCheckLikelyComplete, displayedLikelyComplete)
        ]
    }

    @MainActor
    private func fetchFullArticleText(force: Bool = false) async {
        if isFetchingFullText {
            return
        }
        if force == false, pageExtraction != nil {
            return
        }

        isFetchingFullText = true
        fullTextFetchError = nil
        let requestID = "debug-article-\(UUID().uuidString.lowercased())"

        logger.debug(
            "Fetching full article text in debug inspector",
            category: .ui,
            service: "DeveloperRSSArticleInspectionScreen",
            requestID: requestID,
            metadata: [
                "article_id": article.id,
                "url": article.articleURL.absoluteString
            ]
        )

        defer { isFetchingFullText = false }

        do {
            let html = try await pageClient.fetchPageHTML(from: article.articleURL, requestID: requestID)
            guard let extraction = extractor.extract(from: html, requestID: requestID) else {
                fullTextFetchError = viewModel.rssArticleInspectorFetchErrorMessage(
                    viewModel.rssArticleInspectorNoContentValue
                )
                return
            }

            pageExtraction = extraction
            logger.info(
                "Full article text loaded in debug inspector",
                category: .ui,
                service: "DeveloperRSSArticleInspectionScreen",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "word_count": "\(extraction.wordCount)"
                ]
            )
        } catch {
            pageExtraction = nil
            fullTextFetchError = viewModel.rssArticleInspectorFetchErrorMessage(
                String(describing: error)
            )
            logger.warn(
                "Failed to fetch full article text in debug inspector",
                category: .ui,
                service: "DeveloperRSSArticleInspectionScreen",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "url": article.articleURL.absoluteString,
                    "error": String(describing: error)
                ]
            )
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contentBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .systemBackground))
                )
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperPlaygroundScreen(viewModel: DeveloperPlaygroundViewModel())
    }
}

#endif
