//
//  AppLoggerTests.swift
//  MercuryTests
//
//  Created by Codex on 01/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct AppLoggerTests {
    @Test
    func formattedLineContainsExpectedStructure() {
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = utc

        let timestamp = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 4,
                day: 1,
                hour: 12,
                minute: 34,
                second: 56,
                nanosecond: 789_000_000
            )
        )!

        let entry = AppLogEntry(
            timestamp: timestamp,
            level: .info,
            category: .api,
            service: "RSSFeedClient",
            file: "/tmp/RSSFeedClient.swift",
            line: 88,
            function: "fetchFeedData(from:requestID:)",
            requestID: "req-123",
            message: "Completed request",
            metadata: [
                "status_code": "200",
                "duration_ms": "42"
            ]
        )

        let line = entry.formattedLine(timeZone: utc)

        #expect(
            line ==
            "[01-04-2026 12:34:56.789][ℹ️ INFO][🌐 API][RSSFeedClient][RSSFeedClient.swift:88][fetchFeedData(from:requestID:)][req-123] Completed request | duration_ms=42 status_code=200"
        )
    }

    @Test
    func exportRespectsStoreLimitAndClearEmptiesEntries() async {
        let store = AppLogStore(maxEntries: 2)
        let logger = AppLogger(store: store, minimumLevel: .trace)

        await store.append(
            AppLogEntry(
                level: .debug,
                category: .system,
                service: "TestService",
                file: #fileID,
                line: #line,
                function: #function,
                requestID: nil,
                message: "first",
                metadata: [:]
            )
        )

        await store.append(
            AppLogEntry(
                level: .info,
                category: .system,
                service: "TestService",
                file: #fileID,
                line: #line,
                function: #function,
                requestID: nil,
                message: "second",
                metadata: [:]
            )
        )

        await store.append(
            AppLogEntry(
                level: .warn,
                category: .system,
                service: "TestService",
                file: #fileID,
                line: #line,
                function: #function,
                requestID: nil,
                message: "third",
                metadata: [:]
            )
        )

        let exported = await logger.exportText()
        let lines = exported.split(separator: "\n")

        #expect(lines.count == 2)
        #expect(lines[0].contains("second"))
        #expect(lines[1].contains("third"))

        await logger.clear()
        let afterClear = await logger.exportText()
        #expect(afterClear.isEmpty)
    }
}
