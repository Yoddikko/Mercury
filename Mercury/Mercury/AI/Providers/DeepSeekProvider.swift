//
//  DeepSeekProvider.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

import Foundation

/// AI provider for DeepSeek (https://api.deepseek.com).
///
/// DeepSeek exposes an OpenAI-compatible chat completions API, so the request
/// and response shapes mirror `OpenAIProvider`. Only the base URL and the
/// service tag differ.
struct DeepSeekProvider: AIProvider {
    nonisolated let id: AIProviderID = .deepSeek

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
            service: "DeepSeekProvider",
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
            service: "DeepSeekProvider",
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
            service: "DeepSeekProvider",
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
            service: "DeepSeekProvider",
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
            throw AIProviderError.invalidConfiguration("DeepSeek model is required.")
        }
        guard token.isEmpty == false else {
            throw AIProviderError.invalidConfiguration("DeepSeek token is required.")
        }
        guard timeoutSeconds > 0 else {
            throw AIProviderError.invalidConfiguration("DeepSeek timeout must be greater than zero.")
        }

        let endpoint = try AIProviderSupport.validatedURL(from: "https://api.deepseek.com/v1/chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            // Reasoning models spend the default output budget thinking
            // and can return an empty `content` (issue #125): give the
            // final answer explicit room.
            "max_tokens": 8_192,
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "system",
                    "content": "You are a strict JSON generator. Return only valid JSON."
                ],
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
            service: "DeepSeekProvider",
            logger: logger,
            performRequest: performRequest
        )
        let responseObject = try AIProviderSupport.decodeJSONObject(from: data)
        let text = try extractedText(from: responseObject)
        return try AIProviderSupport.parseJSONObjectString(from: text)
    }

    nonisolated private func extractedText(from object: [String: Any]) throws -> String {
        guard let choices = object["choices"] as? [[String: Any]], let first = choices.first else {
            throw AIProviderError.unsupportedResponse("Missing choices in DeepSeek response.")
        }

        guard let message = first["message"] as? [String: Any] else {
            throw AIProviderError.unsupportedResponse("Missing message object in DeepSeek response.")
        }

        if let content = message["content"] as? String {
            // Reasoning models (deepseek-reasoner, v4-pro) may leave
            // `content` empty and put the text in `reasoning_content`
            // (issue #125) — fall back before giving up.
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let reasoning = message["reasoning_content"] as? String,
               reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return reasoning
            }
            return content
        }

        if let parts = message["content"] as? [[String: Any]] {
            let combined = parts.compactMap { part in
                part["text"] as? String
            }
            let joined = combined.joined(separator: "\n")
            guard joined.isEmpty == false else {
                throw AIProviderError.unsupportedResponse("DeepSeek response content parts were empty.")
            }
            return joined
        }

        throw AIProviderError.unsupportedResponse("Unsupported DeepSeek content format.")
    }
}
