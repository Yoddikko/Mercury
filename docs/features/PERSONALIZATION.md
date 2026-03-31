# Feature: Personalization

## Description

Adapts the news feed based on user preferences and behavior.

This feature enables:

* personalized ranking
* content filtering
* improved relevance
* better user experience over time

---

## Inputs

### Static Inputs

* user preferred categories
* user preferred topics (keywords)
* favorite sources
* hidden sources

### Dynamic Inputs

* interaction history:

  * article clicks
  * reading time
  * scroll depth
  * bookmarks

---

## Outputs

* ranked list of articles
* personalized feed
* optional recommendations

---

## Personalization Levels

### 1. Basic Personalization

* based on selected categories and topics
* static preferences only

---

### 2. Behavioral Personalization

* based on user interactions
* adjusts ranking dynamically

---

## User Profile Structure

```swift id="j8u3qm"
type UserProfile = {
  preferredCategories: [String]
  preferredTopics: [String]
  favoriteSources: [String]
  hiddenSources: [String]
}
```

---

## Interaction Model

```swift id="z4t91x"
type Interaction = {
  articleID: String
  action: String // opened, bookmarked, ignored
  timestamp: Date
  readingDuration: Double?
}
```

---

## Ranking Logic

Each article receives a score based on:

* category match
* topic match
* recency
* user engagement history
* source preference

[Inferenza] Exact scoring formula can evolve

---

## Example Scoring (Conceptual)

```id="3yxg1l"
score =
  recencyWeight +
  categoryMatchWeight +
  topicMatchWeight +
  engagementWeight
```

---

## Flow

1. Load articles from SwiftData
2. Load user profile
3. Load interaction history
4. Calculate score for each article
5. Sort articles by score
6. Return ranked feed

---

## Rules

* Never return empty feed if articles exist
* Always fallback to chronological order if scoring fails
* Hidden sources must be excluded
* Favorite sources should boost ranking
* Avoid overfitting (do not show only one category)

---

## Edge Cases

* no user preferences → fallback to default feed
* new user → use basic personalization only
* no interaction history → ignore behavioral signals
* conflicting signals → prioritize recency

---

## Notes

* Personalization must be lightweight (fast execution)
* Must work offline
* Should not block UI rendering
* Should be recalculated incrementally

---

## Optional Extensions

### Dynamic Interest Learning

[Inferenza]

* infer user interests from behavior
* update preferred topics automatically

---

### Exploration vs Exploitation

* show mostly relevant content
* occasionally introduce new topics

---

### Time-Based Personalization

* short session → high-impact articles
* long session → broader content

---

### Cross-Device Sync

* sync preferences via Firebase
* sync bookmarks and history

---

## Privacy Considerations

* store data locally by default
* minimize cloud usage
* avoid sensitive tracking
* give user control over preferences

---

## Summary

Personalization is the layer that:

* connects user behavior with content
* makes the feed intelligent
* differentiates Mercury from a simple RSS reader
