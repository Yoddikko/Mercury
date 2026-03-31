# Mercury Claude Instructions

Start with:

1. `docs/guidelines/GENERAL.md`
2. `docs/guidelines/CLAUDE.md`
3. `docs/guidelines/GIT_WORKFLOW.md`
4. `docs/guidelines/TESTING.md`
5. `docs/architecture/ARCHITECTURE.md`
6. the relevant feature, AI, and product docs

## Repo Rules

* docs are the current source of truth
* implementation may refine the docs only when the change is necessary, minimal, and documented
* keep architecture and documentation aligned
* avoid unrelated redesign
* add or update tests for behavior changes
* run relevant local verification when feasible and explain any skipped testing
* if preparing or opening a PR, complete the PR body; if you cannot open the PR directly, provide a fully written body ready to paste

## Commit and Release Rules

* do not commit unless explicitly asked
* do not tag or version-bump unless explicitly asked
* when committing, use the workflow in `docs/guidelines/GIT_WORKFLOW.md`
* keep code/doc sync in the same change whenever possible
