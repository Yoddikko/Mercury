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

### 3. Clustered Feed (optional)

* group articles by event
* show one representative item per cluster

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

## RSS Ingestion (Debug)

Debug mode includes a dedicated RSS diagnostics flow to validate ingestion quality
without changing the production Home feed UI.

### Components

* `RSSFeedClient` (download XML feed data)
* `RSSParser` (parse RSS/Atom items with advanced metadata)
* `ArticleNormalizer` (map raw items to `Article` + per-feed dedup + quality heuristics)
* `FeedRefreshService` (run grouped checks + cross-feed dedup)
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
