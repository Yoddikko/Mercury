# Mercury Agent Instructions

Read these files first:

1. `docs/guidelines/GENERAL.md`
2. `docs/guidelines/CODEX.md`
3. `docs/guidelines/GIT_WORKFLOW.md`
4. `docs/architecture/ARCHITECTURE.md`
5. the relevant files under `docs/features/`, `docs/ai/`, and `docs/product/`

## Core Rules

* documentation is the source of truth
* prefer the smallest coherent change
* if behavior, contracts, models, or architecture change, update docs in the same work session
* do not silently diverge from the documented system

## Commit and Versioning Rules

* do not commit unless the user explicitly asks
* do not create tags unless the user explicitly asks
* do not bump versions unless the user explicitly asks or a release workflow clearly requires it
* when asked to commit, follow `docs/guidelines/GIT_WORKFLOW.md`
* keep commits atomic and include required doc updates

## Mercury-Specific Priorities

* preserve the documented MVVM architecture
* preserve provider abstraction for AI integrations
* treat prompt/output contract changes as important and explicit
* prefer documentation updates over speculative redesign
