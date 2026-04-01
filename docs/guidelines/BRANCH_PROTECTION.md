# Branch Protection

## Purpose

This document defines the recommended branch protection policy for Mercury.

It is intended for GitHub repository settings and complements the workflow described in `docs/guidelines/GIT_WORKFLOW.md`.

## Current Limitation

Branch protection cannot be enforced from this repository alone.

It must be configured in GitHub after the repository is connected to a remote.

## Protected Branch

Protect:

* `main`

## Recommended Baseline

Enable these settings for `main`:

* require a pull request before merging
* require status checks to pass before merging
* require conversation resolution before merging
* block force pushes
* block branch deletion

Required status checks:

* `Docs sync`
* `Test impact`
* `Markdown lint`
* `Repository hygiene`
* `App build`
* `Unit tests`

## Approval Policy

### Solo Maintainer Mode

If Mercury is still maintained by one person, do not require approving reviews yet.

Use:

* PR required
* status checks required
* no mandatory approving review

This keeps `main` protected without blocking normal solo development.

### Team Mode

Once there is more than one active maintainer, add:

* at least 1 approving review
* dismiss stale approvals when new commits are pushed

## Merge Strategy

Recommended:

* allow squash merge
* optionally allow rebase merge
* avoid merge commits if you want a cleaner linear history

## Admin Policy

Recommended default:

* admins should follow the same PR and CI flow whenever possible

If GitHub settings allow it, prefer applying the rules to admins too.

## Practical Setup Checklist

When the repository is connected to GitHub:

1. open repository settings
2. go to branch protection or rulesets
3. target `main`
4. require pull requests
5. require the docs CI checks
6. require the iOS CI checks
7. require conversation resolution
8. disable force pushes
9. disable deletion
10. add approval requirements later if and when the team grows
