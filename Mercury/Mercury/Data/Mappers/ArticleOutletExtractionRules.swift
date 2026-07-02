//
//  ArticleOutletExtractionRules.swift
//  Mercury
//
//  Created by Claude on 02/07/26.
//

import Foundation

/// A FiveFilters-style declarative extraction rule for one outlet
/// (issue #91 / meta #80).
///
/// Rules are **data, not code**: they are decoded from
/// `ArticleOutletExtractionRules.json` in the app bundle, so adding an
/// outlet never requires touching the distillation pipeline. Where an
/// entry exists in `fivefilters/ftr-site-config` the rule is a direct
/// translation (XPath → CSS selector); hand-written otherwise, tuned
/// against the fixture corpus under `docs/rss/research/distiller-fixtures/`.
struct ArticleOutletExtractionRule: Sendable {
    /// Stable identifier used only for logging/diagnostics.
    let id: String
    /// Host suffixes the rule applies to (`"ansa.it"` matches
    /// `ansa.it`, `www.ansa.it`, `sport.ansa.it`, …). Stored lowercase.
    let hosts: [String]
    /// CSS selectors tried **in order**; the first one that matches at
    /// least one element replaces the working document with the
    /// matched element(s). No match → the full document is kept, so a
    /// template change can never blank an article.
    let bodySelectors: [String]
    /// CSS selectors whose matches are removed from the working
    /// document (outlet-specific chrome: consent CTAs, paywall
    /// promos, related-link blocks).
    let stripSelectors: [String]
    /// Case-insensitive regexes; elements whose text matches are
    /// removed with the same paragraph/short-container policy as
    /// `ArticleLocaleBoilerplateStripper`.
    let stripTextPatterns: [NSRegularExpression]
}

/// Loads, indexes and matches per-outlet extraction rules by article
/// host. Loading never throws — a malformed resource degrades to an
/// empty catalog (generic pipeline only) with an ERROR log.
struct ArticleOutletRuleCatalog: Sendable {
    let rules: [ArticleOutletExtractionRule]

    /// The catalog decoded from the bundled JSON resource. Decoded
    /// once per process.
    static let bundled: ArticleOutletRuleCatalog = loadBundled()

    init(rules: [ArticleOutletExtractionRule]) {
        self.rules = rules
    }

    /// Returns the rule for `host`, or `nil` when no rule applies
    /// (the caller then runs the generic pipeline unchanged).
    ///
    /// Matching is suffix-based on registrable-domain style keys: a
    /// rule host `ansa.it` matches `ansa.it` and any subdomain
    /// (`www.ansa.it`, `sport.ansa.it`) but never `notansa.it` or
    /// `ansa.it.evil.com`. When several rules match, the longest
    /// (most specific) rule host wins.
    func rule(forHost host: String?) -> ArticleOutletExtractionRule? {
        guard let normalized = Self.normalizedHost(host) else { return nil }

        var best: (rule: ArticleOutletExtractionRule, hostLength: Int)?
        for rule in rules {
            for ruleHost in rule.hosts {
                guard normalized == ruleHost || normalized.hasSuffix("." + ruleHost) else { continue }
                if ruleHost.count > (best?.hostLength ?? -1) {
                    best = (rule, ruleHost.count)
                }
            }
        }
        return best?.rule
    }

    /// Lowercases and trims a raw host; strips a trailing dot
    /// (`"www.ansa.it."` is valid DNS) and a port suffix. Returns
    /// `nil` for empty input.
    static func normalizedHost(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let colon = host.firstIndex(of: ":") {
            host = String(host[..<colon])
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        guard host.isEmpty == false else { return nil }
        return host
    }

    // MARK: - Bundled resource loading

    private static let resourceName = "ArticleOutletExtractionRules"

    static func loadBundled(logger: AppLogger = .shared) -> ArticleOutletRuleCatalog {
        // `Bundle(for:)` resolves the app bundle even when the caller
        // runs inside the unit-test bundle (tests are hosted in
        // Mercury.app, but the token class makes the lookup explicit
        // rather than relying on `Bundle.main`).
        let bundle = Bundle(for: ArticleOutletRuleCatalogBundleToken.self)
        guard let url = bundle.url(forResource: resourceName, withExtension: "json")
                ?? Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            logger.error(
                "Outlet extraction ruleset resource missing from bundle",
                category: .filesystem,
                service: "ArticleOutletRuleCatalog",
                metadata: ["resource": "\(resourceName).json"]
            )
            return ArticleOutletRuleCatalog(rules: [])
        }

        do {
            let data = try Data(contentsOf: url)
            return decode(data: data, logger: logger)
        } catch {
            logger.error(
                "Failed to read outlet extraction ruleset",
                category: .filesystem,
                service: "ArticleOutletRuleCatalog",
                metadata: [
                    "resource": "\(resourceName).json",
                    "error": String(describing: error)
                ]
            )
            return ArticleOutletRuleCatalog(rules: [])
        }
    }

    /// Decodes a ruleset from raw JSON data. Invalid regex patterns
    /// and empty-host rules are skipped with a WARN so one bad entry
    /// never disables the whole catalog.
    static func decode(data: Data, logger: AppLogger = .shared) -> ArticleOutletRuleCatalog {
        let file: RuleFileDTO
        do {
            file = try JSONDecoder().decode(RuleFileDTO.self, from: data)
        } catch {
            logger.error(
                "Failed to decode outlet extraction ruleset",
                category: .filesystem,
                service: "ArticleOutletRuleCatalog",
                metadata: ["error": String(describing: error)]
            )
            return ArticleOutletRuleCatalog(rules: [])
        }

        var rules: [ArticleOutletExtractionRule] = []
        rules.reserveCapacity(file.rules.count)
        for dto in file.rules {
            let hosts = dto.hosts
                .compactMap { normalizedHost($0) }
            guard hosts.isEmpty == false else {
                logger.warn(
                    "Skipping outlet extraction rule without hosts",
                    category: .business,
                    service: "ArticleOutletRuleCatalog",
                    metadata: ["rule_id": dto.id]
                )
                continue
            }

            var patterns: [NSRegularExpression] = []
            for pattern in dto.stripTextPatterns ?? [] {
                do {
                    patterns.append(try NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
                } catch {
                    logger.warn(
                        "Skipping invalid stripTextPattern in outlet extraction rule",
                        category: .business,
                        service: "ArticleOutletRuleCatalog",
                        metadata: ["rule_id": dto.id, "pattern": pattern]
                    )
                }
            }

            rules.append(
                ArticleOutletExtractionRule(
                    id: dto.id,
                    hosts: hosts,
                    bodySelectors: dto.bodySelectors ?? [],
                    stripSelectors: dto.stripSelectors ?? [],
                    stripTextPatterns: patterns
                )
            )
        }

        logger.info(
            "Outlet extraction ruleset loaded",
            category: .business,
            service: "ArticleOutletRuleCatalog",
            metadata: [
                "version": "\(file.version)",
                "rules": "\(rules.count)"
            ]
        )
        return ArticleOutletRuleCatalog(rules: rules)
    }

    // MARK: - DTOs

    private struct RuleFileDTO: Decodable {
        let version: Int
        let rules: [RuleDTO]
    }

    private struct RuleDTO: Decodable {
        let id: String
        let hosts: [String]
        let bodySelectors: [String]?
        let stripSelectors: [String]?
        let stripTextPatterns: [String]?
    }
}

/// Anchor class for bundle resolution — see `loadBundled`.
private final class ArticleOutletRuleCatalogBundleToken {}
