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

    var aiProviderConfigurationSectionTitle: String {
        String(localized: "developer.playground.section.ai_provider_configuration", defaultValue: "AI Provider Configuration")
    }

    var aiProviderConfigurationDescription: String {
        String(
            localized: "developer.playground.ai_provider_configuration.description",
            defaultValue: "Configure active AI provider, models, credentials, and run live provider checks."
        )
    }

    var aiProviderActiveProviderLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.active_provider", defaultValue: "Active provider")
    }

    var aiProviderModelsSectionTitle: String {
        String(localized: "developer.playground.ai_provider_configuration.models_section", defaultValue: "Models")
    }

    var aiProviderOpenAIModelLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.model.openai", defaultValue: "OpenAI model")
    }

    var aiProviderClaudeModelLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.model.claude", defaultValue: "Claude model")
    }

    var aiProviderGeminiModelLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.model.gemini", defaultValue: "Gemini model")
    }

    var aiProviderOllamaModelLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.model.ollama", defaultValue: "Ollama model")
    }

    var aiProviderOllamaEndpointLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.ollama_endpoint", defaultValue: "Ollama endpoint")
    }

    var aiProviderTimeoutLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.timeout", defaultValue: "Timeout (seconds)")
    }

    var aiProviderSaveConfigurationLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.save_configuration", defaultValue: "Save configuration")
    }

    var aiProviderSavingConfigurationLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.saving_configuration", defaultValue: "Saving configuration…")
    }

    var aiProviderCredentialsSectionTitle: String {
        String(localized: "developer.playground.ai_provider_configuration.credentials_section", defaultValue: "Credentials")
    }

    var aiProviderOpenAITokenLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.token.openai", defaultValue: "OpenAI token")
    }

    var aiProviderClaudeTokenLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.token.claude", defaultValue: "Claude token")
    }

    var aiProviderGeminiTokenLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.token.gemini", defaultValue: "Gemini token")
    }

    var aiProviderOllamaTokenLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.token.ollama", defaultValue: "Ollama token (optional)")
    }

    var aiProviderSaveCredentialsLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.save_credentials", defaultValue: "Save credentials")
    }

    var aiProviderSavingCredentialsLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.saving_credentials", defaultValue: "Saving credentials…")
    }

    var aiProviderTokenPresentLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.token.present", defaultValue: "Token stored")
    }

    var aiProviderTokenMissingLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.token.missing", defaultValue: "Token missing")
    }

    var aiProviderCheckPromptLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.check_prompt", defaultValue: "Prompt for AI checks")
    }

    var aiProviderRunChecksLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.run_checks", defaultValue: "Run AI checks")
    }

    var aiProviderRunningChecksLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.running_checks", defaultValue: "Running AI checks…")
    }

    var aiProviderCheckSummaryLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.check_summary", defaultValue: "Summary")
    }

    var aiProviderCheckCategoryLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.check_category", defaultValue: "Category")
    }

    var aiProviderCheckTagsLabel: String {
        String(localized: "developer.playground.ai_provider_configuration.check_tags", defaultValue: "Tags")
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

    var rssArticleInspectorPageFetchSectionTitle: String {
        String(localized: "developer.playground.rss.article_inspector.section.page_fetch", defaultValue: "Article Page Fetch")
    }

    var rssArticleInspectorFieldID: String {
        String(localized: "developer.playground.rss.article_inspector.field.id", defaultValue: "ID")
    }

    var rssArticleInspectorFieldExternalID: String {
        String(localized: "developer.playground.rss.article_inspector.field.external_id", defaultValue: "External ID")
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

    var rssArticleInspectorFieldAuthor: String {
        String(localized: "developer.playground.rss.article_inspector.field.author", defaultValue: "Author")
    }

    var rssArticleInspectorFieldImageURL: String {
        String(localized: "developer.playground.rss.article_inspector.field.image_url", defaultValue: "Image URL")
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

    var rssArticleInspectorFieldContentSource: String {
        String(localized: "developer.playground.rss.article_inspector.field.content_source", defaultValue: "Content Source")
    }

    var rssArticleInspectorFieldWordCount: String {
        String(localized: "developer.playground.rss.article_inspector.field.word_count", defaultValue: "Word Count")
    }

    var rssArticleInspectorFieldLikelyComplete: String {
        String(localized: "developer.playground.rss.article_inspector.field.likely_complete", defaultValue: "Likely Complete Body")
    }

    var rssArticleInspectorFieldDisplayedContent: String {
        String(localized: "developer.playground.rss.article_inspector.field.displayed_content", defaultValue: "Displayed Content")
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

    var rssArticleInspectorCheckHasImage: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_image", defaultValue: "Image is present")
    }

    var rssArticleInspectorCheckHasAuthor: String {
        String(localized: "developer.playground.rss.article_inspector.check.has_author", defaultValue: "Author is present")
    }

    var rssArticleInspectorCheckLikelyComplete: String {
        String(localized: "developer.playground.rss.article_inspector.check.likely_complete", defaultValue: "Body looks complete")
    }

    var rssArticleInspectorContentSourceFeedContent: String {
        String(localized: "developer.playground.rss.article_inspector.content_source.feed_content", defaultValue: "Feed full-content field")
    }

    var rssArticleInspectorContentSourceFeedSummary: String {
        String(localized: "developer.playground.rss.article_inspector.content_source.feed_summary", defaultValue: "Feed summary/description")
    }

    var rssArticleInspectorContentSourceArticlePage: String {
        String(localized: "developer.playground.rss.article_inspector.content_source.article_page", defaultValue: "Article page extraction")
    }

    var rssArticleInspectorContentSourceNone: String {
        String(localized: "developer.playground.rss.article_inspector.content_source.none", defaultValue: "Unavailable")
    }

    var rssArticleInspectorBooleanYes: String {
        String(localized: "developer.playground.rss.article_inspector.boolean.yes", defaultValue: "Yes")
    }

    var rssArticleInspectorBooleanNo: String {
        String(localized: "developer.playground.rss.article_inspector.boolean.no", defaultValue: "No")
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

    var rssArticleInspectorFetchFullTextLabel: String {
        String(localized: "developer.playground.rss.article_inspector.fetch_full_text", defaultValue: "Fetch full article text")
    }

    var rssArticleInspectorRefetchFullTextLabel: String {
        String(localized: "developer.playground.rss.article_inspector.refetch_full_text", defaultValue: "Refetch article text")
    }

    var rssArticleInspectorFetchingFullTextLabel: String {
        String(localized: "developer.playground.rss.article_inspector.fetching_full_text", defaultValue: "Fetching article page content…")
    }

    var rssArticleInspectorFullTextReadyLabel: String {
        String(localized: "developer.playground.rss.article_inspector.full_text_ready", defaultValue: "Full article content loaded from page.")
    }

    var rssArticleInspectorDisplayedContentFeed: String {
        String(localized: "developer.playground.rss.article_inspector.displayed_content.feed", defaultValue: "Feed payload")
    }

    var rssArticleInspectorDisplayedContentArticlePage: String {
        String(localized: "developer.playground.rss.article_inspector.displayed_content.article_page", defaultValue: "Article page fetch")
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

    func aiProviderTokenStateLabel(hasToken: Bool) -> String {
        hasToken ? aiProviderTokenPresentLabel : aiProviderTokenMissingLabel
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

    func rssContentSourceLabel(_ source: String) -> String {
        switch source {
        case "feed_content":
            return rssArticleInspectorContentSourceFeedContent
        case "feed_summary":
            return rssArticleInspectorContentSourceFeedSummary
        case "article_page":
            return rssArticleInspectorContentSourceArticlePage
        default:
            return rssArticleInspectorContentSourceNone
        }
    }

    func rssDisplayedContentLabel(isUsingArticlePageFetch: Bool) -> String {
        isUsingArticlePageFetch
            ? rssArticleInspectorDisplayedContentArticlePage
            : rssArticleInspectorDisplayedContentFeed
    }

    func rssArticleInspectorFetchErrorMessage(_ message: String) -> String {
        let format = String(
            localized: "developer.playground.rss.article_inspector.fetch_error",
            defaultValue: "Unable to fetch full article text: %@"
        )
        return String(format: format, locale: .current, message)
    }

    private static let rssInspectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
