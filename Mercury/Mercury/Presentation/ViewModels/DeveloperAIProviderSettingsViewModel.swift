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
    @Published var isFetchingModels = false
    @Published var isRunningChecks = false

    @Published var activeProviderID: AIProviderID = .openAI {
        didSet {
            syncAvailableModelsForActiveProvider()
            errorMessage = nil
            statusMessage = nil
        }
    }
    @Published var openAIModel = ""
    @Published var claudeModel = ""
    @Published var geminiModel = ""
    @Published var ollamaModel = ""
    @Published var availableModels: [String] = []
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
    private var modelCatalogByProvider: [AIProviderID: [String]] = [:]

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
        syncAvailableModelsForActiveProvider()

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
            syncAvailableModelsForActiveProvider()
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
        await saveActiveCredential()
    }

    func saveActiveCredential() async {
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
            let token = normalizedToken(activeTokenInput)
            try await aiService.saveToken(token, for: activeProviderID)
            clearActiveTokenInput()

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

    func fetchAvailableModelsForActiveProvider() async {
        if isFetchingModels {
            return
        }
        isFetchingModels = true
        errorMessage = nil
        statusMessage = nil

        defer {
            isFetchingModels = false
        }

        let providerID = activeProviderID
        let tokenOverride = normalizedToken(tokenInput(for: providerID))
        let requestID = "debug-ai-models-\(UUID().uuidString.lowercased())"

        logger.info(
            "Fetching model list for active provider",
            category: .ui,
            service: "DeveloperAIProviderSettingsViewModel",
            requestID: requestID,
            metadata: [
                "provider": providerID.rawValue,
                "has_token_override": tokenOverride == nil ? "false" : "true"
            ]
        )

        do {
            if tokenOverride != nil {
                try await aiService.saveToken(tokenOverride, for: providerID)
                clearTokenInput(for: providerID)
                await refreshTokenFlags()
            }

            let models = try await aiService.fetchAvailableModels(
                for: providerID,
                requestID: requestID
            )
            modelCatalogByProvider[providerID] = models

            let currentModel = model(for: providerID).trimmingCharacters(in: .whitespacesAndNewlines)
            if currentModel.isEmpty || models.contains(currentModel) == false {
                setModel(models.first ?? "", for: providerID)
            }
            syncAvailableModelsForActiveProvider()

            statusMessage = String(
                localized: "developer.playground.ai_provider_configuration.status.models_loaded",
                defaultValue: "Models loaded."
            )

            logger.info(
                "Fetched model list for active provider",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                requestID: requestID,
                metadata: [
                    "provider": providerID.rawValue,
                    "models_count": "\(models.count)"
                ]
            )
        } catch {
            errorMessage = error.localizedDescription
            logger.warn(
                "Failed to fetch model list for active provider",
                category: .ui,
                service: "DeveloperAIProviderSettingsViewModel",
                requestID: requestID,
                metadata: [
                    "provider": providerID.rawValue,
                    "error": error.localizedDescription
                ]
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
            let configuration = try buildConfiguration()
            _ = try await aiService.updateProviderConfiguration(configuration)

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
        guard let timeoutSeconds = parseTimeoutSeconds(timeoutSecondsText),
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

    private func parseTimeoutSeconds(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        let localizedFormatter = NumberFormatter()
        localizedFormatter.locale = .current
        localizedFormatter.numberStyle = .decimal
        if let localizedValue = localizedFormatter.number(from: trimmed)?.doubleValue {
            return localizedValue
        }

        let currentDecimalSeparator = localizedFormatter.decimalSeparator ?? "."
        let alternateSeparator = currentDecimalSeparator == "," ? "." : ","
        let normalizedForCurrentLocale = trimmed.replacingOccurrences(
            of: alternateSeparator,
            with: currentDecimalSeparator
        )
        if let normalizedValue = localizedFormatter.number(from: normalizedForCurrentLocale)?.doubleValue {
            return normalizedValue
        }

        let posixFormatter = NumberFormatter()
        posixFormatter.locale = Locale(identifier: "en_US_POSIX")
        posixFormatter.numberStyle = .decimal
        return posixFormatter.number(from: trimmed)?.doubleValue
    }

    private func refreshTokenFlags() async {
        hasOpenAIToken = (try? await aiService.loadToken(for: .openAI))?.isEmpty == false
        hasClaudeToken = (try? await aiService.loadToken(for: .claude))?.isEmpty == false
        hasGeminiToken = (try? await aiService.loadToken(for: .gemini))?.isEmpty == false
        hasOllamaToken = (try? await aiService.loadToken(for: .ollama))?.isEmpty == false
    }

    private func syncAvailableModelsForActiveProvider() {
        availableModels = modelCatalogByProvider[activeProviderID] ?? []
    }

    private func clearActiveTokenInput() {
        clearTokenInput(for: activeProviderID)
    }

    private func clearTokenInput(for providerID: AIProviderID) {
        switch providerID {
        case .openAI:
            openAITokenInput = ""
        case .claude:
            claudeTokenInput = ""
        case .gemini:
            geminiTokenInput = ""
        case .ollama:
            ollamaTokenInput = ""
        }
    }

    private func tokenInput(for providerID: AIProviderID) -> String {
        switch providerID {
        case .openAI:
            openAITokenInput
        case .claude:
            claudeTokenInput
        case .gemini:
            geminiTokenInput
        case .ollama:
            ollamaTokenInput
        }
    }

    private func model(for providerID: AIProviderID) -> String {
        switch providerID {
        case .openAI:
            openAIModel
        case .claude:
            claudeModel
        case .gemini:
            geminiModel
        case .ollama:
            ollamaModel
        }
    }

    private func setModel(_ model: String, for providerID: AIProviderID) {
        switch providerID {
        case .openAI:
            openAIModel = model
        case .claude:
            claudeModel = model
        case .gemini:
            geminiModel = model
        case .ollama:
            ollamaModel = model
        }
    }

    var activeModel: String {
        get {
            switch activeProviderID {
            case .openAI:
                return openAIModel
            case .claude:
                return claudeModel
            case .gemini:
                return geminiModel
            case .ollama:
                return ollamaModel
            }
        }
        set {
            switch activeProviderID {
            case .openAI:
                openAIModel = newValue
            case .claude:
                claudeModel = newValue
            case .gemini:
                geminiModel = newValue
            case .ollama:
                ollamaModel = newValue
            }
        }
    }

    var activeTokenInput: String {
        get {
            switch activeProviderID {
            case .openAI:
                return openAITokenInput
            case .claude:
                return claudeTokenInput
            case .gemini:
                return geminiTokenInput
            case .ollama:
                return ollamaTokenInput
            }
        }
        set {
            switch activeProviderID {
            case .openAI:
                openAITokenInput = newValue
            case .claude:
                claudeTokenInput = newValue
            case .gemini:
                geminiTokenInput = newValue
            case .ollama:
                ollamaTokenInput = newValue
            }
        }
    }

    var hasActiveToken: Bool {
        switch activeProviderID {
        case .openAI:
            return hasOpenAIToken
        case .claude:
            return hasClaudeToken
        case .gemini:
            return hasGeminiToken
        case .ollama:
            return hasOllamaToken
        }
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
