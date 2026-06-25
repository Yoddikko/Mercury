//
//  SwiftDataModelEntitiesTests.swift
//  MercuryTests
//
//  Created by Codex on 02/04/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

struct SwiftDataModelEntitiesTests {
    @Test
    func articleEntityStoresAllCoreFields() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entity = ArticleEntity(
            id: "article-1",
            externalID: "guid-1",
            title: "Sample title",
            sourceName: "Mercury Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article",
            publishedAt: now,
            authorName: "Jane Reporter",
            heroImageURL: "https://example.com/hero.jpg",
            rawContent: "raw",
            cleanedContent: "clean",
            contentSource: "rss",
            contentWordCount: 128,
            isContentLikelyComplete: true,
            summaryShort: "summary",
            summaryBullets: ["b1", "b2"],
            category: "Technology",
            tags: ["AI", "News"],
            language: "en",
            isBookmarked: true,
            isRead: true,
            clusterID: "cluster-1",
            createdAt: now,
            updatedAt: now
        )

        #expect(entity.id == "article-1")
        #expect(entity.externalID == "guid-1")
        #expect(entity.title == "Sample title")
        #expect(entity.sourceName == "Mercury Source")
        #expect(entity.sourceURL == "https://example.com/source")
        #expect(entity.articleURL == "https://example.com/article")
        #expect(entity.publishedAt == now)
        #expect(entity.authorName == "Jane Reporter")
        #expect(entity.heroImageURL == "https://example.com/hero.jpg")
        #expect(entity.rawContent == "raw")
        #expect(entity.cleanedContent == "clean")
        #expect(entity.contentSource == "rss")
        #expect(entity.contentWordCount == 128)
        #expect(entity.isContentLikelyComplete == true)
        #expect(entity.summaryShort == "summary")
        #expect(entity.summaryBullets == ["b1", "b2"])
        #expect(entity.category == "Technology")
        #expect(entity.tags == ["AI", "News"])
        #expect(entity.language == "en")
        #expect(entity.isBookmarked == true)
        #expect(entity.isRead == true)
        #expect(entity.clusterID == "cluster-1")
        #expect(entity.createdAt == now)
        #expect(entity.updatedAt == now)
    }

    @Test
    func articleEntityDefaultsMediaAndSourceOriginFields() {
        let entity = ArticleEntity(
            id: "article-defaults",
            title: "Defaults",
            sourceName: "Mercury Source",
            sourceURL: "https://example.com/source",
            articleURL: "https://example.com/article"
        )

        #expect(entity.externalID == nil)
        #expect(entity.authorName == nil)
        #expect(entity.heroImageURL == nil)
        #expect(entity.contentSource == nil)
        #expect(entity.contentWordCount == 0)
        #expect(entity.isContentLikelyComplete == false)
    }

    @Test
    func supportingEntitiesStoreStructuredData() {
        let cluster = ClusterEntity(
            id: "cluster-1",
            title: "AI News",
            summary: "Grouped articles",
            mainTopic: "AI",
            articleIDs: ["a-1", "a-2"]
        )
        let preferences = UserPreferenceEntity(
            id: "prefs-1",
            preferredCategories: ["Technology"],
            preferredTopics: ["LLM"],
            hiddenSources: ["noisy.example"],
            favoriteSources: ["trusted.example"],
            preferredLanguage: "en"
        )
        let interaction = InteractionEntity(
            id: "interaction-1",
            articleID: "a-1",
            actionType: "open",
            readingDuration: 42,
            scrollDepth: 0.73
        )

        #expect(cluster.articleIDs == ["a-1", "a-2"])
        #expect(cluster.mainTopic == "AI")

        #expect(preferences.preferredCategories == ["Technology"])
        #expect(preferences.preferredTopics == ["LLM"])
        #expect(preferences.hiddenSources == ["noisy.example"])
        #expect(preferences.favoriteSources == ["trusted.example"])
        #expect(preferences.preferredLanguage == "en")

        #expect(interaction.articleID == "a-1")
        #expect(interaction.actionType == "open")
        #expect(interaction.readingDuration == 42)
        #expect(interaction.scrollDepth == 0.73)
    }

    @Test
    func swiftDataContainerInitializesWithAllEntities() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        _ = try ModelContainer(
            for: StoredArticle.self,
            ArticleEntity.self,
            ClusterEntity.self,
            UserPreferenceEntity.self,
            InteractionEntity.self,
            configurations: configuration
        )
    }
}
