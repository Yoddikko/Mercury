//
//  ArticleHTMLSanitizer.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation

/// Removes the subset of HTML that must never reach the article-detail
/// renderer.
///
/// `ArticlePageContentExtractor` already drops `<script>`, `<style>`,
/// `<noscript>`, `<svg>`, `<canvas>`, `<iframe>` and `<form>` blocks while
/// locating the article body. This sanitizer is the *render-time* gate
/// shared by the WKWebView renderer (issue #57) and the native block
/// renderer (issue #59); it strips anything the extractor left behind:
///
/// * inline event handlers (`onclick="…"`, `onerror='…'`, …)
/// * `javascript:` URLs in `href`/`src`
/// * tracking pixels (`<img>` with width or height set to "1")
///
/// The sanitizer is intentionally regex-based to stay dependency-free
/// (no SwiftSoup on the WebView path, per spec) and synchronous: the
/// input is the already-trimmed article body, never an entire document.
struct ArticleHTMLSanitizer: Sendable {
    func sanitize(_ html: String) -> String {
        var output = html

        // Inline event handlers — `on*=` followed by a quoted value.
        output = output.replacingOccurrences(
            of: "(?i)\\son[a-z]+\\s*=\\s*\"[^\"]*\"",
            with: "",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "(?i)\\son[a-z]+\\s*=\\s*'[^']*'",
            with: "",
            options: .regularExpression
        )

        // `javascript:` URLs — drop the whole attribute so the link
        // collapses to plain text rather than executing.
        output = output.replacingOccurrences(
            of: "(?i)\\s(?:href|src)\\s*=\\s*\"\\s*javascript:[^\"]*\"",
            with: "",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "(?i)\\s(?:href|src)\\s*=\\s*'\\s*javascript:[^']*'",
            with: "",
            options: .regularExpression
        )

        // Tracking pixels: <img …> tags where width or height is "1".
        output = output.replacingOccurrences(
            of: "(?is)<img\\b[^>]*\\b(?:width|height)\\s*=\\s*[\"']?1[\"']?[^>]*>",
            with: "",
            options: .regularExpression
        )

        return output
    }
}
