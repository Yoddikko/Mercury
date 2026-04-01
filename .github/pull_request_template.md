# Pull Request

## Summary

Describe the change in a few sentences.

## Why

Explain why this change is needed.

## Scope

Select the one that best fits:

- [ ] docs only
- [ ] bug fix
- [ ] feature
- [ ] refactor
- [ ] release preparation

## Docs Impact

- [ ] no doc update needed
- [ ] updated the relevant docs in this PR

If implementation-sensitive files changed and no docs were edited, the first checkbox must be selected and justified below.

If docs were updated, mention which areas:

- [ ] `docs/features/*`
- [ ] `docs/architecture/*`
- [ ] `docs/ai/*`
- [ ] `docs/product/*`
- [ ] `docs/guidelines/*`

## No-Docs Rationale

If you selected `no doc update needed`, explain why.

## Localization Impact

- [ ] localization resources updated for user-facing copy changes
- [ ] accessibility-facing text was reviewed and localized when needed
- [ ] no localization update needed

If implementation-sensitive files changed without localization updates, the third checkbox must be selected and justified below.

## No-Localization Rationale

If you selected `no localization update needed`, explain why.

## Logging Impact

- [ ] logs added/updated for new or modified functions
- [ ] request IDs propagated for cross-layer flows when applicable
- [ ] no logging update needed

If implementation-sensitive files changed without logging updates, the third checkbox must be selected and justified below.

## No-Logging Rationale

If you selected `no logging update needed`, explain why.

## Testing Impact

- [ ] unit tests added or updated
- [ ] UI tests added or updated
- [ ] no tests needed

If implementation-sensitive files changed without tests being edited, the third checkbox must be selected and justified below.

## No-Tests Rationale

If you selected `no tests needed`, explain why.

## Versioning Impact

- [ ] no version impact
- [ ] patch-level impact
- [ ] minor-level impact
- [ ] release/tag preparation

Explain briefly if version-relevant.

## Validation

Describe how you validated the change. List the commands you ran when relevant.

## Checklist

- [ ] the PR stays focused on one concern
- [ ] unrelated changes were excluded
- [ ] commit messages follow Conventional Commits
- [ ] docs and behavior are aligned
- [ ] localization impact is explicitly addressed
- [ ] logging impact is explicitly addressed
- [ ] relevant tests were added or updated, or a no-tests rationale was provided
- [ ] relevant local checks were run, or any limitation is explained above
- [ ] docs sync check is satisfied
- [ ] `CHANGELOG.md` was updated if this is part of a release
