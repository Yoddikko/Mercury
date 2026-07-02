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
    /// Stable `RSSFeedSource.id` of the outlet that produced this article,
    /// stamped at ingest (issue #94). Nullable so SwiftData lightweight
    /// migration stays additive (precedent: `hasCompletedOnboarding` on
    /// `UserPreferenceEntity`). `nil` for legacy rows persisted before this
    /// field existed — cache filtering falls back to `sourceName` for them.
    var sourceID: String?
    var sourceURL: String
    var articleURL: String
    var publishedAt: Date
    var authorName: String?
    var heroImageURL: String?
    var rawContent: String?
    var cleanedContent: String?
    /// Cleaned article body produced by the content distillation pipeline
    /// (issue #66 / spec PR #65). When non-nil, both renderers read this
    /// field instead of `rawContent`. `nil` for legacy records — they
    /// re-distill on next enrichment pass.
    var distilledBodyHTML: String?
    /// Distiller algorithm version used to produce `distilledBodyHTML`.
    /// Bump in code when the algorithm changes; older values trigger
    /// re-distillation on the next ingest pass.
    var distillerVersion: Int?
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
        sourceID: String? = nil,
        sourceURL: String,
        articleURL: String,
        publishedAt: Date = .now,
        authorName: String? = nil,
        heroImageURL: String? = nil,
        rawContent: String? = nil,
        cleanedContent: String? = nil,
        distilledBodyHTML: String? = nil,
        distillerVersion: Int? = nil,
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
        self.sourceID = sourceID
        self.sourceURL = sourceURL
        self.articleURL = articleURL
        self.publishedAt = publishedAt
        self.authorName = authorName
        self.heroImageURL = heroImageURL
        self.rawContent = rawContent
        self.cleanedContent = cleanedContent
        self.distilledBodyHTML = distilledBodyHTML
        self.distillerVersion = distillerVersion
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
