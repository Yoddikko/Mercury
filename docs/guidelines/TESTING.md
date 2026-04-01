# Testing Guidelines

## Purpose

This document defines how Mercury should approach automated testing.

It applies to:

* human contributors
* Claude
* Codex
* any other AI agent working in the repository

---

## Default Rule

If a change introduces, fixes, or materially alters behavior, it should also introduce or update tests at the right level.

In practice:

* new feature -> add tests
* bug fix -> add a regression test when feasible
* refactor with behavior preserved -> keep existing tests passing and add tests if coverage was missing

If no tests are needed, the PR must say so explicitly and explain why.

---

## Test Levels

Mercury should use a small number of clear test layers.

### 1. Unit Tests

Use `MercuryTests` for:

* domain models
* use cases
* services
* repositories
* parsers
* mappers
* prompt builders
* provider normalization
* view models

Preferred framework:

* `Swift Testing`

Unit tests are the default expectation for behavior changes.

### 2. UI Tests

Use `MercuryUITests` for high-value user flows only.

Good candidates:

* app launch
* onboarding
* feed loading
* article detail navigation
* other critical end-to-end flows

Preferred framework:

* `XCTest`

Do not add brittle UI tests for minor layout or copy-only changes.

---

## What Must Be Tested

These changes should usually add or update unit tests:

* ranking or feed logic
* RSS parsing or normalization
* AI prompt formatting
* AI response mapping
* provider fallback logic
* repository behavior
* model defaults and transformations
* view-model state transitions

These changes may not need new tests on their own:

* copy-only changes
* visual-only styling changes with no behavior impact
* documentation-only updates
* project configuration changes that do not alter runtime behavior

Even in those cases, the PR should state why no tests were needed.

---

## Structure

Recommended test structure:

```text
MercuryTests/
├── Domain/
├── Data/
├── AI/
├── Presentation/
└── TestDoubles/

MercuryUITests/
├── Flows/
└── Support/
```

Keep test files close to the domain they verify.

---

## Feature Testing Rule

Every new feature should define:

1. the expected behavior
2. the important edge cases
3. the level of test required
4. the minimum tests to add before merge

Examples:

* new feed ranking logic -> unit tests on scoring and fallback behavior
* new RSS parser behavior -> unit tests for valid, invalid, and incomplete feed items
* new onboarding flow -> at least one UI smoke test for the main path

---

## AI-Specific Rule

Before finishing an implementation task, an AI agent should:

* read this document
* decide which tests are required
* add or update tests when behavior changed
* run the relevant local verification commands when feasible
* explicitly explain any skipped tests or unrun commands

AI should not treat tests as optional cleanup to do later.

---

## Local Verification Commands

For app changes, use:

```bash
bash scripts/run-ios-build.sh
```

For unit tests, use:

```bash
bash scripts/run-ios-unit-tests.sh
```

If a command cannot run in the current environment, say so explicitly in the PR or final summary.

---

## CI Expectations

On pull requests, Mercury should enforce:

* docs sync
* test impact
* markdown lint
* repository hygiene
* app build
* unit tests

UI tests may run separately, less frequently, or after the main unit-test workflow is stable.

---

## PR Rule

A PR that changes implementation-sensitive files should do one of the following:

* update the relevant tests
* explicitly mark `no tests needed` and explain why

This rule is enforced heuristically in CI.
