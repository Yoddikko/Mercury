# Feature: Summarization

## Description

Generates concise summaries of articles using AI.

---

## Inputs

* cleanedContent

---

## Outputs

* summaryShort (string)
* summaryBullets (array of strings)

---

## Modes

### Short Summary

* 2–3 sentences
* captures main idea

---

### Bullet Summary

* 3–5 bullet points
* key facts only

---

## Flow

1. Article content is available
2. AI provider is selected
3. Summarization request is sent
4. Response is parsed
5. Article is updated in SwiftData

---

## Rules

* Do not hallucinate information
* Use only provided content
* Keep summaries concise
* Avoid repetition

---

## Edge Cases

* very short content → skip summarization
* empty content → no output
* AI failure → retry or skip
* malformed response → discard safely

---

## Notes

* Summarization runs asynchronously
* Cached results should be reused
* Do not regenerate unless needed
