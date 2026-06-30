//
//  FeedRankingServiceTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("FeedRankingService")
struct FeedRankingServiceTests {
    @Test
    func nilPreferencesReturnsInputUntouched() {
        let articles = Self.sample()
        let ranked = FeedRankingService().rank(articles, preferences: nil)
        #expect(ranked.map(\.id) == articles.map(\.id))
    }

    @Test
    func neutralPreferencesReturnsInputUntouched() {
        let articles = Self.sample()
        let ranked = FeedRankingService().rank(articles, preferences: Self.preferences())
        #expect(ranked.map(\.id) == articles.map(\.id))
    }

    @Test
    func preferredCategoryAndFavoriteSourceBubbleUp() {
        let articles = [
            Self.article(id: "a", source: "Generic", category: "Sport"),
            Self.article(id: "b", source: "Favorite Times", category: "Politics"),
            Self.article(id: "c", source: "Generic", category: "Technology")
        ]
        let prefs = Self.preferences(
            categories: ["Technology"],
            favorites: ["Favorite Times"]
        )

        let ranked = FeedRankingService().rank(articles, preferences: prefs)

        // Favorite source (+4) outranks preferred category (+3); "a" trails.
        #expect(ranked.map(\.id) == ["b", "c", "a"])
    }

    @Test
    func hiddenSourcesAreFilteredOut() {
        let articles = [
            Self.article(id: "keep", source: "Trusted"),
            Self.article(id: "drop", source: "Blocked Outlet")
        ]
        let prefs = Self.preferences(hidden: ["Blocked Outlet"])

        let ranked = FeedRankingService().rank(articles, preferences: prefs)

        #expect(ranked.map(\.id) == ["keep"])
    }

    @Test
    func equalScoresTieBreakByPublishedAtDescending() {
        let older = Self.article(
            id: "older",
            source: "Same",
            category: "Sport",
            publishedAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )
        let newer = Self.article(
            id: "newer",
            source: "Same",
            category: "Sport",
            publishedAt: Date(timeIntervalSinceReferenceDate: 2_000)
        )
        let prefs = Self.preferences(categories: ["Sport"])

        let ranked = FeedRankingService().rank([older, newer], preferences: prefs)

        #expect(ranked.map(\.id) == ["newer", "older"])
    }

    @Test
    func matchingTagsAccumulateScore() {
        let articles = [
            Self.article(id: "zero", source: "Generic", tags: ["misc"]),
            Self.article(id: "many", source: "Generic", tags: ["swiftui", "swift", "ios"])
        ]
        let prefs = Self.preferences(topics: ["swiftui", "ios"])

        let ranked = FeedRankingService().rank(articles, preferences: prefs)

        #expect(ranked.first?.id == "many")
    }

    // MARK: - Fixtures

    private static func sample() -> [Article] {
        [
            article(id: "1", source: "A"),
            article(id: "2", source: "B"),
            article(id: "3", source: "C")
        ]
    }

    private static func article(
        id: String,
        source: String,
        category: String? = nil,
        tags: [String] = [],
        language: String? = "en",
        publishedAt: Date = Date(timeIntervalSinceReferenceDate: 1_000)
    ) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: "Title \(id)",
            sourceName: source,
            sourceURL: URL(string: "https://example.com")!,
            articleURL: URL(string: "https://example.com/\(id)")!,
            publishedAt: publishedAt,
            authorName: nil,
            heroImageURL: nil,
            rawContent: nil,
            cleanedContent: nil,
            contentSource: "test",
            contentWordCount: 0,
            isContentLikelyComplete: false,
            summaryShort: nil,
            summaryBullets: [],
            category: category,
            tags: tags,
            language: language,
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private static func preferences(
        categories: [String] = [],
        topics: [String] = [],
        hidden: [String] = [],
        favorites: [String] = [],
        language: String? = nil
    ) -> UserPreference {
        UserPreference(
            id: "test-prefs",
            preferredCategories: categories,
            preferredTopics: topics,
            hiddenSources: hidden,
            favoriteSources: favorites,
            preferredLanguage: language,
            updatedAt: .now
        )
    }
}
