//
//  ArticleEntityMapper.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Thin bidirectional mapping between the domain `Article` value type and
/// the SwiftData `ArticleEntity`.
///
/// This mapper deliberately stays simple and stateless: it does not own a
/// repository, does not perform fetches, and does not handle persistence
/// lifecycles. Those concerns are reserved for the dedicated repository
/// layer tracked by a separate issue.
enum ArticleEntityMapper {
    /// Build a fresh `ArticleEntity` from a domain `Article`.
    ///
    /// The returned entity is detached: callers are responsible for
    /// inserting it into a `ModelContext` when persistence is desired.
    static func makeEntity(from article: Article) -> ArticleEntity {
        ArticleEntity(
            id: article.id,
            externalID: article.externalID,
            title: article.title,
            sourceName: article.sourceName,
            sourceURL: article.sourceURL.absoluteString,
            articleURL: article.articleURL.absoluteString,
            publishedAt: article.publishedAt,
            authorName: article.authorName,
            heroImageURL: article.heroImageURL?.absoluteString,
            rawContent: article.rawContent,
            cleanedContent: article.cleanedContent,
            contentSource: article.contentSource,
            contentWordCount: article.contentWordCount,
            isContentLikelyComplete: article.isContentLikelyComplete,
            summaryShort: article.summaryShort,
            summaryBullets: article.summaryBullets,
            category: article.category,
            tags: article.tags,
            language: article.language,
            isBookmarked: article.isBookmarked,
            isRead: article.isRead,
            clusterID: article.clusterID,
            createdAt: article.createdAt,
            updatedAt: article.updatedAt
        )
    }

    /// Mutate an existing entity in place with the latest values from a
    /// domain `Article`, preserving the entity's identity and keeping
    /// SwiftData change-tracking intact.
    static func apply(_ article: Article, to entity: ArticleEntity) {
        entity.externalID = article.externalID
        entity.title = article.title
        entity.sourceName = article.sourceName
        entity.sourceURL = article.sourceURL.absoluteString
        entity.articleURL = article.articleURL.absoluteString
        entity.publishedAt = article.publishedAt
        entity.authorName = article.authorName
        entity.heroImageURL = article.heroImageURL?.absoluteString
        entity.rawContent = article.rawContent
        entity.cleanedContent = article.cleanedContent
        entity.contentSource = article.contentSource
        entity.contentWordCount = article.contentWordCount
        entity.isContentLikelyComplete = article.isContentLikelyComplete
        entity.summaryShort = article.summaryShort
        entity.summaryBullets = article.summaryBullets
        entity.category = article.category
        entity.tags = article.tags
        entity.language = article.language
        entity.clusterID = article.clusterID
        entity.updatedAt = article.updatedAt
    }

    /// Project a stored `ArticleEntity` into the immutable domain `Article`
    /// used by the presentation layer.
    ///
    /// All persisted fields are projected back as stored. The `contentSource`
    /// falls back to an empty string when missing so the domain model can
    /// remain non-optional while still flagging legacy rows.
    static func makeArticle(from entity: ArticleEntity) -> Article? {
        guard let sourceURL = URL(string: entity.sourceURL) else { return nil }
        guard let articleURL = URL(string: entity.articleURL) else { return nil }

        let heroImageURL = entity.heroImageURL.flatMap(URL.init(string:))

        return Article(
            id: entity.id,
            externalID: entity.externalID,
            title: entity.title,
            sourceName: entity.sourceName,
            sourceURL: sourceURL,
            articleURL: articleURL,
            publishedAt: entity.publishedAt,
            authorName: entity.authorName,
            heroImageURL: heroImageURL,
            rawContent: entity.rawContent,
            cleanedContent: entity.cleanedContent,
            contentSource: entity.contentSource ?? "",
            contentWordCount: entity.contentWordCount,
            isContentLikelyComplete: entity.isContentLikelyComplete,
            summaryShort: entity.summaryShort,
            summaryBullets: entity.summaryBullets,
            category: entity.category,
            tags: entity.tags,
            language: entity.language,
            isBookmarked: entity.isBookmarked,
            isRead: entity.isRead,
            clusterID: entity.clusterID,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
}
