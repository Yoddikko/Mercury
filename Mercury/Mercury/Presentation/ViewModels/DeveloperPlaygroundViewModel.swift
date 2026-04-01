//
//  DeveloperPlaygroundViewModel.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

struct DeveloperPlaygroundViewModel {
    struct ProviderOption: Identifiable, Hashable {
        let id: String
        let displayName: String
    }

    static let defaultProviderID = "openai"

    let providerOptions: [ProviderOption] = [
        ProviderOption(id: "openai", displayName: "OpenAI"),
        ProviderOption(id: "claude", displayName: "Claude"),
        ProviderOption(id: "gemini", displayName: "Gemini"),
        ProviderOption(id: "ollama", displayName: "Ollama")
    ]

    var title: String {
        String(
            localized: "developer.playground.title",
            defaultValue: "Developer Playground"
        )
    }

    var subtitle: String {
        String(
            localized: "developer.playground.subtitle",
            defaultValue: "Debug-only sandbox to test app services and development flows."
        )
    }

    var aiSimulationSectionTitle: String {
        String(localized: "developer.playground.section.ai_simulation", defaultValue: "AI Simulation")
    }

    var providerLabel: String {
        String(localized: "developer.playground.provider", defaultValue: "Provider")
    }

    var promptInputLabel: String {
        String(localized: "developer.playground.prompt_input", defaultValue: "Prompt input")
    }

    var runSimulationLabel: String {
        String(localized: "developer.playground.run_simulation", defaultValue: "Run simulation")
    }

    var swiftDataSandboxSectionTitle: String {
        String(localized: "developer.playground.section.swiftdata_sandbox", defaultValue: "SwiftData Sandbox")
    }

    var insertSampleRecordLabel: String {
        String(localized: "developer.playground.insert_sample_record", defaultValue: "Insert sample record")
    }

    var clearRecordsLabel: String {
        String(localized: "developer.playground.clear_records", defaultValue: "Clear records")
    }

    var rssDiagnosticsSectionTitle: String {
        String(localized: "developer.playground.section.rss_diagnostics", defaultValue: "RSS Diagnostics")
    }

    var rssGroupLabel: String {
        String(localized: "developer.playground.rss.group", defaultValue: "Group")
    }

    var rssRegionLabel: String {
        String(localized: "developer.playground.rss.region", defaultValue: "Region")
    }

    var runRSSDiagnosticsLabel: String {
        String(localized: "developer.playground.rss.run", defaultValue: "Run RSS diagnostics")
    }

    var runningRSSDiagnosticsLabel: String {
        String(localized: "developer.playground.rss.running", defaultValue: "Fetching and validating feeds…")
    }

    var rssSummarySectionTitle: String {
        String(localized: "developer.playground.rss.summary", defaultValue: "RSS Summary")
    }

    var rssMissingFeedsSectionTitle: String {
        String(localized: "developer.playground.rss.missing_feeds", defaultValue: "No Feed URL / Invalid URL")
    }

    var rssFailedFeedsSectionTitle: String {
        String(localized: "developer.playground.rss.failed_feeds", defaultValue: "Failed Feeds")
    }

    var rssNoArticlesSectionTitle: String {
        String(localized: "developer.playground.rss.no_articles", defaultValue: "Feeds With No Articles")
    }

    var rssSuccessSectionTitle: String {
        String(localized: "developer.playground.rss.success_feeds", defaultValue: "Successful Feeds")
    }

    var rssArticlesSectionTitle: String {
        String(localized: "developer.playground.rss.articles", defaultValue: "Normalized Articles")
    }

    var rssExportOutletsReportLabel: String {
        String(localized: "developer.playground.rss.export_report", defaultValue: "Export outlets report")
    }

    var rssExportingOutletsReportLabel: String {
        String(localized: "developer.playground.rss.exporting_report", defaultValue: "Preparing outlets report…")
    }

    var rssOutletsReportReadyLabel: String {
        String(localized: "developer.playground.rss.report_ready", defaultValue: "Outlets report ready for sharing.")
    }

    var rssTapArticleToInspectLabel: String {
        String(localized: "developer.playground.rss.tap_to_inspect", defaultValue: "Tap an article to inspect the full fetched payload.")
    }

    var rssArticleInspectorTitle: String {
        String(localized: "developer.playground.rss.article_inspector.title", defaultValue: "Fetched Article Detail")
    }

    var rssArticleInspectorOverviewSectionTitle: String {
        String(localized: "developer.playground.rss.article_inspector.section.overview", defaultValue: "Overview")
    }

    var rssArticleInspectorChecksSectionTitle: String {
        String(localized: "developer.playground.rss.article_inspector.section.checks", defaultValue: "Data Checks")
    }

    var rssArticleInspectorContentSectionTitle: String {
        String(localized: "developer.playground.rss.article_inspector.section.content", defaultValue: "Content")
    }

    var rssArticleInspectorFieldID: String {
        String(localized: "developer.playground.rss.article_inspector.field.id", defaultValue: "ID")
    }

    var rssArticleInspectorFieldSource: String {
        String(localized: "developer.playground.rss.article_inspector.field.source", defaultValue: "Source")
    }

    var rssArticleInspectorFieldSourceURL: String {
        String(localized: "developer.playground.rss.article_inspector.field.source_url", defaultValue: "Source URL")
    }

    var rssArticleInspectorFieldArticleURL: String {
        String(localized: "developer.playground.rss.article_inspector.field.article_url", defaultValue: "Article URL")
    }

    var rssArticleInspectorFieldPublishedAt: String {
        String(localized: "developer.playground.rss.article_inspector.field.published_at", defaultValue: "Published At")
    }

    var rssArticleInspectorFieldLanguage: String {
        String(localized: "developer.playground.rss.article_inspector.field.language", defaultValue: "Language")
    }

    var rssArticleInspectorFieldCategory: String {
        String(localized: "developer.playground.rss.article_inspector.field.category", defaultValue: "Category")
    }

    var rssArticleInspectorFieldTags: String {
        String(localized: "developer.playground.rss.article_inspector.field.tags", defaultValue: "Tags")
    }

    var rssArticleInspectorFieldRawContent: String {
        String(localized: "developer.playground.rss.article_inspector.field.raw_content", defaultValue: "Raw Content")
    }

    var rssArticleInspectorFieldCleanedContent: String {
        String(localized: "developer.playground.rss.article_inspector.field.cleaned_content", defaultValue: "Cleaned Content")
    }

    var rssArticleInspectorFieldSummaryShort: String {
        String(localized: "developer.playground.rss.article_inspector.field.summary_short", defaultValue: "Summary Short")
    }

    var rssArticleInspectorFieldSummaryBullets: String {
        String(localized: "developer.playground.rss.article_inspector.field.summary_bullets", defaultValue: "Summary Bullets")
    }

    var rssArticleInspectorCheckHasTitle: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_title", defaultValue: "Title is present")
    }

    var rssArticleInspectorCheckHasArticleURL: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_article_url", defaultValue: "Article URL is present")
    }

    var rssArticleInspectorCheckHasPublishedDate: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_published_date", defaultValue: "Published date is meaningful")
    }

    var rssArticleInspectorCheckHasContent: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_content", defaultValue: "Content payload is present")
    }

    var rssArticleInspectorCheckHasLanguage: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_language", defaultValue: "Language is present")
    }

    var rssArticleInspectorEmptyValue: String {
        String(localized: "developer.playground.rss.article_inspector.empty_value", defaultValue: "-")
    }

    var rssArticleInspectorNoContentValue: String {
        String(localized: "developer.playground.rss.article_inspector.no_content", defaultValue: "No content available.")
    }

    var rssArticleInspectorNoBulletsValue: String {
        String(localized: "developer.playground.rss.article_inspector.no_bullets", defaultValue: "No bullets available.")
    }

    var loggingSectionTitle: String {
        String(localized: "developer.playground.section.logging", defaultValue: "Logging")
    }

    var exportLogsLabel: String {
        String(localized: "developer.playground.logging.export", defaultValue: "Export logs")
    }

    var exportingLogsLabel: String {
        String(localized: "developer.playground.logging.exporting", defaultValue: "Preparing log export…")
    }

    var clearLogsLabel: String {
        String(localized: "developer.playground.logging.clear", defaultValue: "Clear logs")
    }

    var logExportReadyLabel: String {
        String(localized: "developer.playground.logging.ready", defaultValue: "Log file ready for sharing.")
    }

    var logExportShareLabel: String {
        String(localized: "developer.playground.logging.share", defaultValue: "Share exported logs")
    }

    func logEntriesLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.logging.entries",
            defaultValue: "Stored log entries: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func simulatedSummary(prompt: String, providerID: String) -> String {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPrompt.isEmpty == false else {
            return String(
                localized: "developer.playground.simulation.empty",
                defaultValue: "Enter a prompt to run a local simulation."
            )
        }

        let providerName = providerOptions.first(where: { $0.id == providerID })?.displayName ?? providerID
        let prefix = String(
            localized: "developer.playground.simulation.prefix",
            defaultValue: "Simulated summary"
        )
        let trimmedPrompt = String(normalizedPrompt.prefix(140))

        return "\(prefix) [\(providerName)]: \(trimmedPrompt)"
    }

    func makeSampleStoredArticle(existingCount: Int) -> StoredArticle {
        StoredArticle(
            title: "Debug Article \(existingCount + 1)",
            sourceName: "Developer Sandbox"
        )
    }

    func storedDebugRecordsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.stored_debug_records",
            defaultValue: "Stored debug records: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssSelectedOutletsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.selected_outlets",
            defaultValue: "Selected outlets: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssOutletsCheckedLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.outlets_checked",
            defaultValue: "Outlets checked: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssSuccessfulFeedsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.success_count",
            defaultValue: "Successful feeds: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssNoArticlesFeedsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.no_articles_count",
            defaultValue: "Feeds with no articles: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssMissingFeedsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.missing_count",
            defaultValue: "Outlets with no feed URL: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssFailedFeedsLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.failed_count",
            defaultValue: "Failed feeds: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssDeduplicatedArticlesLabel(count: Int) -> String {
        let format = String(
            localized: "developer.playground.rss.deduped_count",
            defaultValue: "Deduplicated articles: %lld"
        )
        return String(format: format, locale: .current, Int64(count))
    }

    func rssDurationLabel(milliseconds: Int?) -> String {
        let value = milliseconds ?? 0
        let format = String(
            localized: "developer.playground.rss.duration_ms",
            defaultValue: "Last run duration: %lld ms"
        )
        return String(format: format, locale: .current, Int64(value))
    }

    func rssCheckCaption(result: RSSFeedCheckResult, statusTitle: String) -> String {
        if result.status == .success {
            let format = String(
                localized: "developer.playground.rss.caption.success",
                defaultValue: "%@ • %lld articles • %lld ms"
            )
            return String(
                format: format,
                locale: .current,
                statusTitle,
                Int64(result.articles.count),
                Int64(result.elapsedMs)
            )
        }

        let format = String(
            localized: "developer.playground.rss.caption.default",
            defaultValue: "%@ • %lld ms"
        )
        return String(
            format: format,
            locale: .current,
            statusTitle,
            Int64(result.elapsedMs)
        )
    }

    func formattedRSSInspectionDate(_ date: Date) -> String {
        Self.rssInspectionDateFormatter.string(from: date)
    }

    private static let rssInspectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
