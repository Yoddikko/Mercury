//
//  ArticleRendererMode.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation

/// User-facing choice of how the article-detail screen renders the body
/// HTML (see `docs/features/SETTINGS.md` and `docs/features/ARTICLE.md`).
///
/// Persisted as a raw `String` on `UserPreferenceEntity` so SwiftData
/// migration stays additive (no schema bump on add).
enum ArticleRendererMode: String, Codable, CaseIterable, Sendable {
    /// Default — sanitized HTML rendered in an embedded `WKWebView`.
    case web

    /// Opt-in — sanitized HTML parsed into `[ArticleBlock]` and rendered
    /// with native SwiftUI views. Implemented by issue #59.
    case native

    static let `default`: ArticleRendererMode = .web

    init(rawValueOrDefault raw: String?) {
        guard let raw, let mode = ArticleRendererMode(rawValue: raw) else {
            self = .default
            return
        }
        self = mode
    }
}
