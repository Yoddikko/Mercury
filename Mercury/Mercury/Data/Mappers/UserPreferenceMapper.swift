//
//  UserPreferenceMapper.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Translates between the `UserPreferenceEntity` SwiftData model and the
/// `UserPreference` domain model.
///
/// Mapping is kept pure (no I/O) so the service layer can apply it freely
/// without worrying about SwiftData side effects.
struct UserPreferenceMapper {
    init() {}

    func makeDomain(from entity: UserPreferenceEntity) -> UserPreference {
        UserPreference(
            id: entity.id,
            preferredCategories: entity.preferredCategories,
            preferredTopics: entity.preferredTopics,
            hiddenSources: entity.hiddenSources,
            favoriteSources: entity.favoriteSources,
            preferredLanguage: entity.preferredLanguage,
            articleRenderer: ArticleRendererMode(rawValueOrDefault: entity.articleRendererRawValue),
            updatedAt: entity.updatedAt
        )
    }

    func apply(_ patch: UserPreferencePatch, to entity: UserPreferenceEntity, now: Date) {
        if let categories = patch.preferredCategories {
            entity.preferredCategories = Self.sanitize(categories)
        }
        if let topics = patch.preferredTopics {
            entity.preferredTopics = Self.sanitize(topics)
        }
        if let hidden = patch.hiddenSources {
            entity.hiddenSources = Self.sanitize(hidden)
        }
        if let favorites = patch.favoriteSources {
            entity.favoriteSources = Self.sanitize(favorites)
        }
        if patch.clearsPreferredLanguage {
            entity.preferredLanguage = nil
        } else if let language = patch.preferredLanguage {
            let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
            entity.preferredLanguage = trimmed.isEmpty ? nil : trimmed
        }
        if let renderer = patch.articleRenderer {
            entity.articleRendererRawValue = renderer.rawValue
        }
        entity.updatedAt = now
    }

    /// Strips empty/whitespace-only entries and deduplicates while preserving
    /// insertion order, so the stored arrays stay stable across writes.
    private static func sanitize(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(values.count)
        for raw in values {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
