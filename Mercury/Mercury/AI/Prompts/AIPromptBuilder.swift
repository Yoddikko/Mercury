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
        - If the text begins with a "LANGUAGE:" line, write shortSummary \
        and bullets in that language and ignore the line itself; \
        otherwise use the article's own language.
        - The text may contain multiple articles from different outlets \
        about the same story: in that case summarize the STORY as a \
        whole, merging the facts.
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

    /// Ranks headlines against the user's interests (issue #133).
    /// Input lines are `id<TAB>title`; the model answers JSON-only
    /// picks so the app can map them back to articles.
    static func personalPicksPrompt(interests: [String], headlines: String) -> String {
        """
        You are a personal news editor. From the headlines below, pick \
        the ones genuinely relevant to the reader's interests. Be \
        selective - skip weak matches.

        Reader interests: \(interests.joined(separator: ", "))

        Rules:
        - Each input line is: id<TAB>headline.
        - Pick at most 30 headlines; use only ids from the input.
        - Use each id at most once.
        - "interest" must be one of the reader's interests, verbatim.
        - "relevance" is an integer 1-100 (100 = perfect match).
        - Return JSON only.

        JSON schema:
        {
          "picks": [{"id": "id", "interest": "interest", "relevance": 80}]
        }

        Headlines:
        \(headlines)
        """
    }

    /// Groups news headlines by story/topic (issue #113). Input lines
    /// are `id<TAB>title`; the model must answer JSON-only with groups
    /// of ids so the app can map them back to articles.
    static func headlineGroupingPrompt(for headlines: String) -> String {
        """
        You are a newswire editor. Group the headlines below by story: \
        two headlines belong to the same group ONLY if they clearly \
        report the same fact or topic. Do not force groups - when in \
        doubt, leave a headline alone.

        Rules:
        - Each input line is: id<TAB>headline.
        - Use each id at most once.
        - Only include groups with 2 or more ids (singletons are implied).
        - Use only ids from the input. Do not invent ids.
        - Return JSON only.

        JSON schema:
        {
          "groups": [["id", "id"], ["id", "id", "id"]]
        }

        Headlines:
        \(headlines)
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

