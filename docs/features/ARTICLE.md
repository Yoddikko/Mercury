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
