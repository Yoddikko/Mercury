//
//  RSSParser.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

struct RSSParsedItem: Equatable, Sendable {
    let title: String?
    let link: String?
    let summary: String?
    let content: String?
    let publishedAtRaw: String?
    let categories: [String]
    let language: String?
}

struct RSSParser: Sendable {
    private let logger = AppLogger.shared

    func parse(data: Data, requestID: String? = nil) throws -> [RSSParsedItem] {
        logger.debug(
            "Starting RSS XML parsing",
            category: .business,
            service: "RSSParser",
            requestID: requestID,
            metadata: ["bytes": "\(data.count)"]
        )

        let delegate = RSSXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            let parserErrorDescription = parser.parserError?.localizedDescription ?? "unknown_parser_error"
            logger.error(
                "RSS XML parsing failed",
                category: .business,
                service: "RSSParser",
                requestID: requestID,
                metadata: ["error": parserErrorDescription]
            )
            throw RSSParserError.invalidXML
        }

        logger.debug(
            "RSS XML parsing completed",
            category: .business,
            service: "RSSParser",
            requestID: requestID,
            metadata: ["items": "\(delegate.items.count)"]
        )

        return delegate.items
    }
}

private final class RSSXMLParserDelegate: NSObject, XMLParserDelegate {
    private enum FeedType {
        case unknown
        case rss
        case atom
    }

    private struct ItemBuilder {
        var title: String?
        var link: String?
        var atomSelfLink: String?
        var summary: String?
        var content: String?
        var publishedAtRaw: String?
        var categories: [String] = []
        var language: String?

        var hasMeaningfulContent: Bool {
            [title, link, summary, content, publishedAtRaw].contains { value in
                guard let value else { return false }
                return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
        }
    }

    private(set) var items: [RSSParsedItem] = []

    private var feedType: FeedType = .unknown
    private var feedLanguage: String?

    private var isInsideItem = false
    private var currentItem = ItemBuilder()
    private var textBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = normalizedName(elementName: elementName, qName: qName)
        textBuffer = ""

        switch name {
        case "rss":
            feedType = .rss
            feedLanguage = attributeDict["xml:lang"] ?? attributeDict["lang"] ?? feedLanguage
        case "feed":
            feedType = .atom
            feedLanguage = attributeDict["xml:lang"] ?? attributeDict["lang"] ?? feedLanguage
        case "item", "entry":
            isInsideItem = true
            currentItem = ItemBuilder()
            currentItem.language = attributeDict["xml:lang"] ?? attributeDict["lang"] ?? feedLanguage
        default:
            break
        }

        guard isInsideItem else { return }
        guard feedType == .atom else { return }

        if name == "link" {
            let rel = attributeDict["rel"]?.lowercased()
            if let href = attributeDict["href"], href.isEmpty == false {
                if rel == nil || rel == "alternate" {
                    if currentItem.link == nil {
                        currentItem.link = href
                    }
                } else if rel == "self", currentItem.atomSelfLink == nil {
                    currentItem.atomSelfLink = href
                }
            }
        }

        if name == "category", let term = attributeDict["term"], term.isEmpty == false {
            currentItem.categories.append(term)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else { return }
        textBuffer.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = normalizedName(elementName: elementName, qName: qName)
        let value = normalizedValue(textBuffer)

        if isInsideItem {
            switch name {
            case "title":
                assignIfPresent(value, to: &currentItem.title)
            case "link":
                if feedType == .rss {
                    assignIfPresent(value, to: &currentItem.link)
                }
            case "description", "summary":
                assignIfPresent(value, to: &currentItem.summary)
            case "content:encoded", "content":
                assignIfPresent(value, to: &currentItem.content)
            case "pubdate", "published", "updated", "dc:date":
                assignIfPresent(value, to: &currentItem.publishedAtRaw)
            case "category":
                if let value, value.isEmpty == false {
                    currentItem.categories.append(value)
                }
            case "language", "dc:language":
                assignIfPresent(value, to: &currentItem.language)
            case "item", "entry":
                finishCurrentItemIfNeeded()
                isInsideItem = false
            default:
                break
            }
        } else if name == "language" || name == "dc:language" {
            if let value, value.isEmpty == false {
                feedLanguage = value
            }
        }

        textBuffer = ""
    }

    private func finishCurrentItemIfNeeded() {
        if currentItem.link == nil {
            currentItem.link = currentItem.atomSelfLink
        }

        guard currentItem.hasMeaningfulContent else { return }
        let item = RSSParsedItem(
            title: currentItem.title,
            link: currentItem.link,
            summary: currentItem.summary,
            content: currentItem.content,
            publishedAtRaw: currentItem.publishedAtRaw,
            categories: deduplicated(currentItem.categories),
            language: currentItem.language ?? feedLanguage
        )
        items.append(item)
    }

    private func normalizedName(elementName: String, qName: String?) -> String {
        (qName ?? elementName).lowercased()
    }

    private func normalizedValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func assignIfPresent(_ value: String?, to target: inout String?) {
        guard let value, value.isEmpty == false else { return }
        if target == nil || target?.isEmpty == true {
            target = value
        }
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.isEmpty == false else { return nil }
            let lowered = normalized.lowercased()
            guard seen.insert(lowered).inserted else { return nil }
            return normalized
        }
    }
}
