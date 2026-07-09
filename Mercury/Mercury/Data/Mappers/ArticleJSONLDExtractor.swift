//
//  ArticleJSONLDExtractor.swift
//  Mercury
//
//  Created by Claude on 03/07/26.
//

import Foundation
import SwiftSoup

/// The schema.org article node extracted from a page's JSON-LD blocks
/// (issue #98).
///
/// `articleBody` is the CMS-provided plain text of the article — when
/// present and substantial it is the cleanest possible source for the
/// distilled body: zero page chrome by construction, because the CMS
/// serializes only the editorial content into it.
struct ArticleJSONLDResult: Sendable, Equatable {
    /// Plain-text article body. Paragraph breaks, when the CMS encodes
    /// them at all, arrive as newline runs.
    let articleBody: String
    /// schema.org `headline`, when declared on the same node.
    let headline: String?
    /// schema.org `isAccessibleForFree`. `nil` when the node does not
    /// declare it. CMSes ship it as JSON booleans (`false`) or strings
    /// (`"False"`, `"https://schema.org/False"`) — all normalized here.
    let isAccessibleForFree: Bool?
}

/// Parses `<script type="application/ld+json">` blocks out of a raw
/// article page and returns the first schema.org Article-family node
/// carrying a non-empty `articleBody` (issue #98).
///
/// Notes from the 2026-07-03 corpus survey:
/// * root payloads are objects, arrays of objects, or objects with an
///   `@graph` array — all three shapes are handled;
/// * `@type` is a string or an array of strings; any type whose name
///   ends in `Article` (NewsArticle, ReportageNewsArticle, Article, …)
///   qualifies, plus `BlogPosting`;
/// * Italian outlets that embed `articleBody`: Repubblica, Il Fatto,
///   RaiNews, TGCom24, Gazzetta, Il Messaggero; ANSA does NOT (it uses
///   microdata `itemprop="articleBody"` instead, handled by the DOM
///   pipeline).
///
/// Like every distillation stage this never throws: malformed JSON-LD
/// blocks are skipped and a page without a usable node returns `nil`,
/// letting the DOM pipeline take over.
struct ArticleJSONLDExtractor: Sendable {
    private let logger: AppLogger

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    /// Returns the first Article-family JSON-LD node with a non-empty
    /// `articleBody`, or `nil` when the page has none.
    func articleNode(fromRawHTML html: String, requestID: String? = nil) -> ArticleJSONLDResult? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let scripts: [String]
        do {
            let document = try SwiftSoup.parse(trimmed)
            scripts = try document
                .select("script[type=application/ld+json]")
                .array()
                .map { $0.data() }
        } catch {
            logger.trace(
                "JSON-LD scan failed to parse page HTML",
                category: .business,
                service: "ArticleJSONLDExtractor",
                requestID: requestID,
                metadata: ["error": String(describing: error)]
            )
            return nil
        }

        var scanned = 0
        for script in scripts {
            scanned += 1
            guard let node = firstArticleNode(inJSONText: script) else { continue }
            logger.debug(
                "JSON-LD article node found",
                category: .business,
                service: "ArticleJSONLDExtractor",
                requestID: requestID,
                metadata: [
                    "scripts_scanned": "\(scanned)",
                    "body_chars": "\(node.articleBody.count)",
                    "is_accessible_for_free": node.isAccessibleForFree.map { "\($0)" } ?? "undeclared"
                ]
            )
            return node
        }

        logger.trace(
            "No JSON-LD article node with articleBody on page",
            category: .business,
            service: "ArticleJSONLDExtractor",
            requestID: requestID,
            metadata: ["scripts_scanned": "\(scanned)"]
        )
        return nil
    }

    // MARK: - JSON traversal

    private func firstArticleNode(inJSONText text: String) -> ArticleJSONLDResult? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Some CMSes wrap the payload in CDATA or HTML comments.
            .replacingOccurrences(of: "<!\\[CDATA\\[|\\]\\]>|^<!--|-->$", with: "", options: .regularExpression)
        guard let data = cleaned.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        for node in candidateNodes(from: root) {
            if let result = articleResult(from: node) {
                return result
            }
        }
        return nil
    }

    /// Flattens the three root shapes (object / array / `@graph`) into
    /// a list of candidate dictionaries.
    private func candidateNodes(from root: Any) -> [[String: Any]] {
        if let array = root as? [Any] {
            return array.flatMap { candidateNodes(from: $0) }
        }
        guard let object = root as? [String: Any] else { return [] }
        if let graph = object["@graph"] as? [Any] {
            return [object] + graph.flatMap { candidateNodes(from: $0) }
        }
        return [object]
    }

    private func articleResult(from node: [String: Any]) -> ArticleJSONLDResult? {
        guard isArticleType(node["@type"]) else { return nil }
        guard let rawBody = node["articleBody"] as? String else { return nil }
        let body = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else { return nil }

        return ArticleJSONLDResult(
            articleBody: body,
            headline: (node["headline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            isAccessibleForFree: normalizedBool(node["isAccessibleForFree"])
        )
    }

    private func isArticleType(_ rawType: Any?) -> Bool {
        let types: [String]
        if let single = rawType as? String {
            types = [single]
        } else if let many = rawType as? [String] {
            types = many
        } else {
            return false
        }
        return types.contains { type in
            let normalized = type.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.hasSuffix("Article") || normalized == "BlogPosting"
        }
    }

    /// Normalizes the JSON-LD boolean encodings observed in the wild:
    /// JSON booleans, `"true"` / `"False"` strings, and the schema.org
    /// URL forms (`"https://schema.org/False"`).
    private func normalizedBool(_ raw: Any?) -> Bool? {
        if let bool = raw as? Bool { return bool }
        if let number = raw as? NSNumber { return number.boolValue }
        guard let string = raw as? String else { return nil }
        let lowered = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "true" || lowered.hasSuffix("/true") { return true }
        if lowered == "false" || lowered.hasSuffix("/false") { return false }
        return nil
    }
}
