//
//  SettingsViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 30/06/26.
//

import Foundation
import SwiftData
import Testing
@testable import Mercury

@MainActor
@Suite("SettingsViewModel + ArticleRendererMode persistence")
struct SettingsViewModelTests {
    @Test
    func defaultsToWebWhenNoEntityExists() throws {
        let (service, _) = try Self.makeService()
        let viewModel = SettingsViewModel(service: service)

        viewModel.load()

        #expect(viewModel.articleRenderer == .web)
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test
    func updateArticleRendererPersistsAcrossReloads() throws {
        let (service, _) = try Self.makeService()
        let viewModel = SettingsViewModel(service: service)
        viewModel.load()

        viewModel.updateArticleRenderer(.native)
        #expect(viewModel.articleRenderer == .native)

        let reloaded = SettingsViewModel(service: service)
        reloaded.load()
        #expect(reloaded.articleRenderer == .native)
    }

    @Test
    func unknownRawValueFallsBackToWeb() throws {
        let (service, context) = try Self.makeService()
        let entity = UserPreferenceEntity(articleRendererRawValue: "wat")
        context.insert(entity)
        try context.save()

        let viewModel = SettingsViewModel(service: service)
        viewModel.load()

        #expect(viewModel.articleRenderer == .web)
    }

    @Test
    func mapperRoundTripsArticleRenderer() throws {
        let entity = UserPreferenceEntity(articleRendererRawValue: "native")
        let mapper = UserPreferenceMapper()

        let domain = mapper.makeDomain(from: entity)
        #expect(domain.articleRenderer == .native)
    }

    @Test
    func patchAppliesArticleRendererAndIsEmptyHonorsField() {
        var patch = UserPreferencePatch()
        #expect(patch.isEmpty)

        patch.articleRenderer = .native
        #expect(patch.isEmpty == false)
    }

    @Test
    func sameModeIsNoOp() throws {
        let (service, _) = try Self.makeService()
        let viewModel = SettingsViewModel(service: service)
        viewModel.load()
        let snapshot = try service.loadPreferences().updatedAt

        viewModel.updateArticleRenderer(.web)

        let after = try service.loadPreferences().updatedAt
        #expect(after == snapshot)
    }

    // MARK: - Helpers

    private static func makeService() throws -> (UserPreferencesService, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserPreferenceEntity.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let service = UserPreferencesService(modelContext: context)
        return (service, context)
    }
}
