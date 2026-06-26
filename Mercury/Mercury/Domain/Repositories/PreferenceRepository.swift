//
//  PreferenceRepository.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// Abstraction over the on-device user preferences store.
///
/// `PreferenceRepository` mirrors the public surface of
/// `UserPreferencesService` so consumers (settings view models, ranking,
/// future Firebase sync) can depend on an interface instead of a concrete
/// SwiftData service. The single-document semantics are preserved: every
/// call resolves to the singleton preferences record, bootstrapping the
/// defaults on first launch.
///
/// The protocol is `@MainActor` because the SwiftData-backed
/// implementation must share the main-actor `ModelContext` used by the
/// rest of the preferences-facing UI. Async signatures keep the door open
/// for off-main implementations (Firebase, mocked async fakes) without a
/// breaking change.
@MainActor
protocol PreferenceRepository: AnyObject {
    /// Returns the locally stored preferences, creating the default
    /// record on first launch if needed.
    func loadPreferences(requestID: String?) async throws -> UserPreference

    /// Applies a partial update to the stored preferences and returns the
    /// resulting snapshot. An empty patch is a no-op and returns the
    /// current value without touching the database.
    @discardableResult
    func updatePreferences(
        _ patch: UserPreferencePatch,
        requestID: String?
    ) async throws -> UserPreference

    /// Resets preferences to defaults (empty lists, no language).
    @discardableResult
    func resetPreferences(requestID: String?) async throws -> UserPreference
}

// MARK: - Convenience defaults

extension PreferenceRepository {
    func loadPreferences() async throws -> UserPreference {
        try await loadPreferences(requestID: nil)
    }

    @discardableResult
    func updatePreferences(_ patch: UserPreferencePatch) async throws -> UserPreference {
        try await updatePreferences(patch, requestID: nil)
    }

    @discardableResult
    func resetPreferences() async throws -> UserPreference {
        try await resetPreferences(requestID: nil)
    }
}
