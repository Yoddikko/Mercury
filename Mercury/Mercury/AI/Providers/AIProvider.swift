//
//  AIProvider.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

protocol AIProvider: Sendable {
    var id: AIProviderID { get }

    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult
    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult
    func generateTags(_ content: String, requestID: String?) async throws -> [String]
}
