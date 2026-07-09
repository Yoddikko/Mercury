# Design System — "Paper" (book/newspaper style)

**THIS DESIGN SYSTEM IS MANDATORY. Every new or modified UI surface MUST
follow it.** No screen ships with default iOS styling (system blue, plain
sans-serif titles, rounded gray cards) unless a rule below explicitly
allows it. PRs that touch UI must state design-system compliance in the
review checklist.

The system is derived from **AirBook for CrossPoint** (the author's iOS
companion app for an e-ink reader) and adapted to Mercurio's newspaper
domain: the app must read like printed paper — warm paper background,
near-black ink, serif text, monospaced metadata, hairline rules instead
of shadows and rounded cards.

---

## 1. Color tokens (`Color` extension, `DesignSystem.swift`)

All colors are adaptive (light / dark) and warm-toned. **Never use raw
`Color.blue/.gray/.secondary` or `Color.accentColor` in screens** — use
the tokens.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `paperBackground` | RGB(0.976, 0.969, 0.957) — warm off-white | RGB(0.09, 0.09, 0.09) | screen background, always full-bleed (`ignoresSafeArea`) |
| `paperInk` | RGB(0.08, 0.07, 0.06) — warm near-black | RGB(0.91, 0.90, 0.88) | primary text, icons, strokes, filled emphasis |
| `paperRule` | RGB(0.50, 0.48, 0.45) — warm gray | RGB(0.48, 0.46, 0.44) | secondary text, dividers (typically at `.opacity(0.35)`), disabled |
| `paperError` | RGB(0.48, 0.28, 0.05) — muted amber | RGB(0.62, 0.44, 0.16) | errors ONLY. Never decorative |

Rules:

* Monochrome ink-on-paper. No blues, no greens, no gradients, no shadows.
* Emphasis = weight, size, or an ink-filled block — never a color change.
* `paperError` is the only non-monochrome token and only for failures.

## 2. Typography

Two families, fixed roles. **Never mix roles.**

* **Serif** (`.system(design: .serif)`, i.e. New York) — everything
  editorial: navigation titles, article titles, body text, buttons,
  section prose. This is the voice of the newspaper.
* **Monospaced** (`.system(design: .monospaced)`) — everything
  technical/metadata: timestamps, source names, counts, formats, badges.
  This is the typewriter voice of the newsroom.

Semantic helpers (Font extension in `DesignSystem.swift`):

| Helper | Definition | Use |
| --- | --- | --- |
| `paperTitle` | serif `.title2.bold()` | screen/article titles |
| `paperHeadline` | serif `.headline` | card headlines, section titles |
| `paperBody` | serif `.body` | article body, prose |
| `paperCallout` | serif `.callout` | list rows, secondary prose |
| `paperMeta` | mono `.caption` | metadata rows (source · time) |
| `paperBadge` | mono `.caption2.weight(.medium)` | badges, counters |

Labels and badges are `UPPERCASED` (use `.textCase(.uppercase)` or
`uppercased()`), tight and small — like running heads in a book.

## 3. Shape and structure

* **No rounded cards, no shadows.** Content sits directly on the paper;
  separation comes from typography and hairline rules.
* Dividers: `Rectangle().fill(Color.paperRule.opacity(0.35)).frame(height: 1)`
  or `Divider().overlay(Color.paperRule.opacity(0.35))`.
* Buttons and badges: rectangular, `overlay(Rectangle().stroke(Color.paperInk, lineWidth: 0.8))`
  — hairline ink boxes, like printed coupons. Filled variant:
  `Color.paperInk` background with `paperBackground` text.
* Spacing scale: 4 / 8 / 12 / 16 / 24. Generous whitespace over boxes.

## 4. Screen recipe

Every screen:

1. `Color.paperBackground.ignoresSafeArea()` behind everything;
   `.scrollContentBackground(.hidden)` on Lists/Forms.
2. `.tint(Color.paperInk)` at the root so controls inherit ink.
3. Navigation title in serif (large titles get serif via the
   `paperNavigationTitles()` app-level appearance helper).
4. Text/controls use only the tokens above.

## 5. Exceptions

* Developer/diagnostic screens (Playground, RSS diagnostics) MAY keep
  default styling — they never ship to end users.
* System components that cannot be restyled without fighting UIKit
  (alerts, share sheets) stay native.
* Article hero images are content, not chrome — untouched.

## 6. Compliance

* New UI → tokens only. Touching an old view → migrate it in the same PR.
* PR template "Docs Impact": UI PRs must confirm design-system compliance.
* The tokens live in `Mercury/Presentation/DesignSystem/DesignSystem.swift`
  — one file, no per-screen palettes.
