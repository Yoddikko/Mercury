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
            title: article.title,
            sourceName: article.sourceName,
            sourceURL: article.sourceURL.absoluteString,
            articleURL: article.articleURL.absoluteString,
            publishedAt: article.publishedAt,
            rawContent: article.rawContent,
            cleanedContent: article.cleanedContent,
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
        entity.title = article.title
        entity.sourceName = article.sourceName
        entity.sourceURL = article.sourceURL.absoluteString
        entity.articleURL = article.articleURL.absoluteString
        entity.publishedAt = article.publishedAt
        entity.rawContent = article.rawContent
        entity.cleanedContent = article.cleanedContent
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
    /// Fields that are not persisted yet (for example the body completeness
    /// signals captured during diagnostics) are filled with conservative
    /// defaults so the UI keeps working until richer schemas land.
    static func makeArticle(from entity: ArticleEntity) -> Article? {
        guard let sourceURL = URL(string: entity.sourceURL) else { return nil }
        guard let articleURL = URL(string: entity.articleURL) else { return nil }

        return Article(
            id: entity.id,
            externalID: nil,
            title: entity.title,
            sourceName: entity.sourceName,
            sourceURL: sourceURL,
            articleURL: articleURL,
            publishedAt: entity.publishedAt,
            authorName: nil,
            heroImageURL: nil,
            rawContent: entity.rawContent,
            cleanedContent: entity.cleanedContent,
            contentSource: "swiftdata_cache",
            contentWordCount: 0,
            isContentLikelyComplete: false,
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
