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
}
