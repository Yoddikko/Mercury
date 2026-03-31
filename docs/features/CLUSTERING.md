# Feature: Clustering (Event Detection)

## Description

Groups articles that refer to the same real-world event.

This feature reduces redundancy and improves readability.

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
