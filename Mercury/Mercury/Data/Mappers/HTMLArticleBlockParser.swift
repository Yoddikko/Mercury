//
//  HTMLArticleBlockParser.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation
import SwiftSoup

/// Parses sanitized article HTML into a typed `[ArticleBlock]` for the
/// native SwiftUI renderer (issue #59).
///
/// Input is the same sanitized HTML that the WebView renderer consumes
/// (see `ArticleHTMLSanitizer`), so this parser does not re-implement
/// security stripping; it only structures content.
///
/// Inline tags (`<a>`, `<strong>`, `<em>`, inline `<code>`) collapse
/// into `AttributedString` attributes on the surrounding text block.
/// Unknown or unsupported structural tags fall back to paragraphs so
/// the user never sees a tag swallow content.
struct HTMLArticleBlockParser: Sendable {
    func parse(_ html: String) -> [ArticleBlock] {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }

        let document: Document
        do {
            // `parseBodyFragment` is the right entry point for snippets
            // that aren't a full document — SwiftSoup wraps them in a
            // synthetic `<html><body>…</body></html>` for us.
            document = try SwiftSoup.parseBodyFragment(trimmed)
        } catch {
            // Fall back to a single paragraph carrying the raw text so
            // the user still sees the article content.
            return [.paragraph(AttributedString(strippingTags(trimmed)))]
        }

        guard let body = document.body() else { return [] }
        var blocks: [ArticleBlock] = []
        collectBlocks(from: body, into: &blocks)
        return blocks
    }

    // MARK: - Block walker

    private func collectBlocks(from parent: Element, into blocks: inout [ArticleBlock]) {
        for child in parent.children() {
            let tag = child.tagName().lowercased()
            switch tag {
            case "p":
                if let text = makeAttributedText(from: child), text.runs.first != nil {
                    blocks.append(.paragraph(text))
                }
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let level = Int(String(tag.dropFirst())) ?? 2
                if let text = makeAttributedText(from: child) {
                    blocks.append(.heading(level: level, text))
                }
            case "img":
                if let src = try? child.attr("src"), let url = URL(string: src) {
                    let alt = (try? child.attr("alt")).flatMap { $0.isEmpty ? nil : $0 }
                    blocks.append(.image(url, alt: alt))
                }
            case "figure":
                appendFigure(child, into: &blocks)
            case "ul", "ol":
                appendList(child, ordered: tag == "ol", into: &blocks)
            case "blockquote":
                if let text = makeAttributedText(from: child) {
                    blocks.append(.quote(text))
                }
            case "pre":
                appendPre(child, into: &blocks)
            case "code":
                let body = (try? child.text()) ?? ""
                if body.isEmpty == false {
                    blocks.append(.code(body, language: nil))
                }
            case "div", "section", "article", "main", "header", "footer", "aside":
                // Container — recurse so nested structural tags surface.
                collectBlocks(from: child, into: &blocks)
            case "hr", "br":
                // Skip structural separators; SwiftUI views space themselves.
                continue
            default:
                if let text = makeAttributedText(from: child), text.runs.first != nil {
                    blocks.append(.paragraph(text))
                }
            }
        }
    }

    private func appendFigure(_ figure: Element, into blocks: inout [ArticleBlock]) {
        // A `<figure>` typically wraps an `<img>` plus a `<figcaption>`.
        // We emit the image; the caption rides as the `alt` text when no
        // explicit alt is present.
        guard let img = try? figure.select("img").first() else {
            collectBlocks(from: figure, into: &blocks)
            return
        }
        let src = (try? img.attr("src")) ?? ""
        guard let url = URL(string: src) else {
            collectBlocks(from: figure, into: &blocks)
            return
        }
        let alt = (try? img.attr("alt")).flatMap { $0.isEmpty ? nil : $0 }
        let captionText: String? = {
            guard let caption = try? figure.select("figcaption").first() else { return nil }
            guard let text = try? caption.text(), text.isEmpty == false else { return nil }
            return text
        }()
        blocks.append(.image(url, alt: alt ?? captionText))
    }

    private func appendList(_ list: Element, ordered: Bool, into blocks: inout [ArticleBlock]) {
        let items: [AttributedString] = list.children().compactMap { child in
            guard child.tagName().lowercased() == "li" else { return nil }
            return makeAttributedText(from: child)
        }
        guard items.isEmpty == false else { return }
        blocks.append(.list(ordered: ordered, items: items))
    }

    private func appendPre(_ pre: Element, into blocks: inout [ArticleBlock]) {
        let body = (try? pre.text()) ?? ""
        guard body.isEmpty == false else { return }
        var lang: String?
        if let codeElement = try? pre.select("code").first(),
           let classes = try? codeElement.attr("class") {
            let token = classes
                .split(separator: " ")
                .map(String.init)
                .first { $0.hasPrefix("language-") }
            lang = token.map { String($0.dropFirst("language-".count)) }
        }
        blocks.append(.code(body, language: lang))
    }

    // MARK: - Inline rendering

    private func makeAttributedText(from element: Element) -> AttributedString? {
        var output = AttributedString("")
        var emitted = false

        for node in element.getChildNodes() {
            if let text = node as? TextNode {
                let value = text.text()
                guard value.isEmpty == false else { continue }
                output += AttributedString(value)
                emitted = true
            } else if let child = node as? Element,
                      let fragment = makeInlineFragment(child) {
                output += fragment
                emitted = true
            }
        }

        guard emitted else { return nil }
        let collapsed = collapseWhitespace(String(output.characters))
        guard collapsed.isEmpty == false else { return nil }
        return output
    }

    private func makeInlineFragment(_ element: Element) -> AttributedString? {
        let tag = element.tagName().lowercased()
        switch tag {
        case "a":
            let raw = (try? element.text()) ?? ""
            guard raw.isEmpty == false else { return nil }
            var fragment = AttributedString(raw)
            if let href = try? element.attr("href"),
               let url = URL(string: href) {
                fragment.link = url
            }
            return fragment
        case "strong", "b":
            let raw = (try? element.text()) ?? ""
            guard raw.isEmpty == false else { return nil }
            var fragment = AttributedString(raw)
            fragment.inlinePresentationIntent = .stronglyEmphasized
            return fragment
        case "em", "i":
            let raw = (try? element.text()) ?? ""
            guard raw.isEmpty == false else { return nil }
            var fragment = AttributedString(raw)
            fragment.inlinePresentationIntent = .emphasized
            return fragment
        case "code":
            let raw = (try? element.text()) ?? ""
            guard raw.isEmpty == false else { return nil }
            var fragment = AttributedString(raw)
            fragment.inlinePresentationIntent = .code
            return fragment
        case "br":
            return AttributedString("\n")
        default:
            let raw = (try? element.text()) ?? ""
            guard raw.isEmpty == false else { return nil }
            return AttributedString(raw)
        }
    }

    private func collapseWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func strippingTags(_ value: String) -> String {
        let stripped = value.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        return collapseWhitespace(stripped)
    }
}
