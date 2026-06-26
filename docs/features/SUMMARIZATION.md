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

## Trigger

* **On-demand only.** The summary is generated when the user taps a "Genera sintesi AI" button on the article detail screen.
* No automatic summarization on detail open, on feed refresh, or in the background.
* Once generated, the summary is cached on the article and the button becomes a "Rigenera" affordance.

---

## Flow

1. User taps the "Genera sintesi AI" button on the article detail screen
2. Article content is available
3. AI provider is selected
4. Summarization request is sent
5. Response is parsed
6. Article is updated in SwiftData
7. UI re-renders the cached summary; button switches to "Rigenera"

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

* Summarization runs asynchronously when the user requests it
* Cached results should be reused on subsequent opens (no re-call until user taps "Rigenera")
* Do not regenerate unless explicitly requested
