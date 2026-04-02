//
//  Article.swift
//  Mercury
//
//  Created by Codex on 31/03/26.
//

import Foundation

struct Article: Identifiable, Equatable, Sendable {
    let id: String
    let externalID: String?
    let title: String
    let sourceName: String
    let sourceURL: URL
    let articleURL: URL
    let publishedAt: Date
    let authorName: String?
    let heroImageURL: URL?
    let rawContent: String?
    let cleanedContent: String?
    let contentSource: String
    let contentWordCount: Int
    let isContentLikelyComplete: Bool
    let summaryShort: String?
    let summaryBullets: [String]
    let category: String?
    let tags: [String]
    let language: String?
    let isBookmarked: Bool
    let isRead: Bool
    let clusterID: String?
    let createdAt: Date
    let updatedAt: Date
}

extension Article {
    func updatingContent(
        rawContent: String?,
        cleanedContent: String?,
        contentSource: String,
        contentWordCount: Int,
        isContentLikelyComplete: Bool,
        heroImageURL: URL?,
        summaryShort: String?,
        updatedAt: Date
    ) -> Article {
        Article(
            id: id,
            externalID: externalID,
            title: title,
            sourceName: sourceName,
            sourceURL: sourceURL,
            articleURL: articleURL,
            publishedAt: publishedAt,
            authorName: authorName,
            heroImageURL: heroImageURL,
            rawContent: rawContent,
            cleanedContent: cleanedContent,
            contentSource: contentSource,
            contentWordCount: contentWordCount,
            isContentLikelyComplete: isContentLikelyComplete,
            summaryShort: summaryShort,
            summaryBullets: summaryBullets,
            category: category,
            tags: tags,
            language: language,
            isBookmarked: isBookmarked,
            isRead: isRead,
            clusterID: clusterID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static let previewFeed: [Article] = [
        Article(
            id: "mercury-preview-1",
            externalID: nil,
            title: "AI chip demand continues to reshape European tech spending",
            sourceName: "Tech Signal",
            sourceURL: URL(string: "https://example.com/tech-signal")!,
            articleURL: URL(string: "https://example.com/articles/ai-chip-demand")!,
            publishedAt: .now.addingTimeInterval(-1_800),
            authorName: "Mercury Desk",
            heroImageURL: URL(string: "https://images.example.com/ai-chip-demand.jpg"),
            rawContent: nil,
            cleanedContent: nil,
            contentSource: "preview",
            contentWordCount: 0,
            isContentLikelyComplete: false,
            summaryShort: "Hardware and cloud budgets are shifting toward AI infrastructure across the region.",
            summaryBullets: [
                "European buyers are prioritizing inference capacity.",
                "Cloud spend is moving from pilots to production workloads.",
                "Procurement timelines remain constrained by supply."
            ],
            category: "Technology",
            tags: ["AI", "Semiconductors", "Europe"],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: "cluster-ai-infra",
            createdAt: .now,
            updatedAt: .now
        ),
        Article(
            id: "mercury-preview-2",
            externalID: nil,
            title: "Election debate pushes economic policy back to the center of the news cycle",
            sourceName: "World Brief",
            sourceURL: URL(string: "https://example.com/world-brief")!,
            articleURL: URL(string: "https://example.com/articles/election-debate")!,
            publishedAt: .now.addingTimeInterval(-7_200),
            authorName: "Editorial Team",
            heroImageURL: URL(string: "https://images.example.com/election-debate.jpg"),
            rawContent: nil,
            cleanedContent: nil,
            contentSource: "preview",
            contentWordCount: 0,
            isContentLikelyComplete: false,
            summaryShort: "Candidates focused on inflation, wages, and industrial policy in the latest debate.",
            summaryBullets: [
                "Inflation and cost-of-living pressure dominated exchanges.",
                "Manufacturing policy remained a dividing line.",
                "Markets reacted mainly to tax and spending signals."
            ],
            category: "Politics",
            tags: ["Elections", "Economy", "Policy"],
            language: "en",
            isBookmarked: true,
            isRead: true,
            clusterID: "cluster-election-debate",
            createdAt: .now,
            updatedAt: .now
        ),
        Article(
            id: "mercury-preview-3",
            externalID: nil,
            title: "Researchers publish new climate adaptation framework for major cities",
            sourceName: "Science Desk",
            sourceURL: URL(string: "https://example.com/science-desk")!,
            articleURL: URL(string: "https://example.com/articles/climate-adaptation")!,
            publishedAt: .now.addingTimeInterval(-14_400),
            authorName: "Research Correspondent",
            heroImageURL: URL(string: "https://images.example.com/climate-adaptation.jpg"),
            rawContent: nil,
            cleanedContent: nil,
            contentSource: "preview",
            contentWordCount: 0,
            isContentLikelyComplete: false,
            summaryShort: "The framework ranks urban adaptation actions by urgency, cost, and resilience impact.",
            summaryBullets: [
                "The study compares transport, housing, and water-system adaptation.",
                "Cities are encouraged to prioritize resilience by district.",
                "The methodology is designed for repeated local updates."
            ],
            category: "Science",
            tags: ["Climate", "Cities", "Resilience"],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: .now,
            updatedAt: .now
        )
    ]
}
