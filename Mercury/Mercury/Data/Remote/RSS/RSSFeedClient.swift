//
//  RSSFeedClient.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

struct RSSFeedClient: Sendable {
    private let userAgent = "MercuryRSSClient/1.0"

    func fetchFeedData(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else {
            throw RSSFeedClientError.insecureTransport
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RSSFeedClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw RSSFeedClientError.httpStatusCode(httpResponse.statusCode)
        }

        guard data.isEmpty == false else {
            throw RSSFeedClientError.emptyResponseData
        }

        return data
    }
}
