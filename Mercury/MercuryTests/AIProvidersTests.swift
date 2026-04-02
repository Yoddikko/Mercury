//
//  AIProvidersTests.swift
//  MercuryTests
//
//  Created by Codex on 02/04/26.
//

import Foundation
import Testing
@testable import Mercury

struct AIProvidersTests {
    @Test
    func openAIProviderExecutorReceivesStableRequestSnapshot() async throws {
        let responseData = Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"shortSummary\\":\\"Short summary\\",\\"bullets\\":[\\"One\\",\\"Two\\"]}"
                  }
                }
              ]
            }
            """.utf8
        )
        let observer = RequestObserver()

        let provider = OpenAIProvider(
            model: "gpt-test",
            token: "openai-token",
            timeoutSeconds: 10,
            performRequest: { request in
                await observer.capture(from: request)
                let responseURL = URL(string: "https://example.invalid/openai")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        _ = try await provider.summarizeArticle("Example article", requestID: "req-openai-stable-request")
        let snapshot = await observer.snapshot()

        #expect(snapshot.url == "https://api.openai.com/v1/chat/completions")
        #expect(snapshot.method == "POST")
        #expect(snapshot.authorizationHeader?.hasPrefix("Bearer ") == true)
    }

    @Test
    func openAIProviderBuildsRequestAndParsesSummary() async throws {
        let responseData = Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"shortSummary\\":\\"Short summary\\",\\"bullets\\":[\\"One\\",\\"Two\\",\\"Two\\"]}"
                  }
                }
              ]
            }
            """.utf8
        )

        let provider = OpenAIProvider(
            model: "gpt-test",
            token: "openai-token",
            timeoutSeconds: 10,
            performRequest: { _ in
                let responseURL = URL(string: "https://example.invalid/openai")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let result = try await provider.summarizeArticle("Example article", requestID: "req-openai")

        #expect(result.shortSummary == "Short summary")
        #expect(result.bullets == ["One", "Two"])
    }

    @Test
    func claudeProviderBuildsRequestAndParsesCategory() async throws {
        let responseData = Data(
            """
            {
              "content": [
                {
                  "type": "text",
                  "text": "{\\"category\\":\\"Politics\\"}"
                }
              ]
            }
            """.utf8
        )

        let provider = ClaudeProvider(
            model: "claude-test",
            token: "claude-token",
            timeoutSeconds: 10,
            performRequest: { _ in
                let responseURL = URL(string: "https://example.invalid/claude")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let result = try await provider.categorizeArticle("Example article", requestID: "req-claude")

        #expect(result.category == "Politics")
    }

    @Test
    func geminiProviderBuildsRequestAndParsesTags() async throws {
        let responseData = Data(
            """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      { "text": "{\\"tags\\":[\\"AI\\",\\"Markets\\",\\"AI\\"]}" }
                    ]
                  }
                }
              ]
            }
            """.utf8
        )

        let provider = GeminiProvider(
            model: "gemini-test",
            token: "gemini-token",
            timeoutSeconds: 10,
            performRequest: { _ in
                let responseURL = URL(string: "https://example.invalid/gemini")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let result = try await provider.generateTags("Example article", requestID: "req-gemini")

        #expect(result == ["AI", "Markets"])
    }

    @Test
    func ollamaProviderBuildsRequestAndParsesSummary() async throws {
        let responseData = Data(
            """
            {
              "response": "{\\"shortSummary\\":\\"Local summary\\",\\"bullets\\":[\\"One\\",\\"Two\\",\\"Three\\"]}",
              "done": true
            }
            """.utf8
        )

        let provider = OllamaProvider(
            model: "llama3.1:8b",
            token: nil,
            endpoint: "http://localhost:11434",
            timeoutSeconds: 10,
            performRequest: { _ in
                let responseURL = URL(string: "http://localhost:11434/api/generate")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseData, response)
            }
        )

        let result = try await provider.summarizeArticle("Example article", requestID: "req-ollama")

        #expect(result.shortSummary == "Local summary")
        #expect(result.bullets == ["One", "Two", "Three"])
    }

    @Test
    func providerMapsUnauthorizedStatus() async {
        let provider = OpenAIProvider(
            model: "gpt-test",
            token: "openai-token",
            timeoutSeconds: 10,
            performRequest: { _ in
                let responseURL = URL(string: "https://example.invalid/openai")!
                let response = HTTPURLResponse(
                    url: responseURL,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (Data("{}".utf8), response)
            }
        )

        do {
            _ = try await provider.categorizeArticle("Example article", requestID: "req-openai-unauthorized")
            Issue.record("Expected unauthorized error.")
        } catch let error as AIProviderError {
            #expect(error == .unauthorized)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

private actor RequestObserver {
    struct Snapshot {
        var url: String?
        var method: String?
        var authorizationHeader: String?
    }

    private var snapshotValue = Snapshot()

    func capture(from request: URLRequest) {
        snapshotValue.url = request.url?.absoluteString
        snapshotValue.method = request.httpMethod
        snapshotValue.authorizationHeader = request.value(forHTTPHeaderField: "Authorization")
    }

    func snapshot() -> Snapshot {
        snapshotValue
    }
}
