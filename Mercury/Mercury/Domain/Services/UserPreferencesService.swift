//
//  UserPreferencesService.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData

/// Errors raised by `UserPreferencesService` when SwiftData access fails.
enum UserPreferencesServiceError: Error, Equatable {
    case fetchFailed(String)
    case persistFailed(String)
}

/// On-device service that owns the single `UserPreferenceEntity` record.
///
/// The service is intentionally local-only and exposes a small, focused API
/// the rest of the app can call without touching SwiftData directly:
///
/// * `loadPreferences()` returns the current preferences (bootstrapping
///   defaults on first launch)
/// * `updatePreferences(_:)` applies a partial patch
/// * `resetPreferences()` reverts to the documented defaults
///
/// Cloud sync (issue #12 reserves that for a future iteration) and the
/// repository abstraction (issue #29) are explicitly out of scope here.
///
/// The service is `@MainActor` because `ModelContext` is not `Sendable` and
/// preferences are read/written from view models that already live on the
/// main actor. This keeps the contract simple and matches the SwiftData
/// guidance for SwiftUI-first apps.
@MainActor
final class UserPreferencesService {
    /// Canonical identifier for the single locally stored preferences record.
    /// Preferences are intentionally a single-document model on-device.
    static let singletonRecordID = "default-user-preferences"

    private let modelContext: ModelContext
    private let mapper: UserPreferenceMapper
    private let logger: AppLogger
    private let now: @MainActor () -> Date

    init(
        modelContext: ModelContext,
        mapper: UserPreferenceMapper = UserPreferenceMapper(),
        logger: AppLogger = .shared,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.mapper = mapper
        self.logger = logger
        self.now = now
    }

    /// Returns the locally stored preferences, creating the default record
    /// on first launch if needed.
    func loadPreferences(requestID: String? = nil) throws -> UserPreference {
        let traceID = requestID ?? makeRequestID(prefix: "prefs-load")
        logger.trace(
            "Loading user preferences",
            category: .database,
            service: "UserPreferencesService",
            requestID: traceID
        )

        let entity = try fetchOrBootstrap(requestID: traceID)
        let preference = mapper.makeDomain(from: entity)

        logger.debug(
            "User preferences loaded",
            category: .database,
            service: "UserPreferencesService",
            requestID: traceID,
            metadata: [
                "categories_count": "\(preference.preferredCategories.count)",
                "topics_count": "\(preference.preferredTopics.count)",
                "favorites_count": "\(preference.favoriteSources.count)",
                "hidden_count": "\(preference.hiddenSources.count)",
                "language": preference.preferredLanguage ?? "none"
            ]
        )

        return preference
    }

    /// Applies a partial update to the stored preferences and persists the
    /// resulting record. A no-op patch returns the existing snapshot
    /// without touching the database.
    @discardableResult
    func updatePreferences(
        _ patch: UserPreferencePatch,
        requestID: String? = nil
    ) throws -> UserPreference {
        let traceID = requestID ?? makeRequestID(prefix: "prefs-update")

        if patch.isEmpty {
            logger.trace(
                "Skipping no-op preferences update",
                category: .database,
                service: "UserPreferencesService",
                requestID: traceID
            )
            return try loadPreferences(requestID: traceID)
        }

        logger.info(
            "Updating user preferences",
            category: .business,
            service: "UserPreferencesService",
            requestID: traceID,
            metadata: patchMetadata(patch)
        )

        let entity = try fetchOrBootstrap(requestID: traceID)
        mapper.apply(patch, to: entity, now: now())
        try persist(requestID: traceID, action: "update")

        return mapper.makeDomain(from: entity)
    }

    /// Resets preferences to defaults (empty lists, no language).
    @discardableResult
    func resetPreferences(requestID: String? = nil) throws -> UserPreference {
        let traceID = requestID ?? makeRequestID(prefix: "prefs-reset")
        logger.info(
            "Resetting user preferences to defaults",
            category: .business,
            service: "UserPreferencesService",
            requestID: traceID
        )

        let entity = try fetchOrBootstrap(requestID: traceID)
        entity.preferredCategories = []
        entity.preferredTopics = []
        entity.hiddenSources = []
        entity.favoriteSources = []
        entity.preferredLanguage = nil
        entity.updatedAt = now()
        try persist(requestID: traceID, action: "reset")

        return mapper.makeDomain(from: entity)
    }

    // MARK: - Private helpers

    private func fetchOrBootstrap(requestID: String) throws -> UserPreferenceEntity {
        let singletonID = Self.singletonRecordID
        let descriptor = FetchDescriptor<UserPreferenceEntity>(
            predicate: #Predicate { entity in entity.id == singletonID }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            if let existing = results.first {
                return existing
            }
        } catch {
            logger.error(
                "Failed to fetch user preferences",
                category: .database,
                service: "UserPreferencesService",
                requestID: requestID,
                metadata: ["error": error.localizedDescription]
            )
            throw UserPreferencesServiceError.fetchFailed(error.localizedDescription)
        }

        logger.info(
            "Bootstrapping default user preferences record",
            category: .database,
            service: "UserPreferencesService",
            requestID: requestID,
            metadata: ["record_id": singletonID]
        )

        let entity = UserPreferenceEntity(id: singletonID, updatedAt: now())
        modelContext.insert(entity)
        try persist(requestID: requestID, action: "bootstrap")
        return entity
    }

    private func persist(requestID: String, action: String) throws {
        do {
            try modelContext.save()
        } catch {
            logger.error(
                "Failed to persist user preferences",
                category: .database,
                service: "UserPreferencesService",
                requestID: requestID,
                metadata: [
                    "action": action,
                    "error": error.localizedDescription
                ]
            )
            throw UserPreferencesServiceError.persistFailed(error.localizedDescription)
        }
    }

    private func patchMetadata(_ patch: UserPreferencePatch) -> [String: String] {
        var metadata: [String: String] = [:]
        if let categories = patch.preferredCategories {
            metadata["categories_in"] = "\(categories.count)"
        }
        if let topics = patch.preferredTopics {
            metadata["topics_in"] = "\(topics.count)"
        }
        if let hidden = patch.hiddenSources {
            metadata["hidden_in"] = "\(hidden.count)"
        }
        if let favorites = patch.favoriteSources {
            metadata["favorites_in"] = "\(favorites.count)"
        }
        if patch.clearsPreferredLanguage {
            metadata["language"] = "cleared"
        } else if let language = patch.preferredLanguage {
            metadata["language"] = language
        }
        if let renderer = patch.articleRenderer {
            metadata["article_renderer"] = renderer.rawValue
        }
        return metadata
    }

    private func makeRequestID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.lowercased())"
    }
}
