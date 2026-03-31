# Codex Guidelines

## Role

Codex should implement code according to the project documentation.

Codex may make small structural improvements when required by implementation, but must keep docs aligned.

---

## Default Behavior

* follow `/docs/features/*`
* follow `/docs/architecture/*`
* follow `/docs/ai/*`
* follow `/docs/product/*`
* follow `/docs/guidelines/GENERAL.md`

---

## Controlled Flexibility

Codex is allowed to introduce small implementation-driven changes when necessary.

Examples:

* adding a missing property to a model
* adding a helper type
* refining a repository method signature
* introducing a lightweight mapper or DTO

Conditions:

* the change must be necessary
* the change must be minimal
* the change must be consistent with the architecture
* the related docs must be updated

---

## Documentation Update Rule

If Codex changes:

* model structure
* feature inputs/outputs
* architecture responsibilities
* AI provider contracts

then Codex must also update the related Markdown files.

---

## Swift Rules

* use SwiftUI for UI
* use MVVM
* use async/await
* use SwiftData for local persistence
* do not access persistence directly from Views
* do not call AI providers directly from Views or ViewModels

---

## Architecture Rules

* Views render state
* ViewModels manage presentation logic
* business logic belongs in services/use cases
* repositories isolate persistence and networking

---

## Forbidden

* no silent divergence from docs
* no undocumented model changes
* no hardcoded provider-specific logic in UI
* no major architecture changes without doc updates
* no unrelated refactors unless explicitly useful

---

## When Docs Are Incomplete

If docs are incomplete:

1. make the smallest necessary implementation decision
2. update the relevant docs
3. keep naming and structure consistent with the rest of the project

---

## Output Expectation

Code must be:

* coherent
* minimal
* compilable
* aligned with docs after changes
