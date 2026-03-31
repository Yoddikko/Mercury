# Mercury

Mercury is an AI-powered news aggregation app for iOS.

The project combines RSS ingestion, local-first article storage, AI enrichment, and personalized feed logic behind a documented architecture based on SwiftUI, MVVM, SwiftData, and provider abstraction.

## Repository Status

This repository is currently documentation-first, with an initial Xcode project scaffold under `Mercury/`.

The main source of truth still lives in the Markdown files under `docs/`.

Implementation work should follow the documented architecture and update the docs whenever behavior, models, prompts, or contracts change.

## What Mercury Covers

Mercury is designed to:

* fetch and normalize RSS feeds
* clean and enrich articles with AI
* generate summaries, categories, and embeddings
* cluster related articles into events
* build default and personalized feeds
* keep the app local-first, with optional cloud sync

## Documentation Map

Start here depending on what you need:

* [Architecture](docs/architecture/ARCHITECTURE.md): system structure, layers, and responsibilities
* [Features](docs/features/FEATURES.md): product capabilities and core concepts
* [AI Pipeline](docs/ai/PIPELINE.md): enrichment flow for article processing
* [AI Providers](docs/ai/PROVIDERS.md): provider abstraction and capability rules
* [Product Docs](docs/product/ONBOARDING.md): user-facing behavior and flows
* [General Guidelines](docs/guidelines/GENERAL.md): contribution and implementation principles
* [Git Workflow](docs/guidelines/GIT_WORKFLOW.md): commits, versioning, tags, and releases
* [Branch Protection](docs/guidelines/BRANCH_PROTECTION.md): recommended GitHub protection settings

## Repository Structure

```text
.
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── AGENTS.md
├── CLAUDE.md
├── docs/
│   ├── ai/
│   ├── architecture/
│   ├── features/
│   ├── guidelines/
│   ├── product/
│   └── rss/
└── .github/
    ├── ISSUE_TEMPLATE/
    ├── pull_request_template.md
    └── workflows/
```

## Contributing

Before opening a PR, read:

1. [CONTRIBUTING.md](CONTRIBUTING.md)
2. [General Guidelines](docs/guidelines/GENERAL.md)
3. [Git Workflow](docs/guidelines/GIT_WORKFLOW.md)

Core rules:

* keep changes focused
* avoid unrelated edits
* keep docs and behavior aligned
* use Conventional Commits
* treat version bumps and tags as explicit release actions

## AI Contributors

This repository includes dedicated entrypoints for AI tools:

* [AGENTS.md](AGENTS.md)
* [CLAUDE.md](CLAUDE.md)

AI contributors should read the relevant guidelines first and should not commit, tag, or bump versions unless explicitly asked.

## Versioning and Releases

Mercury uses SemVer with a practical pre-1.0 workflow:

* `PATCH` for fixes and non-contract changes
* `MINOR` for new capabilities, contract changes, and meaningful behavior changes

Release tags use the format `vMAJOR.MINOR.PATCH`, for example:

* `v0.1.0`
* `v0.2.0`

See [CHANGELOG.md](CHANGELOG.md) and [Git Workflow](docs/guidelines/GIT_WORKFLOW.md).

## Repository Standards

The repository includes:

* issue templates
* a PR template
* minimal docs-focused CI
* a docs sync check for implementation-sensitive PRs
* documented branch protection expectations

The branch protection policy is defined, but it can only be applied after the repository is connected to GitHub.
