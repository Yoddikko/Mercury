//
//  ArticleEntityMapperTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import Testing
@testable import Mercury

struct ArticleEntityMapperTests {
    @Test
    func makeEntityCopiesCoreFields() {
        let article = sampleArticle()
        let entity = ArticleEntityMapper.makeEntity(from: article)

        #expect(entity.id == article.id)
        #expect(entity.title == article.title)
        #expect(entity.sourceURL == article.sourceURL.absoluteString)
        #expect(entity.articleURL == article.articleURL.absoluteString)
        #expect(entity.publishedAt == article.publishedAt)
        #expect(entity.summaryShort == article.summaryShort)
        #expect(entity.tags == article.tags)
        #expect(entity.category == article.category)
        #expect(entity.language == article.language)
    }

    @Test
    func applyUpdatesMutableFieldsButPreservesIdentity() {
        let original = sampleArticle()
        let entity = ArticleEntityMapper.makeEntity(from: original)

        let updated = Article(
            id: original.id,
            externalID: original.externalID,
            title: "Updated title",
            sourceName: original.sourceName,
            sourceURL: original.sourceURL,
            articleURL: original.articleURL,
            publishedAt: original.publishedAt.addingTimeInterval(60),
            authorName: original.authorName,
            heroImageURL: original.heroImageURL,
            rawContent: original.rawContent,
            cleanedContent: original.cleanedContent,
            contentSource: original.contentSource,
            contentWordCount: original.contentWordCount,
            isContentLikelyComplete: original.isContentLikelyComplete,
            summaryShort: "Updated summary",
            summaryBullets: ["bullet"],
            category: "News",
            tags: ["updated"],
            language: original.language,
            isBookmarked: original.isBookmarked,
            isRead: original.isRead,
            clusterID: "cluster-1",
            createdAt: original.createdAt,
            updatedAt: original.updatedAt.addingTimeInterval(60)
        )

        ArticleEntityMapper.apply(updated, to: entity)

        #expect(entity.id == original.id)
        #expect(entity.title == "Updated title")
        #expect(entity.summaryShort == "Updated summary")
        #expect(entity.summaryBullets == ["bullet"])
        #expect(entity.category == "News")
        #expect(entity.tags == ["updated"])
        #expect(entity.clusterID == "cluster-1")
        #expect(entity.publishedAt == original.publishedAt.addingTimeInterval(60))
    }

    @Test
    func makeArticleRoundTripsBackToDomainModel() {
        let entity = ArticleEntity(
            id: "round-trip",
            title: "Title",
            sourceName: "Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article",
            publishedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            summaryShort: "Summary",
            summaryBullets: ["a", "b"],
            category: "Tech",
            tags: ["one"],
            language: "en"
        )

        let article = ArticleEntityMapper.makeArticle(from: entity)

        #expect(article?.id == entity.id)
        #expect(article?.title == entity.title)
        #expect(article?.sourceURL.absoluteString == entity.sourceURL)
        #expect(article?.summaryShort == entity.summaryShort)
        #expect(article?.summaryBullets == entity.summaryBullets)
        #expect(article?.tags == entity.tags)
    }

    @Test
    func makeArticleReturnsNilWhenURLsAreInvalid() {
        let entity = ArticleEntity(
            id: "bad-url",
            title: "Title",
            sourceName: "Source",
            sourceURL: "",
            articleURL: "",
            publishedAt: .now
        )

        #expect(ArticleEntityMapper.makeArticle(from: entity) == nil)
    }

    private func sampleArticle() -> Article {
        Article(
            id: "article-1",
            externalID: "ext",
            title: "Title",
            sourceName: "Source",
            sourceURL: URL(string: "https://example.com/source")!,
            articleURL: URL(string: "https://example.com/article")!,
            publishedAt: Date(timeIntervalSinceReferenceDate: 2_000),
            authorName: "Author",
            heroImageURL: URL(string: "https://example.com/hero.jpg"),
            rawContent: "raw",
            cleanedContent: "clean",
            contentSource: "feed_content",
            contentWordCount: 100,
            isContentLikelyComplete: true,
            summaryShort: "Summary",
            summaryBullets: ["bullet 1", "bullet 2"],
            category: "Technology",
            tags: ["AI", "News"],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}
