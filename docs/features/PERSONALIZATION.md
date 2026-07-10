# Feature: Personalization

## Shipped v1 — "Per te" (For You), AI-only (issue #133)

The embedding/behavioral design below remains the long-term target.
The shipped v1 is a dedicated **"Per te" feed** in Home (third segment
next to Ultime and Argomenti), built on the user's **interests** and
the configured AI provider. It is deliberately **AI-only**: interests
are free-form ("vela oceanica", "fusione nucleare"), and matching an
arbitrary interest against headlines is a semantic task the provider
does well and lexical matching does poorly. Without a configured
provider the tab shows a paper-styled prompt to set one up — it never
degrades to a fake personalization.

### Signals (v1)

* `UserPreferenceEntity.preferredTopics` — the interests, collected in
  onboarding (suggested chips: Italia, Politica, Ambiente, Economia,
  Sport, Tecnologia, Cronaca, Esteri, Salute, Cultura, Scienza — plus
  free-text custom entries) and editable later.
* Interaction history (clicks, reading time, bookmarks) is modeled but
  NOT consumed in v1 — behavioral personalization stays future work.

### Single fetch, two algorithms

Argomenti and Per te share **one corpus fetch**: the same last-24h
window from the article cache (800 rows, source allow-list, 20 per
outlet). Argomenti groups it by story (`FeedTopicAggregationService`);
Per te ranks it against the interests:

1. Source-balanced sample of up to 100 headlines (`id<TAB>title`),
   the same sampling used for AI grouping.
2. One provider call (`AIProvider.pickHeadlines`): the prompt carries
   the interest list and the headlines; the model answers JSON-only
   `{"picks": [{"id", "interest", "relevance"}]}` — at most 30 picks,
   only input ids, `interest` naming which user interest matched,
   `relevance` 1–100.
3. Validation mirrors the grouping path: unknown ids dropped, each id
   used once, picks below a minimum relevance (25) discarded.
4. Rendering: articles ordered by relevance, each row carrying an
   uppercase mono badge with the matched interest.

### Caching and refresh

Same policy as Argomenti (issues #127/#131): the picks structure
(savedAt + [{id, interest, relevance}]) persists for 12 hours,
rehydrates from the article cache, shows the live auto-refresh
countdown, and recomputes only on pull-to-refresh or expiry.

### Rules (v1 addenda)

* No provider → dedicated "configure AI" state, never a silent
  lexical imitation.
* Empty picks (nothing matches the interests) → honest empty state,
  never padding with unrelated articles.
* Hidden sources are excluded before the sample (same allow-list).

---

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
