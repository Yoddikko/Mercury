//
//  AIService.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct AIProviderRuntimeContext: Sendable {
    let providerID: AIProviderID
    let model: String
    let token: String?
    let ollamaEndpoint: String
    let timeoutSeconds: Double
    let logger: AppLogger
}

typealias AIProviderFactory = @Sendable (AIProviderRuntimeContext) throws -> any AIProvider

actor AIService {
    private let configurationStore: AIProviderConfigurationStore
    private let credentialStore: AIProviderCredentialStore
    private let logger: AppLogger
    private let providerFactory: AIProviderFactory

    init(
        configurationStore: AIProviderConfigurationStore = UserDefaultsAIProviderConfigurationStore(),
        credentialStore: AIProviderCredentialStore = KeychainAIProviderCredentialStore(),
        logger: AppLogger = .shared,
        providerFactory: @escaping AIProviderFactory = AIService.defaultProviderFactory
    ) {
        self.configurationStore = configurationStore
        self.credentialStore = credentialStore
        self.logger = logger
        self.providerFactory = providerFactory
    }

    func loadProviderConfiguration() -> AIProviderConfiguration {
        let configuration = configurationStore.loadConfiguration()
        logger.trace(
            "Loaded provider configuration",
            category: .system,
            service: "AIService",
            metadata: [
                "active_provider": configuration.activeProviderID.rawValue
            ]
        )
        return configuration
    }

    @discardableResult
    func updateProviderConfiguration(_ configuration: AIProviderConfiguration) throws -> AIProviderConfiguration {
        try validateCompleteConfiguration(configuration)
        do {
            try configurationStore.saveConfiguration(configuration)
            logger.info(
                "Saved provider configuration",
                category: .system,
                service: "AIService",
                metadata: [
                    "active_provider": configuration.activeProviderID.rawValue,
                    "timeout_seconds": "\(configuration.timeoutSeconds)"
                ]
            )
            return configuration
        } catch {
            logger.error(
                "Failed to save provider configuration",
                category: .system,
                service: "AIService",
                metadata: ["error": error.localizedDescription]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    @discardableResult
    func setActiveProvider(_ providerID: AIProviderID) throws -> AIProviderConfiguration {
        var configuration = configurationStore.loadConfiguration()
        configuration.activeProviderID = providerID
        try validateModelPresence(for: providerID, configuration: configuration)
        try validateTimeout(configuration.timeoutSeconds)
        if providerID == .ollama {
            _ = try AIProviderSupport.validatedURL(from: configuration.ollamaEndpoint, allowHTTP: true)
        }

        do {
            try configurationStore.saveConfiguration(configuration)
            logger.info(
                "Updated active provider",
                category: .system,
                service: "AIService",
                metadata: ["active_provider": providerID.rawValue]
            )
            return configuration
        } catch {
            logger.error(
                "Failed to update active provider",
                category: .system,
                service: "AIService",
                metadata: [
                    "active_provider": providerID.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    func saveToken(_ token: String?, for providerID: AIProviderID) throws {
        do {
            try credentialStore.saveToken(token, for: providerID)
            logger.info(
                "Saved provider token",
                category: .security,
                service: "AIService",
                metadata: [
                    "provider": providerID.rawValue,
                    "has_token": token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? "true"
                        : "false"
                ]
            )
        } catch {
            logger.error(
                "Failed to save provider token",
                category: .security,
                service: "AIService",
                metadata: [
                    "provider": providerID.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    func loadToken(for providerID: AIProviderID) throws -> String? {
        do {
            let token = try credentialStore.loadToken(for: providerID)
            logger.trace(
                "Loaded provider token state",
                category: .security,
                service: "AIService",
                metadata: [
                    "provider": providerID.rawValue,
                    "has_token": token?.isEmpty == false ? "true" : "false"
                ]
            )
            return token
        } catch {
            logger.error(
                "Failed to load provider token",
                category: .security,
                service: "AIService",
                metadata: [
                    "provider": providerID.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    func summarizeArticle(_ content: String, requestID: String? = nil) async throws -> AISummaryResult {
        let flowRequestID = requestID ?? Self.generateRequestID(prefix: "ai-summary")
        let provider = try resolveActiveProvider(requestID: flowRequestID)
        do {
            let result = try await provider.summarizeArticle(content, requestID: flowRequestID)
            logger.info(
                "Summary operation completed",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "bullets": "\(result.bullets.count)"
                ]
            )
            return result
        } catch let error as AIProviderError {
            logger.warn(
                "Summary operation failed",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.providerFailure(provider.id, error)
        } catch {
            logger.error(
                "Summary operation failed with unexpected error",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    func categorizeArticle(_ content: String, requestID: String? = nil) async throws -> AICategoryResult {
        let flowRequestID = requestID ?? Self.generateRequestID(prefix: "ai-category")
        let provider = try resolveActiveProvider(requestID: flowRequestID)
        do {
            let result = try await provider.categorizeArticle(content, requestID: flowRequestID)
            logger.info(
                "Category operation completed",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "category": result.category
                ]
            )
            return result
        } catch let error as AIProviderError {
            logger.warn(
                "Category operation failed",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.providerFailure(provider.id, error)
        } catch {
            logger.error(
                "Category operation failed with unexpected error",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    func generateTags(_ content: String, requestID: String? = nil) async throws -> [String] {
        let flowRequestID = requestID ?? Self.generateRequestID(prefix: "ai-tags")
        let provider = try resolveActiveProvider(requestID: flowRequestID)
        do {
            let tags = try await provider.generateTags(content, requestID: flowRequestID)
            logger.info(
                "Tag operation completed",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "tags": "\(tags.count)"
                ]
            )
            return tags
        } catch let error as AIProviderError {
            logger.warn(
                "Tag operation failed",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.providerFailure(provider.id, error)
        } catch {
            logger.error(
                "Tag operation failed with unexpected error",
                category: .business,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    private func resolveActiveProvider(requestID: String?) throws -> any AIProvider {
        let configuration = configurationStore.loadConfiguration()
        let providerID = configuration.activeProviderID
        try validateTimeout(configuration.timeoutSeconds)
        try validateModelPresence(for: providerID, configuration: configuration)
        if providerID == .ollama {
            _ = try AIProviderSupport.validatedURL(from: configuration.ollamaEndpoint, allowHTTP: true)
        }

        let model = configuration.model(for: providerID)
        let token: String?
        do {
            token = try credentialStore.loadToken(for: providerID)
        } catch {
            throw AIServiceError.unknown(error.localizedDescription)
        }

        if providerID.requiresToken, token?.isEmpty != false {
            logger.warn(
                "Active provider missing token",
                category: .security,
                service: "AIService",
                requestID: requestID,
                metadata: ["provider": providerID.rawValue]
            )
            throw AIServiceError.missingToken(providerID)
        }

        let context = AIProviderRuntimeContext(
            providerID: providerID,
            model: model,
            token: token,
            ollamaEndpoint: configuration.ollamaEndpoint,
            timeoutSeconds: configuration.timeoutSeconds,
            logger: logger
        )

        do {
            let provider = try providerFactory(context)
            logger.trace(
                "Resolved active provider",
                category: .system,
                service: "AIService",
                requestID: requestID,
                metadata: [
                    "provider": provider.id.rawValue,
                    "model": model
                ]
            )
            return provider
        } catch let error as AIProviderError {
            throw AIServiceError.providerFailure(providerID, error)
        } catch {
            throw AIServiceError.unknown(error.localizedDescription)
        }
    }

    private func validateCompleteConfiguration(_ configuration: AIProviderConfiguration) throws {
        try validateTimeout(configuration.timeoutSeconds)
        _ = try AIProviderSupport.validatedURL(from: configuration.ollamaEndpoint, allowHTTP: true)
        for providerID in AIProviderID.allCases {
            try validateModelPresence(for: providerID, configuration: configuration)
        }
    }

    private func validateModelPresence(
        for providerID: AIProviderID,
        configuration: AIProviderConfiguration
    ) throws {
        let model = configuration.model(for: providerID)
        guard model.isEmpty == false else {
            throw AIServiceError.invalidConfiguration("Model is required for provider \(providerID.displayName).")
        }
    }

    private func validateTimeout(_ timeoutSeconds: Double) throws {
        guard timeoutSeconds > 0 else {
            throw AIServiceError.invalidConfiguration("Timeout must be greater than zero.")
        }
    }

    private static func defaultProviderFactory(context: AIProviderRuntimeContext) throws -> any AIProvider {
        switch context.providerID {
        case .openAI:
            return OpenAIProvider(
                model: context.model,
                token: context.token ?? "",
                timeoutSeconds: context.timeoutSeconds,
                logger: context.logger
            )
        case .claude:
            return ClaudeProvider(
                model: context.model,
                token: context.token ?? "",
                timeoutSeconds: context.timeoutSeconds,
                logger: context.logger
            )
        case .gemini:
            return GeminiProvider(
                model: context.model,
                token: context.token ?? "",
                timeoutSeconds: context.timeoutSeconds,
                logger: context.logger
            )
        case .ollama:
            return OllamaProvider(
                model: context.model,
                token: context.token,
                endpoint: context.ollamaEndpoint,
                timeoutSeconds: context.timeoutSeconds,
                logger: context.logger
            )
        }
    }

    private static func generateRequestID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.lowercased())"
    }
}

