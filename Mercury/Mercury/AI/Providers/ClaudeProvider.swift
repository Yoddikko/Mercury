//
//  ClaudeProvider.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct ClaudeProvider: AIProvider {
    nonisolated let id: AIProviderID = .claude

    private let model: String
    private let token: String
    private let timeoutSeconds: Double
    private let logger: AppLogger
    private let performRequest: AIProviderRequestExecutor

    nonisolated init(
        model: String,
        token: String,
        timeoutSeconds: Double,
        logger: AppLogger = .shared,
        performRequest: @escaping AIProviderRequestExecutor = AIProviderSupport.providerRequestExecutor()
    ) {
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeoutSeconds = timeoutSeconds
        self.logger = logger
        self.performRequest = performRequest
    }

    nonisolated func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult {
        logger.debug(
            "Running summary operation",
            category: .business,
            service: "ClaudeProvider",
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

    nonisolated func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult {
        logger.debug(
            "Running category operation",
            category: .business,
            service: "ClaudeProvider",
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

    nonisolated func generateTags(_ content: String, requestID: String?) async throws -> [String] {
        logger.debug(
            "Running tag generation operation",
            category: .business,
            service: "ClaudeProvider",
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

    nonisolated private func runPrompt(
        prompt: String,
        requestID: String?
    ) async throws -> [String: Any] {
        guard model.isEmpty == false else {
            throw AIProviderError.invalidConfiguration("Claude model is required.")
        }
        guard token.isEmpty == false else {
            throw AIProviderError.invalidConfiguration("Claude token is required.")
        }
        guard timeoutSeconds > 0 else {
            throw AIProviderError.invalidConfiguration("Claude timeout must be greater than zero.")
        }

        let endpoint = try AIProviderSupport.validatedURL(from: "https://api.anthropic.com/v1/messages")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": 1_024,
            "system": "You are a strict JSON generator. Return only valid JSON.",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        request.httpBody = try AIProviderSupport.encodeJSONBody(body)

        let data = try await AIProviderSupport.performRequest(
            request,
            requestID: requestID,
            service: "ClaudeProvider",
            logger: logger,
            performRequest: performRequest
        )
        let responseObject = try AIProviderSupport.decodeJSONObject(from: data)
        let text = try extractedText(from: responseObject)
        return try AIProviderSupport.parseJSONObjectString(from: text)
    }

    nonisolated private func extractedText(from object: [String: Any]) throws -> String {
        guard let content = object["content"] as? [[String: Any]], content.isEmpty == false else {
            throw AIProviderError.unsupportedResponse("Missing content blocks in Claude response.")
        }

        let textParts = content.compactMap { item in
            item["text"] as? String
        }
        let joined = textParts.joined(separator: "\n")
        guard joined.isEmpty == false else {
            throw AIProviderError.unsupportedResponse("Claude response text blocks were empty.")
        }
        return joined
    }
}
