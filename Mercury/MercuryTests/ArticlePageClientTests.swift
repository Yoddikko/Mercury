//
//  ArticlePageClientTests.swift
//  MercuryTests
//
//  Created by Codex on 01/07/26.
//

import Foundation
import Testing
@testable import Mercury

/// Guards issue #82 — outbound article-page fetches must present a
/// realistic Safari-iOS User-Agent + Italian-preferring
/// Accept-Language, so outlets don't fingerprint us into a lightweight
/// / consent-gated variant of their page.
@Suite("ArticlePageClient")
struct ArticlePageClientTests {
    @Test
    func fetchSetsSafariUserAgentAndItalianAcceptLanguage() async throws {
        let captured = HeaderCapture()
        let client = ArticlePageClient(
            performRequest: { request in
                await captured.record(headers: request.allHTTPHeaderFields ?? [:])
                let payload = Data("<html><body><p>hi</p></body></html>".utf8)
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html; charset=utf-8"]
                )!
                return (payload, response)
            }
        )

        _ = try await client.fetchPageHTML(from: URL(string: "https://ansa.it/x")!)

        let headers = await captured.headers
        let ua = headers["User-Agent"] ?? ""
        let lang = headers["Accept-Language"] ?? ""
        // Realistic UA — has to look like a Safari on iPhone, not our
        // old `MercuryArticleClient/1.0`.
        #expect(ua.contains("iPhone"))
        #expect(ua.contains("Safari"))
        #expect(ua.contains("MercuryArticleClient") == false)
        // Italian must be prioritized so `it.it` outlets serve the IT
        // edition rather than the English fallback.
        #expect(lang.hasPrefix("it"))
        #expect(lang.contains("it-IT"))
    }

    @Test
    func nonHTTPSURLIsRejectedBeforeRequest() async {
        let captured = HeaderCapture()
        let client = ArticlePageClient(
            performRequest: { request in
                await captured.record(headers: request.allHTTPHeaderFields ?? [:])
                return (Data(), HTTPURLResponse())
            }
        )
        await #expect(throws: ArticlePageClientError.insecureTransport) {
            _ = try await client.fetchPageHTML(from: URL(string: "http://ansa.it/x")!)
        }
        let recorded = await captured.headers
        #expect(recorded.isEmpty)
    }

    private actor HeaderCapture {
        private(set) var headers: [String: String] = [:]
        func record(headers: [String: String]) {
            self.headers = headers
        }
    }
}
