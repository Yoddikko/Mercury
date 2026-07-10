//
//  TopicGroupsCache.swift
//  Mercury
//
//  Created by Claude on 10/07/26.
//

import Foundation

/// Persisted result of a topic aggregation (issue #127): only the
/// grouping STRUCTURE is stored — method, timestamp and groups as
/// arrays of article ids. Articles rehydrate from the SwiftData cache
/// through `FeedTopicAggregationService.clusters(fromGroups:)`, so the
/// payload stays tiny and survives relaunches for the TTL.
nonisolated struct TopicGroupsCacheEntry: Codable, Sendable {
    enum Method: String, Codable, Sendable {
        case lexical
        case ai
    }

    let savedAt: Date
    let method: Method
    let groups: [[String]]
}

/// UserDefaults-backed store for the last aggregation. The expensive
/// provider-backed grouping runs only when the entry is missing or
/// older than `ttl`; pull-to-refresh bypasses it explicitly.
nonisolated struct TopicGroupsCache: Sendable {
    /// How long a saved aggregation stays valid (user decision: half a
    /// day of news is an acceptable staleness for the Topics tab).
    static let ttl: TimeInterval = 12 * 60 * 60

    private static let key = "mercury.topics.groups.cache.v1"
    private let defaults: UserDefaults
    private let logger: AppLogger

    init(defaults: UserDefaults = .standard, logger: AppLogger = .shared) {
        self.defaults = defaults
        self.logger = logger
    }

    /// Returns the saved entry when present and younger than `ttl`.
    func loadFresh(now: Date = .now, requestID: String? = nil) -> TopicGroupsCacheEntry? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        guard let entry = try? JSONDecoder().decode(TopicGroupsCacheEntry.self, from: data) else {
            defaults.removeObject(forKey: Self.key)
            return nil
        }
        let age = now.timeIntervalSince(entry.savedAt)
        guard age >= 0, age < Self.ttl else {
            logger.debug(
                "Topics cache expired",
                category: .cache,
                service: "TopicGroupsCache",
                requestID: requestID,
                metadata: ["age_hours": String(format: "%.1f", age / 3600)]
            )
            return nil
        }
        logger.info(
            "Topics cache hit",
            category: .cache,
            service: "TopicGroupsCache",
            requestID: requestID,
            metadata: [
                "method": entry.method.rawValue,
                "groups": "\(entry.groups.count)",
                "age_hours": String(format: "%.1f", age / 3600)
            ]
        )
        return entry
    }

    func save(_ entry: TopicGroupsCacheEntry, requestID: String? = nil) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: Self.key)
        logger.debug(
            "Topics cache saved",
            category: .cache,
            service: "TopicGroupsCache",
            requestID: requestID,
            metadata: ["method": entry.method.rawValue, "groups": "\(entry.groups.count)"]
        )
    }
}
