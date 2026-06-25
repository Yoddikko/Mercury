//
//  AIProviderStoresTests.swift
//  MercuryTests
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct AIProviderStoresTests {
    @Test
    func userDefaultsConfigurationStorePersistsConfiguration() throws {
        let suiteName = "com.mercury.tests.ai-config.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsAIProviderConfigurationStore(
            userDefaults: userDefaults,
            key: "test.ai.configuration"
        )

        var configuration = AIProviderConfiguration(
            activeProviderID: .gemini,
            modelByProvider: [:],
            ollamaEndpoint: "http://localhost:11434",
            timeoutSeconds: 30
        )
        configuration.setModel("gpt-test", for: .openAI)
        configuration.setModel("claude-test", for: .claude)
        configuration.setModel("gemini-test", for: .gemini)
        configuration.setModel("llama3.1:8b", for: .ollama)
        configuration.setModel("deepseek-chat", for: .deepSeek)

        try store.saveConfiguration(configuration)
        let loaded = store.loadConfiguration()

        #expect(loaded == configuration)
    }

    @Test
    func keychainCredentialStoreSavesLoadsAndDeletesToken() throws {
        let service = "com.mercury.tests.ai-credentials.\(UUID().uuidString)"
        let store = KeychainAIProviderCredentialStore(service: service)

        defer {
            try? store.deleteToken(for: .openAI)
        }

        do {
            try store.saveToken("token-value", for: .openAI)
            let loaded = try store.loadToken(for: .openAI)
            #expect(loaded == "token-value")

            try store.deleteToken(for: .openAI)
            let afterDelete = try store.loadToken(for: .openAI)
            #expect(afterDelete == nil)
        } catch let error as AIProviderCredentialStoreError {
            // On some simulator runners Keychain can return errSecMissingEntitlement (-34018).
            // Treat it as an environment limitation, not a store logic regression.
            guard case let .unexpectedStatus(status) = error, status == -34018 else {
                throw error
            }
        }
    }
}
