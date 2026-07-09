//
//  GeminiProvider.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct GeminiProvider: AIProvider {
    nonisolated let id: AIProviderID = .gemini

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
            service: "GeminiProvider",
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
            service: "GeminiProvider",
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
            service: "GeminiProvider",
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

    nonisolated func groupHeadlines(_ headlines: String, requestID: String?) async throws -> [[String]] {
        logger.debug(
            "Running headline grouping operation",
            category: .business,
            service: "GeminiProvider",
            requestID: requestID,
            metadata: [
                "provider": id.rawValue,
                "model": model
            ]
        )

        let output = try await runPrompt(
            prompt: AIPromptBuilder.headlineGroupingPrompt(for: headlines),
            requestID: requestID
        )
        return try AIProviderSupport.normalizedHeadlineGroups(from: output)
    }

    nonisolated private func runPrompt(
        prompt: String,
        requestID: String?
    ) async throws -> [String: Any] {
        guard model.isEmpty == false else {
            throw AIProviderError.invalidConfiguration("Gemini model is required.")
        }
        guard token.isEmpty == false else {
            throw AIProviderError.invalidConfiguration("Gemini token is required.")
        }
        guard timeoutSeconds > 0 else {
            throw AIProviderError.invalidConfiguration("Gemini timeout must be greater than zero.")
        }

        let escapedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        let endpointValue = "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent?key=\(token)"
        let endpoint = try AIProviderSupport.validatedURL(from: endpointValue)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": "You are a strict JSON generator. Return only valid JSON.\n\n\(prompt)"
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0
            ]
        ]
        request.httpBody = try AIProviderSupport.encodeJSONBody(body)

        let data = try await AIProviderSupport.performRequest(
            request,
            requestID: requestID,
            service: "GeminiProvider",
            logger: logger,
            performRequest: performRequest
        )
        let responseObject = try AIProviderSupport.decodeJSONObject(from: data)
        let text = try extractedText(from: responseObject)
        return try AIProviderSupport.parseJSONObjectString(from: text)
    }

    nonisolated private func extractedText(from object: [String: Any]) throws -> String {
        guard let candidates = object["candidates"] as? [[String: Any]], let first = candidates.first else {
            throw AIProviderError.unsupportedResponse("Missing candidates in Gemini response.")
        }

        guard let content = first["content"] as? [String: Any] else {
            throw AIProviderError.unsupportedResponse("Missing content block in Gemini response.")
        }

        guard let parts = content["parts"] as? [[String: Any]], parts.isEmpty == false else {
            throw AIProviderError.unsupportedResponse("Missing parts in Gemini response content.")
        }

        let text = parts.compactMap { part in
            part["text"] as? String
        }.joined(separator: "\n")

        guard text.isEmpty == false else {
            throw AIProviderError.unsupportedResponse("Gemini response parts were empty.")
        }

        return text
    }
}
