# Contributing to Mercury

This repository is documentation-first.

That means contributors should treat the docs as the current source of truth and keep implementation and documentation aligned as the project evolves.

## Read First

Before making changes, read:

1. `docs/guidelines/GENERAL.md`
2. `docs/guidelines/GIT_WORKFLOW.md`
3. `docs/guidelines/TESTING.md`
4. `docs/guidelines/LOCALIZATION.md`
5. `docs/guidelines/LOGGING.md`
6. `docs/architecture/ARCHITECTURE.md`
7. the relevant files under `docs/features/`, `docs/ai/`, and `docs/product/`

If you are using an AI agent, also read:

* `AGENTS.md`
* `CLAUDE.md`

## Contribution Principles

* keep changes small and reviewable
* avoid unrelated edits
* prefer consistency over novelty
* do not silently diverge from documented behavior
* if you change behavior or contracts, update the related docs
* if you change behavior, add or update tests at the right level
* if you change user-facing copy or accessibility text, update localization resources
* if you add or modify functions, add or update logs with `AppLogger`

## Workflow

### 1. Start from `main`

Create a short-lived branch from `main`.

Suggested branch prefixes:

* `feat/`
* `fix/`
* `docs/`
* `refactor/`
* `chore/`

Examples:

* `docs/contributing-guide`
* `feat/article-clustering`
* `fix/rss-normalization`

### 2. Keep the Scope Tight

One branch should address one concern.

Good examples:

* one feature and its related doc updates
* one bug fix and its related tests
* one documentation clarification

Avoid mixing:

* refactors plus features
* formatting cleanup plus behavioral changes
* unrelated fixes

### 3. Update the Docs When Needed

If your change affects any of the following, update the related docs in the same work session:

* feature behavior
* architecture responsibilities
* AI provider contracts
* prompt inputs or outputs
* persisted models or required fields

### 4. Commit with Conventional Commits

Format:

```text
type(scope): short imperative summary
```

Examples:

* `docs(guidelines): add release workflow`
* `feat(feed): add article ranking stage`
* `fix(rss): handle malformed dates`
* `refactor(providers): extract response mapper`

Recommended types:

* `feat`
* `fix`
* `docs`
* `refactor`
* `test`
* `chore`
* `ci`

Use a commit body when the change affects architecture, contracts, or release decisions.

### 5. Open a Focused PR

PRs should explain:

* what changed
* why it changed
* whether docs were updated
* whether localization was updated
* whether the change is version-relevant
* what testing was added, updated, or intentionally skipped

Use the repository PR template.

If implementation-sensitive files change without any documentation update, the PR must explicitly mark `no doc update needed` and explain why.

If AI prepares a PR but cannot create it directly, it should still provide a completed PR body ready to paste.

## Localization and Accessibility

Read `docs/guidelines/LOCALIZATION.md` before changing user-facing UI copy.

Default expectation:

* user-facing text changes -> update localization resources
* accessibility label/hint/value changes -> localize the same update
* keep English and supported i18n locales aligned for new keys
* hardcoded product copy in SwiftUI views should be avoided

If localization updates are intentionally not needed, explain that in the PR.

## Testing

Read `docs/guidelines/TESTING.md` before changing app code.

Default expectation:

* new feature -> add tests
* bug fix -> add a regression test when feasible
* logic change -> update the relevant unit tests
* UI flow change -> consider a UI smoke test if the path is high value

Before opening a PR, run the relevant commands:

```bash
bash scripts/run-ios-build.sh
bash scripts/run-ios-unit-tests.sh
```

If a test command cannot run in your environment, explain that in the PR.

## Versioning

Mercury uses SemVer with a practical pre-1.0 policy.

While the project is pre-1.0:

* `PATCH` for bug fixes, internal cleanup, and docs clarifications that do not change the documented contract
* `MINOR` for new features, behavior changes, new capabilities, model changes, or contract changes

Examples:

* `0.1.0 -> 0.1.1` for a fix
* `0.1.1 -> 0.2.0` for a new feature or contract change

Do not bump versions casually. Version changes should be intentional and tied to a release or milestone.

See `docs/guidelines/GIT_WORKFLOW.md` for the canonical versioning rules.

## Tags and Releases

Use annotated tags on release-ready commits:

```bash
git tag -a v0.1.0 -m "Mercury v0.1.0"
git push origin v0.1.0
```

Rules:

* tag only release-ready states
* keep `CHANGELOG.md` aligned before tagging
* tag from the intended release commit on `main`

## Pull Request Checklist

Before opening or merging a PR, verify:

* the change is focused
* unrelated files are excluded
* the docs are updated if needed
* localization impact is explicitly addressed
* the relevant tests were added or updated
* the relevant local checks were run, or the limitation is explained
* the commit messages are clear
* the version impact is understood
* `CHANGELOG.md` is updated if the change is part of a release

## AI-Specific Rule

AI contributors should not:

* create commits unless explicitly asked
* create tags unless explicitly asked
* bump versions unless explicitly asked or a release workflow requires it

AI should read `docs/guidelines/TESTING.md` and `docs/guidelines/LOCALIZATION.md`, add or update tests when behavior changes, and update localization resources when user-facing copy changes.
AI should also follow `docs/guidelines/LOGGING.md`, including request-id propagation for cross-layer flows.

If AI prepares or opens a PR, it should complete the PR template instead of leaving the description empty.

AI may prepare changes for commit, but committing and releasing should remain explicit actions.
