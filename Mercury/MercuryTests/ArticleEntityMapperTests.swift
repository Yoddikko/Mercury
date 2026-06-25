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
    func makeEntityCopiesMediaAndSourceOriginFields() {
        let article = sampleArticle()
        let entity = ArticleEntityMapper.makeEntity(from: article)

        #expect(entity.externalID == article.externalID)
        #expect(entity.authorName == article.authorName)
        #expect(entity.heroImageURL == article.heroImageURL?.absoluteString)
        #expect(entity.contentSource == article.contentSource)
        #expect(entity.contentWordCount == article.contentWordCount)
        #expect(entity.isContentLikelyComplete == article.isContentLikelyComplete)
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
    func applyUpdatesMediaAndSourceOriginFields() {
        let original = sampleArticle()
        let entity = ArticleEntityMapper.makeEntity(from: original)

        let refreshedHero = URL(string: "https://example.com/refreshed-hero.jpg")!
        let updated = Article(
            id: original.id,
            externalID: "ext-refreshed",
            title: original.title,
            sourceName: original.sourceName,
            sourceURL: original.sourceURL,
            articleURL: original.articleURL,
            publishedAt: original.publishedAt,
            authorName: "Refreshed Author",
            heroImageURL: refreshedHero,
            rawContent: original.rawContent,
            cleanedContent: original.cleanedContent,
            contentSource: "page_extract",
            contentWordCount: 512,
            isContentLikelyComplete: true,
            summaryShort: original.summaryShort,
            summaryBullets: original.summaryBullets,
            category: original.category,
            tags: original.tags,
            language: original.language,
            isBookmarked: original.isBookmarked,
            isRead: original.isRead,
            clusterID: original.clusterID,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt
        )

        ArticleEntityMapper.apply(updated, to: entity)

        #expect(entity.externalID == "ext-refreshed")
        #expect(entity.authorName == "Refreshed Author")
        #expect(entity.heroImageURL == refreshedHero.absoluteString)
        #expect(entity.contentSource == "page_extract")
        #expect(entity.contentWordCount == 512)
        #expect(entity.isContentLikelyComplete == true)
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
    func makeArticlePreservesMediaAndSourceOriginFields() {
        let entity = ArticleEntity(
            id: "round-trip-media",
            externalID: "guid-42",
            title: "Title",
            sourceName: "Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article",
            publishedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            authorName: "Jane Reporter",
            heroImageURL: "https://example.com/hero.jpg",
            contentSource: "rss",
            contentWordCount: 256,
            isContentLikelyComplete: true
        )

        let article = ArticleEntityMapper.makeArticle(from: entity)

        #expect(article?.externalID == "guid-42")
        #expect(article?.authorName == "Jane Reporter")
        #expect(article?.heroImageURL?.absoluteString == "https://example.com/hero.jpg")
        #expect(article?.contentSource == "rss")
        #expect(article?.contentWordCount == 256)
        #expect(article?.isContentLikelyComplete == true)
    }

    @Test
    func makeArticleHandlesMissingOptionalMediaFields() {
        // Legacy rows persisted before this schema extension will have
        // `externalID`, `authorName`, `heroImageURL`, and `contentSource`
        // missing (nil) plus default zero/false values for the numeric and
        // boolean fields. The projection must not crash and must preserve
        // those defaults verbatim.
        let entity = ArticleEntity(
            id: "round-trip-legacy",
            title: "Legacy",
            sourceName: "Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article",
            publishedAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )

        let article = ArticleEntityMapper.makeArticle(from: entity)

        #expect(article?.externalID == nil)
        #expect(article?.authorName == nil)
        #expect(article?.heroImageURL == nil)
        #expect(article?.contentSource == "")
        #expect(article?.contentWordCount == 0)
        #expect(article?.isContentLikelyComplete == false)
    }

    @Test
    func entityToArticleAndBackPreservesAllSchemaFields() {
        let original = sampleArticle()

        let entity = ArticleEntityMapper.makeEntity(from: original)
        let roundTripped = ArticleEntityMapper.makeArticle(from: entity)

        #expect(roundTripped == original)
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
