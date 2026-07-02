//
//  ArticleOutletRuleApplier.swift
//  Mercury
//
//  Created by Claude on 02/07/26.
//

import Foundation
import SwiftSoup

/// Applies one `ArticleOutletExtractionRule` to article HTML
/// (issue #91 / meta #80).
///
/// Runs **before** the generic Readability-style pass
/// (`ArticleBoilerplateRemover`) inside
/// `ArticleContentEnrichmentService.distill`. The rule narrows the
/// document to the outlet's known body container and removes chrome
/// the generic heuristics cannot classify (ANSA Consentless CTA,
/// Corriere paywall promos, Repubblica related-link blocks). Hosts
/// without a rule skip this stage entirely, so the generic pipeline
/// is unchanged for them.
///
/// Like the rest of the distillation passes this NEVER throws: a
/// parse failure returns the input untouched so the downstream
/// fallback chain stays in charge.
struct ArticleOutletRuleApplier: Sendable {
    /// Elements whose matching text is always dropped, regardless of
    /// length (paragraph-level content is essentially never legit
    /// article body when it matches an outlet boilerplate pattern).
    private static let paragraphSelector = "p, li"
    /// Container/heading elements are dropped only when their text is
    /// short — mirrors `ArticleLocaleBoilerplateStripper` so a body
    /// wrapper that mentions a phrase in passing survives.
    private static let containerSelector = "div, span, h1, h2, h3, h4, h5, h6, header, aside, a"
    private static let containerTextCeiling = 80

    private let logger: AppLogger

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    /// Returns `html` with `rule` applied: body-selector narrowing
    /// first, then strip selectors, then strip text patterns.
    func applying(
        _ rule: ArticleOutletExtractionRule,
        to html: String,
        requestID: String? = nil
    ) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return html }

        do {
            let document = try SwiftSoup.parseBodyFragment(trimmed)
            guard var body = document.body() else { return html }

            let matchedBodySelector = try narrowToBodySelector(rule, body: &body)
            let strippedElements = try stripSelectors(rule, in: body)
            let strippedByPattern = try stripTextPatterns(rule, in: body)

            logger.debug(
                "Applied per-outlet extraction rule",
                category: .business,
                service: "ArticleOutletRuleApplier",
                requestID: requestID,
                metadata: [
                    "rule_id": rule.id,
                    "body_selector": matchedBodySelector ?? "none",
                    "stripped_elements": "\(strippedElements)",
                    "stripped_by_pattern": "\(strippedByPattern)"
                ]
            )

            return try body.html()
        } catch {
            logger.warn(
                "Per-outlet extraction rule failed to apply, keeping input",
                category: .business,
                service: "ArticleOutletRuleApplier",
                requestID: requestID,
                metadata: [
                    "rule_id": rule.id,
                    "error": String(describing: error)
                ]
            )
            return html
        }
    }

    // MARK: - Passes

    /// Tries each body selector in order; the first that matches at
    /// least one element replaces `body` with a fragment containing
    /// only the matched element(s). Nested matches are dropped so a
    /// selector matching both a wrapper and its child doesn't
    /// duplicate content. Returns the selector that matched, or `nil`
    /// when none did (document kept whole — a template change must
    /// never blank an article).
    private func narrowToBodySelector(
        _ rule: ArticleOutletExtractionRule,
        body: inout Element
    ) throws -> String? {
        for selector in rule.bodySelectors {
            let matches = (try? body.select(selector).array()) ?? []
            guard matches.isEmpty == false else { continue }

            let roots = matches.filter { element in
                matches.contains(where: { other in
                    other !== element && element.parents().contains(where: { $0 === other })
                }) == false
            }
            let fragment = roots
                .compactMap { try? $0.outerHtml() }
                .joined(separator: "\n")
            guard fragment.isEmpty == false else { continue }

            let narrowed = try SwiftSoup.parseBodyFragment(fragment)
            guard let newBody = narrowed.body() else { continue }
            body = newBody
            return selector
        }
        return nil
    }

    /// Removes every element matching a strip selector. Invalid
    /// selectors are skipped (never fatal). Returns the removed count.
    private func stripSelectors(
        _ rule: ArticleOutletExtractionRule,
        in body: Element
    ) throws -> Int {
        var removed = 0
        for selector in rule.stripSelectors {
            guard let matches = try? body.select(selector).array() else {
                logger.warn(
                    "Invalid stripSelector in outlet extraction rule",
                    category: .business,
                    service: "ArticleOutletRuleApplier",
                    metadata: ["rule_id": rule.id, "selector": selector]
                )
                continue
            }
            for element in matches {
                try element.remove()
                removed += 1
            }
        }
        return removed
    }

    /// Removes elements whose text matches a rule pattern, with the
    /// same policy as `ArticleLocaleBoilerplateStripper`: `p`/`li`
    /// always, short containers/headings only. Returns removed count.
    private func stripTextPatterns(
        _ rule: ArticleOutletExtractionRule,
        in body: Element
    ) throws -> Int {
        guard rule.stripTextPatterns.isEmpty == false else { return 0 }
        var removed = 0

        for element in try body.select(Self.paragraphSelector) {
            guard let text = try? element.text() else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            if ArticleLocaleBoilerplateStripper.matches(text: trimmed, patterns: rule.stripTextPatterns) {
                try element.remove()
                removed += 1
            }
        }

        for element in try body.select(Self.containerSelector) {
            guard let text = try? element.text() else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false, trimmed.count <= Self.containerTextCeiling else { continue }
            if ArticleLocaleBoilerplateStripper.matches(text: trimmed, patterns: rule.stripTextPatterns) {
                try element.remove()
                removed += 1
            }
        }

        return removed
    }
}
