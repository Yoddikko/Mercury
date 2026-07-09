# Feature: Clustering (Event Detection)

## Description

Groups articles that refer to the same real-world event.

This feature reduces redundancy and improves readability.

---

## Shipped v1 — lexical topic aggregation (issue #109)

The embedding-based design below remains the target. The shipped v1
(`FeedTopicAggregationService`) powers the Home "Topics" feed with a
cheaper, fully on-device approximation:

* corpus: articles published in the **last 24 hours**
* features: TF-IDF vectors over diacritics-folded, stopword-filtered
  tokens (Italian + English stopwords) of `title + summaryShort`
* similarity: cosine; greedy agglomeration — an article joins the
  first cluster whose best member similarity ≥ **0.30**, else it
  starts a new cluster (prefer new cluster over wrong merge)
* lead selection: prefers hero image, then main outlet, then recency
* cluster ordering (importance, no personalization): distinct-outlet
  count desc → main-outlet lead → recency
* deterministic and unit-tested with fixture titles; no network, no
  provider dependency. Embeddings can replace the vectorizer without
  touching the pipeline shape.

### AI-first path (issue #113)

When an AI provider is configured, the Topics feed asks it first:
`AIProvider.groupHeadlines` receives `id<TAB>title` lines and answers
JSON-only groups of ids (validated: unknown ids dropped, each id used
once); `FeedTopicAggregationService.clusters(fromGroups:)` maps the
groups back to articles reusing the same lead selection and
coverage-based ordering. Any failure (no provider, no key, network,
malformed output) falls back silently to the lexical clustering above.
The UI marks AI-made groupings with a sparkles indicator.

---

## Inputs

* article embeddings
* article metadata (title, tags)

---

## Outputs

* clusterID assigned to article
* cluster object with:

  * articles[]
  * cluster summary (optional)

---

## Core Idea

Articles are grouped based on semantic similarity.

Two articles belong to the same cluster if:

* they talk about the same event
* similarity score exceeds a threshold

---

## Flow

1. Article embedding is generated
2. Compare embedding with existing articles
3. Calculate similarity score
4. If similarity > threshold:

   * assign to existing cluster
5. Else:

   * create new cluster

---

## Similarity Strategy

[Inferenza] Suggested approach:

* cosine similarity between embeddings

### Threshold Example

* 0.75 → same cluster
* < 0.75 → new cluster

---

## Cluster Structure

```swift
type Cluster = {
  id: String
  title: String
  articleIDs: [String]
  summary: String?
  mainTopic: String?
  createdAt: Date
}
```

---

## Rules

* Each article can belong to only one cluster
* Cluster must contain at least 1 article
* Avoid merging unrelated topics
* Prefer creating new cluster over incorrect merge

---

## Edge Cases

* identical articles → always same cluster
* breaking news evolving → may update cluster
* small variations → still same cluster
* ambiguous similarity → create new cluster

---

## Notes

* Clustering improves:

  * UX (less duplication)
  * summarization (multi-article)
* Can be computationally expensive → optimize
* Can run in background

---

## Optional Extensions

* cluster-level summarization
* timeline tracking (event evolution)
* cluster ranking (importance)
