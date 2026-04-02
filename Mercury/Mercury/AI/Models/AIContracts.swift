//
//  AIContracts.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

enum AIProviderID: String, CaseIterable, Codable, Sendable, Identifiable {
    case openAI = "openai"
    case claude = "claude"
    case gemini = "gemini"
    case ollama = "ollama"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .claude:
            return "Claude"
        case .gemini:
            return "Gemini"
        case .ollama:
            return "Ollama"
        }
    }

    nonisolated var requiresToken: Bool {
        switch self {
        case .openAI, .claude, .gemini:
            return true
        case .ollama:
            return false
        }
    }
}

struct AISummaryResult: Sendable, Equatable {
    nonisolated let shortSummary: String
    nonisolated let bullets: [String]
}

struct AICategoryResult: Sendable, Equatable {
    nonisolated let category: String
}

typealias AITagsResult = [String]

struct AIProviderConfiguration: Sendable, Equatable, Codable {
    var activeProviderID: AIProviderID
    var modelByProvider: [AIProviderID: String]
    var ollamaEndpoint: String
    var timeoutSeconds: Double

    init(
        activeProviderID: AIProviderID = .openAI,
        modelByProvider: [AIProviderID: String] = [:],
        ollamaEndpoint: String = "http://localhost:11434",
        timeoutSeconds: Double = 20
    ) {
        self.activeProviderID = activeProviderID
        self.modelByProvider = modelByProvider
        self.ollamaEndpoint = ollamaEndpoint
        self.timeoutSeconds = timeoutSeconds
    }

    nonisolated func model(for providerID: AIProviderID) -> String {
        modelByProvider[providerID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    nonisolated mutating func setModel(_ model: String, for providerID: AIProviderID) {
        modelByProvider[providerID] = model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static var empty: AIProviderConfiguration { AIProviderConfiguration() }
}

enum AIProviderError: Error, Sendable, Equatable, LocalizedError {
    case invalidConfiguration(String)
    case invalidEndpoint(String)
    case unauthorized
    case timeout
    case rateLimited
    case httpStatusCode(Int)
    case invalidResponse
    case emptyResponse
    case parsingFailure(String)
    case networkFailure(String)
    case unsupportedResponse(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            return "Invalid provider configuration: \(message)"
        case let .invalidEndpoint(value):
            return "Invalid endpoint: \(value)"
        case .unauthorized:
            return "Unauthorized provider request."
        case .timeout:
            return "Provider request timed out."
        case .rateLimited:
            return "Provider request was rate-limited."
        case let .httpStatusCode(code):
            return "Provider request failed with HTTP status \(code)."
        case .invalidResponse:
            return "Provider response format was invalid."
        case .emptyResponse:
            return "Provider response was empty."
        case let .parsingFailure(message):
            return "Provider response parsing failed: \(message)"
        case let .networkFailure(message):
            return "Provider request failed: \(message)"
        case let .unsupportedResponse(message):
            return "Unsupported provider response: \(message)"
        }
    }
}

enum AIServiceError: Error, Sendable, Equatable, LocalizedError {
    case invalidConfiguration(String)
    case missingToken(AIProviderID)
    case providerFailure(AIProviderID, AIProviderError)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            return "AI service configuration invalid: \(message)"
        case let .missingToken(providerID):
            return "Missing API token for provider \(providerID.displayName)."
        case let .providerFailure(providerID, error):
            return "Provider \(providerID.displayName) failed: \(error.localizedDescription)"
        case let .unknown(message):
            return "AI service failed: \(message)"
        }
    }
}
