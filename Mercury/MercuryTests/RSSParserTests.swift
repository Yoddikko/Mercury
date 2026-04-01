//
//  RSSParserTests.swift
//  MercuryTests
//
//  Created by Codex on 01/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct RSSParserTests {
    @Test
    func parsesRSSAndNormalizesWithDeduplication() throws {
        let parser = RSSParser()
        let normalizer = ArticleNormalizer()

        let data = Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <title>Example Feed</title>
                <item>
                  <title>First Story</title>
                  <link>https://example.com/articles/1?utm_source=test</link>
                  <description><![CDATA[<p>Alpha &amp; Beta</p>]]></description>
                  <pubDate>Tue, 01 Apr 2026 10:00:00 GMT</pubDate>
                  <category>Technology</category>
                </item>
                <item>
                  <title>First Story Duplicate URL</title>
                  <link>https://example.com/articles/1</link>
                  <description>Duplicate item</description>
                  <pubDate>Tue, 01 Apr 2026 10:05:00 GMT</pubDate>
                  <category>Technology</category>
                </item>
              </channel>
            </rss>
            """.utf8
        )

        let parsedItems = try parser.parse(data: data)
        #expect(parsedItems.count == 2)

        let source = RSSFeedSource(
            id: "test-source",
            outletName: "Test Source",
            region: .europeWide,
            feedURLString: "https://example.com/feed.xml",
            isMainOutlet: true,
            languageCode: "en",
            tags: [],
            note: nil
        )

        let articles = normalizer.normalize(items: parsedItems, source: source)
        #expect(articles.count == 1)
        #expect(articles.first?.title == "First Story Duplicate URL")
        #expect(articles.first?.cleanedContent == "Duplicate item")
        #expect(articles.first?.tags == ["Technology"])
    }

    @Test
    func extractsAdvancedFieldsFromRSSItem() throws {
        let parser = RSSParser()
        let data = Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:dc="http://purl.org/dc/elements/1.1/">
              <channel>
                <item>
                  <guid>story-123</guid>
                  <title>Advanced RSS Story</title>
                  <link>https://example.com/advanced</link>
                  <description><![CDATA[<p>Summary with <strong>HTML</strong></p>]]></description>
                  <content:encoded xmlns:content="http://purl.org/rss/1.0/modules/content/"><![CDATA[<p>Full body paragraph.</p>]]></content:encoded>
                  <dc:creator>Jane Doe</dc:creator>
                  <media:thumbnail url="https://cdn.example.com/thumb.jpg" />
                </item>
              </channel>
            </rss>
            """.utf8
        )

        let items = try parser.parse(data: data)
        #expect(items.count == 1)
        #expect(items.first?.guid == "story-123")
        #expect(items.first?.author == "Jane Doe")
        #expect(items.first?.imageURL == "https://cdn.example.com/thumb.jpg")
        #expect(items.first?.summary?.contains("Summary") == true)
        #expect(items.first?.content?.contains("Full body paragraph") == true)
    }

    @Test
    func parsesAtomFeed() throws {
        let parser = RSSParser()
        let data = Data(
            """
            <?xml version="1.0" encoding="utf-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
              <title>Atom Example</title>
              <entry>
                <title>Atom Story</title>
                <link rel="alternate" href="https://example.com/atom/1" />
                <updated>2026-04-01T12:00:00Z</updated>
                <summary>Atom summary</summary>
                <category term="Politics" />
              </entry>
            </feed>
            """.utf8
        )

        let items = try parser.parse(data: data)
        #expect(items.count == 1)
        #expect(items.first?.title == "Atom Story")
        #expect(items.first?.link == "https://example.com/atom/1")
        #expect(items.first?.categories == ["Politics"])
        #expect(items.first?.language == "en")
    }

    @Test
    func prefersAtomAlternateLinkOverSelfLink() throws {
        let parser = RSSParser()
        let data = Data(
            """
            <?xml version="1.0" encoding="utf-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
              <entry>
                <title>Atom Link Priority</title>
                <link rel="self" href="https://example.com/api/entry/1" />
                <link rel="alternate" href="https://example.com/articles/1" />
                <updated>2026-04-01T12:00:00Z</updated>
              </entry>
            </feed>
            """.utf8
        )

        let items = try parser.parse(data: data)
        #expect(items.count == 1)
        #expect(items.first?.link == "https://example.com/articles/1")
    }

    @Test
    func resolvesRelativeLinksAgainstFeedURL() {
        let normalizer = ArticleNormalizer()
        let item = RSSParsedItem(
            title: "Relative Link Story",
            link: "/stories/42",
            summary: "Summary",
            content: nil,
            publishedAtRaw: "Tue, 01 Apr 2026 10:00:00 GMT",
            categories: ["General"],
            language: nil
        )
        let source = RSSFeedSource(
            id: "relative-link-source",
            outletName: "Relative Link Source",
            region: .europeWide,
            feedURLString: "https://example.com/feed.xml",
            isMainOutlet: true,
            languageCode: "en",
            tags: [],
            note: nil
        )

        let articles = normalizer.normalize(items: [item], source: source)
        #expect(articles.count == 1)
        #expect(articles.first?.articleURL.absoluteString == "https://example.com/stories/42")
    }

    @Test
    func keepsItemWithoutTitleUsingSummaryFallback() {
        let normalizer = ArticleNormalizer()
        let item = RSSParsedItem(
            title: nil,
            link: "https://example.com/summary-only",
            summary: "Summary fallback title",
            content: nil,
            publishedAtRaw: "Tue, 01 Apr 2026 10:00:00 GMT",
            categories: ["General"],
            language: nil
        )
        let source = RSSFeedSource(
            id: "summary-fallback-source",
            outletName: "Summary Fallback Source",
            region: .europeWide,
            feedURLString: "https://example.com/feed.xml",
            isMainOutlet: true,
            languageCode: "en",
            tags: [],
            note: nil
        )

        let articles = normalizer.normalize(items: [item], source: source)
        #expect(articles.count == 1)
        #expect(articles.first?.title == "Summary fallback title")
    }

    @Test
    func usesDistantPastWhenPublishedDateIsMissing() {
        let normalizer = ArticleNormalizer()
        let item = RSSParsedItem(
            title: "No Date Story",
            link: "https://example.com/no-date",
            summary: "Summary",
            content: nil,
            publishedAtRaw: nil,
            categories: [],
            language: nil
        )
        let source = RSSFeedSource(
            id: "no-date-source",
            outletName: "No Date Source",
            region: .europeWide,
            feedURLString: "https://example.com/feed.xml",
            isMainOutlet: true,
            languageCode: "en",
            tags: [],
            note: nil
        )

        let articles = normalizer.normalize(items: [item], source: source)
        #expect(articles.count == 1)
        #expect(articles.first?.publishedAt == .distantPast)
    }

    @Test
    func throwsOnInvalidXML() {
        let parser = RSSParser()
        let data = Data("<rss><channel><item><title>Broken".utf8)

        do {
            _ = try parser.parse(data: data)
            Issue.record("Expected RSSParserError.invalidXML")
        } catch let error as RSSParserError {
            #expect(error == .invalidXML)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func normalizerPrefersFeedContentExtractsImageAndMarksBodyAsComplete() {
        let normalizer = ArticleNormalizer()
        let longBody = Array(repeating: "Mercury validates complete article payloads", count: 40).joined(separator: " ")

        let item = RSSParsedItem(
            title: "Complete Body Story",
            link: "https://example.com/complete-body",
            summary: "Short summary text.",
            content: "<p>\(longBody)</p><img src=\"https://cdn.example.com/full.jpg\" />",
            publishedAtRaw: "Tue, 01 Apr 2026 10:00:00 GMT",
            categories: ["Technology", "AI"],
            language: "en",
            guid: "complete-body-guid",
            author: "Reporter",
            imageURL: nil
        )

        let source = RSSFeedSource(
            id: "complete-body-source",
            outletName: "Complete Body Source",
            region: .europeWide,
            feedURLString: "https://example.com/feed.xml",
            isMainOutlet: true,
            languageCode: "en",
            tags: ["Newsroom"],
            note: nil
        )

        let articles = normalizer.normalize(items: [item], source: source)
        #expect(articles.count == 1)
        #expect(articles.first?.contentSource == "feed_content")
        #expect(articles.first?.isContentLikelyComplete == true)
        #expect(articles.first?.contentWordCount ?? 0 >= 120)
        #expect(articles.first?.heroImageURL?.absoluteString == "https://cdn.example.com/full.jpg")
        #expect(articles.first?.authorName == "Reporter")
        #expect(articles.first?.externalID == "complete-body-guid")
    }

    @Test
    func normalizerFlagsSummaryOnlyAsPartialContent() {
        let normalizer = ArticleNormalizer()
        let item = RSSParsedItem(
            title: "Summary Only Story",
            link: "https://example.com/summary-only",
            summary: "A short summary and a read more marker.",
            content: nil,
            publishedAtRaw: "Tue, 01 Apr 2026 10:00:00 GMT",
            categories: [],
            language: "en"
        )

        let source = RSSFeedSource(
            id: "summary-only-source",
            outletName: "Summary Source",
            region: .europeWide,
            feedURLString: "https://example.com/feed.xml",
            isMainOutlet: true,
            languageCode: "en",
            tags: [],
            note: nil
        )

        let articles = normalizer.normalize(items: [item], source: source)
        #expect(articles.count == 1)
        #expect(articles.first?.contentSource == "feed_summary")
        #expect(articles.first?.isContentLikelyComplete == false)
    }
}
