# Feature: Article

## Description

Represents a single news item in Mercury.

This is the core data model used across the entire application.

---

## Inputs

* RSS feed item
* extracted article content (optional)

---

## Outputs

* normalized article object
* stored local entity (SwiftData)

---

## Fields

```swift
type Article = {
  id: String
  title: String
  sourceName: String
  sourceURL: String
  articleURL: String
  publishedAt: Date
  
  rawContent: String?
  cleanedContent: String?
  
  summaryShort: String?
  summaryBullets: [String]?
  
  category: String?
  tags: [String]
  
  language: String?
  
  isBookmarked: Bool
  isRead: Bool
  
  clusterID: String?
  
  createdAt: Date
  updatedAt: Date
}
```

---

## Flow

1. RSS item is fetched
2. Article metadata is extracted
3. Article is normalized
4. If RSS body is partial, article page extraction may enrich body/image fields
5. Article is stored in SwiftData
6. AI enrichment may update fields later

---

## Rules

* `id` must be unique (prefer URL hash)
* `title` must never be empty
* `articleURL` must be valid
* `tags` default to empty array
* AI fields are optional and filled asynchronously

---

## Edge Cases

* duplicate articles → must be deduplicated
* missing content → still store metadata
* partial RSS snippet → keep it, then try best-effort page extraction
* invalid date → fallback to current date
* broken RSS → skip item

---

## Notes

* Article is the **single source of truth** for content
* All features (feed, AI, clustering) depend on this model

---

## Body Rendering

Article content arrives as HTML (RSS body or page-extracted). The detail screen renders it through **one of two modes** chosen by the user (see `docs/features/SETTINGS.md`):

### Mode A — Web (default)

* Renders the sanitized HTML in an embedded `WKWebView` wrapped as a SwiftUI `UIViewRepresentable`.
* Inline `<style>` provides system-font typography, link color, dark-mode support via `@media (prefers-color-scheme: dark)`.
* Dynamic height: the view reports its content height via a JS bridge so the outer SwiftUI `ScrollView` owns the scroll axis.
* Full fidelity: inline images, lists, blockquotes, links render as authored.

### Mode B — Native (opt-in)

* Parses the sanitized HTML into a typed `[ArticleBlock]` (paragraph, heading, image, list, quote, code).
* Renders each block with the matching SwiftUI view (`Text(AttributedString)`, `AsyncImage`, native bulleted layout, …).
* SwiftSoup is the parser (`https://github.com/scinfu/SwiftSoup`, Apache-2.0). Chosen over `libxml2`-backed alternatives (Kanna, Fuzi) because it is pure Swift, robust against malformed RSS HTML, and exposes CSS-selector extraction.

### Sanitization (both modes)

* `<script>`, `<style>`, `<iframe>`, `<noscript>`, inline event handlers (`onclick=`, `onerror=`, …) and `javascript:` URLs are stripped at parse time.
* Tracking pixels (`<img width="1" height="1">` patterns) are removed.
* Sanitization runs **before** the mode-specific renderer so both modes share the same trusted input.

### Persistence

* `Article.rawContent` continues to hold the sanitized HTML (no schema migration needed).
* `Article.cleanedContent` (plain text) remains the input for AI summarization and search; it is **not** what the detail screen renders.
