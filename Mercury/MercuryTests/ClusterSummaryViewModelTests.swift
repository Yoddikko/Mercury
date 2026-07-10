//
//  ClusterSummaryViewModelTests.swift
//  MercuryTests
//
//  Created by Claude on 10/07/26.
//

import Foundation
import Testing
@testable import Mercury

@MainActor
@Suite("ClusterSummaryViewModel")
struct ClusterSummaryViewModelTests {
    @Test
    func summarizesTheWholeStoryAndTransitionsToReady() async {
        let cluster = Self.sampleCluster()
        let expected = AISummaryResult(shortSummary: "Sintesi della storia.", bullets: ["Punto uno"])
        let viewModel = ClusterSummaryViewModel(summarize: { content, _ in
            // The combined input must carry every outlet's block.
            #expect(content.contains("SOURCE: ansa"))
            #expect(content.contains("SOURCE: repubblica"))
            #expect(content.contains("TITLE: Titolo guida della storia"))
            return expected
        })

        await viewModel.requestSummary(for: cluster)

        #expect(viewModel.state == .ready(expected))
    }

    @Test
    func failureSurfacesTheReasonAndRetryRegenerates() async {
        struct Boom: LocalizedError {
            var errorDescription: String? { "provider esploso" }
        }
        final class FlipFlop: @unchecked Sendable {
            private let lock = NSLock()
            private var failed = false
            func shouldFail() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                if failed { return false }
                failed = true
                return true
            }
        }
        let flipFlop = FlipFlop()
        let expected = AISummaryResult(shortSummary: "Recuperata.", bullets: [])
        let viewModel = ClusterSummaryViewModel(summarize: { _, _ in
            if flipFlop.shouldFail() { throw Boom() }
            return expected
        })
        let cluster = Self.sampleCluster()

        await viewModel.requestSummary(for: cluster)
        guard case let .failed(reason) = viewModel.state else {
            Issue.record("Expected .failed, got \(viewModel.state)")
            return
        }
        #expect(reason == "provider esploso")

        await viewModel.requestSummary(for: cluster, force: true)
        #expect(viewModel.state == .ready(expected))
    }

    @Test
    func storyInputRespectsTheGlobalBudget() {
        let long = String(repeating: "parola ", count: 3_000)
        let members = (0..<15).map { index in
            Self.article(id: "m-\(index)", source: "fonte-\(index)", title: "Titolo \(index)", text: long)
        }
        let cluster = TopicCluster(
            lead: Self.article(id: "lead", source: "ansa", title: "Guida", text: long),
            members: members,
            sourceCount: 16
        )
        let input = ClusterSummaryViewModel.storyInput(for: cluster)
        #expect(input.count <= ClusterSummaryViewModel.totalCharacterBudget
            + ClusterSummaryViewModel.perArticleCharacterBudget)
    }

    // MARK: - Helpers

    private static func sampleCluster() -> TopicCluster {
        TopicCluster(
            lead: article(id: "a", source: "ansa", title: "Titolo guida della storia", text: "Testo guida."),
            members: [article(id: "b", source: "repubblica", title: "Altro taglio", text: "Testo secondario.")],
            sourceCount: 2
        )
    }

    private static func article(id: String, source: String, title: String, text: String) -> Article {
        Article(
            id: id,
            externalID: nil,
            title: title,
            sourceName: source,
            sourceID: source,
            sourceURL: URL(string: "https://example.com/\(source)")!,
            articleURL: URL(string: "https://example.com/\(source)/\(id)")!,
            publishedAt: .now,
            authorName: nil,
            heroImageURL: nil,
            rawContent: nil,
            cleanedContent: text,
            contentSource: "test",
            contentWordCount: 10,
            isContentLikelyComplete: true,
            summaryShort: nil,
            summaryBullets: [],
            category: nil,
            tags: [],
            language: "it",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

@Suite("SummaryLanguagePreference")
struct SummaryLanguagePreferenceTests {
    @Test
    func defaultsToSystemAndRoundTrips() {
        let defaults = UserDefaults(suiteName: "test-lang-\(UUID().uuidString)")!
        #expect(SummaryLanguagePreference.load(defaults: defaults) == .system)

        SummaryLanguagePreference.italian.save(defaults: defaults)
        #expect(SummaryLanguagePreference.load(defaults: defaults) == .italian)
    }

    @Test
    func promptLanguageNamesAreEnglishNames() {
        #expect(SummaryLanguagePreference.italian.promptLanguageName() == "Italian")
        #expect(SummaryLanguagePreference.english.promptLanguageName() == "English")
        #expect(
            SummaryLanguagePreference.system.promptLanguageName(locale: Locale(identifier: "it_IT"))
                == "Italian"
        )
    }
}
