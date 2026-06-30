//
//  FeedRankingService.swift
//  Mercury
//
//  Created by Codex on 30/06/26.
//

import Foundation

/// Re-orders a feed based on the locally stored `UserPreference`.
///
/// Pure function wrapped in a struct so it stays trivial to test and to
/// swap for a smarter algorithm later (issue #13 documents this as the
/// "base" pre-personalization service; extensibility comes when a real
/// signal — interaction history, ML model — needs to plug in).
///
/// Behavior:
/// * articles whose source is in `hiddenSources` are dropped entirely
/// * remaining articles are scored against the preference signals and
///   sorted by score descending, tie-broken by `publishedAt` descending
/// * when `preferences` is `nil` the input is returned as-is so the
///   pipeline degrades gracefully before the user has set any signal
struct FeedRankingService: Sendable {
    func rank(_ articles: [Article], preferences: UserPreference?) -> [Article] {
        guard let preferences, preferences.hasAnySignal else { return articles }

        let hidden = Set(preferences.hiddenSources.map { $0.lowercased() })
        let categories = Set(preferences.preferredCategories.map { $0.lowercased() })
        let topics = Set(preferences.preferredTopics.map { $0.lowercased() })
        let favorites = Set(preferences.favoriteSources.map { $0.lowercased() })
        let language = preferences.preferredLanguage?.lowercased()

        let visible = articles.filter { article in
            hidden.contains(article.sourceName.lowercased()) == false
        }

        return visible
            .enumerated()
            .map { index, article in
                (index, article, score(
                    article,
                    categories: categories,
                    topics: topics,
                    favorites: favorites,
                    language: language
                ))
            }
            .sorted { lhs, rhs in
                if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
                if lhs.1.publishedAt != rhs.1.publishedAt {
                    return lhs.1.publishedAt > rhs.1.publishedAt
                }
                return lhs.0 < rhs.0
            }
            .map { $0.1 }
    }

    private func score(
        _ article: Article,
        categories: Set<String>,
        topics: Set<String>,
        favorites: Set<String>,
        language: String?
    ) -> Int {
        var total = 0
        if let category = article.category?.lowercased(), categories.contains(category) {
            total += 3
        }
        for tag in article.tags where topics.contains(tag.lowercased()) {
            total += 2
        }
        if favorites.contains(article.sourceName.lowercased()) {
            total += 4
        }
        if let language, article.language?.lowercased() == language {
            total += 1
        }
        return total
    }
}

private extension UserPreference {
    var hasAnySignal: Bool {
        preferredCategories.isEmpty == false
            || preferredTopics.isEmpty == false
            || hiddenSources.isEmpty == false
            || favoriteSources.isEmpty == false
            || (preferredLanguage?.isEmpty == false)
    }
}
