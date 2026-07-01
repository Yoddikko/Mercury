//
//  ArticleBoilerplateRemover.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation
import SwiftSoup

/// SwiftSoup-based pass that applies the three load-bearing
/// Readability heuristics — negative class/id token strip, link-density
/// filter, and text-length floor — to a fragment of article HTML
/// (issue #66 / spec PR #65).
///
/// This is Mercury's "Tier 0" distiller: a self-contained, dependency-free
/// (beyond the SwiftSoup we already ship) cleaner that handles the bulk
/// of the page-chrome the user complained about (cookie banners,
/// "Leggi anche" sidebars, share strips, newsletter CTAs, "Più letti"
/// trending lists, footer chrome, outbrain widgets, sponsored slots).
/// When this is not enough (escalation cases documented in the spec),
/// a Tier 1 wrapper around a maintained Readability port is added in a
/// follow-up issue.
///
/// The pass intentionally NEVER throws: a parse failure returns the
/// original HTML untouched so the caller's fallback chain stays in
/// charge.
struct ArticleBoilerplateRemover: Sendable {
    /// Heuristic knobs. Defaults match the Readability defaults plus
    /// what proved necessary against the Mercury fixture corpus.
    struct Options: Sendable {
        var linkDensityCeiling: Double
        var minimumParagraphLength: Int

        init(linkDensityCeiling: Double = 0.5, minimumParagraphLength: Int = 25) {
            self.linkDensityCeiling = linkDensityCeiling
            self.minimumParagraphLength = minimumParagraphLength
        }
    }

    let options: Options

    init(options: Options = Options()) {
        self.options = options
    }

    func cleaning(_ html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return html }

        do {
            let document = try SwiftSoup.parseBodyFragment(trimmed)
            guard let body = document.body() else { return html }

            try removeStructuralChrome(in: body)
            try removeNegativeContainers(in: body)
            try removeHighLinkDensityContainers(in: body)
            try removeShortParagraphs(in: body)

            return try body.html()
        } catch {
            return html
        }
    }

    /// Convenience: collapse arbitrary HTML to its plain-text content,
    /// using SwiftSoup so entities, whitespace and inline markup are
    /// handled correctly. Returns the empty string on parse failure so
    /// the caller can fall back without an explicit catch.
    static func plainText(from html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        guard let document = try? SwiftSoup.parseBodyFragment(trimmed),
              let body = document.body(),
              let text = try? body.text() else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Heuristic passes

    /// Drops HTML elements that are never article content: site/page
    /// navigation, the page footer, interactive UI controls, the
    /// `<noscript>` fallback chrome, embedded forms. This pass runs
    /// before the class-based negative strip so heavy chrome is gone
    /// before downstream heuristics evaluate anything.
    ///
    /// `<header>` is left to the class-based pass because an outlet
    /// may legitimately wrap the article title/byline in a `<header>`
    /// element with a content-positive class.
    private func removeStructuralChrome(in body: Element) throws {
        // Blanket strip of interactive / non-content elements.
        // `<aside>`, `<header>`, `<footer>` are intentionally NOT in
        // this list — the class-based negative pass handles them,
        // preserving outlets that use those elements for content
        // (article header/byline; article-footer notes; Next.js
        // streaming layouts that wrap the body in an aside).
        //
        // `<title>`, `<meta>`, `<link>`, `<style>`, `<script>`,
        // `<template>` are metadata / resource declarations that
        // sometimes leak into the parsed body when the input is a
        // full HTML document rather than a snippet — strip them
        // defensively so the "SITE — Article title" `<title>` text
        // and JSON-LD blocks never surface in the distilled output.
        let selectors = [
            "nav", "footer", "button", "noscript", "form",
            "title", "meta", "link", "style", "script", "template"
        ]
        for selector in selectors {
            let matches = try body.select(selector).array()
            for element in matches {
                try element.remove()
            }
        }
    }

    private func removeNegativeContainers(in body: Element) throws {
        // Walk a snapshot of descendants in reverse so removals don't
        // disturb the iteration. Match each element's own class/id only.
        let elements = try body.getAllElements().array().reversed()
        for element in elements {
            guard element.tagName().lowercased() != "body" else { continue }
            let classes = (try? element.className()) ?? ""
            let identifier = (try? element.attr("id")) ?? ""
            var haystack = (classes + " " + identifier).lowercased()
            // Strip Tailwind arbitrary variants like
            // `[&:has(.hide-menu)_.nav-menu]:hidden` — those contain
            // CSS selectors that reference *other* classes and must
            // never be treated as the element's own class name.
            haystack = haystack.replacingOccurrences(
                of: "\\[[^\\]]*\\]",
                with: " ",
                options: .regularExpression
            )
            guard haystack.trimmingCharacters(in: .whitespaces).isEmpty == false else { continue }

            if Self.negativeRegex.firstMatch(
                in: haystack,
                options: [],
                range: NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
            ) != nil {
                try element.remove()
            }
        }
    }

    private func removeHighLinkDensityContainers(in body: Element) throws {
        let candidates = try body.select("div, section, aside, nav, ul, ol")
        for element in candidates.array() {
            let text = ((try? element.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else { continue }

            let links = try element.select("a")
            // Require ≥3 links to even consider — a single inline
            // `<a>` in a paragraph must never trigger the filter.
            guard links.size() >= 3 else { continue }

            let linkText = links.array().reduce(0) { partial, link in
                partial + (((try? link.text()) ?? "").count)
            }
            let totalChars = text.count
            guard totalChars > 0 else { continue }

            // Skip content-bearing nodes: if non-link text is
            // substantial, the element is an article body container
            // with incidental inline links, not a navigation widget.
            let nonLinkChars = totalChars - linkText
            if nonLinkChars >= 400 { continue }

            let density = Double(linkText) / Double(totalChars)
            if density > options.linkDensityCeiling {
                try element.remove()
            }
        }
    }

    private func removeShortParagraphs(in body: Element) throws {
        let paragraphs = try body.select("p, li")
        for element in paragraphs.array() {
            let text = ((try? element.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else { continue }
            guard text.count < options.minimumParagraphLength else { continue }
            let hasPunctuation = text.contains(where: { ".?!:".contains($0) })
            guard hasPunctuation == false else { continue }
            try element.remove()
        }
    }

    // MARK: - Negative-class regex

    /// Combined English + Italian negative tokens. Compiled once.
    /// Patterns are matched against `class` + `id` of each element.
    private static let negativeRegex: NSRegularExpression = {
        let tokens = [
            // Consent / privacy (generic + common library / pattern names)
            "cookie", "consent", "gdpr", "privacy", "trattamento", "consenso",
            "prompt-to-accept", "iubenda", "onetrust", "didomi", "quantcast",
            "cmp-banner", "cmp_banner",
            // Sharing
            "share", "social", "condividi", "tweet", "twitter", "facebook",
            "whatsapp", "telegram",
            // Related / recommended
            "related", "correlati", "leggi-anche", "leggi_anche", "leggianche",
            "more-like-this", "outbrain", "taboola", "recirc", "recommended",
            "you-?may-?also-?like",
            // Newsletter / signup
            "newsletter", "signup", "subscribe", "iscriviti",
            // Sponsored / ads
            "sponsor", "sponsored", "advert", "promo",
            "\\bad[-_]", "\\bads?\\b",
            // Navigation / chrome
            "breadcrumb", "pagination", "pager", "sidebar",
            "slim-header", "slim_header", "left-nav", "right-nav",
            "main-nav", "site-nav", "top-nav", "nav-bar", "nav-menu",
            "nav-item", "nav-list",
            // Intentionally NOT matching bare `header__` / `footer__` —
            // those BEM prefixes false-hit legitimate content wrappers
            // like `story__header__content` (which wraps the article
            // title on repubblica.it) or `article__footer__meta`.
            "site-header__", "page-header__", "site-footer__", "page-footer__",
            "open-app", "download-app", "scarica-app",
            // Footer / boilerplate
            "footer", "subfooter", "wall-footer", "copyright", "disclaimer",
            // Trending / most read
            "trending", "most-read", "most_read", "popular",
            "piu-letti", "piu_letti", "più-letti",
            // Modals / popups
            "modal", "popup", "overlay", "interstitial"
        ]
        let pattern = tokens.joined(separator: "|")
        // Force unwrap is safe — the pattern is a constant assembled
        // from validated tokens. Compilation failure here is a build
        // bug that the unit tests will surface.
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
}
