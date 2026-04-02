//
//  AIProviderConfigurationStore.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

protocol AIProviderConfigurationStore: Sendable {
    nonisolated func loadConfiguration() -> AIProviderConfiguration
    nonisolated func saveConfiguration(_ configuration: AIProviderConfiguration) throws
}

struct UserDefaultsAIProviderConfigurationStore: AIProviderConfigurationStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    nonisolated init(
        userDefaults: UserDefaults = .standard,
        key: String = "mercury.ai.provider.configuration.v1"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    nonisolated func loadConfiguration() -> AIProviderConfiguration {
        guard let data = userDefaults.data(forKey: key) else {
            return .empty
        }

        guard let configuration = try? JSONDecoder().decode(AIProviderConfiguration.self, from: data) else {
            return .empty
        }

        return configuration
    }

    nonisolated func saveConfiguration(_ configuration: AIProviderConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        userDefaults.set(data, forKey: key)
    }
}
