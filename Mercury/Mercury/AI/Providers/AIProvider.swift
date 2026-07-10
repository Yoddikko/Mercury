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
    /// Ranks `id<TAB>title` headline lines against the reader's
    /// interests; returns validated picks (issue #133).
    nonisolated func pickHeadlines(_ prompt: String, requestID: String?) async throws -> [AIHeadlinePick]
}

extension AIProvider {
    /// Default: grouping unsupported — callers fall back to the
    /// on-device lexical aggregation. All five shipping providers
    /// override this; the default keeps test doubles and future
    /// providers compiling with graceful degradation.
    nonisolated func groupHeadlines(_ headlines: String, requestID: String?) async throws -> [[String]] {
        throw AIProviderError.parsingFailure("Headline grouping not supported by \(id.rawValue).")
    }

    /// Default: personal picks unsupported — the "Per te" feed surfaces
    /// the failure honestly. All five shipping providers override this.
    nonisolated func pickHeadlines(_ prompt: String, requestID: String?) async throws -> [AIHeadlinePick] {
        throw AIProviderError.parsingFailure("Personal picks not supported by \(id.rawValue).")
    }
}
