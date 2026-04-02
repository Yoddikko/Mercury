//
//  AIPromptBuilder.swift
//  Mercury
//
//  Created by Codex on 02/04/26.
//

import Foundation

enum AIPromptBuilder {
    static func summaryPrompt(for content: String) -> String {
        """
        Summarize the article using only the text provided below.

        Rules:
        - Do not invent facts.
        - Keep short summary <= 3 sentences.
        - Generate 3 to 5 concise bullets.
        - Return JSON only.

        JSON schema:
        {
          "shortSummary": "string",
          "bullets": ["string", "string", "string"]
        }

        Article:
        \(content)
        """
    }

    static func categoryPrompt(for content: String) -> String {
        """
        Classify the article into one category using only the text provided below.

        Allowed categories:
        Technology, Business, Politics, Economy, Science, World, Sports, Culture, Health

        Rules:
        - Exactly one category.
        - Return JSON only.

        JSON schema:
        {
          "category": "string"
        }

        Article:
        \(content)
        """
    }

    static func tagsPrompt(for content: String) -> String {
        """
        Extract concise tags from the article using only the text provided below.

        Rules:
        - Return 3 to 8 tags.
        - Deduplicate semantically equivalent tags.
        - Keep tags short.
        - Return JSON only.

        JSON schema:
        {
          "tags": ["string", "string", "string"]
        }

        Article:
        \(content)
        """
    }
}

