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

* **On-demand only.** The summary is generated when the user taps the summary button on the article detail screen.
* No automatic summarization on detail open, on feed refresh, or in the background.
* **Cached summaries are never auto-displayed.** Even when a cached value exists from a previous tap, the section starts with the button visible. The label adapts:
  * "Mostra sintesi AI" when a cached summary is on disk → tap renders it **instantly**, no provider call.
  * "Genera sintesi AI" when no cache exists → tap calls the provider, then renders.
* Once shown, the section gains a "Rigenera" affordance that bypasses the cache and calls the provider.
* The AI Summary section is **always** rendered on the detail screen. When no provider is configured it shows a small "AI summary unavailable — configure a provider in Developer Tools" fallback instead of the button. **No other summary-shaped block ever renders on the detail screen** — the RSS `<summary>`/description that populates `Article.summaryShort` is used only in the feed preview card, never on the detail page.

---

## Flow

1. User taps the summary button on the article detail screen.
2. If a cached summary exists for this article → render it immediately, no provider call. Stop.
3. Otherwise:
    a. Article content is available
    b. AI provider is selected
    c. Summarization request is sent
    d. Response is parsed
    e. Article is updated in SwiftData
    f. UI renders the new summary; section gains a "Rigenera" affordance for force-refresh

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

* Summarization runs asynchronously when the user requests it.
* Cached results stay on disk; they are NEVER auto-rendered on detail open. The user must tap the button to display them. Tapping with cache present is free (no provider call).
* "Rigenera" is the only path that bypasses the cache and calls the provider for a fresh result.
* Do not regenerate unless explicitly requested.
