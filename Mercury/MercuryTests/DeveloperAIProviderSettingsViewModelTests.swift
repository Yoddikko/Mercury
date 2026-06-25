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
    func fetchModelsForActiveProviderLoadsCatalogAndSetsModel() async {
        let configurationStore = InMemoryAIProviderConfigurationStore2(
            initialConfiguration: completeConfiguration2(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore2()
        let responseData = Data(
            """
            {
              "data": [
                { "id": "gpt-4.1-mini" },
                { "id": "gpt-4o-mini" }
              ]
            }
            """.utf8
        )
        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider2(id: context.providerID)
            },
            performRequest: { _ in
                let responseURL = URL(string: "https://api.openai.com/v1/models")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let viewModel = DeveloperAIProviderSettingsViewModel(aiService: service)
        await viewModel.load()
        viewModel.openAIModel = ""
        viewModel.openAITokenInput = "token-openai"

        await viewModel.fetchAvailableModelsForActiveProvider()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.availableModels == ["gpt-4.1-mini", "gpt-4o-mini"])
        #expect(viewModel.openAIModel == "gpt-4.1-mini")
        #expect(viewModel.hasOpenAIToken == true)
    }

    @Test @MainActor
    func fetchModelsUsesCapturedProviderWhenSelectionChangesMidRequest() async {
        let configurationStore = InMemoryAIProviderConfigurationStore2(
            initialConfiguration: completeConfiguration2(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore2()
        let responseData = Data(
            """
            {
              "data": [
                { "id": "gpt-4.1-mini" },
                { "id": "gpt-4o-mini" }
              ]
            }
            """.utf8
        )
        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider2(id: context.providerID)
            },
            performRequest: { _ in
                try await Task.sleep(nanoseconds: 150_000_000)
                let responseURL = URL(string: "https://api.openai.com/v1/models")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let viewModel = DeveloperAIProviderSettingsViewModel(aiService: service)
        await viewModel.load()
        viewModel.openAIModel = ""
        viewModel.claudeModel = "claude-3-5-sonnet-latest"
        viewModel.openAITokenInput = "token-openai"

        let fetchTask = Task { @MainActor in
            await viewModel.fetchAvailableModelsForActiveProvider()
        }
        try? await Task.sleep(nanoseconds: 30_000_000)
        viewModel.activeProviderID = .claude
        await fetchTask.value

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.activeProviderID == .claude)
        #expect(viewModel.openAIModel == "gpt-4.1-mini")
        #expect(viewModel.claudeModel == "claude-3-5-sonnet-latest")
        #expect(viewModel.availableModels.isEmpty)
    }

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
    func saveConfigurationAcceptsCommaSeparatedTimeout() async {
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
        viewModel.timeoutSecondsText = "2,5"
        await viewModel.saveConfiguration()

        #expect(viewModel.errorMessage == nil)

        let reloadedConfiguration = await service.loadProviderConfiguration()
        #expect(abs(reloadedConfiguration.timeoutSeconds - 2.5) < 0.001)
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

    @Test @MainActor
    func runChecksUsesCurrentModelSelectionWithoutManualSave() async {
        let configurationStore = InMemoryAIProviderConfigurationStore2(
            initialConfiguration: .empty
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
        viewModel.openAIModel = "gpt-4.1-mini"
        viewModel.checkPrompt = "Mercury test prompt"

        await viewModel.runChecks()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.checkSummaryOutput.contains("Fixed summary"))

        let reloadedConfiguration = await service.loadProviderConfiguration()
        #expect(reloadedConfiguration.model(for: .openAI) == "gpt-4.1-mini")
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
    configuration.setModel("deepseek-chat", for: .deepSeek)
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
