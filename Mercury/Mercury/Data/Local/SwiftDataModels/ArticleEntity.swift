//
//  ArticleEntity.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation
import SwiftData

@Model
final class ArticleEntity {
    @Attribute(.unique) var id: String
    var externalID: String?
    var title: String
    var sourceName: String
    var sourceURL: String
    var articleURL: String
    var publishedAt: Date
    var authorName: String?
    var heroImageURL: String?
    var rawContent: String?
    var cleanedContent: String?
    var contentSource: String?
    var contentWordCount: Int
    var isContentLikelyComplete: Bool
    var summaryShort: String?
    var summaryBullets: [String]
    var category: String?
    var tags: [String]
    var language: String?
    var isBookmarked: Bool
    var isRead: Bool
    var clusterID: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString.lowercased(),
        externalID: String? = nil,
        title: String,
        sourceName: String,
        sourceURL: String,
        articleURL: String,
        publishedAt: Date = .now,
        authorName: String? = nil,
        heroImageURL: String? = nil,
        rawContent: String? = nil,
        cleanedContent: String? = nil,
        contentSource: String? = nil,
        contentWordCount: Int = 0,
        isContentLikelyComplete: Bool = false,
        summaryShort: String? = nil,
        summaryBullets: [String] = [],
        category: String? = nil,
        tags: [String] = [],
        language: String? = nil,
        isBookmarked: Bool = false,
        isRead: Bool = false,
        clusterID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.externalID = externalID
        self.title = title
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.articleURL = articleURL
        self.publishedAt = publishedAt
        self.authorName = authorName
        self.heroImageURL = heroImageURL
        self.rawContent = rawContent
        self.cleanedContent = cleanedContent
        self.contentSource = contentSource
        self.contentWordCount = contentWordCount
        self.isContentLikelyComplete = isContentLikelyComplete
        self.summaryShort = summaryShort
        self.summaryBullets = summaryBullets
        self.category = category
        self.tags = tags
        self.language = language
        self.isBookmarked = isBookmarked
        self.isRead = isRead
        self.clusterID = clusterID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
