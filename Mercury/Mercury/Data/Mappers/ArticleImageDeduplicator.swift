//
//  ArticleImageDeduplicator.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation
import SwiftSoup

/// Removes the hero image from the article body when the body contains
/// the same image again (issue #66 / spec PR #65).
///
/// Outlets routinely embed the hero image both as RSS `media:content` /
/// `og:image` (which Mercury renders separately above the title) and as
/// the first `<img>` of the article body. Without this pass the user
/// sees the same image twice in a row on the detail screen.
///
/// The comparison is on the **path basename** of the normalized URL, not
/// the full URL: CDNs append `?w=1024&q=80`-style sizing parameters that
/// change per device while pointing at the same underlying asset.
struct ArticleImageDeduplicator: Sendable {
    /// Returns a copy of `html` with body `<img>` and wrapping `<figure>`
    /// elements removed when their `src` normalizes to the same basename
    /// as `heroImageURLString`. When the hero is unknown the input is
    /// returned untouched.
    func dedupingHero(in html: String, heroImageURLString: String?) -> String {
        guard let hero = heroImageURLString,
              let heroBasename = Self.normalizedBasename(of: hero) else {
            return html
        }

        do {
            let document = try SwiftSoup.parseBodyFragment(html)
            guard let body = document.body() else { return html }

            let images = try body.select("img")
            for img in images {
                guard let src = try? img.attr("src"),
                      let basename = Self.normalizedBasename(of: src),
                      basename == heroBasename else { continue }

                // Drop the wrapping <figure> when present so we don't
                // leave an empty figure + figcaption behind.
                if let figure = try? img.parents().first(where: { $0.tagName().lowercased() == "figure" }) {
                    try figure.remove()
                } else {
                    try img.remove()
                }
            }

            return try body.html()
        } catch {
            // SwiftSoup never throws on parse-fragment for our inputs in
            // practice; if it ever does, return the original so we never
            // regress to a worse output than what came in.
            return html
        }
    }

    /// Lowercases the host, strips query string, strips trailing slash,
    /// returns the URL path's basename (`/wp-content/uploads/2026/06/hero.jpg`
    /// → `hero.jpg`). `nil` when the input can't be parsed as a URL.
    static func normalizedBasename(of urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        guard var components = URLComponents(string: trimmed) else { return nil }
        components.host = components.host?.lowercased()
        components.query = nil
        components.fragment = nil

        let path = components.path
        guard let last = path.split(separator: "/").last else { return nil }
        return String(last).lowercased()
    }
}
