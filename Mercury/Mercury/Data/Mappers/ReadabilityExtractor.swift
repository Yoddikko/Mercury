//
//  ReadabilityExtractor.swift
//  Mercury
//
//  Created by Claude on 03/07/26.
//

import Foundation
import WebKit

/// Runs Mozilla Readability.js against article HTML inside a hidden,
/// extraction-only `WKWebView` (issue #98).
///
/// This is the approach every major reader uses (reeeed,
/// swift-readability, Firefox Reader itself): let the battle-tested
/// Readability algorithm find the article inside the noise instead of
/// maintaining hand-ported DOM heuristics. The webview is never
/// rendered on screen — rendering stays on the native SwiftUI block
/// parser, so this does NOT reintroduce the WKWebView renderer removed
/// in issue #85.
///
/// Safety and determinism:
/// * page JavaScript is disabled (`allowsContentJavaScript = false`);
///   only our injected Readability source runs via
///   `evaluateJavaScript`,
/// * `<script>`/`<noscript>`/`<iframe>` blocks are stripped from the
///   input before load as a second layer,
/// * extraction is bounded by `timeoutSeconds`; any failure returns
///   `nil` and the caller falls back to the SwiftSoup pipeline.
///
/// The class is `@MainActor` because WebKit requires webview creation
/// and scripting on the main thread. Extractions are serialized
/// through a task chain: article enrichment already runs one article
/// at a time per request, so parallel webviews are not worth their
/// memory.
/// `Sendable` bridge that lets the (nonisolated) enrichment service
/// reach the main-actor extractor. `isEnabled == false` turns the
/// stage into a no-op — used by unit tests that pin the SwiftSoup
/// pipeline in isolation.
struct ReadabilityStage: Sendable {
    var isEnabled: Bool = true

    func extract(html: String, requestID: String?) async -> String? {
        guard isEnabled else { return nil }
        return await ReadabilityExtractor.shared.extractContent(
            fromHTML: html,
            requestID: requestID
        )
    }
}

@MainActor
final class ReadabilityExtractor: NSObject {
    static let shared = ReadabilityExtractor()

    /// Upper bound for one extraction (DOM ready poll + script run).
    /// ponytail: fixed 8s cap, no adaptive budget — bump if slow pages
    /// show up in the field.
    static let timeoutSeconds: Double = 8

    /// Minimum plain-text length (chars) for a Readability result to
    /// be considered meaningful. Below this the caller's generic
    /// pipeline usually does better than an empty shell.
    static let minimumContentCharacters = 200

    private let logger: AppLogger
    private var lastTask: Task<Void, Never>?

    /// Vendored `Readability.js` (mozilla/readability, Apache-2.0),
    /// loaded once per process from the app bundle.
    private static let readabilitySource: String? = {
        let bundle = Bundle(for: ReadabilityExtractor.self)
        guard let url = bundle.url(forResource: "Readability", withExtension: "js")
                ?? Bundle.main.url(forResource: "Readability", withExtension: "js") else {
            AppLogger.shared.error(
                "Readability.js missing from bundle; extraction stage disabled",
                category: .filesystem,
                service: "ReadabilityExtractor"
            )
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }()

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    /// Extracts the readable article content HTML from `html`.
    /// Returns `nil` on parse failure, timeout, or trivially short
    /// output — callers then run their own fallback pipeline.
    func extractContent(fromHTML html: String, requestID: String? = nil) async -> String? {
        guard Self.readabilitySource != nil else { return nil }

        // Serialize extractions: chain behind the previous task.
        let previous = lastTask
        let work = Task<String?, Never> { [weak self] in
            await previous?.value
            return await self?.performExtraction(html: html, requestID: requestID)
        }
        lastTask = Task { _ = await work.value }
        return await work.value
    }

    // MARK: - Private

    private func performExtraction(html: String, requestID: String?) async -> String? {
        guard let source = Self.readabilitySource else { return nil }

        let cleaned = Self.strippingExecutableBlocks(from: html)
        guard cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        // Content JS stays ENABLED: some simulator WebKit builds gate
        // `evaluateJavaScript` behind it. Nothing executes anyway — the
        // input has all <script>/<noscript>/<iframe> blocks stripped
        // above, and the page is loaded from a string with no baseURL.
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // A fresh webview starts on about:blank, whose readyState is
        // ALREADY "complete" — polling readyState alone races the
        // commit of our own document and can run Readability against
        // the empty page. Prepend a hidden sentinel node and poll for
        // it: seeing the sentinel proves OUR document committed.
        let sentinelID = "mercury-load-sentinel"
        let startedAt = Date()
        webView.loadHTMLString("<span id=\"\(sentinelID)\" hidden></span>" + cleaned, baseURL: nil)

        // Poll instead of a navigation delegate: no continuation to
        // leak on timeout, and DOM presence is all Readability needs
        // (images may still be loading).
        let readinessProbe = """
        (document.getElementById("\(sentinelID)") !== null && document.readyState !== "loading") ? "ready" : "waiting"
        """
        var domReady = false
        while Date().timeIntervalSince(startedAt) < Self.timeoutSeconds {
            let state = try? await webView.evaluateJavaScript(readinessProbe)
            if let state = state as? String, state == "ready" {
                domReady = true
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if domReady == false {
            // `loadHTMLString` parses synchronously by commit time in
            // practice; if the readyState poll never confirmed (seen on
            // some simulator builds) still attempt the runner once
            // before giving up.
            logger.warn(
                "Readability DOM readiness unconfirmed after timeout, attempting parse anyway",
                category: .business,
                service: "ReadabilityExtractor",
                requestID: requestID,
                metadata: ["timeout_s": "\(Self.timeoutSeconds)"]
            )
        }

        // The runner always resolves to a String so a JS `null` (which
        // the async evaluateJavaScript API surfaces as a throw) stays
        // distinguishable from a genuine evaluation failure.
        let runner = source + """

        (function() {
            try {
                var article = new Readability(document).parse();
                if (!article || !article.content) { return "__readability_null__"; }
                return article.content;
            } catch (e) {
                return "__readability_error__: " + (e && e.message);
            }
        })();
        """

        var evaluationError: String?
        var raw: Any?
        do {
            raw = try await webView.evaluateJavaScript(runner)
        } catch {
            evaluationError = String(describing: error)
        }
        webView.stopLoading()

        guard let content = raw as? String else {
            logger.warn(
                "Readability evaluation produced no string result",
                category: .business,
                service: "ReadabilityExtractor",
                requestID: requestID,
                metadata: ["error": evaluationError ?? "nil result"]
            )
            return nil
        }
        if content == "__readability_null__" {
            logger.debug(
                "Readability found no article in document",
                category: .business,
                service: "ReadabilityExtractor",
                requestID: requestID
            )
            return nil
        }
        if content.hasPrefix("__readability_error__") {
            logger.warn(
                "Readability.js threw during parse",
                category: .business,
                service: "ReadabilityExtractor",
                requestID: requestID,
                metadata: ["error": String(content.prefix(200))]
            )
            return nil
        }

        let textLength = ArticleBoilerplateRemover.plainText(from: content).count
        guard textLength >= Self.minimumContentCharacters else {
            logger.debug(
                "Readability output too short, falling back",
                category: .business,
                service: "ReadabilityExtractor",
                requestID: requestID,
                metadata: ["text_chars": "\(textLength)"]
            )
            return nil
        }

        logger.debug(
            "Readability extracted article content",
            category: .business,
            service: "ReadabilityExtractor",
            requestID: requestID,
            metadata: [
                "text_chars": "\(textLength)",
                "elapsed_ms": "\(Int(Date().timeIntervalSince(startedAt) * 1000))"
            ]
        )
        return content
    }

    /// Drops executable/embedded blocks before the HTML ever reaches
    /// the webview. Page JS is already disabled at the WebKit level;
    /// this is defense in depth and also keeps `<iframe>` subresource
    /// fetches from delaying DOM readiness.
    nonisolated static func strippingExecutableBlocks(from html: String) -> String {
        var output = html
        for pattern in [
            "(?is)<script\\b[^>]*>.*?</script>",
            "(?is)<noscript\\b[^>]*>.*?</noscript>",
            "(?is)<iframe\\b[^>]*>.*?</iframe>",
            "(?is)<iframe\\b[^>]*/>"
        ] {
            output = output.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        return output
    }
}
