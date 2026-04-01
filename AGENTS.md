# Mercury Agent Instructions

Read these files first:

1. `docs/guidelines/GENERAL.md`
2. `docs/guidelines/CODEX.md`
3. `docs/guidelines/GIT_WORKFLOW.md`
4. `docs/guidelines/TESTING.md`
5. `docs/guidelines/LOCALIZATION.md`
6. `docs/guidelines/LOGGING.md`
7. `docs/architecture/ARCHITECTURE.md`
8. the relevant files under `docs/features/`, `docs/ai/`, and `docs/product/`

## Core Rules

* documentation is the source of truth
* prefer the smallest coherent change
* if behavior, contracts, models, or architecture change, update docs in the same work session
* do not silently diverge from the documented system
* if behavior changes, add or update tests at the right level
* if user-facing copy or accessibility text changes, update localization resources
* if new or modified functions are introduced, add or update logs using `AppLogger`
* run relevant local verification before finishing when feasible
* if tests are skipped or cannot run, explain why explicitly
* if preparing or opening a PR, complete the PR body; if you cannot open the PR directly, provide a fully written body ready to paste

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
* follow `docs/guidelines/TESTING.md` for test scope and commands
* follow `docs/guidelines/LOCALIZATION.md` for i18n and accessibility text rules
* follow `docs/guidelines/LOGGING.md` and propagate request IDs across multi-layer flows
