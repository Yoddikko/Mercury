//
//  DeveloperAIProviderSettingsViewModel.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Combine

@MainActor
final class DeveloperAIProviderSettingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSavingConfiguration = false
    @Published var isSavingCredentials = false
    @Published var isRunningChecks = false

    @Published var activeProviderID: AIProviderID = .openAI
    @Published var openAIModel = ""
    @Published var claudeModel = ""
    @Published var geminiModel = ""
    @Published var ollamaModel = ""
    @Published var ollamaEndpoint = "http://localhost:11434"
    @Published var timeoutSecondsText = "20"

    @Published var openAITokenInput = ""
    @Published var claudeTokenInput = ""
    @Published var geminiTokenInput = ""
    @Published var ollamaTokenInput = ""

    @Published var hasOpenAIToken = false
    @Published var hasClaudeToken = false
    @Published var hasGeminiToken = false
    @Published var hasOllamaToken = false

    @Published var checkPrompt = ""
    @Published var checkSummaryOutput = ""
    @Published var checkCategoryOutput = ""
    @Published var checkTagsOutput = ""

    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let aiService: AIService
    private let logger: AppLogger

    init(
        aiService: AIService = AIService(),
        logger: AppLogger = .shared
    ) {
        self.aiService = aiService
        self.logger = logger
    }

    func load() async {
        if isLoading {
            return
        }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        logger.debug(
            "Loading AI provider settings state",
            category: .ui,
            service: "DeveloperAIProviderSettingsViewModel"
        )

        defer {
            isLoading = false
        }

        let configuration = await aiService.loadProviderConfiguration()
        apply(configuration: configuration)
        await refreshTokenFlags()

        logger.info(
            "Loaded AI provider settings state",
            category: .ui,
            service: "DeveloperAIProviderSettingsViewModel",
            metadata: ["active_provider": activeProviderID.rawValue]
        )
    }

    func saveConfiguration() async {
        if isSavingConfiguration {
            return
        }
        isSavingConfiguration = true
        errorMessage = nil
        statusMessage = nil

        defer {
            isSavingConfiguration = false
        }

        do {
            let configuration = try buildConfiguration()
            _ = try await aiService.updateProviderConfiguration(configuration)
            statusMessage = String(
                localized: "developer.playground.ai_provider_configuration.status.configuration_saved",
                defaultValue: "Configuration saved."
            )
            logger.info(
                "Saved AI provider configuration from developer mode",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                metadata: ["active_provider": configuration.activeProviderID.rawValue]
            )
        } catch {
            errorMessage = error.localizedDescription
            logger.warn(
                "Failed to save AI provider configuration",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    func saveCredentials() async {
        if isSavingCredentials {
            return
        }
        isSavingCredentials = true
        errorMessage = nil
        statusMessage = nil

        defer {
            isSavingCredentials = false
        }

        do {
            try await aiService.saveToken(normalizedToken(openAITokenInput), for: .openAI)
            try await aiService.saveToken(normalizedToken(claudeTokenInput), for: .claude)
            try await aiService.saveToken(normalizedToken(geminiTokenInput), for: .gemini)
            try await aiService.saveToken(normalizedToken(ollamaTokenInput), for: .ollama)

            openAITokenInput = ""
            claudeTokenInput = ""
            geminiTokenInput = ""
            ollamaTokenInput = ""

            await refreshTokenFlags()

            statusMessage = String(
                localized: "developer.playground.ai_provider_configuration.status.credentials_saved",
                defaultValue: "Provider credentials saved."
            )
            logger.info(
                "Saved AI provider credentials from developer mode",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel"
            )
        } catch {
            errorMessage = error.localizedDescription
            logger.warn(
                "Failed to save AI provider credentials",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    func runChecks() async {
        if isRunningChecks {
            return
        }

        let normalizedPrompt = checkPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPrompt.isEmpty == false else {
            errorMessage = String(
                localized: "developer.playground.ai_provider_configuration.error.prompt_required",
                defaultValue: "Prompt is required."
            )
            statusMessage = nil
            return
        }

        isRunningChecks = true
        errorMessage = nil
        statusMessage = nil
        checkSummaryOutput = ""
        checkCategoryOutput = ""
        checkTagsOutput = ""

        let requestID = "debug-ai-check-\(UUID().uuidString.lowercased())"

        logger.info(
            "Running AI provider checks from developer mode",
            category: .ui,
            service: "DeveloperAIProviderSettingsViewModel",
            requestID: requestID,
            metadata: ["prompt_length": "\(normalizedPrompt.count)"]
        )

        defer {
            isRunningChecks = false
        }

        do {
            let summary = try await aiService.summarizeArticle(normalizedPrompt, requestID: requestID)
            let category = try await aiService.categorizeArticle(normalizedPrompt, requestID: requestID)
            let tags = try await aiService.generateTags(normalizedPrompt, requestID: requestID)

            checkSummaryOutput = summary.shortSummary + "\n\n• " + summary.bullets.joined(separator: "\n• ")
            checkCategoryOutput = category.category
            checkTagsOutput = tags.joined(separator: ", ")
            statusMessage = String(
                localized: "developer.playground.ai_provider_configuration.status.checks_completed",
                defaultValue: "AI checks completed."
            )

            logger.info(
                "AI provider checks completed from developer mode",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                requestID: requestID,
                metadata: [
                    "bullets": "\(summary.bullets.count)",
                    "tags": "\(tags.count)"
                ]
            )
        } catch {
            errorMessage = error.localizedDescription
            logger.warn(
                "AI provider checks failed from developer mode",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                requestID: requestID,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func apply(configuration: AIProviderConfiguration) {
        activeProviderID = configuration.activeProviderID
        openAIModel = configuration.model(for: .openAI)
        claudeModel = configuration.model(for: .claude)
        geminiModel = configuration.model(for: .gemini)
        ollamaModel = configuration.model(for: .ollama)
        ollamaEndpoint = configuration.ollamaEndpoint
        timeoutSecondsText = formattedTimeout(configuration.timeoutSeconds)
    }

    private func buildConfiguration() throws -> AIProviderConfiguration {
        guard let timeoutSeconds = Double(timeoutSecondsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              timeoutSeconds > 0 else {
            throw AIServiceError.invalidConfiguration(
                String(
                    localized: "developer.playground.ai_provider_configuration.error.timeout_positive",
                    defaultValue: "Timeout must be a positive number."
                )
            )
        }

        var configuration = AIProviderConfiguration(
            activeProviderID: activeProviderID,
            modelByProvider: [:],
            ollamaEndpoint: ollamaEndpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            timeoutSeconds: timeoutSeconds
        )
        configuration.setModel(openAIModel, for: .openAI)
        configuration.setModel(claudeModel, for: .claude)
        configuration.setModel(geminiModel, for: .gemini)
        configuration.setModel(ollamaModel, for: .ollama)
        return configuration
    }

    private func refreshTokenFlags() async {
        hasOpenAIToken = (try? await aiService.loadToken(for: .openAI))?.isEmpty == false
        hasClaudeToken = (try? await aiService.loadToken(for: .claude))?.isEmpty == false
        hasGeminiToken = (try? await aiService.loadToken(for: .gemini))?.isEmpty == false
        hasOllamaToken = (try? await aiService.loadToken(for: .ollama))?.isEmpty == false
    }

    private func normalizedToken(_ token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formattedTimeout(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(value)
    }
}
