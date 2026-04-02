//
//  AppLogger.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

enum AppLogLevel: Int, CaseIterable, Sendable {
    case trace = 0
    case debug = 1
    case info = 2
    case warn = 3
    case error = 4
    case fatal = 5

    var label: String {
        switch self {
        case .trace:
            return "TRACE"
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warn:
            return "WARN"
        case .error:
            return "ERROR"
        case .fatal:
            return "FATAL"
        }
    }

    var icon: String {
        switch self {
        case .trace:
            return "🔍"
        case .debug:
            return "🛠️"
        case .info:
            return "ℹ️"
        case .warn:
            return "⚠️"
        case .error:
            return "❌"
        case .fatal:
            return "💀"
        }
    }

    var displayName: String {
        "\(icon) \(label)"
    }
}

enum AppLogCategory: String, CaseIterable, Sendable {
    case system
    case api
    case auth
    case database
    case cache
    case queue
    case ui
    case business
    case security
    case performance
    case filesystem
    case email
    case notification
    case analytics

    var label: String {
        switch self {
        case .system:
            return "SYSTEM"
        case .api:
            return "API"
        case .auth:
            return "AUTH"
        case .database:
            return "DATABASE"
        case .cache:
            return "CACHE"
        case .queue:
            return "QUEUE"
        case .ui:
            return "UI"
        case .business:
            return "BUSINESS"
        case .security:
            return "SECURITY"
        case .performance:
            return "PERFORMANCE"
        case .filesystem:
            return "FILESYSTEM"
        case .email:
            return "EMAIL"
        case .notification:
            return "NOTIFICATION"
        case .analytics:
            return "ANALYTICS"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "🖥️"
        case .api:
            return "🌐"
        case .auth:
            return "🔐"
        case .database:
            return "🗄️"
        case .cache:
            return "🧠"
        case .queue:
            return "📨"
        case .ui:
            return "🎨"
        case .business:
            return "💼"
        case .security:
            return "🛡️"
        case .performance:
            return "⚡"
        case .filesystem:
            return "📁"
        case .email:
            return "✉️"
        case .notification:
            return "🔔"
        case .analytics:
            return "📊"
        }
    }

    var displayName: String {
        "\(icon) \(label)"
    }
}

struct AppLogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: AppLogLevel
    let category: AppLogCategory
    let service: String
    let file: String
    let line: Int
    let function: String
    let requestID: String?
    let message: String
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: AppLogLevel,
        category: AppLogCategory,
        service: String,
        file: String,
        line: Int,
        function: String,
        requestID: String?,
        message: String,
        metadata: [String: String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.service = service
        self.file = AppLogEntry.fileName(from: file)
        self.line = line
        self.function = function
        self.requestID = requestID
        self.message = message
        self.metadata = metadata
    }

    var formattedLine: String {
        formattedLine(timeZone: .current)
    }

    func formattedLine(timeZone: TimeZone) -> String {
        let timestampChunk = "[\(Self.formattedTimestamp(timestamp, timeZone: timeZone))]"
        let levelChunk = "[\(level.displayName)]"
        let categoryChunk = "[\(category.displayName)]"
        let serviceChunk = "[\(service)]"
        let locationChunk = "[\(file):\(line)]"
        let functionChunk = "[\(function)]"
        let requestChunk = "[\(requestID ?? "-")]"

        let metadataChunk: String
        if metadata.isEmpty {
            metadataChunk = ""
        } else {
            let serializedPairs = metadata
                .sorted { lhs, rhs in lhs.key < rhs.key }
                .map { key, value in
                    "\(Self.cleanMetadataToken(key))=\(Self.cleanMetadataValue(value))"
                }
                .joined(separator: " ")
            metadataChunk = " | \(serializedPairs)"
        }

        return "\(timestampChunk)\(levelChunk)\(categoryChunk)\(serviceChunk)\(locationChunk)\(functionChunk)\(requestChunk) \(message)\(metadataChunk)"
    }

    private static func fileName(from file: String) -> String {
        URL(fileURLWithPath: file).lastPathComponent
    }

    private static func formattedTimestamp(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents(
            [.day, .month, .year, .hour, .minute, .second, .nanosecond],
            from: date
        )

        let day = components.day ?? 0
        let month = components.month ?? 0
        let year = components.year ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let millisecond = (components.nanosecond ?? 0) / 1_000_000

        return String(
            format: "%02d-%02d-%04d %02d:%02d:%02d.%03d",
            day,
            month,
            year,
            hour,
            minute,
            second,
            millisecond
        )
    }

    private static func cleanMetadataToken(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "unknown" }
        return trimmed.replacingOccurrences(of: " ", with: "_")
    }

    private static func cleanMetadataValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        if escaped.contains(" ") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

final class AppLogStore: @unchecked Sendable {
    nonisolated static let shared = AppLogStore(maxEntries: 5_000)

    private let maxEntries: Int
    private var entries: [AppLogEntry] = []
    private let lock = NSLock()

    init(maxEntries: Int) {
        self.maxEntries = maxEntries
    }

    nonisolated func append(_ entry: AppLogEntry) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    nonisolated func entryCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    nonisolated func entriesSnapshot() -> [AppLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    nonisolated func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll(keepingCapacity: true)
    }
}

struct AppLogger: Sendable {
    nonisolated static let shared = AppLogger(store: .shared)

    private let store: AppLogStore
    private let minimumLevel: AppLogLevel

    nonisolated init(
        store: AppLogStore,
        minimumLevel: AppLogLevel = AppLogger.defaultMinimumLevel
    ) {
        self.store = store
        self.minimumLevel = minimumLevel
    }

    nonisolated func trace(
        _ message: String,
        category: AppLogCategory,
        service: String,
        requestID: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        log(
            level: .trace,
            category: category,
            service: service,
            requestID: requestID,
            message: message,
            metadata: metadata,
            file: file,
            line: line,
            function: function
        )
    }

    nonisolated func debug(
        _ message: String,
        category: AppLogCategory,
        service: String,
        requestID: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        log(
            level: .debug,
            category: category,
            service: service,
            requestID: requestID,
            message: message,
            metadata: metadata,
            file: file,
            line: line,
            function: function
        )
    }

    nonisolated func info(
        _ message: String,
        category: AppLogCategory,
        service: String,
        requestID: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        log(
            level: .info,
            category: category,
            service: service,
            requestID: requestID,
            message: message,
            metadata: metadata,
            file: file,
            line: line,
            function: function
        )
    }

    nonisolated func warn(
        _ message: String,
        category: AppLogCategory,
        service: String,
        requestID: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        log(
            level: .warn,
            category: category,
            service: service,
            requestID: requestID,
            message: message,
            metadata: metadata,
            file: file,
            line: line,
            function: function
        )
    }

    nonisolated func error(
        _ message: String,
        category: AppLogCategory,
        service: String,
        requestID: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        log(
            level: .error,
            category: category,
            service: service,
            requestID: requestID,
            message: message,
            metadata: metadata,
            file: file,
            line: line,
            function: function
        )
    }

    nonisolated func fatal(
        _ message: String,
        category: AppLogCategory,
        service: String,
        requestID: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        log(
            level: .fatal,
            category: category,
            service: service,
            requestID: requestID,
            message: message,
            metadata: metadata,
            file: file,
            line: line,
            function: function
        )
    }

    nonisolated func entryCount() async -> Int {
        store.entryCount()
    }

    nonisolated func clear() async {
        store.clear()
    }

    nonisolated func exportText(minimumLevel: AppLogLevel? = nil) async -> String {
        let entries = store.entriesSnapshot()
        let filteredEntries: [AppLogEntry]
        if let minimumLevel {
            filteredEntries = entries.filter { $0.level.rawValue >= minimumLevel.rawValue }
        } else {
            filteredEntries = entries
        }
        return filteredEntries.map(\.formattedLine).joined(separator: "\n")
    }

    nonisolated func exportToTemporaryFile(minimumLevel: AppLogLevel? = nil) async throws -> URL {
        let logText = await exportText(minimumLevel: minimumLevel)
        let output = logText.isEmpty ? "No logs collected yet." : logText
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MercuryLogs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let timestamp = Self.exportTimestamp(Date())
        let fileURL = directory.appendingPathComponent("mercury-logs-\(timestamp).log")
        try Data(output.utf8).write(to: fileURL, options: .atomic)
        return fileURL
    }

    nonisolated private func log(
        level: AppLogLevel,
        category: AppLogCategory,
        service: String,
        requestID: String?,
        message: String,
        metadata: [String: String],
        file: String,
        line: Int,
        function: String
    ) {
        guard level.rawValue >= minimumLevel.rawValue else { return }

        let entry = AppLogEntry(
            level: level,
            category: category,
            service: service,
            file: file,
            line: line,
            function: function,
            requestID: requestID,
            message: message,
            metadata: metadata
        )

        store.append(entry)

#if DEBUG
        print(entry.formattedLine)
#endif
    }

    nonisolated private static var defaultMinimumLevel: AppLogLevel {
#if DEBUG
        .trace
#else
        .info
#endif
    }

    nonisolated private static func exportTimestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return String(
            format: "%04d%02d%02d-%02d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}
