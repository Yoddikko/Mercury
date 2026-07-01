//
//  ArticleImageDeduplicator.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//  Extended for CDN + <picture>/srcset variants on 01/07/26 (issue #81).
//

import Foundation
import SwiftSoup

/// Removes the hero image from the article body when the body contains
/// the same image again (issue #66 / spec PR #65 / #81).
///
/// Outlets routinely embed the hero image both as RSS `media:content` /
/// `og:image` (which Mercury renders separately above the title) and as
/// the first `<img>` / `<picture>` of the article body. Without this
/// pass the user sees the same image twice in a row on the detail
/// screen.
///
/// Comparison is on a **normalized basename** — CDNs append
/// `?w=1024&q=80`-style sizing parameters that vary per device, wrap
/// the asset in `-1024x768` / `@2x` / `-mobile` suffixes, and
/// re-declare the same asset across `<source>` elements inside
/// `<picture>` with different `srcset` widths. Normalization strips all
/// of that so the underlying asset key survives.
struct ArticleImageDeduplicator: Sendable {
    /// Returns a copy of `html` with body `<img>` / `<picture>` /
    /// wrapping `<figure>` elements removed when any of their image
    /// URLs (`src`, `srcset`, nested `<source srcset>`) normalize to
    /// the same key as `heroImageURLString`. When the hero is unknown
    /// the input is returned untouched.
    func dedupingHero(in html: String, heroImageURLString: String?) -> String {
        guard let hero = heroImageURLString,
              let heroKey = Self.normalizedKey(of: hero) else {
            return html
        }

        do {
            let document = try SwiftSoup.parseBodyFragment(html)
            guard let body = document.body() else { return html }

            // <picture> first — an outer picture wraps its own <img>
            // and multiple <source srcset> entries. Match against any
            // of those and remove the whole picture (and figure if
            // wrapped).
            let pictures = try body.select("picture").array()
            for picture in pictures {
                if pictureMatchesHero(picture, heroKey: heroKey) {
                    if let figure = try? picture.parents().first(where: { $0.tagName().lowercased() == "figure" }) {
                        try figure.remove()
                    } else {
                        try picture.remove()
                    }
                }
            }

            let images = try body.select("img").array()
            for img in images {
                guard imageMatchesHero(img, heroKey: heroKey) else { continue }
                if let figure = try? img.parents().first(where: { $0.tagName().lowercased() == "figure" }) {
                    try figure.remove()
                } else if let picture = try? img.parents().first(where: { $0.tagName().lowercased() == "picture" }) {
                    try picture.remove()
                } else {
                    try img.remove()
                }
            }

            return try body.html()
        } catch {
            return html
        }
    }

    private func imageMatchesHero(_ img: Element, heroKey: String) -> Bool {
        if let src = try? img.attr("src"),
           let key = Self.normalizedKey(of: src),
           key == heroKey {
            return true
        }
        if let srcset = try? img.attr("srcset"),
           Self.srcsetURLs(from: srcset).contains(where: { Self.normalizedKey(of: $0) == heroKey }) {
            return true
        }
        return false
    }

    private func pictureMatchesHero(_ picture: Element, heroKey: String) -> Bool {
        // <source srcset="url 1x, url2 2x, ...">
        if let sources = try? picture.select("source").array() {
            for source in sources {
                if let srcset = try? source.attr("srcset"),
                   Self.srcsetURLs(from: srcset).contains(where: { Self.normalizedKey(of: $0) == heroKey }) {
                    return true
                }
            }
        }
        if let innerImages = try? picture.select("img").array() {
            for img in innerImages {
                if imageMatchesHero(img, heroKey: heroKey) { return true }
            }
        }
        return false
    }

    /// Parse a `srcset` attribute value into its URL candidates. The
    /// attribute is a comma-separated list of `"url [descriptor]"`
    /// entries; we ignore descriptors and return the URL portion of
    /// each entry.
    static func srcsetURLs(from srcset: String) -> [String] {
        srcset.split(separator: ",")
            .compactMap { candidate -> String? in
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { return nil }
                if let firstSpace = trimmed.firstIndex(where: { $0.isWhitespace }) {
                    return String(trimmed[..<firstSpace])
                }
                return trimmed
            }
    }

    /// Normalized dedup key: lowercased path basename with sizing
    /// suffixes and file extension stripped. Query string, fragment,
    /// and host are ignored — the same asset lives under many CDN
    /// hostnames + query permutations.
    static func normalizedKey(of urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        var candidate = trimmed
        if let questionMark = candidate.firstIndex(of: "?") {
            candidate = String(candidate[..<questionMark])
        }
        if let hash = candidate.firstIndex(of: "#") {
            candidate = String(candidate[..<hash])
        }
        // Extract basename from the path.
        guard let last = candidate.split(separator: "/").last else { return nil }
        var basename = String(last).lowercased()

        // Strip the file extension so `hero.jpg` and `hero.webp` share
        // a key (same asset, different format).
        if let dot = basename.lastIndex(of: ".") {
            basename = String(basename[..<dot])
        }

        // Strip trailing size suffixes: `-1024x768`, `_1024x768`,
        // `-800w`, `-large`, `-mobile`, `@2x`, `@3x`.
        let sizeRegex = "([-_](?:\\d{2,4}x\\d{2,4}|\\d{2,5}w|large|medium|small|mobile|desktop|tablet|thumb|thumbnail|hero|main))+$"
        basename = basename.replacingOccurrences(
            of: sizeRegex,
            with: "",
            options: .regularExpression
        )
        basename = basename.replacingOccurrences(
            of: "@(?:2|3)x$",
            with: "",
            options: .regularExpression
        )

        return basename.isEmpty ? nil : basename
    }

    /// Kept for source-compat with older callers/tests. New code should
    /// use `normalizedKey(of:)`.
    static func normalizedBasename(of urlString: String) -> String? {
        normalizedKey(of: urlString)
    }
}
