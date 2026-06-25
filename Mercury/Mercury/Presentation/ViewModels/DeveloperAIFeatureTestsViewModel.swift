//
//  DeveloperAIFeatureTestsViewModel.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

#if DEBUG

import Foundation
import Combine

/// Identifies the single AI features that the Developer Playground can
/// exercise in isolation. Mirrors the per-step capabilities documented in
/// `docs/ai/PIPELINE.md` (categorization, summarization, tags) so each
/// pipeline step has a corresponding playground affordance.
enum DeveloperAIFeatureKind: String, CaseIterable, Identifiable, Sendable {
    case summary
    case category
    case tags

    var id: String { rawValue }
}

/// Result of a single AI feature invocation in the developer playground.
struct DeveloperAIFeatureRunOutcome: Sendable, Equatable {
    enum Status: Sendable, Equatable {
        case success
        case failure(String)
    }

    let kind: DeveloperAIFeatureKind
    let status: Status
    let output: String
    let providerID: AIProviderID
    let model: String
    let durationMs: Int
    let requestID: String
    let sampleID: String

    var isSuccess: Bool {
        if case .success = status { return true }
        return false
    }
}

/// Minimal state machine used by the Developer Playground to track running
/// single-feature AI tests.
@MainActor
final class DeveloperAIFeatureTestsViewModel: ObservableObject {
    @Published var selectedSampleID: String
    @Published var customPromptOverride: String = ""
    @Published var runningFeatures: Set<DeveloperAIFeatureKind> = []
    @Published var outcomesByFeature: [DeveloperAIFeatureKind: DeveloperAIFeatureRunOutcome] = [:]
    @Published var lastErrorMessage: String?
    @Published var lastStatusMessage: String?

    let availableSamples: [AIPlaygroundSampleArticles.Sample]

    private let aiService: AIService
    private let logger: AppLogger
    private let clock: @Sendable () -> Date

    init(
        aiService: AIService = AIService(),
        logger: AppLogger = .shared,
        samples: [AIPlaygroundSampleArticles.Sample] = AIPlaygroundSampleArticles.all,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.aiService = aiService
        self.logger = logger
        self.availableSamples = samples
        self.selectedSampleID = samples.first?.id ?? ""
        self.clock = clock
    }

    /// Body that will be sent to the provider for the currently selected
    /// fixture. Returns `nil` when no fixture is selected and no override
    /// was provided.
    var resolvedPromptContent: String? {
        let trimmedOverride = customPromptOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOverride.isEmpty == false {
            return trimmedOverride
        }
        guard let sample = currentSample else { return nil }
        return sample.body
    }

    var currentSample: AIPlaygroundSampleArticles.Sample? {
        availableSamples.first { $0.id == selectedSampleID }
    }

    func isRunning(_ kind: DeveloperAIFeatureKind) -> Bool {
        runningFeatures.contains(kind)
    }

    var isRunningAny: Bool { runningFeatures.isEmpty == false }

    /// Runs a single AI feature against the resolved prompt and records the
    /// outcome (success or failure) along with elapsed time.
    func runFeature(_ kind: DeveloperAIFeatureKind) async {
        guard runningFeatures.contains(kind) == false else { return }

        guard let prompt = resolvedPromptContent, prompt.isEmpty == false else {
            let message = String(
                localized: "developer.playground.ai_features.error.prompt_required",
                defaultValue: "Select a sample article or provide a custom prompt before running."
            )
            lastErrorMessage = message
            lastStatusMessage = nil
            logger.warn(
                "AI feature test invoked with empty prompt",
                category: .ui,
                service: "DeveloperAIFeatureTestsViewModel",
                metadata: ["feature": kind.rawValue]
            )
            return
        }

        runningFeatures.insert(kind)
        lastErrorMessage = nil
        lastStatusMessage = nil

        let requestID = "debug-ai-feature-\(kind.rawValue)-\(UUID().uuidString.lowercased())"
        let startedAt = clock()
        let configuration = await aiService.loadProviderConfiguration()
        let providerID = configuration.activeProviderID
        let model = configuration.model(for: providerID)

        logger.info(
            "Starting AI feature test",
            category: .ui,
            service: "DeveloperAIFeatureTestsViewModel",
            requestID: requestID,
            metadata: [
                "feature": kind.rawValue,
                "provider": providerID.rawValue,
                "model": model,
                "sample_id": currentSample?.id ?? "custom",
                "prompt_length": "\(prompt.count)"
            ]
        )

        defer {
            runningFeatures.remove(kind)
        }

        do {
            let output = try await invoke(kind: kind, content: prompt, requestID: requestID)
            let elapsedMs = elapsedMilliseconds(since: startedAt)
            let outcome = DeveloperAIFeatureRunOutcome(
                kind: kind,
                status: .success,
                output: output,
                providerID: providerID,
                model: model,
                durationMs: elapsedMs,
                requestID: requestID,
                sampleID: currentSample?.id ?? "custom"
            )
            outcomesByFeature[kind] = outcome
            lastStatusMessage = featureStatusMessage(for: kind, success: true)

            logger.info(
                "AI feature test completed",
                category: .ui,
                service: "DeveloperAIFeatureTestsViewModel",
                requestID: requestID,
                metadata: [
                    "feature": kind.rawValue,
                    "provider": providerID.rawValue,
                    "duration_ms": "\(elapsedMs)",
                    "output_length": "\(output.count)"
                ]
            )
        } catch {
            let elapsedMs = elapsedMilliseconds(since: startedAt)
            let message = error.localizedDescription
            let outcome = DeveloperAIFeatureRunOutcome(
                kind: kind,
                status: .failure(message),
                output: "",
                providerID: providerID,
                model: model,
                durationMs: elapsedMs,
                requestID: requestID,
                sampleID: currentSample?.id ?? "custom"
            )
            outcomesByFeature[kind] = outcome
            lastErrorMessage = featureFailureMessage(for: kind, message: message)
            lastStatusMessage = nil

            logger.warn(
                "AI feature test failed",
                category: .ui,
                service: "DeveloperAIFeatureTestsViewModel",
                requestID: requestID,
                metadata: [
                    "feature": kind.rawValue,
                    "provider": providerID.rawValue,
                    "duration_ms": "\(elapsedMs)",
                    "error": message
                ]
            )
        }
    }

    /// Convenience helper that runs every documented feature sequentially.
    /// Used by the "run all" button in the playground UI.
    func runAllFeatures() async {
        for feature in DeveloperAIFeatureKind.allCases {
            await runFeature(feature)
        }
    }

    func clearResults() {
        outcomesByFeature.removeAll()
        lastErrorMessage = nil
        lastStatusMessage = nil
        logger.debug(
            "Cleared AI feature test outcomes",
            category: .ui,
            service: "DeveloperAIFeatureTestsViewModel"
        )
    }

    // MARK: - Private

    private func invoke(
        kind: DeveloperAIFeatureKind,
        content: String,
        requestID: String
    ) async throws -> String {
        switch kind {
        case .summary:
            let result = try await aiService.summarizeArticle(content, requestID: requestID)
            return formatSummary(result)
        case .category:
            let result = try await aiService.categorizeArticle(content, requestID: requestID)
            return result.category
        case .tags:
            let result = try await aiService.generateTags(content, requestID: requestID)
            return result.joined(separator: ", ")
        }
    }

    private func formatSummary(_ result: AISummaryResult) -> String {
        let bulletsBlock = result.bullets.isEmpty
            ? ""
            : "\n\n• " + result.bullets.joined(separator: "\n• ")
        return result.shortSummary + bulletsBlock
    }

    private func elapsedMilliseconds(since start: Date) -> Int {
        let interval = clock().timeIntervalSince(start)
        return max(0, Int((interval * 1000).rounded()))
    }

    private func featureStatusMessage(for kind: DeveloperAIFeatureKind, success: Bool) -> String {
        let format = String(
            localized: "developer.playground.ai_features.status.completed",
            defaultValue: "%@ completed."
        )
        return String(format: format, locale: .current, displayName(for: kind))
    }

    private func featureFailureMessage(for kind: DeveloperAIFeatureKind, message: String) -> String {
        let format = String(
            localized: "developer.playground.ai_features.status.failed",
            defaultValue: "%@ failed: %@"
        )
        return String(format: format, locale: .current, displayName(for: kind), message)
    }

    func displayName(for kind: DeveloperAIFeatureKind) -> String {
        switch kind {
        case .summary:
            return String(
                localized: "developer.playground.ai_features.feature.summary",
                defaultValue: "Summarization"
            )
        case .category:
            return String(
                localized: "developer.playground.ai_features.feature.category",
                defaultValue: "Categorization"
            )
        case .tags:
            return String(
                localized: "developer.playground.ai_features.feature.tags",
                defaultValue: "Tag generation"
            )
        }
    }

    func promptSource(for kind: DeveloperAIFeatureKind) -> String {
        switch kind {
        case .summary:
            return String(
                localized: "developer.playground.ai_features.prompt_source.summary",
                defaultValue: "AIPromptBuilder.summaryPrompt"
            )
        case .category:
            return String(
                localized: "developer.playground.ai_features.prompt_source.category",
                defaultValue: "AIPromptBuilder.categoryPrompt"
            )
        case .tags:
            return String(
                localized: "developer.playground.ai_features.prompt_source.tags",
                defaultValue: "AIPromptBuilder.tagsPrompt"
            )
        }
    }

    func sampleTitle(_ sample: AIPlaygroundSampleArticles.Sample) -> String {
        switch sample.id {
        case "tech_chip":
            return String(
                localized: "developer.playground.ai_features.sample.tech_chip.title",
                defaultValue: "Aurora unveils 2 nm AI chip with on-device large model support"
            )
        case "business_merger":
            return String(
                localized: "developer.playground.ai_features.sample.business_merger.title",
                defaultValue: "Northwind and Vesta agree on 14 billion dollar merger to reshape grocery logistics"
            )
        case "science_climate":
            return String(
                localized: "developer.playground.ai_features.sample.science_climate.title",
                defaultValue: "Ocean heat content reaches new record as researchers refine 2026 climate outlook"
            )
        default:
            return sample.titleFallback
        }
    }

    func sampleDescription(_ sample: AIPlaygroundSampleArticles.Sample) -> String {
        switch sample.id {
        case "tech_chip":
            return String(
                localized: "developer.playground.ai_features.sample.tech_chip.description",
                defaultValue: "Long-form technology article useful for summarization, categorization, and tag generation."
            )
        case "business_merger":
            return String(
                localized: "developer.playground.ai_features.sample.business_merger.description",
                defaultValue: "Business and economy article for testing categorization and tag extraction."
            )
        case "science_climate":
            return String(
                localized: "developer.playground.ai_features.sample.science_climate.description",
                defaultValue: "Science and climate article for testing summarization quality and categorization edge cases."
            )
        default:
            return sample.descriptionFallback
        }
    }
}

#endif
