//
//  ArticleBlock.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation

/// A single typed unit of article content, produced by
/// `HTMLArticleBlockParser` (issue #59) and rendered by
/// `ArticleBlockListView` when the user picks the native rendering mode.
///
/// The case set intentionally maps to the small subset of structural
/// HTML the renderer actually understands. Inline formatting (`<a>`,
/// `<strong>`, `<em>`, inline `<code>`) is collapsed into the text
/// blocks' `AttributedString`.
enum ArticleBlock: Equatable, Sendable, Identifiable {
    case paragraph(AttributedString)
    case heading(level: Int, AttributedString)
    case image(URL, alt: String?)
    case list(ordered: Bool, items: [AttributedString])
    case quote(AttributedString)
    case code(String, language: String?)

    var id: String {
        switch self {
        case .paragraph(let text):
            return "p:\(text.hashValue)"
        case .heading(let level, let text):
            return "h\(level):\(text.hashValue)"
        case .image(let url, let alt):
            return "img:\(url.absoluteString):\(alt ?? "")"
        case .list(let ordered, let items):
            return "list:\(ordered):\(items.map(\.hashValue))"
        case .quote(let text):
            return "q:\(text.hashValue)"
        case .code(let body, let lang):
            return "code:\(lang ?? ""):\(body.hashValue)"
        }
    }
}
