//
//  ArticlePageClient.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

struct ArticlePageClient: Sendable {
    private let userAgent = "MercuryArticleClient/1.0"
    private let maxHTMLBytes = 2_000_000
    private let logger: AppLogger
    private let performRequest: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    nonisolated init(
        logger: AppLogger = .shared,
        performRequest: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.logger = logger
        self.performRequest = performRequest
    }

    func fetchPageHTML(from url: URL, requestID: String? = nil) async throws -> String {
        logger.trace(
            "Starting article page request",
            category: .api,
            service: "ArticlePageClient",
            requestID: requestID,
            metadata: ["url": url.absoluteString]
        )

        guard url.scheme?.lowercased() == "https" else {
            logger.warn(
                "Rejected non-HTTPS article URL",
                category: .security,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw ArticlePageClientError.insecureTransport
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 14
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error(
                "Article response was not HTTP",
                category: .api,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw ArticlePageClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.warn(
                "Article request failed with non-2xx status",
                category: .api,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: [
                    "url": url.absoluteString,
                    "status_code": "\(httpResponse.statusCode)"
                ]
            )
            throw ArticlePageClientError.httpStatusCode(httpResponse.statusCode)
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if let contentType,
           contentType.contains("text/html") == false,
           contentType.contains("application/xhtml+xml") == false {
            logger.trace(
                "Article response is not HTML",
                category: .api,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: [
                    "url": url.absoluteString,
                    "content_type": contentType
                ]
            )
            throw ArticlePageClientError.nonHTMLResponse(contentType)
        }

        guard data.isEmpty == false else {
            logger.warn(
                "Article request returned empty payload",
                category: .api,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw ArticlePageClientError.emptyResponseData
        }

        guard data.count <= maxHTMLBytes else {
            logger.warn(
                "Article payload exceeded max HTML size",
                category: .api,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: [
                    "url": url.absoluteString,
                    "bytes": "\(data.count)",
                    "max_bytes": "\(maxHTMLBytes)"
                ]
            )
            throw ArticlePageClientError.payloadTooLarge(data.count)
        }

        guard let html = decodedHTMLString(from: data, response: httpResponse) else {
            logger.warn(
                "Article payload could not be decoded as string",
                category: .api,
                service: "ArticlePageClient",
                requestID: requestID,
                metadata: ["url": url.absoluteString]
            )
            throw ArticlePageClientError.undecodablePayload
        }

        logger.debug(
            "Article page request completed",
            category: .api,
            service: "ArticlePageClient",
            requestID: requestID,
            metadata: [
                "url": url.absoluteString,
                "status_code": "\(httpResponse.statusCode)",
                "bytes": "\(data.count)"
            ]
        )

        return html
    }

    private func decodedHTMLString(from data: Data, response: HTTPURLResponse) -> String? {
        if let textEncodingName = response.textEncodingName?.lowercased() {
            if textEncodingName.contains("utf-8"), let utf8 = String(data: data, encoding: .utf8) {
                return utf8
            }
            if textEncodingName.contains("iso-8859-1") || textEncodingName.contains("latin1"),
               let latin1 = String(data: data, encoding: .isoLatin1) {
                return latin1
            }
            if textEncodingName.contains("windows-1252"),
               let windows1252 = String(data: data, encoding: .windowsCP1252) {
                return windows1252
            }
        }

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        return String(data: data, encoding: .isoLatin1)
    }
}

enum ArticlePageClientError: Error, Sendable, Equatable {
    case insecureTransport
    case invalidResponse
    case httpStatusCode(Int)
    case nonHTMLResponse(String?)
    case emptyResponseData
    case payloadTooLarge(Int)
    case undecodablePayload
}
