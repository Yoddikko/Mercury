//
//  ArticlePageContentExtractor.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct ArticlePageExtractionResult: Sendable, Equatable {
    let rawHTML: String
    let cleanedText: String
    let heroImageURLString: String?
    let wordCount: Int
    let isLikelyComplete: Bool
}

struct ArticlePageContentExtractor: Sendable {
    private let logger: AppLogger

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    func extract(from html: String, requestID: String? = nil) -> ArticlePageExtractionResult? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            logger.trace(
                "Article page extraction skipped due to empty HTML",
                category: .business,
                service: "ArticlePageContentExtractor",
                requestID: requestID
            )
            return nil
        }

        let sanitized = removingNonContentTags(from: trimmed)
        let candidate = bestContentCandidate(in: sanitized)
        let fallbackBody = bodyHTML(in: sanitized) ?? sanitized
        let candidateCleaned = cleanedText(from: candidate)
        let fallbackCleaned = cleanedText(from: fallbackBody)
        let candidateWordCount = wordCount(in: candidateCleaned)
        let fallbackWordCount = wordCount(in: fallbackCleaned)

        let usesFallbackBody = shouldPreferFallbackBody(
            candidateWords: candidateWordCount,
            fallbackWords: fallbackWordCount,
            candidateText: candidateCleaned
        )
        let selectedHTML = usesFallbackBody ? fallbackBody : candidate
        let cleaned = usesFallbackBody ? fallbackCleaned : candidateCleaned

        guard cleaned.isEmpty == false else {
            logger.trace(
                "Article page extraction produced empty cleaned text",
                category: .business,
                service: "ArticlePageContentExtractor",
                requestID: requestID
            )
            return nil
        }

        let words = wordCount(in: cleaned)
        let complete = isLikelyComplete(cleanedText: cleaned, wordCount: words)
        let heroImageURLString = extractHeroImageURLString(from: sanitized)
        let clippedRaw = clip(selectedHTML, maxCharacters: 250_000)
        let clippedCleaned = clip(cleaned, maxCharacters: 250_000)

        logger.debug(
            "Article page extraction completed",
            category: .business,
            service: "ArticlePageContentExtractor",
            requestID: requestID,
            metadata: [
                "raw_chars": "\(clippedRaw.count)",
                "cleaned_chars": "\(clippedCleaned.count)",
                "word_count": "\(words)",
                "likely_complete": complete ? "true" : "false",
                "fallback_body_used": usesFallbackBody ? "true" : "false",
                "hero_image": heroImageURLString ?? "none"
            ]
        )

        return ArticlePageExtractionResult(
            rawHTML: clippedRaw,
            cleanedText: clippedCleaned,
            heroImageURLString: heroImageURLString,
            wordCount: words,
            isLikelyComplete: complete
        )
    }

    private func bestContentCandidate(in html: String) -> String {
        var candidates: [String] = []
        candidates.reserveCapacity(8)

        candidates.append(contentsOf: matches(in: html, regex: Self.articleRegex))
        candidates.append(contentsOf: matches(in: html, regex: Self.mainRegex))
        candidates.append(contentsOf: matches(in: html, regex: Self.keywordContainerRegex))

        if candidates.isEmpty {
            return bodyHTML(in: html) ?? html
        }

        return candidates.max(by: { lhs, rhs in
            wordCount(in: cleanedText(from: lhs)) < wordCount(in: cleanedText(from: rhs))
        }) ?? html
    }

    private func bodyHTML(in html: String) -> String? {
        guard let bodyRegex = Self.bodyRegex else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = bodyRegex.firstMatch(in: html, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }

        return substring(in: html, range: match.range(at: 1))
    }

    private func matches(in html: String, regex: NSRegularExpression?) -> [String] {
        guard let regex else { return [] }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let found = regex.matches(in: html, options: [], range: range)
        var values: [String] = []
        values.reserveCapacity(found.count)

        for match in found {
            guard match.numberOfRanges > 1 else { continue }
            guard let extracted = substring(in: html, range: match.range(at: 1)) else { continue }
            let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            values.append(trimmed)
        }

        return values
    }

    private func cleanedText(from html: String) -> String {
        var output = html
        output = output.replacingOccurrences(
            of: "(?i)<\\s*br\\s*/?\\s*>",
            with: "\n",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "(?i)</\\s*(p|div|section|article|main|h[1-6]|li|blockquote)\\s*>",
            with: "\n",
            options: .regularExpression
        )
        output = output.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        output = decodeHTMLEntities(output)
        output = output.replacingOccurrences(of: "\r\n", with: "\n")
        output = output.replacingOccurrences(of: "\r", with: "\n")

        let lines = output.components(separatedBy: .newlines)
        var normalized: [String] = []
        normalized.reserveCapacity(lines.count)

        for line in lines {
            let collapsed = line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard collapsed.isEmpty == false else { continue }
            normalized.append(collapsed)
        }

        return normalized.joined(separator: "\n")
    }

    private func extractHeroImageURLString(from html: String) -> String? {
        for regex in Self.heroImageMetaRegexes {
            let values = matches(in: html, regex: regex)
            if let first = values.first(where: { $0.isEmpty == false }) {
                return decodeHTMLEntities(first)
            }
        }

        if let firstImage = matches(in: html, regex: Self.firstImageRegex).first {
            return decodeHTMLEntities(firstImage)
        }

        return nil
    }

    private func removingNonContentTags(from html: String) -> String {
        var output = html
        output = output.replacingOccurrences(
            of: "(?is)<(script|style|noscript|svg|canvas|iframe|form)[^>]*>.*?</\\1>",
            with: " ",
            options: .regularExpression
        )
        return output
    }

    private func shouldPreferFallbackBody(
        candidateWords: Int,
        fallbackWords: Int,
        candidateText: String
    ) -> Bool {
        guard fallbackWords > candidateWords else { return false }
        guard fallbackWords >= 60 else { return false }

        if candidateWords < 80 {
            return true
        }

        if candidateWords < 140, fallbackWords >= candidateWords + 40 {
            return true
        }

        if fallbackWords >= (candidateWords * 2), fallbackWords >= candidateWords + 100 {
            return true
        }

        let lowered = candidateText.lowercased()
        let truncationHints = [
            "read more",
            "continue reading",
            "subscribe to continue",
            "sign in to continue",
            "view the full article"
        ]

        for hint in truncationHints where lowered.contains(hint) {
            return fallbackWords >= candidateWords + 20
        }

        return false
    }

    private func isLikelyComplete(cleanedText: String, wordCount: Int) -> Bool {
        guard wordCount >= 160 else { return false }

        let lower = cleanedText.lowercased()
        let truncationHints = [
            "read more",
            "continue reading",
            "subscribe to continue",
            "sign in to continue"
        ]

        for hint in truncationHints where lower.contains(hint) {
            return false
        }

        let trimmed = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("...") || trimmed.hasSuffix("…") || trimmed.hasSuffix("[…]") {
            return false
        }

        return true
    }

    private func clip(_ value: String, maxCharacters: Int) -> String {
        guard value.count > maxCharacters else { return value }
        return String(value.prefix(maxCharacters))
    }

    private func wordCount(in value: String) -> Int {
        value.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func substring(in text: String, range: NSRange) -> String? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
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
            "&nbsp;": " ",
            "&#8211;": "-",
            "&#8212;": "-",
            "&#8220;": "\"",
            "&#8221;": "\""
        ]

        for (entity, replacement) in entityMap {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }

        return output
    }

    private static let articleRegex = try? NSRegularExpression(
        pattern: "(?is)<article\\b[^>]*>(.*?)</article>",
        options: []
    )
    private static let mainRegex = try? NSRegularExpression(
        pattern: "(?is)<main\\b[^>]*>(.*?)</main>",
        options: []
    )
    private static let keywordContainerRegex = try? NSRegularExpression(
        pattern: "(?is)<(?:section|div)\\b[^>]*(?:id|class)\\s*=\\s*['\\\"][^'\\\"]*(?:article|story|post|entry|content|body)[^'\\\"]*['\\\"][^>]*>(.*?)</(?:section|div)>",
        options: []
    )
    private static let bodyRegex = try? NSRegularExpression(
        pattern: "(?is)<body\\b[^>]*>(.*?)</body>",
        options: []
    )
    private static let firstImageRegex = try? NSRegularExpression(
        pattern: "(?is)<img\\b[^>]*\\bsrc\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"][^>]*>",
        options: []
    )
    private static let heroImageMetaRegexes: [NSRegularExpression?] = [
        try? NSRegularExpression(
            pattern: "(?is)<meta\\b[^>]*(?:property|name)\\s*=\\s*['\\\"](?:og:image|twitter:image|twitter:image:src)['\\\"][^>]*\\bcontent\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"][^>]*>",
            options: []
        ),
        try? NSRegularExpression(
            pattern: "(?is)<meta\\b[^>]*\\bcontent\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"][^>]*(?:property|name)\\s*=\\s*['\\\"](?:og:image|twitter:image|twitter:image:src)['\\\"][^>]*>",
            options: []
        )
    ]
}
