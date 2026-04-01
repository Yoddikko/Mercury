//
//  RSSFeedClient.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

struct RSSFeedClient: Sendable {
    private let userAgent = "MercuryRSSClient/1.0"
    private let logger = AppLogger.shared

    func fetchFeedData(from url: URL, requestID: String? = nil) async throws -> Data {
        logger.debug(
            "Starting feed request",
            category: .api,
            service: "RSSFeedClient",
            requestID: requestID,
            metadata: ["url": url.absoluteString]
        )

        guard url.scheme?.lowercased() == "https" else {
            logger.warn(
                "Rejected non-HTTPS feed URL",
                category: .security,
                service: "RSSFeedClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw RSSFeedClientError.insecureTransport
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error(
                "Feed response was not HTTP",
                category: .api,
                service: "RSSFeedClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw RSSFeedClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.warn(
                "Feed request failed with non-2xx status",
                category: .api,
                service: "RSSFeedClient",
                requestID: requestID,
                metadata: [
                    "url": url.absoluteString,
                    "status_code": "\(httpResponse.statusCode)"
                ]
            )
            throw RSSFeedClientError.httpStatusCode(httpResponse.statusCode)
        }

        guard data.isEmpty == false else {
            logger.warn(
                "Feed request returned empty payload",
                category: .api,
                service: "RSSFeedClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw RSSFeedClientError.emptyResponseData
        }

        logger.debug(
            "Feed request completed",
            category: .api,
            service: "RSSFeedClient",
            requestID: requestID,
            metadata: [
                "url": url.absoluteString,
                "status_code": "\(httpResponse.statusCode)",
                "bytes": "\(data.count)"
            ]
        )

        return data
    }
}
