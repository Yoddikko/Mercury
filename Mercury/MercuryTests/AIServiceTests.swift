//
//  AIServiceTests.swift
//  MercuryTests
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct AIServiceTests {
    @Test
    func fetchAvailableModelsParsesAndDeduplicatesOpenAIResults() async throws {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore()
        let responseData = Data(
            """
            {
              "data": [
                { "id": "gpt-4.1-mini" },
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
                FixedAIProvider(id: context.providerID)
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

        let models = try await service.fetchAvailableModels(
            for: .openAI,
            tokenOverride: "token-openai"
        )

        #expect(models == ["gpt-4.1-mini", "gpt-4o-mini"])
    }

    @Test
    func fetchAvailableModelsParsesAndDeduplicatesDeepSeekResults() async throws {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .deepSeek)
        )
        let credentialStore = InMemoryAIProviderCredentialStore(
            initialTokens: [.deepSeek: "token-deepseek"]
        )
        let responseData = Data(
            """
            {
              "data": [
                { "id": "deepseek-chat" },
                { "id": "deepseek-chat" },
                { "id": "deepseek-reasoner" }
              ]
            }
            """.utf8
        )

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            },
            performRequest: { request in
                #expect(request.url?.absoluteString == "https://api.deepseek.com/v1/models")
                #expect(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
                let responseURL = URL(string: "https://api.deepseek.com/v1/models")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let models = try await service.fetchAvailableModels(for: .deepSeek)

        #expect(models == ["deepseek-chat", "deepseek-reasoner"])
    }

    @Test
    func fetchAvailableModelsFailsWhenTokenMissingForCloudProvider() async {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            }
        )

        do {
            _ = try await service.fetchAvailableModels(for: .openAI)
            Issue.record("Expected missing token error.")
        } catch let error as AIServiceError {
            guard case let .missingToken(providerID) = error else {
                Issue.record("Expected .missingToken, got \(error)")
                return
            }
            #expect(providerID == .openAI)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func switchesActiveProviderSuccessfully() async throws {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            }
        )

        _ = try await service.setActiveProvider(.gemini)
        let loaded = await service.loadProviderConfiguration()

        #expect(loaded.activeProviderID == .gemini)
    }

    @Test
    func updateConfigurationAllowsMissingModelsForInactiveProviders() async throws {
        var configuration = completeConfiguration(active: .openAI)
        configuration.setModel("", for: .claude)

        let service = AIService(
            configurationStore: InMemoryAIProviderConfigurationStore(initialConfiguration: .empty),
            credentialStore: InMemoryAIProviderCredentialStore(),
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            }
        )

        _ = try await service.updateProviderConfiguration(configuration)
    }

    @Test
    func updateConfigurationAllowsMissingModelForActiveProvider() async throws {
        // Issue #119: a key-only configuration (no model picked) is valid;
        // resolution falls back to the provider default at call time.
        var configuration = completeConfiguration(active: .openAI)
        configuration.setModel("", for: .openAI)

        let service = AIService(
            configurationStore: InMemoryAIProviderConfigurationStore(initialConfiguration: .empty),
            credentialStore: InMemoryAIProviderCredentialStore(),
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            }
        )

        _ = try await service.updateProviderConfiguration(configuration)
    }

    @Test
    func emptyModelResolvesToProviderDefault() async throws {
        var configuration = completeConfiguration(active: .openAI)
        configuration.setModel("", for: .openAI)

        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: configuration
        )
        let credentialStore = InMemoryAIProviderCredentialStore(
            initialTokens: [.openAI: "token-openai"]
        )
        // The factory is synchronous — capture with a locked box.
        final class ModelCapture: @unchecked Sendable {
            private let lock = NSLock()
            private var models: [String] = []
            func record(_ model: String) {
                lock.lock()
                defer { lock.unlock() }
                models.append(model)
            }
            var snapshot: [String] {
                lock.lock()
                defer { lock.unlock() }
                return models
            }
        }
        let capturedModel = ModelCapture()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                capturedModel.record(context.model)
                return FixedAIProvider(id: context.providerID)
            }
        )

        _ = try await service.summarizeArticle("Body")
        #expect(capturedModel.snapshot == [AIProviderID.openAI.defaultModel])
    }

    @Test
    func summarizeFailsWhenTokenMissingForCloudProvider() async {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            }
        )

        do {
            _ = try await service.summarizeArticle("Example body")
            Issue.record("Expected missing token error.")
        } catch let error as AIServiceError {
            guard case let .missingToken(providerID) = error else {
                Issue.record("Expected .missingToken, got \(error)")
                return
            }
            #expect(providerID == .openAI)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func whitespaceOnlyTokenIsStoredAsMissingAndFailsFast() async {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                FixedAIProvider(id: context.providerID)
            }
        )

        do {
            try await service.saveToken("   ", for: .openAI)
            let loadedToken = try await service.loadToken(for: .openAI)
            #expect(loadedToken == nil)

            _ = try await service.summarizeArticle("Body")
            Issue.record("Expected missing token error.")
        } catch let error as AIServiceError {
            guard case let .missingToken(providerID) = error else {
                Issue.record("Expected .missingToken, got \(error)")
                return
            }
            #expect(providerID == .openAI)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func headlineGroupingRetriesOnceOnTransientNetworkFailure() async throws {
        // Issue #123: NSURLErrorNetworkConnectionLost mid-generation is
        // transient — the first attempt fails, the retry succeeds.
        final class AttemptCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func next() -> Int {
                lock.lock()
                defer { lock.unlock() }
                value += 1
                return value
            }
            var count: Int {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
        }
        struct FlakyGroupingProvider: AIProvider {
            let id: AIProviderID
            let counter: AttemptCounter
            func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
                throw AIProviderError.invalidResponse
            }
            func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
                throw AIProviderError.invalidResponse
            }
            func generateTags(_ content: String, requestID: String?) async throws -> [String] {
                throw AIProviderError.invalidResponse
            }
            func groupHeadlines(_ headlines: String, requestID: String?) async throws -> [[String]] {
                if counter.next() == 1 {
                    throw AIProviderError.networkFailure("La connessione è persa.")
                }
                return [["a", "b"]]
            }
        }

        let counter = AttemptCounter()
        let service = AIService(
            configurationStore: InMemoryAIProviderConfigurationStore(
                initialConfiguration: completeConfiguration(active: .deepSeek)
            ),
            credentialStore: InMemoryAIProviderCredentialStore(
                initialTokens: [.deepSeek: "token-deepseek"]
            ),
            providerFactory: { context in
                FlakyGroupingProvider(id: context.providerID, counter: counter)
            }
        )

        let groups = try await service.groupArticleHeadlines(
            [(id: "a", title: "Titolo uno"), (id: "b", title: "Titolo due")]
        )
        #expect(groups == [["a", "b"]])
        #expect(counter.count == 2)
    }

    @Test
    func propagatesRequestIDToProvider() async throws {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore(
            initialTokens: [.openAI: "token-openai"]
        )
        let recorder = RequestIDRecorder()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                RecordingAIProvider(id: context.providerID, recorder: recorder)
            }
        )

        _ = try await service.summarizeArticle("Body", requestID: "req-123")
        let ids = await recorder.snapshot()

        #expect(ids == ["req-123"])
    }

    @Test
    func failsFastWithoutProviderFallback() async {
        let configurationStore = InMemoryAIProviderConfigurationStore(
            initialConfiguration: completeConfiguration(active: .openAI)
        )
        let credentialStore = InMemoryAIProviderCredentialStore(
            initialTokens: [
                .openAI: "token-openai",
                .claude: "token-claude",
                .gemini: "token-gemini"
            ]
        )
        let invocationCounter = InvocationCounter()

        let service = AIService(
            configurationStore: configurationStore,
            credentialStore: credentialStore,
            providerFactory: { context in
                invocationCounter.increment()
                if context.providerID == .openAI {
                    return FailingAIProvider(id: context.providerID)
                }
                return FixedAIProvider(id: context.providerID)
            }
        )

        do {
            _ = try await service.generateTags("Body")
            Issue.record("Expected provider failure.")
        } catch let error as AIServiceError {
            guard case let .providerFailure(providerID, providerError) = error else {
                Issue.record("Expected .providerFailure, got \(error)")
                return
            }
            #expect(providerID == .openAI)
            #expect(providerError == .networkFailure("simulated failure"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        let count = invocationCounter.value()
        #expect(count == 1)
    }
}

private func completeConfiguration(active: AIProviderID) -> AIProviderConfiguration {
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

private final class InMemoryAIProviderConfigurationStore: @unchecked Sendable, AIProviderConfigurationStore {
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

private final class InMemoryAIProviderCredentialStore: @unchecked Sendable, AIProviderCredentialStore {
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

private struct FixedAIProvider: AIProvider {
    let id: AIProviderID

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        AISummaryResult(
            shortSummary: "Summary",
            bullets: ["Point 1", "Point 2", "Point 3"]
        )
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        AICategoryResult(category: "Technology")
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        ["AI", "News", "Technology"]
    }
}

private struct FailingAIProvider: AIProvider {
    let id: AIProviderID

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        throw AIProviderError.networkFailure("simulated failure")
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        throw AIProviderError.networkFailure("simulated failure")
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        throw AIProviderError.networkFailure("simulated failure")
    }
}

private struct RecordingAIProvider: AIProvider {
    let id: AIProviderID
    let recorder: RequestIDRecorder

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        await recorder.append(requestID)
        return AISummaryResult(
            shortSummary: "Summary",
            bullets: ["Point 1", "Point 2", "Point 3"]
        )
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        await recorder.append(requestID)
        return AICategoryResult(category: "Technology")
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        await recorder.append(requestID)
        return ["AI", "News", "Technology"]
    }
}

private actor RequestIDRecorder {
    private var ids: [String?] = []

    func append(_ value: String?) {
        ids.append(value)
    }

    func snapshot() -> [String?] {
        ids
    }
}

private final class InvocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }

    func value() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
