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
    private let performRequest: AIProviderRequestExecutor

    init(
        configurationStore: AIProviderConfigurationStore = UserDefaultsAIProviderConfigurationStore(),
        credentialStore: AIProviderCredentialStore = KeychainAIProviderCredentialStore(),
        logger: AppLogger = .shared,
        providerFactory: @escaping AIProviderFactory = AIService.defaultProviderFactory,
        performRequest: @escaping AIProviderRequestExecutor = AIProviderSupport.providerRequestExecutor()
    ) {
        self.configurationStore = configurationStore
        self.credentialStore = credentialStore
        self.logger = logger
        self.providerFactory = providerFactory
        self.performRequest = performRequest
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

    func fetchAvailableModels(
        for providerID: AIProviderID,
        tokenOverride: String? = nil,
        requestID: String? = nil
    ) async throws -> [String] {
        let flowRequestID = requestID ?? Self.generateRequestID(prefix: "ai-models")
        let configuration = configurationStore.loadConfiguration()
        try validateTimeout(configuration.timeoutSeconds)

        let token = resolvedToken(for: providerID, tokenOverride: tokenOverride)
        if providerID.requiresToken, token == nil {
            logger.warn(
                "Model fetch blocked because token is missing",
                category: .security,
                service: "AIService",
                requestID: flowRequestID,
                metadata: ["provider": providerID.rawValue]
            )
            throw AIServiceError.missingToken(providerID)
        }

        let request = try buildModelListRequest(
            for: providerID,
            token: token,
            configuration: configuration
        )

        do {
            let data = try await AIProviderSupport.performRequest(
                request,
                requestID: flowRequestID,
                service: "AIService",
                logger: logger,
                performRequest: performRequest
            )
            let models = try parseModelListResponse(data, for: providerID)
            guard models.isEmpty == false else {
                throw AIProviderError.unsupportedResponse("Provider returned no models.")
            }

            logger.info(
                "Fetched provider model list",
                category: .api,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": providerID.rawValue,
                    "models_count": "\(models.count)"
                ]
            )
            return models
        } catch let error as AIProviderError {
            logger.warn(
                "Failed to fetch provider model list",
                category: .api,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": providerID.rawValue,
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.providerFailure(providerID, error)
        } catch let error as AIServiceError {
            throw error
        } catch {
            logger.error(
                "Unexpected failure while fetching model list",
                category: .api,
                service: "AIService",
                requestID: flowRequestID,
                metadata: [
                    "provider": providerID.rawValue,
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

    private func resolvedToken(
        for providerID: AIProviderID,
        tokenOverride: String?
    ) -> String? {
        if let tokenOverride {
            let normalized = tokenOverride.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty == false {
                return normalized
            }
        }

        do {
            let stored = try credentialStore.loadToken(for: providerID)
            let normalized = stored?.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized?.isEmpty == false ? normalized : nil
        } catch {
            logger.error(
                "Failed to load token while fetching model list",
                category: .security,
                service: "AIService",
                metadata: [
                    "provider": providerID.rawValue,
                    "error": error.localizedDescription
                ]
            )
            return nil
        }
    }

    private func buildModelListRequest(
        for providerID: AIProviderID,
        token: String?,
        configuration: AIProviderConfiguration
    ) throws -> URLRequest {
        switch providerID {
        case .openAI:
            guard let token else {
                throw AIServiceError.missingToken(.openAI)
            }
            let endpoint = try AIProviderSupport.validatedURL(from: "https://api.openai.com/v1/models")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.timeoutSeconds
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return request
        case .claude:
            guard let token else {
                throw AIServiceError.missingToken(.claude)
            }
            let endpoint = try AIProviderSupport.validatedURL(from: "https://api.anthropic.com/v1/models")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.timeoutSeconds
            request.setValue(token, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            return request
        case .gemini:
            guard let token else {
                throw AIServiceError.missingToken(.gemini)
            }
            var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
            components?.queryItems = [
                URLQueryItem(name: "key", value: token)
            ]
            guard let url = components?.url else {
                throw AIProviderError.invalidEndpoint("https://generativelanguage.googleapis.com/v1beta/models")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.timeoutSeconds
            return request
        case .ollama:
            let endpoint = try AIProviderSupport.validatedURL(from: configuration.ollamaEndpoint, allowHTTP: true)
            let url = endpoint
                .appendingPathComponent("api", isDirectory: true)
                .appendingPathComponent("tags", isDirectory: false)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.timeoutSeconds
            if let token, token.isEmpty == false {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return request
        }
    }

    private func parseModelListResponse(_ data: Data, for providerID: AIProviderID) throws -> [String] {
        let object = try AIProviderSupport.decodeJSONObject(from: data)

        switch providerID {
        case .openAI:
            let rows = object["data"] as? [[String: Any]] ?? []
            let models = rows.compactMap { row in
                Self.normalizedModelIdentifier(row["id"] as? String)
            }
            return Self.uniqueSortedModels(models)
        case .claude:
            let rows = object["data"] as? [[String: Any]] ?? []
            let models = rows.compactMap { row in
                Self.normalizedModelIdentifier(row["id"] as? String)
            }
            return Self.uniqueSortedModels(models)
        case .gemini:
            let rows = object["models"] as? [[String: Any]] ?? []
            let models = rows.compactMap { row -> String? in
                let methods = row["supportedGenerationMethods"] as? [String] ?? []
                if methods.isEmpty == false, methods.contains("generateContent") == false {
                    return nil
                }
                return Self.normalizedGeminiModelIdentifier(row["name"] as? String)
            }
            return Self.uniqueSortedModels(models)
        case .ollama:
            let rows = object["models"] as? [[String: Any]] ?? []
            let models = rows.compactMap { row in
                Self.normalizedModelIdentifier(row["name"] as? String)
            }
            return Self.uniqueSortedModels(models)
        }
    }

    private static func normalizedModelIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedGeminiModelIdentifier(_ value: String?) -> String? {
        guard let value = normalizedModelIdentifier(value) else { return nil }
        if value.hasPrefix("models/") {
            let candidate = String(value.dropFirst("models/".count))
            return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private static func uniqueSortedModels(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        output.reserveCapacity(values.count)

        for value in values {
            let key = value.lowercased()
            guard seen.contains(key) == false else { continue }
            seen.insert(key)
            output.append(value)
        }

        return output.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}
