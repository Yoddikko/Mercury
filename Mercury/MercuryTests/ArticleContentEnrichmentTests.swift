//
//  ArticleContentEnrichmentTests.swift
//  MercuryTests
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct ArticleContentEnrichmentTests {
    @Test
    func extractorParsesMainArticleTextAndHeroImage() {
        let extractor = ArticlePageContentExtractor()
        let html = """
        <html>
          <head>
            <meta property="og:image" content="https://cdn.example.com/hero.jpg" />
          </head>
          <body>
            <article>
              <h1>Example Story</h1>
              <p>Paragraph one with enough words to simulate a real article body for extraction quality checks.</p>
              <p>Paragraph two continues the text and should remain visible after sanitization and HTML stripping.</p>
              <script>console.log('ignore me');</script>
            </article>
          </body>
        </html>
        """

        let result = extractor.extract(from: html)
        #expect(result != nil)
        #expect(result?.heroImageURLString == "https://cdn.example.com/hero.jpg")
        #expect(result?.cleanedText.contains("Paragraph one") == true)
        #expect(result?.cleanedText.contains("console.log") == false)
        #expect((result?.wordCount ?? 0) > 20)
    }

    @Test
    func enrichmentServiceUpgradesSummaryOnlyArticleUsingPageExtraction() async {
        let html = """
        <html>
          <head>
            <meta property="og:image" content="https://cdn.example.com/fetched.jpg" />
          </head>
          <body>
            <article>
              <p>This fetched body contains significantly more detail than the feed summary and should be used.</p>
              <p>It includes additional context and enough length to exceed the replacement threshold.</p>
              <p>A third paragraph keeps the extracted word count high for completeness heuristics.</p>
            </article>
          </body>
        </html>
        """

        let pageClient = ArticlePageClient { request in
            let responseURL = request.url ?? URL(string: "https://example.invalid/article")!
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            return (Data(html.utf8), response)
        }
        let service = ArticleContentEnrichmentService(
            pageClient: pageClient,
            extractor: ArticlePageContentExtractor(),
            readabilityStage: ReadabilityStage(isEnabled: false),
            maxFetchesPerSource: 1
        )

        let input = makeArticle(
            contentSource: "feed_summary",
            contentWordCount: 12,
            cleanedContent: "Short feed summary only."
        )

        let enriched = await service.enrichArticlesIfNeeded([input])
        #expect(enriched.count == 1)
        #expect(enriched[0].contentSource == "article_page")
        #expect(enriched[0].contentWordCount > input.contentWordCount)
        #expect(enriched[0].cleanedContent?.contains("significantly more detail") == true)
        #expect(enriched[0].heroImageURL?.absoluteString == "https://cdn.example.com/fetched.jpg")
    }

    @Test
    func enrichmentServiceUsesJSONLDFastPathWhenBodyIsSubstantial() async {
        // JSON-LD fast path (#98): the schema.org articleBody is taken
        // directly, so the DOM chrome on the page (cookie banner,
        // related widget) can never leak into the distilled body.
        let sentence = "Questa frase appartiene al corpo serializzato dal CMS dentro il nodo JSON-LD."
        let body = Array(repeating: sentence, count: 12).joined(separator: " ")
        let html = """
        <html>
          <head>
            <script type="application/ld+json">
            {"@type": "NewsArticle", "isAccessibleForFree": true,
             "articleBody": "\(body)"}
            </script>
          </head>
          <body>
            <div class="page">
              <article>
                <p>\(body)</p>
                <div>Accetta tutti i cookie per continuare la navigazione sul nostro sito.</div>
                <div>Ti potrebbe interessare: altri articoli scelti dalla redazione per te.</div>
              </article>
            </div>
          </body>
        </html>
        """

        let pageClient = ArticlePageClient { request in
            let responseURL = request.url ?? URL(string: "https://example.invalid/article")!
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            return (Data(html.utf8), response)
        }
        let service = ArticleContentEnrichmentService(
            pageClient: pageClient,
            extractor: ArticlePageContentExtractor(),
            readabilityStage: ReadabilityStage(isEnabled: false),
            maxFetchesPerSource: 1
        )

        let input = makeArticle(
            contentSource: "feed_summary",
            contentWordCount: 5,
            cleanedContent: "Sommario RSS breve."
        )

        let enriched = await service.enrichArticlesIfNeeded([input])
        #expect(enriched.count == 1)
        #expect(enriched[0].contentSource == "article_page")
        let distilled = enriched[0].distilledBodyHTML ?? ""
        #expect(distilled.contains("corpo serializzato dal CMS"))
        #expect(distilled.lowercased().contains("cookie") == false)
        #expect(distilled.lowercased().contains("ti potrebbe interessare") == false)
        #expect(enriched[0].distillerVersion == ArticleContentEnrichmentService.distillerVersion)
    }

    @Test
    func enrichmentServiceKeepsArticleUnEnrichedForSubscriberOnlyTeaser() async {
        // Subscriber-only page (#95): headline + teaser + subscription
        // CTA, body absent, schema.org `isAccessibleForFree: false`.
        // The service must return the article unchanged so the reader
        // keeps the RSS summary instead of rendering CTA copy.
        let teaserHTML = """
        <html>
          <head>
            <script type="application/ld+json">
            {"@type": "NewsArticle", "isAccessibleForFree": false,
             "articleBody": "La vicenda risale al 2018 ma rischia di…"}
            </script>
          </head>
          <body>
            <article>
              <h1>Titolo dell'articolo premium</h1>
              <p>Prime righe del sommario che anticipano il contenuto riservato dell'articolo.</p>
              <p>Abbonati per continuare a leggere questo contenuto esclusivo sul nostro sito.</p>
            </article>
          </body>
        </html>
        """

        let pageClient = ArticlePageClient { request in
            let responseURL = request.url ?? URL(string: "https://example.invalid/article")!
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            return (Data(teaserHTML.utf8), response)
        }
        let service = ArticleContentEnrichmentService(
            pageClient: pageClient,
            extractor: ArticlePageContentExtractor(),
            readabilityStage: ReadabilityStage(isEnabled: false),
            maxFetchesPerSource: 1
        )

        let input = makeArticle(
            contentSource: "feed_summary",
            contentWordCount: 3,
            cleanedContent: "RSS summary text."
        )

        let enriched = await service.enrichArticlesIfNeeded([input])
        #expect(enriched == [input])
        #expect(enriched[0].contentSource == "feed_summary")
        #expect(enriched[0].cleanedContent == "RSS summary text.")
        #expect(enriched[0].distilledBodyHTML == nil)
    }

    @Test
    func enrichmentServiceKeepsOriginalArticleWhenFetchFails() async {
        let pageClient = ArticlePageClient { _ in
            throw URLError(.timedOut)
        }
        let service = ArticleContentEnrichmentService(
            pageClient: pageClient,
            extractor: ArticlePageContentExtractor(),
            readabilityStage: ReadabilityStage(isEnabled: false),
            maxFetchesPerSource: 1
        )

        let input = makeArticle(
            contentSource: "feed_summary",
            contentWordCount: 12,
            cleanedContent: "Short feed summary only."
        )

        let enriched = await service.enrichArticlesIfNeeded([input])
        #expect(enriched == [input])
    }

    private func makeArticle(
        contentSource: String,
        contentWordCount: Int,
        cleanedContent: String?
    ) -> Article {
        Article(
            id: "article-test-1",
            externalID: "external-1",
            title: "Test Story",
            sourceName: "Test Source",
            sourceURL: URL(string: "https://example.com/feed.xml")!,
            articleURL: URL(string: "https://example.com/articles/1")!,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            authorName: "Test Author",
            heroImageURL: nil,
            rawContent: cleanedContent,
            cleanedContent: cleanedContent,
            contentSource: contentSource,
            contentWordCount: contentWordCount,
            isContentLikelyComplete: false,
            summaryShort: cleanedContent,
            summaryBullets: [],
            category: "General",
            tags: ["test"],
            language: "en",
            isBookmarked: false,
            isRead: false,
            clusterID: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
