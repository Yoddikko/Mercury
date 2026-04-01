//
//  ArticleNormalizer.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import CryptoKit
import Foundation

struct ArticleNormalizer: Sendable {
    func normalize(items: [RSSParsedItem], source: RSSFeedSource) -> [Article] {
        var deduplicatedByKey: [String: Article] = [:]

        for item in items {
            guard let article = normalize(item: item, source: source) else { continue }
            let dedupeKey = dedupeKey(for: article)

            if let existing = deduplicatedByKey[dedupeKey] {
                if article.publishedAt > existing.publishedAt {
                    deduplicatedByKey[dedupeKey] = article
                }
                continue
            }

            deduplicatedByKey[dedupeKey] = article
        }

        return deduplicatedByKey.values.sorted { lhs, rhs in
            lhs.publishedAt > rhs.publishedAt
        }
    }

    func dedupeKey(for article: Article) -> String {
        canonicalURLString(article.articleURL) ?? article.id
    }

    private func normalize(item: RSSParsedItem, source: RSSFeedSource) -> Article? {
        let cleanedTitle = sanitizeText(item.title)
        guard cleanedTitle.isEmpty == false else { return nil }

        let now = Date()
        let articleURL = resolvedArticleURL(item.link, fallback: source.resolvedURL)
        let publishedAt = RSSDateParser.parse(item.publishedAtRaw) ?? .distantPast
        let rawContent = firstNonEmpty(item.content, item.summary)
        let cleanedContent = sanitizeText(rawContent)
        let tags = Array(item.categories.prefix(6))

        let idSeed = [
            source.id,
            canonicalURLString(articleURL) ?? "",
            cleanedTitle.lowercased()
        ].joined(separator: "|")

        let stableID = sha256(idSeed)
        let sourceURL = source.resolvedURL ?? URL(string: "https://example.invalid/\(source.id)")!

        return Article(
            id: stableID,
            title: cleanedTitle,
            sourceName: source.outletName,
            sourceURL: sourceURL,
            articleURL: articleURL,
            publishedAt: publishedAt,
            rawContent: rawContent,
            cleanedContent: cleanedContent.isEmpty ? nil : cleanedContent,
            summaryShort: nil,
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
