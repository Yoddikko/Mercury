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

    let title = "Mercury"
    let subtitle = "Mercury turns RSS into a structured AI-assisted news experience."
    let feedModes: [FeedMode]
    let featuredArticles: [Article]

    init(
        feedModes: [FeedMode] = [
            FeedMode(
                id: "default",
                title: "Default Feed",
                detail: "Chronological fallback so the app always returns news, even without personalization."
            ),
            FeedMode(
                id: "personalized",
                title: "Personalized Feed",
                detail: "Ranking based on preferred categories, topics, and interaction history."
            ),
            FeedMode(
                id: "clustered",
                title: "Clustered Feed",
                detail: "Optional event grouping so multiple articles can be reduced to one representative story."
            )
        ],
        featuredArticles: [Article] = Article.previewFeed
    ) {
        self.feedModes = feedModes
        self.featuredArticles = featuredArticles
    }
}
