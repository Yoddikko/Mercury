# Localization Guidelines

## Purpose

This document defines how Mercury handles localization and accessibility-facing text.

It applies to:

* app UI strings
* accessibility labels, hints, and values
* human contributors
* AI contributors

---

## Baseline Rule

Mercury should always ship user-facing text in:

* English (`en`) as the required base locale
* all supported i18n locales configured for the app

If a PR introduces or changes user-facing copy, localization should be updated in the same work session.

---

## Source of Truth for Strings

Use localization resources, not hardcoded UI text.

Preferred approach:

* String Catalog (`.xcstrings`) for app strings
* a consistent key strategy for reusable strings

Avoid:

* leaving user-visible copy hardcoded in SwiftUI views
* adding one-off ad-hoc strings without catalog entries

Hardcoded text is acceptable only for:

* internal debug output
* temporary developer-only diagnostics

---

## SwiftUI Localization Rule

User-facing text in UI components should be localized, including:

* `Text`
* `Button`
* `Label`
* `navigationTitle`
* alerts and confirmation dialogs
* empty states and error messages

When adding new strings:

* add English first
* add the same key for all supported locales
* do not merge partial localization silently without noting it in the PR

---

## Accessibility Localization Rule

Accessibility text is product text and must be localized too.

This includes:

* `accessibilityLabel`
* `accessibilityHint`
* `accessibilityValue`
* spoken announcements and assistive prompts

Rules:

* keep accessibility wording clear and concise
* localize placeholders and dynamic message templates
* avoid relying on icon-only or emoji-only meaning

---

## PR Rule

A PR that changes user-facing copy or accessibility-facing text should do one of the following:

* update localization resources (English + supported locales)
* explicitly mark `no localization update needed` in the PR template and explain why

Every PR should include an explicit localization decision.

---

## CI Expectation

Mercury should run a `Localization impact` check on pull requests.

The check is heuristic and should enforce:

* implementation-sensitive changes with localization updates, or
* an explicit `no localization update needed` declaration in the PR body

Repository script:

* `.github/scripts/check-localization-sync.sh`

---

## Review Checklist

Before merge, verify:

* new user-facing strings are localized
* English and supported locales stay aligned for new keys
* accessibility strings are localized where applicable
* the PR includes a clear localization impact decision
