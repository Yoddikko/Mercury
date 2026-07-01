# Feature: Settings

## Description

The Settings screen exposes app-level toggles the user can change at any time. It is distinct from the Preferences screen (which captures content-personalization signals — preferred categories, topics, favorite/hidden sources, preferred language) in that Settings configures **how the app behaves and presents content**, not **what content to surface**.

---

## Scope

In scope (this iteration):

* feed sources — region selection + per-outlet on/off (shared with the
  onboarding flow described in `docs/product/ONBOARDING.md`)

Reserved for future iterations (out of scope here, listed so the screen can grow without re-litigating):

* theme (system / light / dark)
* refresh cadence
* AI provider selection (already lives under Developer Tools today)
* iCloud sync toggle

Removed (issue #83): the article renderer picker. The reader is now
native SwiftUI (`ArticleBlockListView`) with no user-facing switch.
The `articleRendererRawValue` column on `UserPreferenceEntity` is
kept as a nullable field so SwiftData lightweight migration on
pre-#83 installs stays additive; no code reads it.

---

## Inputs

* current `UserPreference` snapshot from `UserPreferencesService`

---

## Outputs

* mutations applied via `UserPreferencePatch`

---

## Fields

The current Settings surface exposes only the Feed sources picker.
The article renderer choice was removed with #83; the reader is
native-only.

---

## Rules

* The Settings screen is **stateless across launches** — every read goes through `UserPreferencesService`. No `@AppStorage`-only fields.
* Changes take effect on the next render (no app restart required).

---

## Feed sources

A new `Feed sources` section in `SettingsScreen` lets the user revisit the
choices captured during onboarding.

### Fields

* `enabledRegionRawValues: [String]` — raw values of `RSSFeedRegion` the
  user opted in to. **Opt-in semantics**: the persisted list holds
  exactly the regions the user picked. Empty is only the pre-onboarding
  state and triggers the `RSSSourceFilter` fallback to
  `RSSFeedCatalog.mainOutlets`.
* `hiddenSources: [String]` — outlet IDs the user has toggled off. Reused
  from the existing preferences field so per-outlet opt-outs stay in one
  place.

### Rules

* The picker is **opt-in**. A fresh install shows every region toggled
  OFF; the persisted `enabledRegionRawValues` is exactly the set the
  user opted in to (not "everyone minus the ones they turned off").
* Toggling a region on/off updates `enabledRegionRawValues` via
  `UserPreferencePatch`. Toggles are optimistic — the row flips
  immediately and only rolls back on persistence failure — so rapid
  taps stay snappy.
* Toggling an outlet on/off updates `hiddenSources` via the same patch,
  mirrored into a published `Set<String>` so the disclosure rows
  re-render without a full picker rebuild.
* The region → outlets projection is memoized in the view model
  (`outletsByRegion`) at first load. Toggles never rescan
  `RSSFeedCatalog`.
* `RSSSourceFilter` still treats an empty `enabledRegionRawValues` as
  "fall back to `RSSFeedCatalog.mainOutlets`" so pre-onboarding installs
  keep working. Post-onboarding writes always materialize the explicit
  list.
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

### Onboarding-first fetch order (issue #87)

No feed fetch runs before onboarding completes. `HomeViewModel.
loadInitialFeedIfNeeded` skips while `hasCompletedOnboarding == false`,
and `AppRouter` never mounts `HomeScreen` while the flag is still
loading from SwiftData. The first fetch of a fresh install is always
the post-Continue one, resolved through `RSSSourceFilter` against the
regions/outlets just picked.

## Notes

* The Personalization (`PERSONALIZATION.md`) and Settings features both write into the same `UserPreference` model; their separation is **semantic only** (Personalization = ranking signals, Settings = display behavior).
* Future cloud sync (per `ARCHITECTURE.md` §2.3 / §13.3) naturally covers both because they share the same entity.
