# Feature: Settings

## Description

The Settings screen exposes app-level toggles the user can change at any time. It is distinct from the Preferences screen (which captures content-personalization signals — preferred categories, topics, favorite/hidden sources, preferred language) in that Settings configures **how the app behaves and presents content**, not **what content to surface**.

---

## Scope

In scope (this iteration):

* article body rendering mode (web view vs native blocks)
* feed sources — region selection + per-outlet on/off (shared with the
  onboarding flow described in `docs/product/ONBOARDING.md`)

Reserved for future iterations (out of scope here, listed so the screen can grow without re-litigating):

* theme (system / light / dark)
* refresh cadence
* AI provider selection (already lives under Developer Tools today)
* iCloud sync toggle

---

## Inputs

* current `UserPreference` snapshot from `UserPreferencesService`

---

## Outputs

* mutations applied via `UserPreferencePatch`

---

## Fields

### `articleRenderer: ArticleRendererMode`

```swift
enum ArticleRendererMode: String, Codable, CaseIterable, Sendable {
    case web        // default — WKWebView, full HTML fidelity
    case native     // opt-in — parsed [ArticleBlock] rendered with SwiftUI
}
```

* **Default**: `.web` on first launch.
* **Persistence**: stored as a String on `UserPreferenceEntity` so SwiftData migration is additive and reversible.
* **Patch**: exposed via `UserPreferencePatch.articleRenderer` (optional; `nil` means "leave untouched", explicit value means "set to this").

---

## Flow

1. User opens the Settings screen (root or via app menu).
2. Screen reads the current `UserPreference` via `UserPreferencesService`.
3. User toggles the article rendering mode.
4. View model builds a `UserPreferencePatch(articleRenderer: …)` and calls `UserPreferencesService.updatePreferences(_:)`.
5. Persistence write commits; next article detail open observes the new mode.

---

## Rules

* The Settings screen is **stateless across launches** — every read goes through `UserPreferencesService`. No `@AppStorage`-only fields.
* Changes take effect on the next render (no app restart required).
* The renderer toggle defaults to `.web` for users who never visit Settings.

---

## Edge Cases

* Persisted value is missing or unrecognized → fall back to `.web`.
* Persistence write fails → surface a non-blocking error toast; previous selection remains visible.

---

## Feed sources

A new `Feed sources` section in `SettingsScreen` lets the user revisit the
choices captured during onboarding.

### Fields

* `enabledRegionRawValues: [String]` — raw values of `RSSFeedRegion` the
  user opted in to. Empty means "all regions".
* `hiddenSources: [String]` — outlet IDs the user has toggled off. Reused
  from the existing preferences field so per-outlet opt-outs stay in one
  place.

### Rules

* Toggling a region on/off updates `enabledRegionRawValues` via
  `UserPreferencePatch`.
* Toggling an outlet on/off updates `hiddenSources` via the same patch.
* Empty `enabledRegionRawValues` + empty `hiddenSources` falls back to
  the pre-onboarding default (`RSSFeedCatalog.mainOutlets`).
* `RSSSourceFilter` is the single service that resolves preferences into
  the final `[RSSFeedSource]` list consumed by `HomeViewModel`.

### Flow

1. User opens Settings → Feed sources.
2. Screen reads `UserPreference` and renders regions grouped from
   `RSSFeedCatalog.availableRegions`, each row showing an on/off toggle
   plus an expandable list of outlets.
3. Toggles build a `UserPreferencePatch` and call
   `UserPreferencesService.updatePreferences(_:)`.
4. The next Home refresh reads the updated preferences and only fetches
   the enabled subset.

## Notes

* The Personalization (`PERSONALIZATION.md`) and Settings features both write into the same `UserPreference` model; their separation is **semantic only** (Personalization = ranking signals, Settings = display behavior).
* Future cloud sync (per `ARCHITECTURE.md` §2.3 / §13.3) naturally covers both because they share the same entity.
