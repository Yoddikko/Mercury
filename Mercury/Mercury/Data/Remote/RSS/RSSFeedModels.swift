//
//  RSSFeedModels.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

enum RSSFeedRegion: String, CaseIterable, Identifiable, Sendable {
    case europeWide
    case austria
    case belgium
    case bulgaria
    case croatia
    case denmark
    case finland
    case france
    case germany
    case greece
    case hungary
    case ireland
    case italy
    case netherlands
    case norway
    case poland
    case portugal
    case romania
    case spain
    case sweden
    case switzerland
    case unitedKingdom

    var id: String { rawValue }

    var fallbackDisplayName: String {
        switch self {
        case .europeWide:
            return "Europe-Wide"
        case .austria:
            return "Austria"
        case .belgium:
            return "Belgium"
        case .bulgaria:
            return "Bulgaria"
        case .croatia:
            return "Croatia"
        case .denmark:
            return "Denmark"
        case .finland:
            return "Finland"
        case .france:
            return "France"
        case .germany:
            return "Germany"
        case .greece:
            return "Greece"
        case .hungary:
            return "Hungary"
        case .ireland:
            return "Ireland"
        case .italy:
            return "Italy"
        case .netherlands:
            return "Netherlands"
        case .norway:
            return "Norway"
        case .poland:
            return "Poland"
        case .portugal:
            return "Portugal"
        case .romania:
            return "Romania"
        case .spain:
            return "Spain"
        case .sweden:
            return "Sweden"
        case .switzerland:
            return "Switzerland"
        case .unitedKingdom:
            return "United Kingdom"
        }
    }
}

enum RSSFeedGroupMode: String, CaseIterable, Identifiable, Sendable {
    case allOutlets
    case mainOutlets
    case byRegion

    var id: String { rawValue }
}

struct RSSFeedSource: Identifiable, Hashable, Sendable {
    let id: String
    let outletName: String
    let region: RSSFeedRegion
    let feedURLString: String?
    let isMainOutlet: Bool
    let languageCode: String?
    let tags: [String]
    let note: String?

    var resolvedURL: URL? {
        guard let feedURLString else { return nil }
        guard let url = URL(string: feedURLString) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}

enum RSSFeedCheckStatus: String, Sendable {
    case success
    case noArticles
    case noFeedURL
    case invalidFeedURL
    case requestFailed
    case parseFailed
}

struct RSSFeedCheckResult: Identifiable, Sendable {
    let source: RSSFeedSource
    let status: RSSFeedCheckStatus
    let articles: [Article]
    let elapsedMs: Int
    let message: String?

    var id: String { source.id }
}

struct RSSFeedBatchResult: Sendable {
    let checkedAt: Date
    let groupMode: RSSFeedGroupMode
    let selectedRegion: RSSFeedRegion?
    let checks: [RSSFeedCheckResult]
    let deduplicatedArticles: [Article]
}

enum RSSFeedClientError: Error, Sendable, Equatable {
    case insecureTransport
    case invalidResponse
    case httpStatusCode(Int)
    case emptyResponseData
}

enum RSSParserError: Error, Sendable, Equatable {
    case invalidXML
}
