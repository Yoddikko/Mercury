# General Guidelines

## Purpose

These guidelines define how Mercury should be implemented and evolved.

They apply to:

* all contributors
* all AI systems
* all generated code and documentation updates

---

## Core Principle

Documentation is the current source of truth.

However, documentation is allowed to evolve when implementation reveals a necessary improvement, missing field, missing constraint, or better structure.

In that case:

* the implementation may proceed
* the related documentation must also be updated

---

## Documentation Rule

AI should follow the docs by default.

If the docs are incomplete, outdated, or missing something required for implementation, AI may extend the implementation **only if**:

1. the change is small and clearly justified
2. the change is consistent with the project architecture
3. the relevant docs are updated to reflect the change

---

## Allowed Deviations

Allowed examples:

* adding a missing model field
* adding a missing enum case
* refining a repository interface
* splitting a feature into smaller components
* clarifying an ambiguous rule in docs

Not allowed:

* inventing large new features without documentation
* changing architecture without updating docs
* introducing incompatible data model changes silently
* replacing core patterns without explicit documentation changes

---

## Documentation Sync Requirement

If code changes require structural changes, AI must update the related docs, for example:

* `/docs/features/*`
* `/docs/architecture/*`
* `/docs/ai/*`
* `/docs/product/*`

Implementation and documentation should remain aligned.

---

## Data Models

* Prefer existing documented models
* If a model needs a new field, add it only when justified
* Any added field must be reflected in the relevant documentation

---

## Architecture

* Follow MVVM
* Use SwiftUI for UI where possible
* Use SwiftData for local persistence
* Use Firebase only where cloud sync or remote user data is needed
* Use provider abstraction for AI integrations

---

## Engineering Principles

* prefer small, reversible changes
* avoid hidden assumptions
* prefer consistency over novelty
* prefer explicit updates over silent divergence

---

## Git and Versioning

Commits, tags, and version changes should follow `/docs/guidelines/GIT_WORKFLOW.md`.

AI should not create commits, tags, or version bumps unless explicitly asked.

---

## Testing

Testing changes should follow `/docs/guidelines/TESTING.md`.

AI should not treat tests as optional for behavior changes.

If behavior changes and tests are not updated, the PR should explain why.

---

## Localization

Localization and accessibility text should follow `/docs/guidelines/LOCALIZATION.md`.

AI should not leave user-facing copy hardcoded in UI code.

If user-facing or accessibility-facing text changes and localization is not updated, the PR should explain why.

---

## Error Handling

* never fail silently
* prefer partial success over total failure
* use safe fallbacks where possible

---

## Performance

* avoid blocking the main thread
* use async operations for network and AI work
* cache results where appropriate

---

## Final Rule

If implementation and documentation differ, the mismatch should be resolved immediately by updating the relevant docs.
