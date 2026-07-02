# Product: Feed Logic

## Description

Defines how Mercury builds, ranks, filters, and presents the main feed.

The feed must balance:

* relevance
* freshness
* diversity
* source quality
* user interests

---

## Feed Objectives

The feed should:

* surface relevant articles quickly
* avoid redundancy
* support both explicit and learned interests
* remain understandable and controllable for the user

---

## Feed Inputs

### Content Inputs

* articles from selected RSS sources
* article metadata
* article language
* category
* tags
* summaries
* clusters (if enabled)

### User Inputs

* selected countries / source regions
* selected sources
* hidden sources
* preferred language
* translation settings
* explicit interests
* inferred interests
* interaction history

---

## Feed Modes

## 1. Default Feed

Chronological feed ordered by freshness.

### Use case

* first app use
* no personalization data
* fallback mode

---

## 2. Personalized Feed

Ranked using explicit preferences and behavioral signals.

### Use case

* normal app usage
* main Mercury experience

---

## 3. Clustered Feed (Optional)

Articles about the same event are grouped into a single entry or event card.

### Use case

* reduce duplication
* improve overview of ongoing stories

---

## Ranking Priorities

Ranking should consider:

1. source eligibility
2. recency
3. explicit interest match
4. inferred interest match
5. source preference
6. user engagement history
7. diversity controls

---

## Explicit Interests

Explicit interests come from onboarding or settings.

Examples:

* categories selected by the user
* topics selected by the user
* favorite sources

### Rule

Explicit interests should have higher authority than inferred interests.

---

## Inferred Interests

Inferred interests are learned over time from behavior.

Examples:

* Technology
* Gaming
* Crash Bandicoot
* Nintendo

### Signals

* repeated article opens
* time spent reading
* repeated bookmarks
* repeated interactions with a topic or source

### Rules

* inferred interests should refine ranking
* inferred interests should not hard-lock the feed
* inferred interests should remain user-editable

---

## Interest Hierarchy

Mercury should support hierarchical topic refinement.

### Example

* Technology
* Technology > Gaming
* Technology > Gaming > Crash Bandicoot

### Purpose

* improve relevance
* preserve broad topic grouping
* allow deeper personalization over time

---

## Language and Translation Behavior

### Preferred Language

The feed should prioritize presentation in the user's preferred language where possible.

### Translation Behavior

If article language differs from preferred language:

* Mercury may display AI-translated content depending on user settings
* original text must remain accessible

### Labeling Requirement

All AI-translated content must be clearly labeled.

Examples:

* AI-translated title
* AI-translated summary
* AI-translated article excerpt

---

## Redundancy Reduction

The feed should reduce noise by:

* deduplicating identical articles
* optionally grouping related articles into clusters
* avoiding repeated near-identical stories in sequence

---

## Diversity Controls

The feed should not become too narrow.

### Rules

* avoid showing only one source repeatedly
* avoid showing only one micro-topic continuously
* occasionally surface adjacent interests
* preserve some editorial diversity

### Example

If the user likes:

* Technology > Gaming > Crash Bandicoot

The feed may still surface:

* broader gaming news
* platform news
* industry news
* general technology news

---

## Feed Item Types

Possible feed items:

* standard article card
* AI-summary-enhanced article card
* cluster/event card
* translated article card
* recommended topic block (optional)

---

## Fallback Behavior

If personalization is weak or unavailable:

* fallback to chronological feed
* fallback to selected-source feed
* do not leave the feed empty when content exists

---

## User Controls

Users should be able to:

* hide a source
* favorite a source
* mark a topic as not interesting
* change preferred language
* change translation behavior
* reset inferred interests

---

## Cached Content Rules (issue #94)

The offline cache must never widen the feed beyond the user's source
choices:

* cache replay (cold start) and search honor the same enabled-region /
  hidden-source preferences as the network fetch
* articles are stamped with their outlet's stable source id at ingest;
  legacy cached rows without the stamp are matched by source name
  against the catalog
* disabling a region or outlet purges its cached articles immediately
* favorited (bookmarked) articles are never purged — bookmarking is the
  explicit "keep this" signal
* non-favorite cached articles expire after 30 days (retention sweep at
  refresh time)
* when the user has expressed no source preferences, replay stays
  unfiltered (pre-onboarding behavior)

---

## Notes

* feed ranking must be fast
* feed generation must support offline cached content
* AI enhancements should improve feed quality without blocking the base reading experience
