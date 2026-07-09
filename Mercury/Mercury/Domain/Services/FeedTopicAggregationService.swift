//
//  FeedTopicAggregationService.swift
//  Mercury
//
//  Created by Claude on 09/07/26.
//

import Foundation

/// A story: one lead article plus the other articles covering the same
/// topic, produced by `FeedTopicAggregationService` (issue #109).
struct TopicCluster: Identifiable, Equatable, Sendable {
    /// Stable identity: the lead article's id.
    var id: String { lead.id }
    let lead: Article
    /// Other covering articles, most recent first. Empty for
    /// single-article topics.
    let members: [Article]
    /// Distinct outlets covering the story (lead included).
    let sourceCount: Int

    var isAggregated: Bool { members.isEmpty == false }
}

/// Groups the last-24h articles by story using on-device lexical
/// clustering: TF-IDF over title+summary tokens, cosine similarity,
/// greedy agglomeration. Importance without personalization: clusters
/// covered by more distinct outlets rank first (many outlets ⇒
/// important world/local news), then main-outlet leads, then recency.
/// See `docs/features/CLUSTERING.md` § Shipped v1. The embedding-based
/// clustering spec remains the upgrade path: only the vectorizer
/// changes, the pipeline shape stays.
struct FeedTopicAggregationService: Sendable {
    /// An article joins the first cluster whose best member similarity
    /// reaches this value; otherwise it starts a new cluster ("prefer
    /// new cluster over incorrect merge", CLUSTERING.md § Rules).
    /// ponytail: fixed threshold tuned on Italian headline fixtures —
    /// revisit only with real-corpus evidence.
    static let similarityThreshold = 0.30

    /// Only stories from the last day are aggregated.
    static let recencyWindow: TimeInterval = 24 * 60 * 60

    private let mainOutletIDs: Set<String>
    private let logger: AppLogger

    init(
        mainOutletIDs: Set<String> = Set(
            RSSFeedCatalog.allSources.filter(\.isMainOutlet).map(\.id)
        ),
        logger: AppLogger = .shared
    ) {
        self.mainOutletIDs = mainOutletIDs
        self.logger = logger
    }

    /// Aggregates `articles` into topic clusters. Pure and synchronous;
    /// callers run it off the main actor (Home shows a dedicated
    /// "grouping" state meanwhile).
    func aggregate(
        articles: [Article],
        now: Date = .now,
        requestID: String? = nil
    ) -> [TopicCluster] {
        let startedAt = Date()
        let cutoff = now.addingTimeInterval(-Self.recencyWindow)
        let recent = articles
            .filter { $0.publishedAt >= cutoff && $0.publishedAt <= now.addingTimeInterval(300) }
            .sorted { $0.publishedAt > $1.publishedAt }

        guard recent.isEmpty == false else {
            logger.debug(
                "Topic aggregation skipped: no articles in window",
                category: .business,
                service: "FeedTopicAggregationService",
                requestID: requestID,
                metadata: ["input": "\(articles.count)"]
            )
            return []
        }

        let vectors = Self.tfidfVectors(for: recent)

        // Greedy agglomeration over recency-ordered articles.
        var clusters: [[Int]] = []
        for index in recent.indices {
            var bestCluster = -1
            var bestSimilarity = 0.0
            for (clusterIndex, memberIndexes) in clusters.enumerated() {
                let similarity = memberIndexes
                    .map { Self.cosine(vectors[index], vectors[$0]) }
                    .max() ?? 0
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestCluster = clusterIndex
                }
            }
            if bestSimilarity >= Self.similarityThreshold {
                clusters[bestCluster].append(index)
            } else {
                clusters.append([index])
            }
        }

        let result = clusters
            .map { memberIndexes in build(from: memberIndexes.map { recent[$0] }) }
            .sorted { lhs, rhs in
                if lhs.sourceCount != rhs.sourceCount {
                    return lhs.sourceCount > rhs.sourceCount
                }
                let lhsMain = isMainOutlet(lhs.lead)
                let rhsMain = isMainOutlet(rhs.lead)
                if lhsMain != rhsMain { return lhsMain }
                return lhs.lead.publishedAt > rhs.lead.publishedAt
            }

        logger.info(
            "Topic aggregation completed",
            category: .business,
            service: "FeedTopicAggregationService",
            requestID: requestID,
            metadata: [
                "input": "\(articles.count)",
                "in_window": "\(recent.count)",
                "clusters": "\(result.count)",
                "aggregated": "\(result.filter(\.isAggregated).count)",
                "elapsed_ms": "\(Int(Date().timeIntervalSince(startedAt) * 1000))"
            ]
        )
        return result
    }

    // MARK: - Cluster assembly

    private func build(from articles: [Article]) -> TopicCluster {
        // Lead: image first (the card shows a thumbnail only for the
        // lead), then main outlet, then recency.
        let lead = articles.min { lhs, rhs in
            let lhsKey = leadRank(lhs)
            let rhsKey = leadRank(rhs)
            if lhsKey != rhsKey { return lhsKey < rhsKey }
            return lhs.publishedAt > rhs.publishedAt
        } ?? articles[0]

        let members = articles
            .filter { $0.id != lead.id }
            .sorted { $0.publishedAt > $1.publishedAt }
        let sources = Set(articles.map { $0.sourceID ?? $0.sourceName })
        return TopicCluster(lead: lead, members: members, sourceCount: sources.count)
    }

    /// Lower ranks first: 0 = image + main outlet … 3 = neither.
    private func leadRank(_ article: Article) -> Int {
        let hasImage = article.heroImageURL != nil
        let isMain = isMainOutlet(article)
        switch (hasImage, isMain) {
        case (true, true): return 0
        case (true, false): return 1
        case (false, true): return 2
        case (false, false): return 3
        }
    }

    private func isMainOutlet(_ article: Article) -> Bool {
        guard let sourceID = article.sourceID else { return false }
        return mainOutletIDs.contains(sourceID)
    }

    // MARK: - Lexical features

    private static func tfidfVectors(for articles: [Article]) -> [[String: Double]] {
        let tokenized = articles.map { tokens(for: $0) }
        var documentFrequency: [String: Int] = [:]
        for documentTokens in tokenized {
            for token in Set(documentTokens) {
                documentFrequency[token, default: 0] += 1
            }
        }
        let corpusSize = Double(articles.count)
        return tokenized.map { documentTokens in
            var counts: [String: Double] = [:]
            for token in documentTokens {
                counts[token, default: 0] += 1
            }
            return counts.reduce(into: [:]) { vector, entry in
                let idf = log(corpusSize / Double(documentFrequency[entry.key] ?? 1)) + 1
                vector[entry.key] = entry.value * idf
            }
        }
    }

    private static func tokens(for article: Article) -> [String] {
        let text = article.title + " " + (article.summaryShort ?? "")
        return text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && stopwords.contains($0) == false }
    }

    private static func cosine(_ lhs: [String: Double], _ rhs: [String: Double]) -> Double {
        guard lhs.isEmpty == false, rhs.isEmpty == false else { return 0 }
        let (small, large) = lhs.count <= rhs.count ? (lhs, rhs) : (rhs, lhs)
        var dot = 0.0
        for (token, weight) in small {
            if let other = large[token] { dot += weight * other }
        }
        guard dot > 0 else { return 0 }
        let lhsNorm = sqrt(lhs.values.reduce(0) { $0 + $1 * $1 })
        let rhsNorm = sqrt(rhs.values.reduce(0) { $0 + $1 * $1 })
        return dot / (lhsNorm * rhsNorm)
    }

    /// Italian + English stopwords for headline text. Compact on
    /// purpose: TF-IDF already downweights ubiquitous tokens.
    private static let stopwords: Set<String> = [
        // Italian
        "che", "chi", "con", "cosa", "come", "dal", "dalla", "dagli", "dalle",
        "dei", "del", "della", "delle", "dello", "degli", "dopo", "dove",
        "ecco", "fra", "gli", "hanno", "l'", "loro", "mentre", "nel", "nella",
        "nelle", "nello", "negli", "non", "nuovo", "nuova", "oggi", "ore",
        "per", "perche", "piu", "prima", "quando", "questa", "questo", "qui",
        "sara", "senza", "solo", "sono", "sotto", "sua", "sul", "sulla",
        "sulle", "sullo", "sugli", "suo", "tra", "tutte", "tutti", "tutto",
        "una", "uno", "verso", "video", "anni", "anno", "casa", "contro",
        "essere", "fare", "giorni", "grande", "italia", "italiana", "italiano",
        "milioni", "mila", "euro", "due", "tre",
        // English
        "the", "and", "for", "with", "from", "that", "this", "after", "over",
        "into", "about", "amid", "are", "was", "will", "has", "have", "how",
        "why", "what", "when", "where", "who", "new", "news", "says", "said",
        "year", "years", "his", "her", "its", "their", "more", "than", "one"
    ]
}
