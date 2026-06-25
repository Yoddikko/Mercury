//
//  DeveloperAIFeatureTestsViewModelTests.swift
//  MercuryTests
//
//  Created by Codex on 25/06/26.
//

import Foundation
import Testing
@testable import Mercury

#if DEBUG

@MainActor
struct DeveloperAIFeatureTestsViewModelTests {
    // MARK: - Initial state

    @Test
    func initialStateExposesFixturesAndIdleState() {
        let viewModel = makeViewModel()

        #expect(viewModel.availableSamples.isEmpty == false)
        #expect(viewModel.selectedSampleID == AIPlaygroundSampleArticles.all.first?.id)
        #expect(viewModel.currentSample?.id == AIPlaygroundSampleArticles.all.first?.id)
        #expect(viewModel.customPromptOverride.isEmpty)
        #expect(viewModel.runningFeatures.isEmpty)
        #expect(viewModel.outcomesByFeature.isEmpty)
        #expect(viewModel.lastErrorMessage == nil)
        #expect(viewModel.lastStatusMessage == nil)
        #expect(viewModel.isRunningAny == false)
        for kind in DeveloperAIFeatureKind.allCases {
            #expect(viewModel.isRunning(kind) == false)
        }
    }

    @Test
    func selectingSampleUpdatesCurrentSample() {
        let viewModel = makeViewModel()
        let candidate = AIPlaygroundSampleArticles.all.last
        #expect(candidate != nil)

        viewModel.selectedSampleID = candidate?.id ?? ""

        #expect(viewModel.currentSample?.id == candidate?.id)
        #expect(viewModel.resolvedPromptContent == candidate?.body)
    }

    @Test
    func customPromptOverrideTakesPrecedenceOverSample() {
        let viewModel = makeViewModel()
        viewModel.customPromptOverride = "  Hand-written prompt body. "

        #expect(viewModel.resolvedPromptContent == "Hand-written prompt body.")
    }

    @Test
    func resolvedPromptIsNilWhenSampleMissingAndOverrideBlank() {
        let viewModel = makeViewModel(samples: [])
        viewModel.customPromptOverride = "   "

        #expect(viewModel.currentSample == nil)
        #expect(viewModel.resolvedPromptContent == nil)
    }

    // MARK: - Feature run success transitions

    @Test
    func summaryFeatureTransitionsThroughRunningThenSuccess() async {
        let observer = RunningStateObserver()
        let provider = ScriptedAIProvider(
            summary: { _, _ in
                await observer.recordObservation()
                return AISummaryResult(shortSummary: "Headline", bullets: ["Alpha", "Beta"])
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)
        await observer.attach(viewModel: viewModel, kind: .summary)

        await viewModel.runFeature(.summary)

        let observedRunning = await observer.observedRunning
        #expect(observedRunning == true)
        #expect(viewModel.isRunning(.summary) == false)
        let outcome = viewModel.outcomesByFeature[.summary]
        #expect(outcome != nil)
        #expect(outcome?.isSuccess == true)
        #expect(outcome?.kind == .summary)
        #expect(outcome?.output.contains("Headline") == true)
        #expect(outcome?.output.contains("Alpha") == true)
        #expect(viewModel.lastErrorMessage == nil)
        #expect(viewModel.lastStatusMessage?.isEmpty == false)
    }

    @Test
    func categoryFeatureTransitionsToSuccessWithCategoryPayload() async {
        let provider = ScriptedAIProvider(
            category: { _, _ in
                AICategoryResult(category: "Science")
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)

        await viewModel.runFeature(.category)

        let outcome = viewModel.outcomesByFeature[.category]
        #expect(outcome?.isSuccess == true)
        #expect(outcome?.output == "Science")
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test
    func tagsFeatureTransitionsToSuccessWithJoinedTags() async {
        let provider = ScriptedAIProvider(
            tags: { _, _ in
                ["AI", "Chips", "Privacy"]
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)

        await viewModel.runFeature(.tags)

        let outcome = viewModel.outcomesByFeature[.tags]
        #expect(outcome?.isSuccess == true)
        #expect(outcome?.output == "AI, Chips, Privacy")
    }

    // MARK: - Feature run failure transitions

    @Test
    func summaryFeatureTransitionsToFailedWhenProviderThrows() async {
        let provider = ScriptedAIProvider(
            summary: { _, _ in
                throw AIProviderError.networkFailure("offline")
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)

        await viewModel.runFeature(.summary)

        let outcome = viewModel.outcomesByFeature[.summary]
        #expect(outcome != nil)
        #expect(outcome?.isSuccess == false)
        if case let .failure(message) = outcome?.status {
            #expect(message.isEmpty == false)
        } else {
            Issue.record("Expected failure status, got \(String(describing: outcome?.status))")
        }
        #expect(viewModel.lastErrorMessage?.isEmpty == false)
        #expect(viewModel.lastStatusMessage == nil)
    }

    @Test
    func categoryFeatureTransitionsToFailedWhenProviderThrows() async {
        let provider = ScriptedAIProvider(
            category: { _, _ in
                throw AIProviderError.unsupportedResponse("bad json")
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)

        await viewModel.runFeature(.category)

        let outcome = viewModel.outcomesByFeature[.category]
        #expect(outcome?.isSuccess == false)
    }

    @Test
    func tagsFeatureTransitionsToFailedWhenProviderThrows() async {
        let provider = ScriptedAIProvider(
            tags: { _, _ in
                throw AIProviderError.networkFailure("timeout")
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)

        await viewModel.runFeature(.tags)

        let outcome = viewModel.outcomesByFeature[.tags]
        #expect(outcome?.isSuccess == false)
    }

    // MARK: - Concurrent runs

    @Test
    func concurrentRunsDoNotCrossContaminateState() async {
        let gate = Gate()
        let provider = ScriptedAIProvider(
            summary: { _, _ in
                await gate.waitForRelease()
                return AISummaryResult(shortSummary: "summary-done", bullets: ["s1"])
            },
            category: { _, _ in
                AICategoryResult(category: "Technology")
            }
        )
        let service = makeService(provider: provider)
        let viewModel = makeViewModel(aiService: service)

        async let summaryRun: Void = viewModel.runFeature(.summary)
        // Give the summary task a moment to start
        try? await Task.sleep(nanoseconds: 30_000_000)
        await viewModel.runFeature(.category)

        #expect(viewModel.isRunning(.summary) == true)
        #expect(viewModel.isRunning(.category) == false)
        #expect(viewModel.outcomesByFeature[.category]?.isSuccess == true)
        #expect(viewModel.outcomesByFeature[.category]?.output == "Technology")
        #expect(viewModel.outcomesByFeature[.summary] == nil)

        await gate.release()
        await summaryRun

        #expect(viewModel.isRunning(.summary) == false)
        #expect(viewModel.outcomesByFeature[.summary]?.isSuccess == true)
        #expect(viewModel.outcomesByFeature[.summary]?.output.contains("summary-done") == true)
        // Category outcome must remain untouched after summary completes.
        #expect(viewModel.outcomesByFeature[.category]?.output == "Technology")
    }

    // MARK: - Helpers

    private func makeViewModel(
        aiService: AIService = AIService(
            configurationStore: InMemoryConfigStore(initial: configWith(active: .openAI)),
            credentialStore: InMemoryCredentialStore(initial: [.openAI: "token-openai"]),
            providerFactory: { context in
                FixedScriptedAIProvider(id: context.providerID)
            }
        ),
        samples: [AIPlaygroundSampleArticles.Sample] = AIPlaygroundSampleArticles.all
    ) -> DeveloperAIFeatureTestsViewModel {
        DeveloperAIFeatureTestsViewModel(aiService: aiService, samples: samples)
    }

    private func makeService(provider: ScriptedAIProvider) -> AIService {
        AIService(
            configurationStore: InMemoryConfigStore(initial: configWith(active: .openAI)),
            credentialStore: InMemoryCredentialStore(initial: [.openAI: "token-openai"]),
            providerFactory: { context in
                provider.bound(to: context.providerID)
            }
        )
    }
}

// MARK: - Configuration helpers

private func configWith(active: AIProviderID) -> AIProviderConfiguration {
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

private final class InMemoryConfigStore: @unchecked Sendable, AIProviderConfigurationStore {
    private let lock = NSLock()
    private var configuration: AIProviderConfiguration

    init(initial: AIProviderConfiguration) {
        self.configuration = initial
    }

    func loadConfiguration() -> AIProviderConfiguration {
        lock.lock(); defer { lock.unlock() }
        return configuration
    }

    func saveConfiguration(_ configuration: AIProviderConfiguration) throws {
        lock.lock(); defer { lock.unlock() }
        self.configuration = configuration
    }
}

private final class InMemoryCredentialStore: @unchecked Sendable, AIProviderCredentialStore {
    private let lock = NSLock()
    private var tokens: [AIProviderID: String]

    init(initial: [AIProviderID: String] = [:]) {
        self.tokens = initial
    }

    func loadToken(for providerID: AIProviderID) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return tokens[providerID]
    }

    func saveToken(_ token: String?, for providerID: AIProviderID) throws {
        lock.lock(); defer { lock.unlock() }
        if let token, token.isEmpty == false {
            tokens[providerID] = token
        } else {
            tokens.removeValue(forKey: providerID)
        }
    }

    func deleteToken(for providerID: AIProviderID) throws {
        lock.lock(); defer { lock.unlock() }
        tokens.removeValue(forKey: providerID)
    }
}

// MARK: - Test doubles

private struct FixedScriptedAIProvider: AIProvider {
    let id: AIProviderID

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        AISummaryResult(shortSummary: "Default summary", bullets: ["Default point"])
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        AICategoryResult(category: "Default")
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        ["Default"]
    }
}

/// Closure-driven provider used by tests to inject success or failure behavior
/// per AI capability. Each closure mirrors the signature exposed by AIProvider.
private final class ScriptedAIProvider: AIProvider, @unchecked Sendable {
    typealias SummaryClosure = @Sendable (String, String?) async throws -> AISummaryResult
    typealias CategoryClosure = @Sendable (String, String?) async throws -> AICategoryResult
    typealias TagsClosure = @Sendable (String, String?) async throws -> [String]

    private(set) var id: AIProviderID = .openAI
    private let summary: SummaryClosure
    private let category: CategoryClosure
    private let tags: TagsClosure

    init(
        summary: @escaping SummaryClosure = { _, _ in
            AISummaryResult(shortSummary: "ok", bullets: [])
        },
        category: @escaping CategoryClosure = { _, _ in
            AICategoryResult(category: "Other")
        },
        tags: @escaping TagsClosure = { _, _ in [] }
    ) {
        self.summary = summary
        self.category = category
        self.tags = tags
    }

    func bound(to providerID: AIProviderID) -> ScriptedAIProvider {
        id = providerID
        return self
    }

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        try await summary(content, requestID)
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        try await category(content, requestID)
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        try await tags(content, requestID)
    }
}

/// Observes whether a specific feature was ever marked as running while the
/// scripted provider was working. Lets tests assert the running→success
/// transition without leaking timing assumptions outside the view model.
@MainActor
private final class RunningStateObserver {
    private(set) var observedRunning = false
    private weak var viewModel: DeveloperAIFeatureTestsViewModel?
    private var kind: DeveloperAIFeatureKind = .summary

    func attach(viewModel: DeveloperAIFeatureTestsViewModel, kind: DeveloperAIFeatureKind) {
        self.viewModel = viewModel
        self.kind = kind
    }

    func recordObservation() async {
        await MainActor.run {
            if let viewModel, viewModel.isRunning(self.kind) {
                self.observedRunning = true
            }
        }
    }
}

/// Suspends a producer until `release()` is called. Used to deterministically
/// interleave two view-model runs in the cross-contamination test.
private actor Gate {
    private var isReleased = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func waitForRelease() async {
        if isReleased { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            continuations.append(continuation)
        }
    }

    func release() {
        isReleased = true
        let waiters = continuations
        continuations.removeAll()
        for continuation in waiters {
            continuation.resume()
        }
    }
}

#endif
