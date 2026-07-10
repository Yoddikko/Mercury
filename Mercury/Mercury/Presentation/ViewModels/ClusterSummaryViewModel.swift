//
//  ClusterSummaryViewModel.swift
//  Mercury
//
//  Created by Claude on 10/07/26.
//

import Combine
import Foundation

/// Drives the "AI story summary" section of the topic cluster screen
/// (issue #129): combines every article of the story into one input
/// (source + title + best available text, truncated) and asks the
/// provider for a single synthesis. On-demand only, like the article
/// summary; the result lives in memory for the screen's lifetime.
@MainActor
final class ClusterSummaryViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case summarizing
        case ready(AISummaryResult)
        case failed(String)
    }

    /// Seam for tests: production wires `AIService.summarizeArticle`,
    /// which injects the user's summary-language preference.
    typealias Summarize = @Sendable (_ content: String, _ requestID: String) async throws -> AISummaryResult

    @Published private(set) var state: State = .idle

    /// Per-article text budget: enough to carry each outlet's angle
    /// without blowing up the prompt on 10-article stories.
    static let perArticleCharacterBudget = 1_200
    /// Global input cap across all articles.
    static let totalCharacterBudget = 10_000

    private let summarize: Summarize
    private let logger: AppLogger

    init(
        summarize: Summarize? = nil,
        logger: AppLogger = .shared
    ) {
        self.summarize = summarize ?? { content, requestID in
            try await AIService().summarizeArticle(content, requestID: requestID)
        }
        self.logger = logger
    }

    /// User-initiated: summarize the whole story. `force` regenerates
    /// past a ready result.
    func requestSummary(for cluster: TopicCluster, force: Bool = false) async {
        if case .summarizing = state { return }
        if force == false, case .ready = state { return }

        let requestID = "story-summary-\(UUID().uuidString.lowercased())"
        state = .summarizing
        logger.info(
            "Story summary requested",
            category: .ui,
            service: "ClusterSummaryViewModel",
            requestID: requestID,
            metadata: [
                "cluster_id": cluster.id,
                "articles": "\(cluster.members.count + 1)",
                "force": "\(force)"
            ]
        )

        let input = Self.storyInput(for: cluster)
        do {
            let result = try await summarize(input, requestID)
            state = .ready(result)
            logger.info(
                "Story summary completed",
                category: .ui,
                service: "ClusterSummaryViewModel",
                requestID: requestID,
                metadata: ["bullets": "\(result.bullets.count)"]
            )
        } catch {
            state = .failed(error.localizedDescription)
            logger.warn(
                "Story summary failed",
                category: .ui,
                service: "ClusterSummaryViewModel",
                requestID: requestID,
                metadata: ["error": String(describing: error)]
            )
        }
    }

    /// One block per article — source, title, best available text —
    /// so the model can merge the outlets' angles into one synthesis.
    nonisolated static func storyInput(for cluster: TopicCluster) -> String {
        var blocks: [String] = []
        var remaining = totalCharacterBudget
        for article in [cluster.lead] + cluster.members {
            guard remaining > 0 else { break }
            let bestText = article.cleanedContent ?? article.summaryShort ?? ""
            let body = String(bestText.prefix(min(perArticleCharacterBudget, remaining)))
            let block = """
            SOURCE: \(article.sourceName)
            TITLE: \(article.title)
            \(body)
            """
            blocks.append(block)
            remaining -= block.count
        }
        return blocks.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Localized copy

    var buttonLabel: String {
        String(
            localized: "topics.story_summary.button",
            defaultValue: "AI story summary"
        )
    }

    var loadingLabel: String {
        String(
            localized: "article.detail.ai_summary.loading",
            defaultValue: "Generating the AI summary…"
        )
    }

    var failedLabel: String {
        String(
            localized: "article.detail.ai_summary.failed",
            defaultValue: "The AI summary could not be generated right now. You can still read the article below."
        )
    }

    var regenerateLabel: String {
        String(
            localized: "article.detail.ai_summary.regenerate",
            defaultValue: "Regenerate"
        )
    }
}
