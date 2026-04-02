//
//  OllamaProvider.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct OllamaProvider: AIProvider {
    let id: AIProviderID = .ollama

    private let model: String
    private let token: String?
    private let endpoint: String
    private let timeoutSeconds: Double
    private let logger: AppLogger
    private let performRequest: AIProviderRequestExecutor

    init(
        model: String,
        token: String?,
        endpoint: String,
        timeoutSeconds: Double,
        logger: AppLogger = .shared,
        performRequest: @escaping AIProviderRequestExecutor = AIProviderSupport.providerRequestExecutor()
    ) {
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeoutSeconds = timeoutSeconds
        self.logger = logger
        self.performRequest = performRequest
    }

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        logger.debug(
            "Running summary operation",
            category: .business,
            service: "OllamaProvider",
            requestID: requestID,
            metadata: [
                "provider": id.rawValue,
                "model": model
            ]
        )

        let output = try await runPrompt(
            prompt: AIPromptBuilder.summaryPrompt(for: content),
            requestID: requestID
        )
        return try AIProviderSupport.normalizedSummary(from: output)
    }

    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        logger.debug(
            "Running category operation",
            category: .business,
            service: "OllamaProvider",
            requestID: requestID,
            metadata: [
                "provider": id.rawValue,
                "model": model
            ]
        )

        let output = try await runPrompt(
            prompt: AIPromptBuilder.categoryPrompt(for: content),
            requestID: requestID
        )
        return try AIProviderSupport.normalizedCategory(from: output)
    }

    func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        logger.debug(
            "Running tag generation operation",
            category: .business,
            service: "OllamaProvider",
            requestID: requestID,
            metadata: [
                "provider": id.rawValue,
                "model": model
            ]
        )

        let output = try await runPrompt(
            prompt: AIPromptBuilder.tagsPrompt(for: content),
            requestID: requestID
        )
        return try AIProviderSupport.normalizedTags(from: output)
    }

    private func runPrompt(
        prompt: String,
        requestID: String?
    ) async throws -> [String: Any] {
        guard model.isEmpty == false else {
            throw AIProviderError.invalidConfiguration("Ollama model is required.")
        }
        guard timeoutSeconds > 0 else {
            throw AIProviderError.invalidConfiguration("Ollama timeout must be greater than zero.")
        }

        let endpointURL = try AIProviderSupport.validatedURL(from: endpoint, allowHTTP: true)
        let generateEndpoint = endpointURL
            .appendingPathComponent("api", isDirectory: true)
            .appendingPathComponent("generate", isDirectory: false)

        var request = URLRequest(url: generateEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]
        request.httpBody = try AIProviderSupport.encodeJSONBody(body)

        let data = try await AIProviderSupport.performRequest(
            request,
            requestID: requestID,
            service: "OllamaProvider",
            logger: logger,
            performRequest: performRequest
        )
        let responseObject = try AIProviderSupport.decodeJSONObject(from: data)
        return try extractedJSONObject(from: responseObject)
    }

    private func extractedJSONObject(from object: [String: Any]) throws -> [String: Any] {
        if let responseObject = object["response"] as? [String: Any] {
            return responseObject
        }

        guard let responseText = object["response"] as? String else {
            throw AIProviderError.unsupportedResponse("Missing response field in Ollama payload.")
        }

        return try AIProviderSupport.parseJSONObjectString(from: responseText)
    }
}

