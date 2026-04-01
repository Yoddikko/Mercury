//
//  RSSDiagnosticsReportExporter.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

enum RSSDiagnosticsReportExporter {
    static func buildReport(from result: RSSFeedBatchResult) -> String {
        let successCount = result.checks.filter { $0.status == .success }.count
        let noArticlesCount = result.checks.filter { $0.status == .noArticles }.count
        let noFeedOrInvalidCount = result.checks.filter { $0.status == .noFeedURL || $0.status == .invalidFeedURL }.count
        let failedCount = result.checks.filter { $0.status == .requestFailed || $0.status == .parseFailed }.count

        var lines: [String] = []
        lines.append("Mercury RSS Outlets Report")
        lines.append("checked_at=\(iso8601Formatter.string(from: result.checkedAt))")
        lines.append("group_mode=\(result.groupMode.rawValue)")
        lines.append("selected_region=\(result.selectedRegion?.rawValue ?? "none")")
        lines.append("outlets_checked=\(result.checks.count)")
        lines.append("successful=\(successCount)")
        lines.append("no_articles=\(noArticlesCount)")
        lines.append("no_feed_or_invalid=\(noFeedOrInvalidCount)")
        lines.append("failed=\(failedCount)")
        lines.append("deduplicated_articles=\(result.deduplicatedArticles.count)")
        lines.append("")
        lines.append("outlets:")

        for check in result.checks {
            let status = check.status.rawValue.uppercased()
            let feedURL = check.source.feedURLString ?? "-"
            let message = check.message ?? "-"
            lines.append(
                """
                [\(status)] outlet="\(escaped(check.source.outletName))" region="\(escaped(check.source.region.fallbackDisplayName))" main=\(check.source.isMainOutlet) articles=\(check.articles.count) elapsed_ms=\(check.elapsedMs) feed_url="\(escaped(feedURL))" message="\(escaped(message))"
                """
            )
        }

        return lines.joined(separator: "\n")
    }

    static func exportReport(
        from result: RSSFeedBatchResult,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> URL {
        let reportText = buildReport(from: result)
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("MercuryRSSReports", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileName = "rss-outlets-report-\(fileNameTimestamp(now)).log"
        let fileURL = directory.appendingPathComponent(fileName)
        try Data(reportText.utf8).write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func fileNameTimestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return String(
            format: "%04d%02d%02d-%02d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
