# Git Workflow and Versioning

## Purpose

This document defines how Mercury should handle branches, commits, version bumps, and release tags.

These rules apply to:

* human contributors
* Claude
* Codex
* any other AI agent working in the repository

---

## Operating Principle

Keep changes small, explicit, and easy to review.

For Mercury, documentation and implementation must move together.

If a change affects behavior, contracts, models, prompts, or architecture, the related docs must be updated in the same work session and, when practical, in the same commit.

---

## Branch Strategy

* `main` is the canonical branch
* use short-lived branches for focused work
* branch names should describe one concern only

Suggested prefixes:

* `feat/`
* `fix/`
* `docs/`
* `refactor/`
* `chore/`

Examples:

* `docs/git-workflow`
* `feat/feed-ranking`
* `fix/rss-date-parsing`

---

## Commit Policy

### Default Rule

AI should not create commits, tags, or version bumps unless explicitly asked.

AI may prepare the work for commit, but the act of committing should be intentional.

### Scope Rule

Each commit should contain one coherent change.

Good:

* one feature with its required doc updates
* one bug fix with its related tests
* one prompt contract change with the docs it requires

Avoid:

* mixing refactor + feature + docs cleanup in one commit
* bundling unrelated formatting changes
* slipping opportunistic fixes into an otherwise focused change

### Documentation Sync Rule

If a commit changes any of the following, it should also update the related Markdown docs:

* feature behavior
* architecture responsibilities
* provider capabilities or contracts
* prompt structure or expected output format
* persisted model shape

---

## Commit Message Format

Use Conventional Commits:

```text
type(scope): short imperative summary
```

Examples:

* `feat(feed): add article clustering pipeline`
* `fix(rss): normalize malformed publish dates`
* `docs(prompts): clarify categorization output contract`
* `refactor(providers): extract response mapper`

Recommended types:

* `feat`
* `fix`
* `docs`
* `refactor`
* `test`
* `chore`
* `ci`

Recommended scopes for Mercury:

* `architecture`
* `feed`
* `article`
* `rss`
* `categorization`
* `summarization`
* `clustering`
* `personalization`
* `providers`
* `prompts`
* `onboarding`
* `guidelines`
* `docs`

Commit message rules:

* keep the subject line concise
* use imperative mood
* avoid vague summaries like `update stuff`
* mention the domain, not just the file

Optional body template:

```text
Why:
- ...

What:
- ...

Docs:
- updated: ...
```

Use a body when the change touches contracts, architecture, or versioning decisions.

---

## Versioning Policy

Mercury should use SemVer, with a practical pre-1.0 rule set.

### Before 1.0.0

Use `0.y.z`.

Interpret bumps this way:

* `PATCH` (`0.y.z -> 0.y.z+1`): bug fix, internal cleanup, docs-only clarification, prompt tuning that keeps the same documented output contract
* `MINOR` (`0.y.z -> 0.y+1.0`): new feature, meaningful behavior change, new documented capability, contract change, persisted model change, provider interface change

Before `1.0.0`, Mercury should treat potentially breaking product or contract changes as a `MINOR` bump.

### From 1.0.0 onward

Use normal SemVer:

* `PATCH`: backward-compatible fixes
* `MINOR`: backward-compatible features
* `MAJOR`: breaking changes

### No Automatic Version Drift

AI should not bump versions by default.

A version bump should happen only when:

* the user explicitly asks for it
* a release is being prepared
* the repository already contains an established release workflow that requires it

---

## What Counts as Version-Relevant

These changes should be called out as version-relevant:

* changing the `AIProvider` interface
* changing prompt output JSON shape
* adding or removing required model fields
* changing documented feature flows in a user-visible way
* changing persistence assumptions that affect existing stored data

These changes are usually not version-relevant on their own:

* typo fixes
* wording clarifications
* formatting cleanup
* internal refactors with no documented behavioral effect

---

## Tags and Releases

Use annotated tags on `main`:

```text
v0.1.0
v0.2.0
v1.0.0
```

Rules:

* tag only release-ready states
* do not tag intermediate work branches
* do not create release tags unless explicitly asked

If a release note or changelog process exists later, keep it aligned with the same version decision.

### Tag Format

Use this exact format:

```text
vMAJOR.MINOR.PATCH
```

Examples:

* `v0.1.0`
* `v0.2.3`
* `v1.0.0`

Do not use:

* `0.1.0` without the `v`
* ad-hoc tags like `release-final`
* multiple tag naming styles in the same repository

### Annotated Tag Example

Prefer annotated tags:

```bash
git tag -a v0.1.0 -m "Mercury v0.1.0"
git push origin v0.1.0
```

### When to Create a Tag

Create a tag only when all of the following are true:

* the related work is already committed
* the release version has been intentionally chosen
* `CHANGELOG.md` is aligned, if present
* the tagged commit is the intended release point

### Recommended First Release

For this repository, the first meaningful tag should normally be:

* `v0.1.0` for the first stable project baseline

Do not create `v0.0.1`, `v0.0.2`, and similar micro-tags unless the project truly needs them.

---

## Changelog Rule

Use a root `CHANGELOG.md` file.

Recommended structure:

* `Unreleased`
* released versions in descending order

Each release entry should summarize:

* Added
* Changed
* Fixed
* Docs

The changelog should describe project-level impact, not every internal edit.

---

## Release Flow

Use this release sequence:

1. finish the intended work
2. update the related docs
3. decide the correct version bump
4. update `CHANGELOG.md`
5. commit the release preparation, if needed
6. create an annotated tag on the release commit
7. push the branch and the tag

Example:

```bash
git commit -m "chore(release): prepare v0.1.0"
git tag -a v0.1.0 -m "Mercury v0.1.0"
git push origin main
git push origin v0.1.0
```

---

## AI Checklist Before Commit

Before creating a commit, an AI agent should verify:

* the change is focused
* unrelated files are excluded
* relevant docs were updated
* the version impact is understood
* the commit message follows the agreed format
* the user actually asked for a commit

If implementation-sensitive files change without any docs update, the change should include an explicit rationale in the PR.

Relevant tests should also be added or updated when behavior changes.

If tests are not updated, the PR should include an explicit rationale.

Localization impact should also be addressed when user-facing or accessibility-facing text changes.

If localization is not updated, the PR should include an explicit rationale.

If a PR is being prepared, the PR template should be completed.

If the AI cannot open the PR directly, it should still provide a complete body ready to paste.

---

## AI Checklist Before Version Bump or Tag

Before changing a version number or creating a tag, an AI agent should verify:

* the user asked for a release or version bump
* the bump type matches the actual impact
* related docs are already aligned
* `CHANGELOG.md` is aligned, if present
* the release point is on `main` or intended for `main`

---

## Preferred Behavior for This Repository Today

At the current stage of Mercury:

* prefer `docs(...)` commits for documentation-only work
* keep architecture and feature doc changes tightly scoped
* avoid version bumps for ordinary documentation refinement
* reserve version numbers and tags for meaningful milestones
