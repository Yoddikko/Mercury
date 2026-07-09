//
//  FeedTopicAggregationServiceTests.swift
//  MercuryTests
//
//  Created by Claude on 09/07/26.
//

import Foundation
import Testing
@testable import Mercury

@Suite("FeedTopicAggregationService")
struct FeedTopicAggregationServiceTests {
    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func makeService(mainOutlets: Set<String> = []) -> FeedTopicAggregationService {
        FeedTopicAggregationService(mainOutletIDs: mainOutlets)
    }

    @Test
    func sameStoryFromDifferentOutletsClustersTogether() {
        let service = Self.makeService()
        let clusters = service.aggregate(
            articles: [
                Self.article(
                    id: "a", source: "ansa",
                    title: "Terremoto di magnitudo 5.2 nel centro Italia, scossa avvertita anche a Roma",
                    minutesAgo: 30
                ),
                Self.article(
                    id: "b", source: "repubblica",
                    title: "Forte scossa di terremoto magnitudo 5.2, paura nel centro Italia",
                    minutesAgo: 50
                ),
                Self.article(
                    id: "c", source: "tgcom24",
                    title: "Centro Italia, terremoto di magnitudo 5.2: la scossa avvertita a Roma",
                    minutesAgo: 70
                ),
                Self.article(
                    id: "d", source: "gazzetta",
                    title: "Calciomercato, il difensore argentino firma il rinnovo del contratto",
                    minutesAgo: 10
                )
            ],
            now: Self.now
        )

        #expect(clusters.count == 2)
        let quake = clusters[0]
        #expect(quake.isAggregated)
        #expect(quake.sourceCount == 3)
        #expect(Set([quake.lead.id] + quake.members.map(\.id)) == ["a", "b", "c"])
        // The unrelated story stays alone and ranks below the 3-outlet one.
        #expect(clusters[1].isAggregated == false)
        #expect(clusters[1].lead.id == "d")
    }

    @Test
    func unrelatedStoriesStaySeparate() {
        let service = Self.makeService()
        let clusters = service.aggregate(
            articles: [
                Self.article(id: "a", source: "ansa", title: "Sciopero dei treni, disagi per i pendolari lombardi", minutesAgo: 5),
                Self.article(id: "b", source: "ansa", title: "Vertice europeo sul clima, raggiunto accordo sulle emissioni", minutesAgo: 15),
                Self.article(id: "c", source: "ansa", title: "Festival del cinema, premiata la regista esordiente", minutesAgo: 25)
            ],
            now: Self.now
        )
        #expect(clusters.count == 3)
        #expect(clusters.allSatisfy { $0.isAggregated == false })
    }

    @Test
    func articlesOlderThanTwentyFourHoursAreExcluded() {
        let service = Self.makeService()
        let clusters = service.aggregate(
            articles: [
                Self.article(id: "fresh", source: "ansa", title: "Nuova missione spaziale europea partita da Kourou", minutesAgo: 60),
                Self.article(id: "stale", source: "ansa", title: "Nuova missione spaziale europea partita ieri da Kourou", minutesAgo: 60 * 30)
            ],
            now: Self.now
        )
        #expect(clusters.count == 1)
        #expect(clusters[0].lead.id == "fresh")
        #expect(clusters[0].members.isEmpty)
    }

    @Test
    func leadPrefersArticleWithHeroImage() {
        let service = Self.makeService()
        let clusters = service.aggregate(
            articles: [
                Self.article(
                    id: "no-image", source: "ansa",
                    title: "Elezioni amministrative, al ballottaggio il capoluogo lombardo",
                    minutesAgo: 10
                ),
                Self.article(
                    id: "with-image", source: "repubblica",
                    title: "Amministrative, il capoluogo lombardo va al ballottaggio",
                    minutesAgo: 40,
                    hasImage: true
                )
            ],
            now: Self.now
        )
        #expect(clusters.count == 1)
        #expect(clusters[0].lead.id == "with-image")
        #expect(clusters[0].members.map(\.id) == ["no-image"])
    }

    @Test
    func sourceCountIsDistinctPerOutlet() {
        let service = Self.makeService()
        let clusters = service.aggregate(
            articles: [
                Self.article(id: "a", source: "ansa", title: "Alluvione in Romagna, evacuate duecento famiglie nella notte", minutesAgo: 10),
                Self.article(id: "b", source: "ansa", title: "Romagna, alluvione nella notte: duecento famiglie evacuate", minutesAgo: 20),
                Self.article(id: "c", source: "corriere", title: "Alluvione in Romagna: nella notte evacuate duecento famiglie", minutesAgo: 30)
            ],
            now: Self.now
        )
        #expect(clusters.count == 1)
        #expect(clusters[0].sourceCount == 2)
    }

    // MARK: - Helpers

    private static func article(
        id: String,
        source: String,
        title: String,
        minutesAgo: Int,
        hasImage: Bool = false
    ) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: title,
            sourceName: source,
            sourceID: source,
            sourceURL: URL(string: "https://example.com/\(source)")!,
            articleURL: URL(string: "https://example.com/\(source)/\(id)")!,
            publishedAt: now.addingTimeInterval(TimeInterval(-60 * minutesAgo)),
            authorName: nil,
            heroImageURL: hasImage ? URL(string: "https://example.com/\(id).jpg") : nil,
            rawContent: nil,
            cleanedContent: nil,
            contentSource: "test",
            contentWordCount: 0,
            isContentLikelyComplete: false,
            summaryShort: nil,
            summaryBullets: [],
            category: nil,
            tags: [],
            language: "it",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
