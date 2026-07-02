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

Article content arrives as HTML (RSS body or page-extracted). The detail screen renders it through a single native SwiftUI reader (`ArticleBlockListView`). The legacy `WKWebView` renderer was removed with issue #83.

### Native reader

* Parses the sanitized + distilled HTML into a typed `[ArticleBlock]` (paragraph, heading, image, list, quote, code) via `HTMLArticleBlockParser`.
* Renders each block with the matching SwiftUI view (`Text(AttributedString)`, `AsyncImage`, native bulleted layout, quote rail, monospaced scrollable code).
* SwiftSoup is the parser (`https://github.com/scinfu/SwiftSoup`, Apache-2.0). Chosen over `libxml2`-backed alternatives (Kanna, Fuzi) because it is pure Swift, robust against malformed RSS HTML, and exposes CSS-selector extraction.
* Falls back to `Text(displayBody)` when the parser yields no blocks (very short RSS-only articles), and to a placeholder when neither is available.

### Sanitization

* `<script>`, `<style>`, `<iframe>`, `<noscript>`, inline event handlers (`onclick=`, `onerror=`, …) and `javascript:` URLs are stripped at parse time.
* Tracking pixels (`<img width="1" height="1">` patterns) are removed.
* Sanitization runs **before** the block parser so the reader sees a trusted, script-free tree.

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
[ArticleHTMLSanitizer]               (render-time safety strip)
        │
        ▼
[Per-outlet extraction rule]         (issue #91 — FiveFilters-style,
        │                             matched by article host; hosts
        │                             with no rule skip this stage)
        │   • bodySelectors: narrow the document to the outlet's known
        │     article container (first matching selector wins; no match
        │     keeps the full document)
        │   • stripSelectors: remove outlet-specific chrome (ANSA
        │     Consentless CTA, Corriere paywall promos, Repubblica
        │     related-link blocks)
        │   • stripTextPatterns: regex text pass with the same
        │     paragraph / short-container policy as the locale stripper
        ▼
[Terminator truncation]              (issue #81 — script/style-aware)
        │   • cuts the HTML at the first visible occurrence of the
        │     per-language article terminator ("Riproduzione riservata"
        │     for it), skipping matches inside <script> / <style> blocks
        │     (ANSA embeds the marker in JS image-slider captions)
        ▼
[ArticleBoilerplateRemover]          (Readability heuristics)
        │   • negative-class strip (now includes paywall / bt-Subscribe /
        │     bt-abbonati / consentless / metered / premium-lock)
        │   • link-density filter (> 50% link chars, ≥ 3 links)
        │   • run-of-3+ consecutive single-link <p> strip (issue #81)
        │   • short-paragraph floor (< 25 chars without punctuation)
        ▼
[ArticleImageDeduplicator]           (SwiftSoup pass, #81 extended)
        │   • drop body <img> / <picture> whose normalized key equals the
        │     heroImageURL key (extension-stripped, size-suffix-stripped
        │     so `-1024x768` / `@2x` / `-mobile` all collapse to one key)
        │   • also match against `srcset` and nested `<source srcset>`
        ▼
[ArticleLocaleBoilerplateStripper]   (language-aware text-pattern pass)
        │   • drops paragraphs matching localized patterns (it +
        │     ANSA Consentless / paywall CTAs; en: equivalents)
        ▼
Article.distilledBodyHTML            (persisted on the entity)
Article.cleanedContent               (re-derived from the distilled HTML)
Article.distillerVersion             (Int? — bump to force re-distillation on next access)
```

### Library strategy

Tiered, escalation-ready:

* **Tier 0 (shipped, no new dep)** — Mercury reproduces the three load-bearing Readability heuristics on top of the SwiftSoup we already ship:
  * negative class/id token strip (cookies, consent, share, related, outbrain, newsletter, sponsor, ad-, footer, sidebar, trending, modal, popup, plus common library names: iubenda, onetrust, didomi, quantcast, prompt-to-accept)
  * link-density filter (drops `div|section|aside|nav|ul|ol` whose text is >50% link)
  * text-length floor (drops `<p>` / `<li>` shorter than 25 chars with no terminal punctuation)
  Combined with the locale-aware boilerplate stripper and image deduplicator, this covers the user-cited fixture and the bulk of expected outlets without any new SPM dependency.
* **Tier 1 (escalation, not yet shipped)** — [`Ryu0118/swift-readability`](https://github.com/Ryu0118/swift-readability) (MIT, tagged releases, runs canonical Mozilla `Readability.js` inside a hidden `WKWebView`). Added if the Tier 0 heuristics fail on > 2/10 fixture outlets. Heavier (per-article WKWebView, async on main actor) but bug-compat with Firefox Reader.
* **Tier 2 (last resort)** — vendor [`lake-of-fire/swift-readability`](https://github.com/lake-of-fire/swift-readability) under `Mercury/Mercury/Vendor/Readability/`. It is a clean native Swift port of Mozilla Readability, but its `Package.swift` uses a local-path dependency on SwiftSoup so it is not installable as a remote SPM dependency without vendoring.

The original spec singled out lake-of-fire as the primary choice; investigation surfaced the local-path-dependency blocker, and the user-cited ANSA fixture is fully cleaned by Tier 0 already, so Tier 0 ships first.

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

The hero image is selected from RSS `media:content` / `<enclosure>` / `og:image` and rendered separately above the title. Outlets commonly include the same image again as the first `<img>` / `<picture>` of the article body. The dedup pass drops that body image when its normalized key matches the hero. Normalization (issue #81):

* Strip query string and fragment.
* Strip file extension so `hero.jpg` and `hero.webp` share a key.
* Strip trailing CDN size suffixes (`-1024x768`, `_800w`, `@2x`, `@3x`, `-large`, `-medium`, `-small`, `-mobile`, `-desktop`, `-tablet`, `-thumb`, `-thumbnail`, `-hero`, `-main`).
* Lowercase basename.

The dedup also walks `<picture><source srcset>` and image `srcset` attributes — outlets often declare the hero across multiple resolutions inside a `<picture>`; without srcset-aware matching the wrapper would survive.

### Article terminator truncation (issue #81)

Most Italian outlets end the article body with `Riproduzione riservata` / `© RIPRODUZIONE RISERVATA`. Everything after is chrome (newsletter CTAs, related-article grids, subscribe prompts, share strips). Truncating at the first visible occurrence of that marker (before the Readability pass runs) is by far the highest-ROI Italian cleanup — one match kills a long chain of downstream widgets.

The truncation is `<script>` / `<style>` / `<!-- -->`-aware: ANSA embeds the same marker inside a JS image-slider caption near the top of the page, and a naïve search would cut everything after. The pass walks the HTML once, tracks whether the current position is inside a script/style/comment block, and only records offsets in the visible content stream. If no visible terminator is present, the input passes through unchanged.

### Per-outlet extraction rules (issue #91)

A declarative, FiveFilters-style rule layer runs **before** the generic
Readability pass. Rules are **data, not code**: they live in
`Mercury/Resources/ExtractionRules/ArticleOutletExtractionRules.json`
(bundled with the app, decoded once per process by
`ArticleOutletRuleCatalog`), so adding an outlet never touches the
pipeline. A JSON resource was chosen over a Swift static table because
the rule fields (CSS selectors, regex strings, host lists) are pure
data with no behavior, the format mirrors `fivefilters/ftr-site-config`
entries (making translation mechanical — the Repubblica rule is a
direct port of `.repubblica.it.txt`), and a decode failure degrades
safely to the generic pipeline instead of a compile error. Everything
stays on-device — no server-side extraction, no remote rule fetch.

Each rule entry:

```json
{
  "id": "ansa",
  "hosts": ["ansa.it"],
  "bodySelectors": ["div[itemprop=articleBody]"],
  "stripSelectors": [".bt-Subscribe", ".prompt-to-accept"],
  "stripTextPatterns": ["\\babbonamento\\s+consentless\\b"],
  "paywallMarkers": ["\\bsolo\\s+per\\s+abbonati\\b"]
}
```

* `hosts` — lowercase host suffixes; `ansa.it` matches `www.ansa.it`
  and every other subdomain, never `notansa.it` or `ansa.it.evil.com`.
  When several rules match, the longest (most specific) rule host wins.
* `bodySelectors` — CSS selectors tried in order; the first that
  matches at least one element replaces the working document with the
  matched element(s). No match keeps the full document, so an outlet
  template change can never blank an article (list multiple selectors
  to cover template variants, e.g. Corriere's `section.body-article`
  vs the older `.container-body-article`).
* `stripSelectors` — CSS selectors whose matches are removed
  (outlet-specific chrome the generic class heuristics cannot name).
* `stripTextPatterns` — case-insensitive regexes; matching `p`/`li`
  elements are always dropped, containers/headings only when their
  text is ≤ 80 chars (same policy as the locale stripper).

Seeded rules: **ANSA** (iubenda "Consentless" subscription CTA:
`.bt-Subscribe` / `.bt-abbonati` / `.prompt-to-accept`), **Corriere**
(metered-paywall chrome: `[id^=pno-]`, `.modal-access` variants),
**Repubblica** (related-link blocks: `.aside-story`,
`.limio-fr-related`; body selector ported from FiveFilters).

Adding a rule is a 4-step ritual:

1. Append an entry to `ArticleOutletExtractionRules.json` (translate
   the `fivefilters/ftr-site-config` entry if one exists — `body:`
   XPath becomes a CSS selector, `strip:`/`strip_id_or_class:` become
   `stripSelectors`).
2. Make sure a fixture for the outlet exists under
   `docs/rss/research/distiller-fixtures/` with its host set in
   `ItalianDistillationFixturesTests.fixtures` (every rule must be
   exercised by at least one fixture).
3. Pin the outlet's specific chrome as `bannedSubstrings` on that
   fixture.
4. Run `MercuryTests/ItalianDistillationFixturesTests` and
   `MercuryTests/ArticleOutletExtractionRulesTests`.

Rule application is applied at distill time by
`ArticleOutletRuleApplier` (SwiftSoup, never throws — parse failure
returns the input) and logged with rule id, matched body selector and
strip counts. Hosts with no rule skip the stage entirely, leaving the
generic pipeline unchanged.

### Realistic HTTP fetching (issue #82)

`ArticlePageClient` presents a Safari-on-iPhone `User-Agent` and prioritizes `it-IT` in `Accept-Language`. Prior fetches used `MercuryArticleClient/1.0`, which several Italian outlets fingerprinted into a lightweight / paywall-gated variant of the page. The realistic UA does not defeat cookie-consent chrome (still handled by the boilerplate remover) but it stops the outlet from serving a stripped body.

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
* **Italian fixture corpus** committed under `docs/rss/research/distiller-fixtures/` (18 outlets at time of writing): ANSA, la Repubblica, Corriere della Sera, Il Sole 24 Ore, Il Messaggero, Il Fatto Quotidiano, Il Post, Il Foglio, Il Giornale, Il Giorno, Il Manifesto, Open, Sky TG24, TG La7, Wired Italia, Avvenire, HuffPost Italia, Lettera43. Each fixture has a parameterized integration test in `MercuryTests/ItalianDistillationFixturesTests.swift` that pins (a) at least one keyword from the article title that MUST survive, (b) seven generic chrome substrings that MUST be absent. Adding a new fixture is a 3-step ritual: drop the HTML under `distiller-fixtures/<name>.html`, append a `FixtureSpec` to `Self.fixtures`, run the suite; if it fails, tune the heuristics until it passes. Pages with no static article body (live-coverage diretta pages, fully JS-rendered SPAs like Adnkronos / TGCom24, paywall preview-only pages) are skipped by design — the distiller cannot recover what isn't in the HTML.
* International corpus to follow (BBC, NYT, Reuters, Le Monde, Spiegel, El País).

### Out of scope

* Reader-style full-screen modal sheet (cosmetic; deferred).
* Translation pipeline.
* AI rewriting of the body.
* Removing distillation per-outlet via Settings (no current need).
