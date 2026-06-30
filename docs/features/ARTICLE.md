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
* `Article.distilledBodyHTML` (added by the Content Distillation pipeline below) holds the cleaned article body; both renderers read this field when present, falling back to `rawContent` when absent.
* `Article.cleanedContent` (plain text) remains the input for AI summarization and search; when distillation runs it is **re-derived** from `distilledBodyHTML` so AI features automatically receive clean input.

---

## Content Distillation

### Problem

Both `rawContent` (RSS-supplied) and the output of `ArticlePageContentExtractor` (best-effort page scrape) routinely include non-article material — cookie/consent banners, "related articles" widgets, share-button strips, newsletter CTAs, footer chrome, inline ads, and the hero image duplicated inside the body. Mercury today renders this noise verbatim. The distillation pipeline applies the same family of techniques used by Firefox Reader, Safari Reader, NetNewsWire / Reeder / Feedbin / Apple News (Mozilla Readability / Boilerpipe lineage) to keep only the article body.

### Pipeline

```
RSS body OR page-fetched HTML
        │
        ▼
[ArticleHTMLSanitizer]               (existing, render-time safety strip)
        │
        ▼
[ArticleReadabilityDistiller]        (NEW, ingest-time content extraction)
        │   • DOM scoring on top of SwiftSoup (Mozilla Readability algorithm)
        │   • returns main content root + title + byline + excerpt
        ▼
[ArticleImageDeduplicator]           (NEW, tiny SwiftSoup pass)
        │   • drop body <img> whose normalized basename equals the heroImageURL basename
        │   • normalization: lowercase host, strip query string, strip srcset, resolve relative
        ▼
[ArticleLocaleBoilerplateStripper]   (NEW, language-aware regex pass — optional)
        │   • drops paragraphs matching localized patterns
        │     (it: "Leggi anche", "Articoli correlati", "Iscriviti alla newsletter",
        │      "Riproduzione riservata", "Tutti i diritti riservati"; en: equivalents)
        ▼
Article.distilledBodyHTML            (persisted on the entity)
Article.cleanedContent               (re-derived from the distilled HTML)
Article.distillerVersion             (Int? — bump to force re-distillation on next access)
```

### Library

* **Primary**: [`lake-of-fire/swift-readability`](https://github.com/lake-of-fire/swift-readability) (BSD-3, native Swift port of Mozilla `Readability.js` on top of SwiftSoup — same dependency we already ship).
* **Fallback (deferred)**: [`Ryu0118/swift-readability`](https://github.com/Ryu0118/swift-readability) (MIT, runs the canonical Mozilla JS inside a hidden `WKWebView`). Adopted only if the fixture corpus shows the native port misbehaving on representative outlets.
* The choice is documented because the user-facing impact is large and the library risk is real (small star count on the primary port). We pin the version in `Package.resolved` and may vendor the source under `Mercury/Mercury/Vendor/Readability/` if upstream cadence becomes an issue.

### Trigger and timing

* Distillation runs **at ingest time** inside the existing `ArticleContentEnrichmentService`, NOT at render time. The cleaned body is cached on the `Article` and reused for every subsequent render.
* When the RSS body is already complete (no page fetch needed), distillation still runs on the RSS body so the cleaning is applied uniformly.
* Re-distillation is triggered on access whenever `Article.distillerVersion` is older than the build's current distiller version — this lets us roll out algorithm improvements without a global migration.

### Fallback chain

Distillation **must never** produce worse content than the existing pipeline:

1. Distiller returns body with ≥ 80 words **and** ≥ 1 `<p>` → use it.
2. Distiller returns short or empty → fall back to current `ArticlePageContentExtractor` output.
3. Both fail → fall back to the original `rawContent` (RSS body).
4. Every fallback logs the article URL and the reason, so per-outlet tuning is auditable.

### Image deduplication

The hero image is selected from RSS `media:content` / `<enclosure>` / `og:image` and rendered separately above the title. Outlets commonly include the same image again as the first `<img>` of the article body. The dedup pass drops that body image when its normalized basename matches the hero. Normalization:

* lowercase host, strip `?query` and `srcset`, resolve relative paths against the article URL, compare the final URL path's basename.

### Locale-aware boilerplate

Italian (and other localized) outlets embed boilerplate as ordinary `<p>` text that Readability's class/id heuristics do not catch (e.g., "Riproduzione riservata", "Iscriviti alla newsletter"). A localized regex pass runs after Readability, gated by `Article.language`. The pass:

* Always drops matching `<p>` and `<li>` elements (paragraph-level — these are nearly always boilerplate when text matches).
* Conditionally drops matching `<div>`, `<span>`, `<h1..h6>`, `<header>`, `<aside>` elements *only* when their text length is ≤ 80 characters. This catches standalone "Leggi anche" / "Articoli correlati" / "Più letti" widget headers (typically short labels) without wiping out long containers that legitimately mention a phrase in passing.

Patterns live in a per-locale table; the table starts with `it` and `en` only, and extends as new outlets reveal new boilerplate. Tuning is driven by the fixture corpus (see Acceptance below).

### Tuning: link density

The link-density filter (Readability heuristic #2) drops `<div|section|aside|nav|ul|ol>` whose text is more than 50% link characters. Two guards keep the filter from punishing legitimate article body wrappers:

* **At least 3 links** must be present before the filter runs (a paragraph with one inline `<a>` never triggers).
* **Non-link text ≥ 400 chars** exempts the element (substantial body content overrides density).

Both thresholds are tunable via `ArticleBoilerplateRemover.Options`.

### Trigger of AI features — UNCHANGED

Distillation improves the **input** to AI summarization (`Article.cleanedContent` is re-derived from the distilled body), but does NOT change the **trigger**. AI summary remains explicitly on-demand: the user must tap the "Genera sintesi AI" button on the article detail screen for any summarization to occur. See `docs/features/SUMMARIZATION.md` for the canonical contract.

### Acceptance

* The user-cited ANSA URL renders the article body only — no cookie banner, no "Leggi anche" sidebar, no share strip, no newsletter CTA, no duplicate hero image — in both Web and Native modes.
* `distillerVersion` is stamped on every distilled article so re-rolls are possible.
* Fallback fires (and is logged) on outlets where Readability collapses, never showing a blank or shorter article than the legacy extractor.
* **Italian fixture corpus** committed under `docs/rss/research/distiller-fixtures/` (12 outlets at time of writing): ANSA, la Repubblica, Corriere della Sera, Il Sole 24 Ore, Il Messaggero, Il Fatto Quotidiano, Il Post, Il Foglio, Open, Sky TG24, TG La7, Wired Italia. Each fixture has a parameterized integration test in `MercuryTests/ItalianDistillationFixturesTests.swift` that pins (a) at least one keyword from the article title that MUST survive, (b) seven generic chrome substrings that MUST be absent. Adding a new fixture is a 3-step ritual: drop the HTML under `distiller-fixtures/<name>.html`, append a `FixtureSpec` to `Self.fixtures`, run the suite; if it fails, tune the heuristics until it passes.
* International corpus to follow (BBC, NYT, Reuters, Le Monde, Spiegel, El País).

### Out of scope

* Reader-style full-screen modal sheet (cosmetic; deferred).
* Translation pipeline.
* AI rewriting of the body.
* Removing distillation per-outlet via Settings (no current need).
