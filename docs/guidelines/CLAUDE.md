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
