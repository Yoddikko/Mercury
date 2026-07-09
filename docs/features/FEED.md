# Feature: Feed

## Description

Displays a list of articles ranked and filtered based on logic and user preferences.

---

## Inputs

* articles (from SwiftData)
* user preferences
* interaction history

---

## Outputs

* ordered list of articles

---

## Feed Types

### 1. Default Feed

* chronological order
* newest first

---

### 2. Personalized Feed

* ranked based on:

  * preferred categories
  * preferred topics
  * past interactions

---

### 3. Topic Feed (shipped v1, issue #109)

* second Home feed, selectable via a paper-styled segmented control at
  the top of the Home screen (`Latest` / `Topics`)
* groups the articles of the **last 24 hours** by story/topic using
  on-device lexical clustering (see `docs/features/CLUSTERING.md`
  § Shipped v1) — no user preferences, no provider calls
* importance without personalization: clusters are ordered by the
  number of **distinct outlets** covering the story (many outlets ⇒
  important world/local news), with a main-outlet boost and recency as
  tie-breaks
* aggregated cluster card: the **lead article** shows headline,
  metadata and a small thumbnail (only the lead gets an image); the
  other covering articles are listed **title-only**, each tappable,
  with an uppercase mono coverage badge ("N testate") making the
  aggregation explicit
* single-article topics fall into a trailing title-only "More news"
  section
* the topics corpus is the full last-24h window fetched from the
  local cache (up to 300 rows, source allow-list applied) - not just
  the articles currently displayed (issue #117); the AI grouper sees
  the newest 80 headlines and ungrouped articles become singletons
* tapping an aggregated story opens a dedicated list of ALL its
  articles (lead first) so the user picks which outlet to read;
  pull-to-refresh re-aggregates and retries the AI path (e.g. right
  after configuring a provider)
* aggregation runs off the main thread; the Topics tab shows a
  dedicated loading state ("grouping the news by topic…") while it
  computes
* when an AI provider is configured, grouping goes through the
  provider first (issue #113, see `CLUSTERING.md` § AI-first path) and
  the list shows a small sparkles "Grouped with AI" indicator; any
  provider failure falls back silently to the lexical clustering

---

## Ranking Logic

Score is based on:

* recency
* category match
* topic match
* engagement signals

[Inferenza] exact weighting can evolve

---

## Flow

1. Load articles from SwiftData
2. Filter based on user settings
3. Apply ranking algorithm
4. Remove duplicates (optional)
5. Return ordered list

---

## Cache Replay & Retention (issue #94)

The cold-start replay (`HomeViewModel.loadCachedArticles`) and search
(`SearchViewModel`) apply the same Feed sources preferences as the
network fetch, via `RSSSourceFilter.makeArticleAllowList`:

* `Article` / `ArticleEntity` carry a nullable `sourceID` — the stable
  `RSSFeedSource.id` stamped by `ArticleNormalizer` at ingest. The field
  is additive, so SwiftData migrates existing stores lightweight-ly.
* Rows with a `sourceID` are matched against the resolved outlet ids.
  Legacy rows (`sourceID == nil`) fall back to matching `sourceName`
  against the resolved outlets' display names.
* When the preferences impose no filter (no enabled regions and no
  hidden sources — the pre-onboarding state), replay stays unfiltered.

`ArticleCacheMaintenanceService` owns cache cleanup:

* **Purge on preference change** — every persisted region/outlet toggle
  in `FeedSourcesViewModel` deletes cached articles from now-disabled
  sources (best-effort; the replay filter still hides leftovers if the
  purge fails).
* **Retention sweep** — at refresh time, non-favorite cached articles
  whose `createdAt` (ingest time) is older than 30 days are deleted
  (`defaultRetentionDays`). `createdAt` is used instead of `publishedAt`
  because unparsable feed dates persist as `.distantPast`.
* Favorited articles (`isBookmarked == true`) are **never** deleted by
  either operation.

All maintenance operations log purged-row counts through `AppLogger`
(`cache` category) with request-id propagation.

---

## RSS Ingestion (Debug)

Debug mode includes a dedicated RSS diagnostics flow to validate ingestion quality
without changing the production Home feed UI.

### Components

* `RSSFeedClient` (download XML feed data)
* `RSSParser` (parse RSS/Atom items with advanced metadata)
* `ArticleNormalizer` (map raw items to `Article` + per-feed dedup + quality heuristics)
* `ArticlePageClient` (download HTML pages for article URLs when RSS body looks partial)
* `ArticlePageContentExtractor` (extract likely main body text + hero image from HTML)
* `ArticleContentEnrichmentService` (best-effort upgrade from RSS snippet to page body)
* `FeedRefreshService` (run grouped checks + cross-feed dedup; exposes
  `refreshFeed(...)` for the production Home pipeline and
  `runDiagnostics(...)` for the Developer Playground — both share the
  same fetch core so the per-source statuses always agree)
* `AppLogger` (structured diagnostics with request-id propagation)

### Parsed RSS Fields (Advanced)

The parser/normalizer attempts to extract, when available:

* canonical link and external ID (`guid` / Atom `id`)
* publish date and language
* author (`author`, `dc:creator`, Atom author name)
* categories/tags
* hero image URL (`media:*`, `enclosure`, `itunes:image`, first `<img>` fallback)
* full body candidates (`content:encoded`, Atom content/fulltext fields)
* summary/description fallback when full body is unavailable

### Body Completeness Heuristic

For debug diagnostics, each normalized article includes a conservative signal for
whether the feed likely provides a complete body:

* source field used (`feed_content` vs `feed_summary`)
* extracted word count
* truncation hints (`read more`, trailing ellipsis)
* final `isContentLikelyComplete` flag for quick QA

When RSS body looks incomplete, the diagnostics pipeline attempts a best-effort
page extraction from `articleURL` and updates content source to `article_page`
only if the extracted body is meaningfully richer than the RSS payload.

### Group Modes

* all outlets (all documented sources)
* main outlets (subset marked as primary)
* by region (single selected region)

### Diagnostics Output

For each run, the debug screen reports:

* successful feeds
* feeds with no feed URL / invalid URL
* request failures
* parse failures
* feeds with zero normalized articles
* deduplicated normalized article list
* debug log export (text file) for troubleshooting
* outlet-level diagnostics export (text report with per-outlet status)
* article inspection screen to review full fetched payload and field checks
* article-level quality checks (author/image/body completeness)

This is used to quickly verify source coverage, parser behavior, and feed health
across regions.

---

## Rules

* Feed must always return content (fallback to chronological)
* No empty feed unless no data exists
* Avoid showing duplicate articles
* Prefer fresh content

---

## Edge Cases

* no preferences → fallback to default feed
* no articles → show empty state
* broken ranking → fallback to chronological

---

## Notes

* Feed is the main entry point of the app
* Performance is critical
* Must work offline
