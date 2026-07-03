//
//  ArticleContentEnrichmentService.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct ArticleContentEnrichmentService: Sendable {
    /// Version stamped on `Article.distillerVersion` for every record
    /// distilled by this service. Bump when the pipeline composition
    /// changes so old records re-distill on next ingest.
    /// v2: per-outlet extraction rule layer (#91).
    /// v3: paywalled-teaser classification (#95) — subscriber-only
    ///     pages keep the RSS summary instead of teaser/CTA leftovers.
    static let distillerVersion: Int = 3

    /// Minimum word count required for the distilled output to be
    /// preferred over the raw extractor output. Below this threshold
    /// the pipeline keeps the raw HTML so the user never sees a
    /// shorter article than before.
    private static let distilledMinimumWords: Int = 80

    private let pageClient: ArticlePageClient
    private let extractor: ArticlePageContentExtractor
    private let sanitizer: ArticleHTMLSanitizer
    private let jsonLDExtractor: ArticleJSONLDExtractor
    private let outletRuleCatalog: ArticleOutletRuleCatalog
    private let outletRuleApplier: ArticleOutletRuleApplier
    private let boilerplateRemover: ArticleBoilerplateRemover
    private let imageDeduplicator: ArticleImageDeduplicator
    private let localeStripper: ArticleLocaleBoilerplateStripper
    private let paywallClassifier: ArticlePaywallClassifier
    private let logger: AppLogger
    private let maxFetchesPerSource: Int

    nonisolated init(
        pageClient: ArticlePageClient = ArticlePageClient(),
        extractor: ArticlePageContentExtractor = ArticlePageContentExtractor(),
        sanitizer: ArticleHTMLSanitizer = ArticleHTMLSanitizer(),
        jsonLDExtractor: ArticleJSONLDExtractor = ArticleJSONLDExtractor(),
        outletRuleCatalog: ArticleOutletRuleCatalog = .bundled,
        outletRuleApplier: ArticleOutletRuleApplier = ArticleOutletRuleApplier(),
        boilerplateRemover: ArticleBoilerplateRemover = ArticleBoilerplateRemover(),
        imageDeduplicator: ArticleImageDeduplicator = ArticleImageDeduplicator(),
        localeStripper: ArticleLocaleBoilerplateStripper = ArticleLocaleBoilerplateStripper(),
        paywallClassifier: ArticlePaywallClassifier = ArticlePaywallClassifier(),
        logger: AppLogger = .shared,
        maxFetchesPerSource: Int = 3
    ) {
        self.pageClient = pageClient
        self.extractor = extractor
        self.sanitizer = sanitizer
        self.jsonLDExtractor = jsonLDExtractor
        self.outletRuleCatalog = outletRuleCatalog
        self.outletRuleApplier = outletRuleApplier
        self.boilerplateRemover = boilerplateRemover
        self.imageDeduplicator = imageDeduplicator
        self.localeStripper = localeStripper
        self.paywallClassifier = paywallClassifier
        self.logger = logger
        self.maxFetchesPerSource = max(0, maxFetchesPerSource)
    }

    func enrichArticlesIfNeeded(
        _ articles: [Article],
        requestID: String? = nil
    ) async -> [Article] {
        guard articles.isEmpty == false else { return articles }

        logger.debug(
            "Starting article page enrichment",
            category: .business,
            service: "ArticleContentEnrichmentService",
            requestID: requestID,
            metadata: [
                "articles_in": "\(articles.count)",
                "max_fetches_per_source": "\(maxFetchesPerSource)"
            ]
        )

        var remainingFetchBudget = maxFetchesPerSource
        var attempts = 0
        var upgraded = 0
        var output: [Article] = []
        output.reserveCapacity(articles.count)

        for article in articles {
            guard shouldAttemptEnrichment(for: article) else {
                output.append(article)
                continue
            }

            guard remainingFetchBudget > 0 else {
                output.append(article)
                continue
            }

            remainingFetchBudget -= 1
            attempts += 1
            let enriched = await enrichSingleArticle(article, requestID: requestID)
            if enriched.contentSource == "article_page", enriched.contentWordCount > article.contentWordCount {
                upgraded += 1
            }
            output.append(enriched)
        }

        logger.debug(
            "Article page enrichment completed",
            category: .business,
            service: "ArticleContentEnrichmentService",
            requestID: requestID,
            metadata: [
                "articles_in": "\(articles.count)",
                "attempts": "\(attempts)",
                "upgraded": "\(upgraded)",
                "articles_out": "\(output.count)"
            ]
        )

        return output
    }

    private func shouldAttemptEnrichment(for article: Article) -> Bool {
        guard article.articleURL.scheme?.lowercased() == "https" else { return false }

        if article.contentSource == "article_page", article.contentWordCount >= 180 {
            return false
        }

        if article.isContentLikelyComplete, article.contentWordCount >= 220 {
            return false
        }

        if article.contentSource == "feed_content", article.contentWordCount >= 350 {
            return false
        }

        return true
    }

    private func enrichSingleArticle(_ article: Article, requestID: String?) async -> Article {
        do {
            let html = try await pageClient.fetchPageHTML(from: article.articleURL, requestID: requestID)
            guard let extraction = extractor.extract(from: html, requestID: requestID) else {
                return article
            }

            guard shouldReplaceContent(existingArticle: article, extraction: extraction) else {
                return article
            }

            let resolvedImageURL = article.heroImageURL ?? resolvedImageURLString(
                extraction.heroImageURLString,
                fallback: article.articleURL
            )
            let summary = resolvedSummary(existing: article.summaryShort, cleanedContent: extraction.cleanedText)

            logger.trace(
                "Article content upgraded from page extraction",
                category: .business,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "old_word_count": "\(article.contentWordCount)",
                    "new_word_count": "\(extraction.wordCount)"
                ]
            )

            // Distillation runs on the FULL fetched page (not just the
            // extractor's regex-selected block) because the extractor's
            // heuristic can pick chrome-heavy wrappers when the cookie
            // banner outweighs the article body. The Readability-style
            // heuristics in `ArticleBoilerplateRemover` are responsible
            // for finding the article inside the noise.
            let distillation = distill(
                rawHTML: html,
                fallbackCleanedText: extraction.cleanedText,
                heroURLString: resolvedImageURL?.absoluteString,
                language: article.language,
                host: article.articleURL.host,
                requestID: requestID
            )

            // Subscriber-only teaser (#95): the page has no readable
            // body, only teaser + subscription CTA. Rendering the
            // fallback extractor text would surface that CTA as the
            // article body, so keep the article un-enriched — the
            // reader shows the RSS item summary instead.
            if distillation.isPaywalledTeaser {
                logger.info(
                    "Article kept un-enriched: page is a subscriber-only teaser",
                    category: .business,
                    service: "ArticleContentEnrichmentService",
                    requestID: requestID,
                    metadata: [
                        "article_id": article.id,
                        "url": article.articleURL.absoluteString
                    ]
                )
                return article
            }

            return article.updatingContent(
                rawContent: extraction.rawHTML,
                cleanedContent: distillation.cleanedText,
                contentSource: "article_page",
                contentWordCount: distillation.wordCount ?? extraction.wordCount,
                isContentLikelyComplete: extraction.isLikelyComplete,
                heroImageURL: resolvedImageURL,
                summaryShort: summary,
                updatedAt: .now,
                distilledBodyHTML: distillation.distilledHTML,
                distillerVersion: distillation.distilledHTML == nil ? nil : Self.distillerVersion
            )
        } catch {
            logger.trace(
                "Article page enrichment failed and fell back to feed content",
                category: .api,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "article_id": article.id,
                    "url": article.articleURL.absoluteString,
                    "error": String(describing: error)
                ]
            )
            return article
        }
    }

    private func shouldReplaceContent(
        existingArticle: Article,
        extraction: ArticlePageExtractionResult
    ) -> Bool {
        let newWords = extraction.wordCount
        let oldWords = existingArticle.contentWordCount

        guard newWords > 0 else { return false }
        if oldWords == 0 { return true }

        if existingArticle.contentSource == "feed_summary" {
            return newWords >= oldWords + 15
        }

        if existingArticle.isContentLikelyComplete {
            return newWords >= oldWords + 80
        }

        if oldWords < 120 {
            return newWords >= oldWords + 20
        }

        return newWords >= oldWords + 35 || newWords >= 180
    }

    private func resolvedImageURLString(_ value: String?, fallback: URL) -> URL? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let absolute = URL(string: trimmed),
           let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absolute
        }

        if trimmed.hasPrefix("//"), let protocolRelative = URL(string: "https:\(trimmed)") {
            return protocolRelative
        }

        if trimmed.lowercased().hasPrefix("www."),
           let normalized = URL(string: "https://\(trimmed)") {
            return normalized
        }

        if let relative = URL(string: trimmed, relativeTo: fallback)?.absoluteURL,
           let scheme = relative.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return relative
        }

        return nil
    }

    private func resolvedSummary(existing: String?, cleanedContent: String) -> String? {
        if let existing, existing.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 {
            return existing
        }

        let trimmed = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return existing }

        if trimmed.count <= 280 {
            return trimmed
        }

        let snippet = String(trimmed.prefix(280)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard snippet.isEmpty == false else { return existing }
        return "\(snippet)..."
    }

    // MARK: - Distillation pipeline (issue #66)

    /// Result of the distillation pipeline. `distilledHTML` is `nil`
    /// when the pipeline could not produce a usable output (short,
    /// empty, parse failure) — callers then keep the original raw HTML
    /// in place and skip stamping `distillerVersion`.
    /// `isPaywalledTeaser` (#95) is `true` when the short output is
    /// classified as a subscriber-only teaser — callers must then keep
    /// the article un-enriched instead of using the fallback text.
    /// Internal (not private) so the fixture suites and the audit
    /// harness exercise the exact production pipeline.
    struct DistillationOutput {
        let distilledHTML: String?
        let cleanedText: String
        let wordCount: Int?
        let isPaywalledTeaser: Bool
    }

    func distill(
        rawHTML: String,
        fallbackCleanedText: String,
        heroURLString: String?,
        language: String?,
        host: String?,
        requestID: String?
    ) -> DistillationOutput {
        // JSON-LD fast path (#98): when the CMS embeds the article body
        // in a schema.org Article node, take it directly — zero page
        // chrome by construction. Substantial-body check keeps teaser
        // JSON-LD (Repubblica premium ships a 400-char preview) on the
        // DOM pipeline, where the paywall classifier (#95) sees it.
        if let fastPath = jsonLDFastPath(
            rawHTML: rawHTML,
            language: language,
            requestID: requestID
        ) {
            return fastPath
        }

        let sanitized = sanitizer.sanitize(rawHTML)
        // Per-outlet extraction rule (#91) — applied BEFORE the generic
        // Readability-style pass. When the article host has a declared
        // rule (ANSA Consentless CTA, Corriere paywall chrome,
        // Repubblica link blocks) the rule narrows the document to the
        // outlet's body container and strips outlet-specific chrome.
        // Hosts without a rule pass through untouched.
        let rule = outletRuleCatalog.rule(forHost: host)
        let ruled: String
        if let rule {
            logger.debug(
                "Per-outlet extraction rule matched",
                category: .business,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "rule_id": rule.id,
                    "host": host ?? "unknown"
                ]
            )
            ruled = outletRuleApplier.applying(rule, to: sanitized, requestID: requestID)
        } else {
            logger.trace(
                "No per-outlet extraction rule for host, generic pipeline only",
                category: .business,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: ["host": host ?? "unknown"]
            )
            ruled = sanitized
        }
        // Truncate at the Italian article terminator (#81). Most IT
        // outlets end the body with "Riproduzione riservata" and follow
        // it with newsletter CTAs, related-article grids, subscribe
        // prompts, and share strips. Cutting there is the single
        // highest-ROI cleanup step we can take.
        let truncated = ArticleContentEnrichmentService.truncatedAtTerminator(
            html: ruled,
            language: language
        )
        let withoutBoilerplate = boilerplateRemover.cleaning(truncated)
        let withoutHeroDuplicate = imageDeduplicator.dedupingHero(
            in: withoutBoilerplate,
            heroImageURLString: heroURLString
        )
        let final = localeStripper.stripping(
            html: withoutHeroDuplicate,
            language: language
        )

        let plainText = ArticleBoilerplateRemover.plainText(from: final)
        let wordCount = plainText
            .split { $0.isWhitespace || $0.isNewline }
            .count

        guard wordCount >= Self.distilledMinimumWords else {
            logger.trace(
                "Distillation produced short output, falling back to extractor cleanedText",
                category: .business,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "distilled_word_count": "\(wordCount)",
                    "threshold": "\(Self.distilledMinimumWords)"
                ]
            )
            // Teaser-short output → run the paywall classifier (#95)
            // on the RAW page. Scanning raw HTML is deliberate: the
            // markers (JSON-LD `isAccessibleForFree`, CTA copy) live
            // in regions the pipeline already stripped.
            let isPaywalledTeaser = paywallClassifier.isLikelyPaywalledTeaser(
                rawHTML: rawHTML,
                distilledWordCount: wordCount,
                outletMarkers: rule?.paywallMarkers ?? [],
                requestID: requestID
            )
            return DistillationOutput(
                distilledHTML: nil,
                cleanedText: fallbackCleanedText,
                wordCount: nil,
                isPaywalledTeaser: isPaywalledTeaser
            )
        }

        logger.debug(
            "Distillation pipeline produced cleaned body",
            category: .business,
            service: "ArticleContentEnrichmentService",
            requestID: requestID,
            metadata: [
                "distilled_word_count": "\(wordCount)",
                "language": language ?? "unknown",
                "distiller_version": "\(Self.distillerVersion)"
            ]
        )

        return DistillationOutput(
            distilledHTML: final,
            cleanedText: plainText,
            wordCount: wordCount,
            isPaywalledTeaser: false
        )
    }

    // MARK: - JSON-LD fast path (issue #98)

    /// Builds the distilled output straight from the page's JSON-LD
    /// `articleBody` when one exists and is substantial (≥ the
    /// pipeline's minimum distilled word count). Returns `nil` when
    /// the page has no usable node — the DOM pipeline then runs
    /// unchanged, including the paywalled-teaser classification for
    /// pages whose JSON-LD body is only a preview.
    private func jsonLDFastPath(
        rawHTML: String,
        language: String?,
        requestID: String?
    ) -> DistillationOutput? {
        guard let node = jsonLDExtractor.articleNode(fromRawHTML: rawHTML, requestID: requestID) else {
            return nil
        }

        // Cut the body at the Italian article terminator if the CMS
        // serialized it into `articleBody` (several outlets keep the
        // "© RIPRODUZIONE RISERVATA" line inside the field).
        let truncatedBody = Self.truncatedTextAtTerminator(
            text: node.articleBody,
            language: language
        )

        let paragraphsHTML = Self.paragraphsHTML(fromPlainText: truncatedBody)
        // Locale stripper post-pass: catches newsletter CTAs and
        // related-content labels a CMS occasionally serializes into
        // the body field as standalone paragraphs.
        let final = localeStripper.stripping(html: paragraphsHTML, language: language)
        let plainText = ArticleBoilerplateRemover.plainText(from: final)
        let wordCount = plainText
            .split { $0.isWhitespace || $0.isNewline }
            .count

        guard wordCount >= Self.distilledMinimumWords else {
            logger.trace(
                "JSON-LD articleBody too short for fast path, deferring to DOM pipeline",
                category: .business,
                service: "ArticleContentEnrichmentService",
                requestID: requestID,
                metadata: [
                    "jsonld_word_count": "\(wordCount)",
                    "threshold": "\(Self.distilledMinimumWords)",
                    "is_accessible_for_free": node.isAccessibleForFree.map { "\($0)" } ?? "undeclared"
                ]
            )
            return nil
        }

        logger.debug(
            "Distilled body taken from JSON-LD articleBody fast path",
            category: .business,
            service: "ArticleContentEnrichmentService",
            requestID: requestID,
            metadata: [
                "jsonld_word_count": "\(wordCount)",
                "language": language ?? "unknown",
                "distiller_version": "\(Self.distillerVersion)"
            ]
        )

        return DistillationOutput(
            distilledHTML: final,
            cleanedText: plainText,
            wordCount: wordCount,
            isPaywalledTeaser: false
        )
    }

    /// Converts a plain-text article body into paragraph HTML. Splits
    /// on newline runs when the CMS preserved them; a body without
    /// newlines becomes a single paragraph. Text is HTML-escaped, so
    /// the output is chrome-free AND markup-safe by construction.
    static func paragraphsHTML(fromPlainText text: String) -> String {
        let paragraphs = text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        return paragraphs
            .map { "<p>\(escapedHTMLText($0))</p>" }
            .joined(separator: "\n")
    }

    /// Minimal HTML text escaping for text-node content.
    static func escapedHTMLText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Plain-text variant of `truncatedAtTerminator` for JSON-LD
    /// bodies: cuts `text` at the first case-insensitive occurrence of
    /// a per-language terminator marker. Unknown language passes
    /// through untouched.
    static func truncatedTextAtTerminator(text: String, language: String?) -> String {
        guard let normalized = ArticleLocaleBoilerplateStripper.normalizedLanguage(language),
              let terminators = terminatorMarkers[normalized] else {
            return text
        }
        var earliest: Range<String.Index>?
        for terminator in terminators {
            guard let range = text.range(of: terminator, options: [.caseInsensitive]) else { continue }
            if earliest == nil || range.lowerBound < earliest!.lowerBound {
                earliest = range
            }
        }
        guard let earliest else { return text }
        return String(text[..<earliest.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trim `html` at the first occurrence of a per-language article
    /// terminator (Italian: "Riproduzione riservata" / "©
    /// RIPRODUZIONE RISERVATA"). Case-insensitive.
    ///
    /// The scan walks the HTML with a small state machine and only
    /// records characters that will actually render as visible text.
    /// Skipped regions:
    /// * `<script>...</script>` bodies — ANSA embeds the marker inside
    ///   JS image-slider captions near the top of the page.
    /// * `<style>...</style>` bodies.
    /// * `<!-- ... -->` comments.
    /// * Everything between `<` and `>` (tag markup + attribute
    ///   values). ANSA also puts "RIPRODUZIONE RISERVATA" in
    ///   `alt=""` on its hero image, and without this the truncation
    ///   would still fire at the very top of the article.
    ///
    /// If the terminator is not present in the visible content, the
    /// input is returned unchanged. `nil` / unknown language also
    /// passes through.
    static func truncatedAtTerminator(html: String, language: String?) -> String {
        guard let normalized = ArticleLocaleBoilerplateStripper.normalizedLanguage(language),
              let terminators = terminatorMarkers[normalized] else {
            return html
        }

        // Precompute the lowercase HTML once so `<script` / `</script>`
        // /`<!--` detection is O(n) case-insensitive without recompiling
        // NSRegularExpression per iteration.
        let lowered = html.lowercased()
        let bytes = Array(lowered.utf8)
        let originalBytes = Array(html.utf8)
        let count = bytes.count

        // Prepare each terminator's UTF-8 lowercase byte pattern.
        let markerPatterns: [[UInt8]] = terminators.map { Array($0.utf8) }

        // Byte-level state machine.
        var i = 0
        while i < count {
            let byte = bytes[i]
            if byte == 0x3C { // '<'
                // Handle <!-- ... -->
                if Self.hasPrefix(bytes, at: i, "<!--".utf8) {
                    if let end = Self.indexOfPrefix(bytes, from: i + 4, "-->".utf8) {
                        i = end + 3
                    } else {
                        i = count
                    }
                    continue
                }
                // Handle <script ...>...</script>
                if Self.hasPrefix(bytes, at: i, "<script".utf8) {
                    if let closeStart = Self.indexOfPrefix(bytes, from: i + 7, "</script>".utf8) {
                        i = closeStart + 9
                    } else {
                        i = count
                    }
                    continue
                }
                // Handle <style ...>...</style>
                if Self.hasPrefix(bytes, at: i, "<style".utf8) {
                    if let closeStart = Self.indexOfPrefix(bytes, from: i + 6, "</style>".utf8) {
                        i = closeStart + 8
                    } else {
                        i = count
                    }
                    continue
                }
                // Handle <figure ...>...</figure>. Italian outlets use
                // "RIPRODUZIONE RISERVATA" as a hero-image credit
                // caption ("Papa Leone - RIPRODUZIONE RISERVATA") that
                // sits inside the figure wrapping the article's opening
                // image. Without skipping figures the truncation would
                // fire against that caption and eat the entire article
                // body.
                if Self.hasPrefix(bytes, at: i, "<figure".utf8) {
                    if let closeStart = Self.indexOfPrefix(bytes, from: i + 7, "</figure>".utf8) {
                        i = closeStart + 9
                    } else {
                        i = count
                    }
                    continue
                }
                // Handle bare <figcaption ...>...</figcaption> (some
                // templates omit the wrapping <figure>).
                if Self.hasPrefix(bytes, at: i, "<figcaption".utf8) {
                    if let closeStart = Self.indexOfPrefix(bytes, from: i + 11, "</figcaption>".utf8) {
                        i = closeStart + 13
                    } else {
                        i = count
                    }
                    continue
                }
                // Any other tag markup — skip up to the closing '>'.
                var j = i + 1
                while j < count, bytes[j] != 0x3E { // '>'
                    j += 1
                }
                i = j < count ? j + 1 : count
                continue
            }

            // Visible byte — try to match any terminator anchored here.
            for pattern in markerPatterns {
                if Self.hasPrefix(bytes, at: i, ArraySlice(pattern)) {
                    return String(decoding: originalBytes.prefix(i), as: UTF8.self)
                }
            }
            i += 1
        }
        return html
    }

    /// Byte-slice prefix check. Kept nonisolated + inlinable so the
    /// terminator scanner stays branch-predictable.
    @inline(__always)
    private static func hasPrefix<S: Collection>(
        _ bytes: [UInt8],
        at index: Int,
        _ pattern: S
    ) -> Bool where S.Element == UInt8 {
        var i = index
        for expected in pattern {
            guard i < bytes.count else { return false }
            if bytes[i] != expected { return false }
            i += 1
        }
        return true
    }

    /// Find the earliest index ≥ `from` where `bytes` matches `pattern`.
    private static func indexOfPrefix<S: Collection>(
        _ bytes: [UInt8],
        from: Int,
        _ pattern: S
    ) -> Int? where S.Element == UInt8 {
        let patternArray = Array(pattern)
        guard patternArray.isEmpty == false else { return from }
        let last = bytes.count - patternArray.count
        if last < from { return nil }
        for start in from...last {
            if hasPrefix(bytes, at: start, ArraySlice(patternArray)) {
                return start
            }
        }
        return nil
    }

    /// Per-locale article terminators. Kept minimal so we don't cut
    /// legitimate paragraphs; add new markers only when we've seen
    /// them survive the boilerplate remover on the fixture corpus.
    ///
    /// All Italian variants **require the copyright glyph** adjacent
    /// to the phrase because Italian outlets use bare "RIPRODUZIONE
    /// RISERVATA" as an image-credit caption ("Papa Leone -
    /// RIPRODUZIONE RISERVATA") that sits near the top of the page —
    /// truncating there would eat the article. The real
    /// article-ending line always carries `©` / `&copy;`, so this
    /// tightening loses nothing.
    private static let terminatorMarkers: [String: [String]] = [
        "it": [
            "© riproduzione riservata",
            "©riproduzione riservata",
            "riproduzione riservata ©",
            "riproduzione riservata &copy;",
            "riproduzione riservata&copy;"
        ]
    ]
}
