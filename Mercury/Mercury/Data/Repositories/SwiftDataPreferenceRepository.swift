//
//  SwiftDataPreferenceRepository.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation
import SwiftData

/// SwiftData-backed concrete `PreferenceRepository`.
///
/// The repository delegates to the existing `UserPreferencesService` so
/// the bootstrap/patch/reset behavior, mapper sanitization, and logging
/// stay in a single canonical place. The wrapper exists purely to give
/// consumers an interface-shaped seam (for testability and the eventual
/// Firebase sync layer) without forcing them to depend on the concrete
/// service or a `ModelContext`.
///
/// `@MainActor` matches the underlying service: the SwiftData `ModelContext`
/// used for preferences lives on the main actor and is shared with the
/// preferences UI.
@MainActor
final class SwiftDataPreferenceRepository: PreferenceRepository {
    private let service: UserPreferencesService

    /// Convenience initializer that builds the backing service from a
    /// shared `ModelContainer`. The new `ModelContext` is created on the
    /// main actor to match the service contract.
    init(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        self.service = UserPreferencesService(modelContext: context)
    }

    /// Test seam: inject a pre-built service so repository tests can
    /// share the same in-memory `ModelContext` for assertions.
    init(service: UserPreferencesService) {
        self.service = service
    }

    func loadPreferences(requestID: String?) async throws -> UserPreference {
        try service.loadPreferences(requestID: requestID)
    }

    @discardableResult
    func updatePreferences(
        _ patch: UserPreferencePatch,
        requestID: String?
    ) async throws -> UserPreference {
        try service.updatePreferences(patch, requestID: requestID)
    }

    @discardableResult
    func resetPreferences(requestID: String?) async throws -> UserPreference {
        try service.resetPreferences(requestID: requestID)
    }
}
