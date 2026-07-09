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
    /// Groups `id<TAB>title` headline lines by story; returns groups of
    /// article ids, singletons implied by omission (issue #113).
    nonisolated func groupHeadlines(_ headlines: String, requestID: String?) async throws -> [[String]]
}

extension AIProvider {
    /// Default: grouping unsupported — callers fall back to the
    /// on-device lexical aggregation. All five shipping providers
    /// override this; the default keeps test doubles and future
    /// providers compiling with graceful degradation.
    nonisolated func groupHeadlines(_ headlines: String, requestID: String?) async throws -> [[String]] {
        throw AIProviderError.parsingFailure("Headline grouping not supported by \(id.rawValue).")
    }
}
