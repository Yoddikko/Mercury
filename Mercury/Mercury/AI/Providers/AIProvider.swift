//
//  AIProvider.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

protocol AIProvider: Sendable {
    nonisolated var id: AIProviderID { get }

    nonisolated func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult
    nonisolated func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult
    nonisolated func generateTags(_ content: String, requestID: String?) async throws -> [String]
}
