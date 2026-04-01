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
        #expect(articles.first?.title == "First Story")
        #expect(articles.first?.cleanedContent == "Alpha & Beta")
        #expect(articles.first?.tags == ["Technology"])
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
}
