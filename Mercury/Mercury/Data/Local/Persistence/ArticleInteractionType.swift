//
//  ArticleInteractionType.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Canonical action types persisted in `InteractionEntity.actionType`.
///
/// The entity stores raw strings to keep the on-disk schema flexible, but
/// callers should funnel writes through these cases so the action vocabulary
/// stays consistent across features (history, analytics, ranking signals).
enum ArticleInteractionType: String, CaseIterable, Sendable {
    /// The user opened the article detail view.
    case open
    /// The user bookmarked/unbookmarked the article.
    case bookmarkToggle = "bookmark_toggle"
    /// The user marked the article as read (either explicitly or via scroll).
    case markRead = "mark_read"
}
