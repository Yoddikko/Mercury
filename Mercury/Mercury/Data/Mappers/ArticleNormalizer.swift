//
//  ArticleNormalizer.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import CryptoKit
import Foundation

struct ArticleNormalizer: Sendable {
    private enum FeedContentSource: String {
        case feedContent = "feed_content"
        case feedSummary = "feed_summary"
        case unavailable = "none"
    }

    private struct ResolvedContent {
        let raw: String?
        let source: FeedContentSource
    }

    private let logger = AppLogger.shared
    private static let htmlImageRegex = try? NSRegularExpression(
        pattern: "<img\\b[^>]*?\\bsrc\\s*=\\s*(?:['\\\"]?)([^'\\\"\\s>]+)(?:['\\\"]?)[^>]*>",
        options: [.caseInsensitive]
    )

    func normalize(
        items: [RSSParsedItem],
        source: RSSFeedSource,
        requestID: String? = nil
    ) -> [Article] {
        logger.debug(
            "Starting article normalization",
            category: .business,
            service: "ArticleNormalizer",
            requestID: requestID,
            metadata: [
                "source_id": source.id,
                "items_in": "\(items.count)"
            ]
        )

        var deduplicatedByKey: [String: Article] = [:]

        for item in items {
            guard let article = normalize(item: item, source: source, requestID: requestID) else { continue }
            let dedupeKey = dedupeKey(for: article)

            if let existing = deduplicatedByKey[dedupeKey] {
                if article.publishedAt > existing.publishedAt {
                    deduplicatedByKey[dedupeKey] = article
                }
                continue
            }

            deduplicatedByKey[dedupeKey] = article
        }

        let normalized = deduplicatedByKey.values.sorted { lhs, rhs in
            lhs.publishedAt > rhs.publishedAt
        }

        logger.debug(
            "Completed article normalization",
            category: .business,
            service: "ArticleNormalizer",
            requestID: requestID,
            metadata: [
                "source_id": source.id,
                "articles_out": "\(normalized.count)"
            ]
        )

        return normalized
    }

    func dedupeKey(for article: Article) -> String {
        canonicalURLString(article.articleURL) ?? article.id
    }

    private func normalize(
        item: RSSParsedItem,
        source: RSSFeedSource,
        requestID: String?
    ) -> Article? {
        let cleanedTitle = resolvedTitle(item: item, source: source)
        guard cleanedTitle.isEmpty == false else {
            logger.trace(
                "Skipped RSS item with no usable title candidates",
                category: .business,
                service: "ArticleNormalizer",
                requestID: requestID,
                metadata: ["source_id": source.id]
            )
            return nil
        }

        let now = Date()
        let articleURL = resolvedArticleURL(item.link, fallback: source.resolvedURL)
        let publishedAt = RSSDateParser.parse(item.publishedAtRaw) ?? .distantPast
        let resolvedContent = resolvedContent(for: item)
        let rawContent = resolvedContent.raw
        let cleanedContent = sanitizeText(rawContent)
        let contentWordCount = wordCount(in: cleanedContent)
        let likelyCompleteContent = isLikelyCompleteContent(
            rawContent: rawContent,
            cleanedContent: cleanedContent,
            source: resolvedContent.source
        )
        let tags = deduplicatedNormalizedTags(item.categories + source.tags)
        let summaryShort = resolvedSummaryShort(item: item, cleanedContent: cleanedContent)
        let authorName = sanitizedOptionalText(item.author)
        let heroImageURL = resolvedHeroImageURL(item: item, articleURL: articleURL, sourceURL: source.resolvedURL)

        let idSeed = [
            source.id,
            item.guid ?? "",
            canonicalURLString(articleURL) ?? "",
            cleanedTitle.lowercased()
        ].joined(separator: "|")

        let stableID = sha256(idSeed)
        let sourceURL = source.resolvedURL ?? URL(string: "https://example.invalid/\(source.id)")!

        return Article(
            id: stableID,
            externalID: sanitizedOptionalText(item.guid),
            title: cleanedTitle,
            sourceName: source.outletName,
            sourceURL: sourceURL,
            articleURL: articleURL,
            publishedAt: publishedAt,
            authorName: authorName,
            heroImageURL: heroImageURL,
            rawContent: rawContent,
            cleanedContent: cleanedContent.isEmpty ? nil : cleanedContent,
            contentSource: resolvedContent.source.rawValue,
            contentWordCount: contentWordCount,
            isContentLikelyComplete: likelyCompleteContent,
            summaryShort: summaryShort,
            summaryBullets: [],
            category: tags.first,
            tags: tags,
            language: firstNonEmpty(item.language, source.languageCode),
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func resolvedArticleURL(_ link: String?, fallback: URL?) -> URL {
        if let link {
            if let resolved = URL(string: link), let scheme = resolved.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return resolved
            }

            if let fallback,
               let resolved = URL(string: link, relativeTo: fallback)?.absoluteURL,
               let scheme = resolved.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return resolved
            }
        }

        if let fallback {
            return fallback
        }

        return URL(string: "https://example.invalid/")!
    }

    private func resolvedContent(for item: RSSParsedItem) -> ResolvedContent {
        if let content = firstNonEmpty(item.content, nil) {
            return ResolvedContent(raw: content, source: .feedContent)
        }

        if let summary = firstNonEmpty(item.summary, nil) {
            return ResolvedContent(raw: summary, source: .feedSummary)
        }

        return ResolvedContent(raw: nil, source: .unavailable)
    }

    private func canonicalURLString(_ url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let allowedTrackingParameters: Set<String> = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "fbclid", "gclid"]
        components.fragment = nil
        components.queryItems = components.queryItems?.filter { item in
            allowedTrackingParameters.contains(item.name.lowercased()) == false
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }

        return components.string?.lowercased()
    }

    private func sanitizeText(_ value: String?) -> String {
        guard let value else { return "" }
        guard value.isEmpty == false else { return "" }

        var output = value
        output = output.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        output = decodeHTMLEntities(output)
        output = output.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedOptionalText(_ value: String?) -> String? {
        let sanitized = sanitizeText(value)
        return sanitized.isEmpty ? nil : sanitized
    }

    private func resolvedTitle(item: RSSParsedItem, source: RSSFeedSource) -> String {
        let title = sanitizeText(item.title)
        if title.isEmpty == false {
            return title
        }

        let summaryFallback = sanitizeText(item.summary)
        if summaryFallback.isEmpty == false {
            return String(summaryFallback.prefix(120))
        }

        let contentFallback = sanitizeText(item.content)
        if contentFallback.isEmpty == false {
            return String(contentFallback.prefix(120))
        }

        if let link = item.link, link.isEmpty == false {
            return source.outletName
        }

        return ""
    }

    private func resolvedSummaryShort(item: RSSParsedItem, cleanedContent: String) -> String? {
        let explicitSummary = sanitizeText(item.summary)
        if explicitSummary.isEmpty == false {
            return String(explicitSummary.prefix(280))
        }

        if cleanedContent.isEmpty == false {
            if cleanedContent.count <= 280 {
                return cleanedContent
            }
            let snippet = String(cleanedContent.prefix(280)).trimmingCharacters(in: .whitespacesAndNewlines)
            return snippet.isEmpty ? nil : "\(snippet)…"
        }

        return nil
    }

    private func resolvedHeroImageURL(
        item: RSSParsedItem,
        articleURL: URL,
        sourceURL: URL?
    ) -> URL? {
        let directCandidate = sanitizedOptionalText(item.imageURL)
        let contentCandidate = firstImageSourceInHTML(item.content)
        let summaryCandidate = firstImageSourceInHTML(item.summary)
        let candidates = [directCandidate, contentCandidate, summaryCandidate]

        for candidate in candidates {
            guard let candidate else { continue }
            if let resolved = resolvedHTTPURL(candidate, fallback: articleURL) {
                return resolved
            }
            if let resolved = resolvedHTTPURL(candidate, fallback: sourceURL) {
                return resolved
            }
            if let resolved = resolvedHTTPURL(candidate, fallback: nil) {
                return resolved
            }
        }

        return nil
    }

    private func firstImageSourceInHTML(_ html: String?) -> String? {
        guard let html, html.isEmpty == false else { return nil }
        guard let regex = Self.htmlImageRegex else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range) else { return nil }
        guard match.numberOfRanges > 1 else { return nil }
        guard let captureRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[captureRange])
    }

    private func resolvedHTTPURL(_ value: String, fallback: URL?) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let absolute = URL(string: trimmed),
           let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absolute
        }

        if trimmed.hasPrefix("//") {
            let scheme = resolvedHTTPFallbackScheme(from: fallback)
            if let protocolRelative = URL(string: "\(scheme):\(trimmed)") {
                return protocolRelative
            }
        }

        if trimmed.lowercased().hasPrefix("www."),
           let normalized = URL(string: "https://\(trimmed)") {
            return normalized
        }

        if let fallback,
           let relative = URL(string: trimmed, relativeTo: fallback)?.absoluteURL,
           let scheme = relative.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return relative
        }

        return nil
    }

    private func resolvedHTTPFallbackScheme(from fallback: URL?) -> String {
        guard let scheme = fallback?.scheme?.lowercased() else {
            return "https"
        }
        if scheme == "http" || scheme == "https" {
            return scheme
        }
        return "https"
    }

    private func deduplicatedNormalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        output.reserveCapacity(8)

        for value in values {
            let normalized = sanitizeText(value)
            guard normalized.isEmpty == false else { continue }
            let lowered = normalized.lowercased()
            guard seen.insert(lowered).inserted else { continue }
            output.append(normalized)
            if output.count == 8 {
                break
            }
        }

        return output
    }

    private func wordCount(in value: String) -> Int {
        value.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func isLikelyCompleteContent(
        rawContent: String?,
        cleanedContent: String,
        source: FeedContentSource
    ) -> Bool {
        guard source == .feedContent else { return false }

        let words = wordCount(in: cleanedContent)
        guard words >= 120 else { return false }

        let lowercased = cleanedContent.lowercased()
        if lowercased.contains("read more") || lowercased.contains("continue reading") {
            return false
        }

        let trailing = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trailing.hasSuffix("...") || trailing.hasSuffix("…") || trailing.hasSuffix("[…]") {
            return false
        }

        if let rawContent {
            let lowerRaw = rawContent.lowercased()
            if lowerRaw.contains("href") && lowerRaw.contains("read more") {
                return false
            }
        }

        return true
    }

    private func decodeHTMLEntities(_ value: String) -> String {
        var output = value
        let entityMap: [String: String] = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " "
        ]

        for (entity, replacement) in entityMap {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }

        return output
    }

    private func firstNonEmpty(_ first: String?, _ second: String?) -> String? {
        if let first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return first
        }
        if let second, second.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return second
        }
        return nil
    }

    private func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private enum RSSDateParser {
    private static let rfc822Formats = [
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm zzz"
    ]

    private static let iso8601Options: [ISO8601DateFormatter.Options] = [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime]
    ]

    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return nil }

        for options in iso8601Options {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: value) {
                return date
            }
        }

        for format in rfc822Formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}
