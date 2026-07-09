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
    /// Stable `RSSFeedSource.id` of the outlet that produced this article,
    /// stamped by `ArticleNormalizer` at ingest (issue #94). `nil` for
    /// legacy cached rows persisted before the field existed.
    let sourceID: String?
    let sourceURL: URL
    let articleURL: URL
    let publishedAt: Date
    let authorName: String?
    let heroImageURL: URL?
    let rawContent: String?
    let cleanedContent: String?
    /// Cleaned article body produced by the content distillation pipeline
    /// (issue #66 / spec PR #65). Renderers prefer this over `rawContent`.
    let distilledBodyHTML: String?
    /// Distiller algorithm version that produced `distilledBodyHTML`.
    let distillerVersion: Int?
    let contentSource: String
    let contentWordCount: Int
    let isContentLikelyComplete: Bool
    let summaryShort: String?
    let summaryBullets: [String]
    /// AI-generated summary written only by the user-triggered
    /// summarization flow (issue #100); `summaryShort` is the RSS/excerpt
    /// text for the feed card and never implies an AI summary exists.
    let aiSummaryShort: String?
    let aiSummaryBullets: [String]
    let category: String?
    let tags: [String]
    let language: String?
    let isBookmarked: Bool
    let isRead: Bool
    let clusterID: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        externalID: String?,
        title: String,
        sourceName: String,
        sourceID: String? = nil,
        sourceURL: URL,
        articleURL: URL,
        publishedAt: Date,
        authorName: String?,
        heroImageURL: URL?,
        rawContent: String?,
        cleanedContent: String?,
        distilledBodyHTML: String? = nil,
        distillerVersion: Int? = nil,
        contentSource: String,
        contentWordCount: Int,
        isContentLikelyComplete: Bool,
        summaryShort: String?,
        summaryBullets: [String],
        aiSummaryShort: String? = nil,
        aiSummaryBullets: [String] = [],
        category: String?,
        tags: [String],
        language: String?,
        isBookmarked: Bool,
        isRead: Bool,
        clusterID: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.externalID = externalID
        self.title = title
        self.sourceName = sourceName
        self.sourceID = sourceID
        self.sourceURL = sourceURL
        self.articleURL = articleURL
        self.publishedAt = publishedAt
        self.authorName = authorName
        self.heroImageURL = heroImageURL
        self.rawContent = rawContent
        self.cleanedContent = cleanedContent
        self.distilledBodyHTML = distilledBodyHTML
        self.distillerVersion = distillerVersion
        self.contentSource = contentSource
        self.contentWordCount = contentWordCount
        self.isContentLikelyComplete = isContentLikelyComplete
        self.summaryShort = summaryShort
        self.summaryBullets = summaryBullets
        self.aiSummaryShort = aiSummaryShort
        self.aiSummaryBullets = aiSummaryBullets
        self.category = category
        self.tags = tags
        self.language = language
        self.isBookmarked = isBookmarked
        self.isRead = isRead
        self.clusterID = clusterID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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
        updatedAt: Date,
        distilledBodyHTML: String? = nil,
        distillerVersion: Int? = nil
    ) -> Article {
        Article(
            id: id,
            externalID: externalID,
            title: title,
            sourceName: sourceName,
            sourceID: sourceID,
            sourceURL: sourceURL,
            articleURL: articleURL,
            publishedAt: publishedAt,
            authorName: authorName,
            heroImageURL: heroImageURL,
            rawContent: rawContent,
            cleanedContent: cleanedContent,
            distilledBodyHTML: distilledBodyHTML ?? self.distilledBodyHTML,
            distillerVersion: distillerVersion ?? self.distillerVersion,
            contentSource: contentSource,
            contentWordCount: contentWordCount,
            isContentLikelyComplete: isContentLikelyComplete,
            summaryShort: summaryShort,
            summaryBullets: summaryBullets,
            aiSummaryShort: aiSummaryShort,
            aiSummaryBullets: aiSummaryBullets,
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
