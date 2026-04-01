//
//  HomeViewModel.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

import Foundation

struct HomeViewModel {
    struct FeedMode: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
    }

    let title: String
    let subtitle: String
    let feedModes: [FeedMode]
    let featuredArticles: [Article]
    let isDeveloperModeEnabled: Bool

    init(
        feedModes: [FeedMode]? = nil,
        featuredArticles: [Article] = Article.previewFeed,
        isDeveloperModeEnabled: Bool = DeveloperMode.isEnabled
    ) {
        self.title = String(localized: "home.title", defaultValue: "Mercury")
        self.subtitle = String(
            localized: "home.subtitle",
            defaultValue: "Mercury turns RSS into a structured AI-assisted news experience."
        )
        self.feedModes = feedModes ?? Self.defaultFeedModes()
        self.featuredArticles = featuredArticles
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
    }

    var navigationTitle: String {
        String(localized: "home.navigation.title", defaultValue: "Mercury")
    }

    var feedModesSectionTitle: String {
        String(localized: "home.section.feed_modes", defaultValue: "Feed Modes")
    }

    var sampleArticlesSectionTitle: String {
        String(localized: "home.section.sample_articles", defaultValue: "Sample Articles")
    }

    var uncategorizedLabel: String {
        String(localized: "home.article.uncategorized", defaultValue: "Uncategorized")
    }

    var developerToolsLabel: String {
        String(localized: "home.developer_tools", defaultValue: "Developer Tools")
    }

    func articleMetadataLine(sourceName: String, category: String?) -> String {
        let resolvedCategory = category ?? uncategorizedLabel
        return "\(sourceName) • \(resolvedCategory)"
    }

    private static func defaultFeedModes() -> [FeedMode] {
        [
            FeedMode(
                id: "default",
                title: String(localized: "home.feed_mode.default.title", defaultValue: "Default Feed"),
                detail: String(
                    localized: "home.feed_mode.default.detail",
                    defaultValue: "Chronological fallback so the app always returns news, even without personalization."
                )
            ),
            FeedMode(
                id: "personalized",
                title: String(localized: "home.feed_mode.personalized.title", defaultValue: "Personalized Feed"),
                detail: String(
                    localized: "home.feed_mode.personalized.detail",
                    defaultValue: "Ranking based on preferred categories, topics, and interaction history."
                )
            ),
            FeedMode(
                id: "clustered",
                title: String(localized: "home.feed_mode.clustered.title", defaultValue: "Clustered Feed"),
                detail: String(
                    localized: "home.feed_mode.clustered.detail",
                    defaultValue: "Optional event grouping so multiple articles can be reduced to one representative story."
                )
            )
        ]
    }
}
