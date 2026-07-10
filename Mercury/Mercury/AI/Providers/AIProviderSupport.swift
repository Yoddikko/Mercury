//
//  AIProviderSupport.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

typealias AIProviderRequestExecutor = @Sendable (URLRequest) async throws -> (Data, URLResponse)

enum AIProviderSupport {
    nonisolated static func providerRequestExecutor() -> AIProviderRequestExecutor {
        { request in
            try await URLSession.shared.data(for: request)
        }
    }

    nonisolated static func performRequest(
        _ request: URLRequest,
        requestID: String?,
        service: String,
        logger: AppLogger,
        performRequest: AIProviderRequestExecutor
    ) async throws -> Data {
        let start = DispatchTime.now().uptimeNanoseconds

        logger.debug(
            "Starting provider request",
            category: .api,
            service: service,
            requestID: requestID,
            metadata: [
                "url": request.url?.absoluteString ?? "missing",
                "method": request.httpMethod ?? "GET"
            ]
        )

        do {
            // Make an owned copy before crossing the async boundary to avoid
            // lifetime issues with borrowed URLRequest storage.
            let requestCopy = request
            let (data, response) = try await performRequest(requestCopy)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error(
                    "Provider response was not HTTP",
                    category: .api,
                    service: service,
                    requestID: requestID
                )
                throw AIProviderError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                logger.warn(
                    "Provider request failed with non-2xx status",
                    category: .api,
                    service: service,
                    requestID: requestID,
                    metadata: [
                        "status_code": "\(httpResponse.statusCode)"
                    ]
                )
                throw mapHTTPStatusCode(httpResponse.statusCode)
            }

            guard data.isEmpty == false else {
                logger.warn(
                    "Provider response was empty",
                    category: .api,
                    service: service,
                    requestID: requestID
                )
                throw AIProviderError.emptyResponse
            }

            logger.debug(
                "Provider request completed",
                category: .api,
                service: service,
                requestID: requestID,
                metadata: [
                    "status_code": "\(httpResponse.statusCode)",
                    "bytes": "\(data.count)",
                    "duration_ms": "\(elapsedMilliseconds(since: start))"
                ]
            )

            return data
        } catch let error as AIProviderError {
            throw error
        } catch let error as URLError {
            logger.warn(
                "Provider request failed with URL error",
                category: .api,
                service: service,
                requestID: requestID,
                metadata: [
                    "code": "\(error.code.rawValue)",
                    "error": error.localizedDescription
                ]
            )
            throw mapURLError(error)
        } catch {
            logger.error(
                "Provider request failed with unexpected error",
                category: .api,
                service: service,
                requestID: requestID,
                metadata: ["error": error.localizedDescription]
            )
            throw AIProviderError.networkFailure(error.localizedDescription)
        }
    }

    nonisolated static func encodeJSONBody(_ object: Any) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: object, options: [])
        } catch {
            throw AIProviderError.parsingFailure("Failed to encode request payload.")
        }
    }

    nonisolated static func decodeJSONObject(from data: Data) throws -> [String: Any] {
        do {
            let value = try JSONSerialization.jsonObject(with: data)
            guard let object = value as? [String: Any] else {
                throw AIProviderError.invalidResponse
            }
            return object
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.parsingFailure("Failed to decode JSON object from provider response.")
        }
    }

    nonisolated static func decodeJSONArray(from data: Data) throws -> [Any] {
        do {
            let value = try JSONSerialization.jsonObject(with: data)
            guard let array = value as? [Any] else {
                throw AIProviderError.invalidResponse
            }
            return array
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.parsingFailure("Failed to decode JSON array from provider response.")
        }
    }

    /// Extracts the first parseable JSON object from model output.
    /// Hardened for real-world model behavior (issue #138): prose
    /// around/before the JSON (reasoning fallbacks), stray braces in
    /// that prose, trailing commas, and output truncated mid-array by
    /// the token budget are all tolerated. On final failure a bounded
    /// prefix of the raw output is logged so an attached-console
    /// session shows exactly what the model sent.
    nonisolated static func parseJSONObjectString(from text: String) throws -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw AIProviderError.emptyResponse
        }

        var candidates: [String] = []
        candidates.append(contentsOf: balancedJSONObjectCandidates(in: trimmed))
        if let legacy = firstJSONObjectCandidate(in: trimmed) {
            candidates.append(legacy)
        }
        candidates.append(trimmed)
        if let repaired = repairedTruncatedJSON(in: trimmed) {
            candidates.append(repaired)
        }

        for candidate in candidates {
            if let object = decodedObject(from: candidate) {
                return object
            }
            if let object = decodedObject(from: strippingTrailingCommas(candidate)) {
                return object
            }
        }

        AppLogger.shared.warn(
            "Model output is not parseable JSON",
            category: .business,
            service: "AIProviderSupport",
            metadata: [
                "output_length": "\(trimmed.count)",
                "output_prefix": String(trimmed.prefix(300))
            ]
        )
        throw AIProviderError.parsingFailure("Invalid JSON in model output.")
    }

    nonisolated private static func decodedObject(from candidate: String) -> [String: Any]? {
        guard let data = candidate.data(using: .utf8) else { return nil }
        guard let value = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return value as? [String: Any]
    }

    /// Top-level `{…}` blocks found with a string/escape-aware depth
    /// scan, in order of appearance.
    nonisolated private static func balancedJSONObjectCandidates(
        in text: String,
        limit: Int = 5
    ) -> [String] {
        var candidates: [String] = []
        var depth = 0
        var inString = false
        var escaped = false
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex, candidates.count < limit {
            let character = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"":
                    inString = true
                case "{":
                    if depth == 0 { start = index }
                    depth += 1
                case "}":
                    if depth > 0 {
                        depth -= 1
                        if depth == 0, let startIndex = start {
                            candidates.append(String(text[startIndex...index]))
                            start = nil
                        }
                    }
                default:
                    break
                }
            }
            index = text.index(after: index)
        }
        return candidates
    }

    /// Recovers the object anchored at the first `{"` (a stray
    /// unbalanced prose brace before it poisons the depth scan above,
    /// but prose braces are almost never followed by a quote): cuts the
    /// incomplete trailing token at the last closed bracket, then closes
    /// whatever brackets the token budget left open.
    nonisolated private static func repairedTruncatedJSON(in text: String) -> String? {
        guard let start = text.range(of: "{\"")?.lowerBound ?? text.firstIndex(of: "{") else {
            return nil
        }
        var candidate = String(text[start...])
        if let lastClosed = candidate.lastIndex(where: { $0 == "}" || $0 == "]" }) {
            candidate = String(candidate[...lastClosed])
        }
        var stack: [Character] = []
        var inString = false
        var escaped = false
        for character in candidate {
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"": inString = true
                case "{", "[": stack.append(character)
                case "}", "]": _ = stack.popLast()
                default: break
                }
            }
        }
        let closers = stack.reversed().map { $0 == "{" ? "}" : "]" }.joined()
        return candidate + closers
    }

    /// Removes trailing commas before `}` / `]` — a common model slip
    /// that strict JSON parsing rejects.
    nonisolated private static func strippingTrailingCommas(_ text: String) -> String {
        text.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )
    }

    nonisolated static func normalizedSummary(from object: [String: Any]) throws -> AISummaryResult {
        let shortSummary = sanitizeText(object["shortSummary"] as? String)
        guard shortSummary.isEmpty == false else {
            throw AIProviderError.parsingFailure("Missing shortSummary.")
        }

        let bulletsCandidate = object["bullets"] as? [Any] ?? []
        let bullets = deduplicatedList(
            bulletsCandidate.compactMap { element in
                sanitizeText(element as? String)
            }
        )
        let resolvedBullets = Array(bullets.prefix(5))
        guard resolvedBullets.isEmpty == false else {
            throw AIProviderError.parsingFailure("Missing summary bullets.")
        }

        return AISummaryResult(shortSummary: shortSummary, bullets: resolvedBullets)
    }

    nonisolated static func normalizedCategory(from object: [String: Any]) throws -> AICategoryResult {
        let category = sanitizeText(object["category"] as? String)
        guard category.isEmpty == false else {
            throw AIProviderError.parsingFailure("Missing category.")
        }
        return AICategoryResult(category: category)
    }

    /// Parses the personal-picks response (issue #133): `picks` as an
    /// array of {id, interest, relevance} objects; malformed entries
    /// are dropped, relevance is clamped to 1-100.
    nonisolated static func normalizedPicks(from object: [String: Any]) throws -> [AIHeadlinePick] {
        guard let rawPicks = object["picks"] as? [Any] else {
            throw AIProviderError.parsingFailure("Missing picks array.")
        }
        return rawPicks.compactMap { rawPick -> AIHeadlinePick? in
            guard let pick = rawPick as? [String: Any] else { return nil }
            let id = sanitizeText(pick["id"] as? String)
            let interest = sanitizeText(pick["interest"] as? String)
            guard id.isEmpty == false, interest.isEmpty == false else { return nil }
            let relevance = (pick["relevance"] as? Int)
                ?? Int(pick["relevance"] as? Double ?? 0)
            return AIHeadlinePick(
                id: id,
                interest: interest,
                relevance: min(100, max(1, relevance))
            )
        }
    }

    /// Parses the headline-grouping response (issue #113): `groups` as
    /// an array of arrays of ids, dropping empties and one-element
    /// groups (singletons are implied by omission).
    nonisolated static func normalizedHeadlineGroups(from object: [String: Any]) throws -> [[String]] {
        guard let rawGroups = object["groups"] as? [Any] else {
            throw AIProviderError.parsingFailure("Missing groups array.")
        }
        return rawGroups.compactMap { rawGroup -> [String]? in
            guard let ids = rawGroup as? [Any] else { return nil }
            let cleaned = ids
                .compactMap { sanitizeText($0 as? String) }
                .filter { $0.isEmpty == false }
            return cleaned.count >= 2 ? cleaned : nil
        }
    }

    nonisolated static func normalizedTags(from object: [String: Any]) throws -> [String] {
        let tags = deduplicatedList(
            (object["tags"] as? [Any] ?? []).compactMap { element in
                sanitizeText(element as? String)
            }
        )
        let resolved = Array(tags.prefix(8))
        guard resolved.isEmpty == false else {
            throw AIProviderError.parsingFailure("Missing tags.")
        }
        return resolved
    }

    nonisolated static func ensureHTTPS(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw AIProviderError.invalidEndpoint(url.absoluteString)
        }
    }

    nonisolated static func validatedURL(from value: String, allowHTTP: Bool = false) throws -> URL {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AIProviderError.invalidEndpoint(value)
        }

        guard let scheme = url.scheme?.lowercased() else {
            throw AIProviderError.invalidEndpoint(value)
        }

        if allowHTTP {
            guard scheme == "http" || scheme == "https" else {
                throw AIProviderError.invalidEndpoint(value)
            }
        } else {
            guard scheme == "https" else {
                throw AIProviderError.invalidEndpoint(value)
            }
        }

        return url
    }

    nonisolated private static func firstJSONObjectCandidate(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        guard let end = text.lastIndex(of: "}") else { return nil }
        guard start < end else { return nil }
        return String(text[start...end])
    }

    nonisolated private static func deduplicatedList(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []
        output.reserveCapacity(values.count)

        for value in values {
            let normalized = value.lowercased()
            guard seen.contains(normalized) == false else { continue }
            seen.insert(normalized)
            output.append(value)
        }

        return output
    }

    nonisolated private static func sanitizeText(_ value: String?) -> String {
        guard let value else { return "" }
        let collapsed = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed
    }

    nonisolated private static func mapURLError(_ error: URLError) -> AIProviderError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .userAuthenticationRequired, .userCancelledAuthentication:
            return .unauthorized
        default:
            return .networkFailure(error.localizedDescription)
        }
    }

    nonisolated private static func mapHTTPStatusCode(_ code: Int) -> AIProviderError {
        switch code {
        case 401, 403:
            return .unauthorized
        case 408:
            return .timeout
        case 429:
            return .rateLimited
        default:
            return .httpStatusCode(code)
        }
    }

    nonisolated private static func elapsedMilliseconds(since start: UInt64) -> Int {
        let now = DispatchTime.now().uptimeNanoseconds
        let delta = now >= start ? now - start : 0
        return Int(delta / 1_000_000)
    }
}
