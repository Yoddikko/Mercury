//
//  ArticleQuery.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Lightweight, value-type query description consumed by `ArticleLocalStore`.
///
/// The store keeps SwiftData predicates internal; view-model and use-case code
/// builds an `ArticleQuery` and lets the store materialize it.
struct ArticleQuery: Equatable, Sendable {
    /// Restrict the result to articles published on or after this date.
    var publishedAfter: Date?
    /// Restrict the result to articles published on or before this date.
    var publishedBefore: Date?
    /// Restrict the result to articles whose `sourceName` matches one of the
    /// supplied values (case-sensitive, exact match).
    var sourceNames: [String]?
    /// When `true`, only bookmarked articles are returned.
    var onlyBookmarked: Bool = false
    /// When `true`, only unread articles are returned.
    var onlyUnread: Bool = false
    /// Ordering applied to the result set.
    var sort: ArticleSortOrder = .publishedAtDescending
    /// Maximum number of articles to return. `nil` means no limit.
    var limit: Int?

    init(
        publishedAfter: Date? = nil,
        publishedBefore: Date? = nil,
        sourceNames: [String]? = nil,
        onlyBookmarked: Bool = false,
        onlyUnread: Bool = false,
        sort: ArticleSortOrder = .publishedAtDescending,
        limit: Int? = nil
    ) {
        self.publishedAfter = publishedAfter
        self.publishedBefore = publishedBefore
        self.sourceNames = sourceNames
        self.onlyBookmarked = onlyBookmarked
        self.onlyUnread = onlyUnread
        self.sort = sort
        self.limit = limit
    }
}

/// Sort orders supported by `ArticleLocalStore.fetchArticles(_:)`.
enum ArticleSortOrder: Sendable, Equatable {
    case publishedAtDescending
    case publishedAtAscending
    case createdAtDescending
    case updatedAtDescending
}
