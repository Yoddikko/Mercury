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
* `RSSParser` (parse RSS/Atom items)
* `ArticleNormalizer` (map raw items to `Article` + per-feed dedup)
* `FeedRefreshService` (run grouped checks + cross-feed dedup)

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
