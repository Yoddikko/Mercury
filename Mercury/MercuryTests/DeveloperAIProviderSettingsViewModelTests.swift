//
//  DeveloperAIProviderSettingsViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct DeveloperAIProviderSettingsViewModelTests {
    @Test @MainActor
    func saveConfigurationShowsValidationErrorForInvalidTimeout() async {
        let configurationStore = InMemoryAIProviderConfigurationStore2(
            initialConfiguration: completeConfiguration2(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore2(
            initialTokens: [.openAI: "token-openai"]
        )
        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider2(id: context.providerID)
            }
        )

        let viewModel = DeveloperAIProviderSettingsViewModel(aiService: service)
        await viewModel.load()
        viewModel.timeoutSecondsText = "0"
        await viewModel.saveConfiguration()

        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test @MainActor
    func runChecksPopulatesSummaryCategoryAndTags() async {
        let configurationStore = InMemoryAIProviderConfigurationStore2(
            initialConfiguration: completeConfiguration2(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore2(
            initialTokens: [.openAI: "token-openai"]
        )
        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider2(id: context.providerID)
            }
        )

        let viewModel = DeveloperAIProviderSettingsViewModel(aiService: service)
        await viewModel.load()
        viewModel.checkPrompt = "Mercury test prompt"
        await viewModel.runChecks()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.checkSummaryOutput.contains("Fixed summary"))
        #expect(viewModel.checkCategoryOutput == "Technology")
        #expect(viewModel.checkTagsOutput == "AI, News, Product")
    }
}

private func completeConfiguration2(active: AIProviderID) -> AIProviderConfiguration {
    var configuration = AIProviderConfiguration(
        activeProviderID: active,
        modelByProvider: [:],
        ollamaEndpoint: "http://localhost:11434",
        timeoutSeconds: 20
    )
    configuration.setModel("gpt-4.1-mini", for: .openAI)
    configuration.setModel("claude-3-5-sonnet-latest", for: .claude)
    configuration.setModel("gemini-2.5-flash", for: .gemini)
    configuration.setModel("llama3.1:8b", for: .ollama)
    return configuration
}

private final class InMemoryAIProviderConfigurationStore2: @unchecked Sendable, AIProviderConfigurationStore {
    private let lock = NSLock()
    private var configuration: AIProviderConfiguration

    init(initialConfiguration: AIProviderConfiguration) {
        self.configuration = initialConfiguration
    }

    func loadConfiguration() -> AIProviderConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return configuration
    }

    func saveConfiguration(_ configuration: AIProviderConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }
        self.configuration = configuration
    }
}

private final class InMemoryAIProviderCredentialStore2: @unchecked Sendable, AIProviderCredentialStore {
    private let lock = NSLock()
    private var tokens: [AIProviderID: String]

    init(initialTokens: [AIProviderID: String] = [:]) {
        self.tokens = initialTokens
    }

    func loadToken(for providerID: AIProviderID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return tokens[providerID]
    }

    func saveToken(_ token: String?, for providerID: AIProviderID) throws {
        lock.lock()
        defer { lock.unlock() }
        if let token, token.isEmpty == false {
            tokens[providerID] = token
        } else {
            tokens.removeValue(forKey: providerID)
        }
    }

    func deleteToken(for providerID: AIProviderID) throws {
        lock.lock()
        defer { lock.unlock() }
        tokens.removeValue(forKey: providerID)
    }
}

private struct FixedAIProvider2: AIProvider {
    let id: AIProviderID

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        AISummaryResult(shortSummary: "Fixed summary", bullets: ["Point 1", "Point 2", "Point 3"])
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        AICategoryResult(category: "Technology")
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        ["AI", "News", "Product"]
    }
}

