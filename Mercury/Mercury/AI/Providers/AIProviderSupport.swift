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

    nonisolated static func parseJSONObjectString(from text: String) throws -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw AIProviderError.emptyResponse
        }

        let candidate = firstJSONObjectCandidate(in: trimmed) ?? trimmed
        guard let data = candidate.data(using: .utf8) else {
            throw AIProviderError.parsingFailure("Failed to encode model output as UTF-8.")
        }

        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else {
            throw AIProviderError.parsingFailure("Model output JSON root is not an object.")
        }
        return object
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
