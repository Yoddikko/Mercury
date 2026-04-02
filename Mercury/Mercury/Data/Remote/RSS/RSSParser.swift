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
    let guid: String?
    let author: String?
    let imageURL: String?

    init(
        title: String?,
        link: String?,
        summary: String?,
        content: String?,
        publishedAtRaw: String?,
        categories: [String],
        language: String?,
        guid: String? = nil,
        author: String? = nil,
        imageURL: String? = nil
    ) {
        self.title = title
        self.link = link
        self.summary = summary
        self.content = content
        self.publishedAtRaw = publishedAtRaw
        self.categories = categories
        self.language = language
        self.guid = guid
        self.author = author
        self.imageURL = imageURL
    }
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
        var description: String?
        var content: String?
        var publishedAtRaw: String?
        var categories: [String] = []
        var language: String?
        var guid: String?
        var author: String?
        var imageCandidates: [String] = []

        var hasMeaningfulContent: Bool {
            [title, link, summary, description, content, publishedAtRaw, guid].contains { value in
                guard let value else { return false }
                return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
        }
    }

    private(set) var items: [RSSParsedItem] = []

    private var feedType: FeedType = .unknown
    private var feedLanguage: String?

    private var isInsideItem = false
    private var isInsideAtomAuthor = false
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

        if name == "author", feedType == .atom {
            isInsideAtomAuthor = true
        }

        if name == "link", feedType == .atom {
            let rel = attributeDict["rel"]?.lowercased()
            if let href = attributeDict["href"], href.isEmpty == false {
                if rel == nil || rel == "alternate" {
                    if currentItem.link == nil {
                        currentItem.link = href
                    }
                } else if rel == "self", currentItem.atomSelfLink == nil {
                    currentItem.atomSelfLink = href
                } else if rel == "enclosure" {
                    let type = attributeDict["type"]?.lowercased()
                    if isImageMedia(type: type, medium: nil, urlString: href) {
                        appendImageCandidateIfPresent(href)
                    }
                }
            }
        }

        if name == "category", let term = attributeDict["term"], term.isEmpty == false {
            currentItem.categories.append(term)
        }

        if name == "enclosure" {
            let type = attributeDict["type"]?.lowercased() ?? ""
            if type.hasPrefix("image/"), let url = attributeDict["url"], url.isEmpty == false {
                appendImageCandidateIfPresent(url)
            }
        }

        if name == "media:content" {
            let type = attributeDict["type"]?.lowercased()
            let medium = attributeDict["medium"]?.lowercased()
            if let url = attributeDict["url"], isImageMedia(type: type, medium: medium, urlString: url) {
                appendImageCandidateIfPresent(url)
            }
        }

        if name == "media:thumbnail" {
            if let url = attributeDict["url"], url.isEmpty == false {
                appendImageCandidateIfPresent(url)
            }
        }

        if name == "itunes:image" {
            if let href = attributeDict["href"], href.isEmpty == false {
                appendImageCandidateIfPresent(href)
            }
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
            case "description":
                assignIfPresent(value, to: &currentItem.description)
            case "summary":
                assignIfPresent(value, to: &currentItem.summary)
            case "content:encoded", "content", "content:fulltext", "fulltext", "full-content":
                assignIfPresent(value, to: &currentItem.content)
            case "pubdate", "published", "updated", "dc:date":
                assignIfPresent(value, to: &currentItem.publishedAtRaw)
            case "category":
                if let value, value.isEmpty == false {
                    currentItem.categories.append(value)
                }
            case "language", "dc:language":
                assignIfPresent(value, to: &currentItem.language)
            case "guid", "id":
                assignIfPresent(value, to: &currentItem.guid)
            case "author":
                if isInsideAtomAuthor == false || feedType == .rss {
                    assignIfPresent(value, to: &currentItem.author)
                }
                if feedType == .atom {
                    isInsideAtomAuthor = false
                }
            case "dc:creator":
                assignIfPresent(value, to: &currentItem.author)
            case "name":
                if isInsideAtomAuthor {
                    assignIfPresent(value, to: &currentItem.author)
                }
            case "media:description":
                assignIfPresent(value, to: &currentItem.description)
            case "item", "entry":
                finishCurrentItemIfNeeded()
                isInsideItem = false
                isInsideAtomAuthor = false
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
        let mergedSummary = firstNonEmpty(currentItem.summary, currentItem.description)
        let item = RSSParsedItem(
            title: currentItem.title,
            link: currentItem.link,
            summary: mergedSummary,
            content: currentItem.content,
            publishedAtRaw: currentItem.publishedAtRaw,
            categories: deduplicated(currentItem.categories),
            language: currentItem.language ?? feedLanguage,
            guid: currentItem.guid,
            author: currentItem.author,
            imageURL: deduplicated(currentItem.imageCandidates).first
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

    private func appendImageCandidateIfPresent(_ value: String?) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        currentItem.imageCandidates.append(trimmed)
    }

    private func firstNonEmpty(_ first: String?, _ second: String?) -> String? {
        if let first {
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        if let second {
            let trimmed = second.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return nil
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

    private func isImageMedia(type: String?, medium: String?, urlString: String) -> Bool {
        if let type {
            return type.hasPrefix("image/")
        }

        if let medium {
            return medium == "image"
        }

        return hasKnownImageFileExtension(urlString)
    }

    private func hasKnownImageFileExtension(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let pathExtension = url.pathExtension.lowercased()
        guard pathExtension.isEmpty == false else { return false }

        let knownImageExtensions: Set<String> = [
            "jpg", "jpeg", "png", "webp", "gif", "bmp", "tiff", "svg", "avif", "heic", "heif"
        ]
        return knownImageExtensions.contains(pathExtension)
    }
}
