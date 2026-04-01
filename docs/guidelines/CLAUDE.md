# Claude Guidelines

## Role

Claude may reason about architecture, feature design, refactoring, and implementation details.

Claude should preserve project consistency while allowing controlled evolution.

---

## Default Behavior

* respect existing docs
* prefer documented behavior
* avoid unnecessary redesign
* follow `/docs/guidelines/GIT_WORKFLOW.md`
* follow `/docs/guidelines/TESTING.md`
* follow `/docs/guidelines/LOCALIZATION.md`
* follow `/docs/guidelines/LOGGING.md`

---

## Controlled Flexibility

Claude may propose or implement small changes when the current docs do not fully support the intended implementation.

Examples:

* clarifying ambiguous feature behavior
* adding a missing field
* improving a prompt contract
* refining a data flow step
* documenting a missing dependency

Conditions:

* the change must be justified by implementation needs
* the change must remain consistent with Mercury's architecture
* the relevant docs must be updated

---

## Documentation Sync Rule

Claude should never leave implementation more advanced than documentation for long.

If code or structure changes, the related docs should be updated in the same work session whenever possible.

---

## Refactoring Rule

Claude may improve structure, but should not:

* replace MVVM
* replace SwiftData as primary local persistence
* replace provider abstraction
* introduce large undocumented subsystems

unless the docs are updated accordingly

---

## Reasoning Rule

When docs and implementation conflict:

* prefer the smallest coherent resolution
* update docs
* avoid speculative redesign

---

## Communication Rule

When making changes, explain briefly:

* what changed
* why it was necessary
* which docs should now reflect it

---

## Safety Rule

Do not invent major features or requirements without documenting them.

---

## Commit and Versioning Rule

Claude should not:

* create commits unless explicitly asked
* create tags unless explicitly asked
* change versions unless explicitly asked or a release workflow requires it

When asked to commit, Claude should follow `/docs/guidelines/GIT_WORKFLOW.md`.

---

## Testing Rule

Claude should:

* require tests for meaningful behavior changes
* prefer unit tests for logic-heavy changes
* ask for or provide a clear no-tests rationale when tests are intentionally skipped
* run relevant verification when feasible and report any limitation

---

## Localization Rule

Claude should:

* require localization updates when user-facing copy changes
* require localization updates for accessibility-facing text changes
* avoid leaving hardcoded product copy in UI code
* ask for or provide a clear no-localization rationale when updates are intentionally skipped

---

## Logging Rule

Claude should:

* require logs in every new or modified function
* enforce meaningful levels and categories via `AppLogger`
* require request-id propagation for cross-layer flows
* include operational metadata useful for diagnosis
* avoid logging secrets or private user data

---

## PR Preparation Rule

If Claude opens or prepares a PR:

* complete the repository PR template
* summarize docs and testing impact explicitly
* provide a ready-to-paste PR body if direct PR creation is not available
