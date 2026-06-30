# Mercury — Architecture

## 1. Overview

Mercury is an AI-powered news aggregation app for iOS.

The system is designed to:

* fetch and normalize RSS news sources
* enrich articles with AI features
* persist articles and local user data on-device
* optionally sync user-related data to a cloud backend

The architecture follows:

* **MVVM**
* **SwiftUI** for UI
* **SwiftData** for local persistence
* **LLM provider abstraction** for AI integrations
* **Firebase** for remote user-related data when needed

---

## 2. Main Architectural Decisions

## 2.1 UI Architecture

* **Pattern:** MVVM
* **UI Framework:** SwiftUI
* **Navigation:** SwiftUI NavigationStack
* **State Management:** Observable / @State / @Bindable / environment-based dependency injection where needed

### Reasoning

MVVM works well with SwiftUI because:

* views remain declarative
* view models handle presentation logic
* business logic can stay outside the UI layer
* the project remains easier to scale and test

---

## 2.2 Local Persistence

* **Primary local database:** SwiftData

### Use SwiftData for:

* cached RSS articles
* article summaries
* categories and tags
* clusters/events
* bookmarks
* reading history
* local user preferences
* cached AI results
* provider metadata if needed

### Reasoning

SwiftData is appropriate because:

* native Apple integration
* simple model definitions
* good fit for SwiftUI
* easy local-first approach

---

## 2.3 Cloud / Remote Persistence

* **Optional remote backend:** Firebase

### Use Firebase for:

* account-based sync
* user preferences across devices
* saved articles sync
* usage analytics
* remote feature flags
* optional notification-related metadata

### Important note

Firebase should **not** replace SwiftData as the main app database.

Recommended approach:

* **SwiftData = source of truth on device**
* **Firebase = sync / cloud support**

---

## 2.4 AI Integration

* **Approach:** API-token-based provider system
* **Supported providers:**

  * OpenAI / ChatGPT
  * Anthropic / Claude
  * Google / Gemini
  * Ollama

### Design principle

AI integrations must be abstracted behind a single provider interface so the app does not depend on one specific vendor.

---

## 3. High-Level Architecture

```text
+---------------------+
|     SwiftUI UI      |
|  Screens / Views    |
+----------+----------+
           |
           v
+---------------------+
|     ViewModels      |
|   Presentation      |
+----------+----------+
           |
           v
+---------------------+
|  Application Layer  |
|  Use Cases/Services |
+----+---------+------+
     |         |
     |         |
     v         v
+---------+  +------------------+
|SwiftData|  | AI Provider Layer|
| Local DB|  | Claude/GPT/etc.  |
+----+----+  +---------+--------+
     |                 |
     |                 |
     v                 v
+----------------+  +-------------------+
| RSS Ingestion   | | External AI APIs   |
| Parsing/Cleaning| | or Local Ollama    |
+----------------+  +-------------------+

           |
           v
+---------------------+
| Firebase (optional) |
| Sync / User Cloud   |
+---------------------+
```

---

## 4. Layers

## 4.1 Presentation Layer

Contains:

* SwiftUI views
* reusable UI components
* view models

### Responsibilities

* render UI
* react to user input
* bind state to views
* call use cases/services
* transform domain data into display-ready data

### Should not contain

* RSS parsing logic
* HTTP implementation details
* AI provider implementation
* database-heavy logic

---

## 4.2 Application Layer

Contains:

* use cases
* coordinators if needed
* app services

### Examples

* `FetchFeedsUseCase`
* `SummarizeArticleUseCase`
* `CategorizeArticleUseCase`
* `ClusterArticlesUseCase`
* `BuildPersonalizedFeedUseCase`
* `SyncUserPreferencesUseCase`

### Responsibilities

* orchestrate workflows
* connect repositories and services
* keep business logic reusable

---

## 4.3 Data Layer

Contains:

* repositories
* API clients
* persistence adapters
* feed parsers

### Examples

* `ArticleRepository`
* `UserPreferencesRepository`
* `RSSFeedClient`
* `AIProviderRepository`
* `FirebaseUserRepository`

---

## 4.4 AI Layer

Contains:

* provider abstraction
* provider implementations
* prompt builders
* response mappers

### Responsibilities

* send prompts/requests
* normalize responses
* handle provider-specific settings
* manage failures and retries
* expose one unified API to the application layer

---

## 5. Recommended Folder Structure

```text
Mercury/
├── App/
│   ├── MercuryApp.swift
│   ├── AppRouter.swift
│   └── DependencyContainer.swift
│
├── Presentation/
│   ├── Screens/
│   │   ├── Home/
│   │   ├── ArticleDetail/
│   │   ├── Search/
│   │   ├── Bookmarks/
│   │   ├── Preferences/
│   │   └── Settings/
│   │
│   ├── Components/
│   └── ViewModels/
│
├── Domain/
│   ├── Models/
│   ├── UseCases/
│   ├── Interfaces/
│   └── Services/
│
├── Data/
│   ├── Repositories/
│   ├── Local/
│   │   ├── SwiftDataModels/
│   │   └── Persistence/
│   │
│   ├── Remote/
│   │   ├── RSS/
│   │   ├── AI/
│   │   └── Firebase/
│   │
│   └── Mappers/
│
├── AI/
│   ├── Providers/
│   │   ├── OpenAIProvider.swift
│   │   ├── ClaudeProvider.swift
│   │   ├── GeminiProvider.swift
│   │   └── OllamaProvider.swift
│   │
│   ├── Prompts/
│   ├── Models/
│   └── AIService.swift
│
├── Shared/
│   ├── Extensions/
│   ├── Utilities/
│   ├── Constants/
│   └── DesignSystem/
│
└── Resources/
```

`Shared/Utilities/` includes cross-cutting helpers such as `DeveloperMode` and
the centralized `AppLogger` used across Presentation, Domain, and Data layers.

---

## 6. Core Modules

## 6.1 RSS Module

### Responsibilities

* fetch RSS feeds
* parse XML
* normalize article metadata
* deduplicate items
* pass content into local persistence and AI pipeline

### Main components

* `RSSFeedClient`
* `RSSParser`
* `ArticleNormalizer`
* `FeedRefreshService`
* `AppLogger` (cross-cutting diagnostics)

---

## 6.2 Article Module

### Responsibilities

* store article data
* expose article queries
* manage bookmarks/history
* provide article detail data to the UI
* distill the article body so renderers and AI features consume the article only, not the surrounding page chrome

### Main components

* `ArticleRepository`
* `ArticleModel`
* `ArticleDetailViewModel`
* `ArticleReadabilityDistiller` — Mozilla Readability-style content extraction layered on `SwiftSoup`, run at ingest time via `ArticleContentEnrichmentService`. Outputs `Article.distilledBodyHTML`; consumed by both renderers (`ArticleBodyWebView`, `ArticleBlockListView`) and re-derives `cleanedContent` for AI features. See `docs/features/ARTICLE.md` § Content Distillation.
* `ArticleImageDeduplicator` — drops body `<img>` whose normalized basename matches the hero image URL.
* `ArticleLocaleBoilerplateStripper` — language-gated regex pass that removes Italian/English boilerplate paragraphs Readability leaves behind (`Riproduzione riservata`, `Leggi anche`, `Iscriviti alla newsletter`, …).

---

## 6.3 AI Enrichment Module

### Responsibilities

* summarize article content
* categorize content
* generate tags
* optionally explain articles
* optionally support cluster-level summarization

### Main components

* `AIService`
* `AIProviderProtocol`
* `PromptBuilder`
* `SummaryMapper`

---

## 6.4 Logging and Observability

### Responsibilities

* emit structured logs with consistent format
* classify events by level and category
* propagate request IDs across multi-step flows
* retain logs in memory for debug export

### Main components

* `AppLogger`
* `AppLogStore`
* Developer Playground logging export action (debug-only)
* `CategoryMapper`

---

## 6.4 Personalization Module

### Responsibilities

* store user interests
* track interactions
* rank content
* optionally sync preferences through Firebase

### Main components

* `UserPreferencesRepository`
* `FeedRankingService` — base pre-personalization scorer (issue #13). Pure
  function over `(Article, UserPreference)`: hidden sources are filtered;
  remaining articles are scored by category match (+3), tag/topic match
  (+2 per matched tag), favorite source (+4), language match (+1); ties
  broken by `publishedAt` descending. Called by `HomeViewModel` after the
  refresh use case and on cached reads.
* `InteractionTracker`
* `PreferenceSyncService`

---

## 6.5 Settings Module

### Responsibilities

* expose app-behavior toggles distinct from content-personalization signals
* persist toggles via the shared `UserPreferencesService`
* surface the article body rendering mode (web vs native) to the user

### Main components

* `SettingsScreen` / `SettingsViewModel`
* `ArticleRendererMode` (enum, persisted on `UserPreferenceEntity`)

See `docs/features/SETTINGS.md` for the full spec.

---

## 7. MVVM Structure

## 7.1 View

The View:

* displays UI
* binds to published state
* forwards user actions to the ViewModel

Example responsibilities:

* render article card
* show loading/error state
* navigate to article detail

---

## 7.2 ViewModel

The ViewModel:

* fetches data through use cases/repositories
* exposes UI state
* formats data for the view
* handles user-triggered actions

Example:

* `HomeViewModel`
* `ArticleDetailViewModel`
* `PreferencesViewModel`

---

## 7.3 Model

In this project, "Model" includes:

* domain models
* SwiftData entities
* DTOs from APIs/RSS
* AI request/response models

---

## 8. SwiftData Model Suggestions

## 8.1 ArticleEntity

Suggested fields:

* `id`
* `externalID`
* `title`
* `sourceName`
* `sourceURL`
* `articleURL`
* `publishedAt`
* `authorName`
* `heroImageURL`
* `rawContent`
* `cleanedContent`
* `contentSource`
* `contentWordCount`
* `isContentLikelyComplete`
* `summaryShort`
* `summaryBullets`
* `category`
* `tags`
* `language`
* `isBookmarked`
* `isRead`
* `clusterID`
* `createdAt`
* `updatedAt`

The media (`authorName`, `heroImageURL`) and source-origin
(`externalID`, `contentSource`, `contentWordCount`, `isContentLikelyComplete`)
fields keep cached articles aligned with the domain `Article` so the home feed
preserves thumbnails, authorship, and content-completeness signals after a
SwiftData load. All new fields are optional or default-valued so SwiftData
lightweight migration handles existing stores without manual code.

---

## 8.2 ClusterEntity

Suggested fields:

* `id`
* `title`
* `summary`
* `mainTopic`
* `articleIDs`
* `createdAt`

---

## 8.3 UserPreferenceEntity

Suggested fields:

* `id`
* `preferredCategories`
* `preferredTopics`
* `hiddenSources`
* `favoriteSources`
* `preferredLanguage`
* `updatedAt`

---

## 8.4 InteractionEntity

Suggested fields:

* `id`
* `articleID`
* `actionType`
* `timestamp`
* `readingDuration`
* `scrollDepth`

---

## 8.5 Repository Abstraction

SwiftData access is exposed to the rest of the app through two domain-level
protocols, `ArticleRepository` (`Domain/Repositories/ArticleRepository.swift`)
and `PreferenceRepository` (`Domain/Repositories/PreferenceRepository.swift`),
implemented respectively by `SwiftDataArticleRepository` and
`SwiftDataPreferenceRepository` under `Data/Repositories/`. Both concrete
implementations wrap the existing persistence types via delegation —
`ArticleLocalStore` (`@ModelActor`) and `UserPreferencesService` (`@MainActor`)
— so the predicate, sort, sanitization, and AppLogger logic stays in a single
canonical place while consumers (view models, services, use cases) depend
only on the protocol. View-model migration to the protocols and the eventual
retirement of the underlying services is intentionally deferred to a follow-up
refactor (see issue #30); a future Firebase sync layer (issue #12) can adopt
the same protocols without touching call sites.

---

## 9. Firebase Usage

## Recommended Firebase services

* **Firebase Auth** for optional login
* **Cloud Firestore** for synced preferences and saved items
* **Firebase Analytics** if analytics are needed
* **Firebase Cloud Messaging** if intelligent notifications are added later

## Suggested data to sync

* user profile
* interests
* saved articles references
* hidden sources
* read-later list
* onboarding choices

## Avoid storing in Firebase unless needed

* full article cache
* all RSS article content
* all AI outputs for every article

That should remain primarily local unless a specific product reason requires cloud sync.

---

## 10. AI Provider Abstraction

## 10.1 Protocol

```swift
protocol AIProvider {
    var id: AIProviderID { get }
    
    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult
    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult
    func generateTags(_ content: String, requestID: String?) async throws -> [String]
}
```

---

## 10.2 Provider Implementations

Suggested implementations:

* `OpenAIProvider`
* `ClaudeProvider`
* `GeminiProvider`
* `OllamaProvider`

Each provider should:

* accept API key / token configuration
* normalize request and response
* expose the same interface
* support provider-specific settings internally
* enforce strict JSON prompt-output contracts

---

## 10.3 AI Service

A central service should choose the active provider.

Example responsibilities:

* select provider from app settings
* validate token presence
* fail gracefully
* switch provider if user changes preference
* propagate request IDs to provider calls
* fail fast without auto-fallback to other providers

---

## 11. Token / Provider Configuration

## Suggested settings model

* active provider
* provider token (Keychain)
* explicit model name for each provider (required)
* local Ollama endpoint
* timeout settings

### Important security note

[Inferenza] For a real production app, storing raw third-party API keys directly on-device can be risky.

Recommended options:

* for personal/dev use: local secure storage via Keychain
* keep non-sensitive provider settings in a separate local settings store
* for shared/public release: move sensitive provider access behind your own backend when needed

---

## 12. Networking Strategy

## RSS Networking

* use `URLSession`
* background refresh if appropriate
* cache using HTTP headers when possible
* avoid aggressive polling

## AI Networking

* async/await
* request timeout handling
* retry only where appropriate
* structured error mapping

---

## 13. Data Flow

## 13.1 Feed Refresh Flow

1. App triggers RSS refresh
2. RSS client downloads feed XML
3. Parser extracts raw items
4. Normalizer builds article objects
5. SwiftData stores or updates articles
6. AI enrichment runs for eligible articles
7. Updated articles appear in feed UI

---

## 13.2 AI Enrichment Flow

1. Article content becomes available
2. AI service selects active provider
3. Provider generates:

   * summary
   * category
   * tags
4. Results are normalized
5. SwiftData updates local article record
6. UI refreshes automatically

---

## 13.3 User Preferences Flow

1. User selects interests
2. Preferences saved in SwiftData
3. If sync is enabled, preferences are mirrored to Firebase
4. Feed ranking service uses preferences to reorder content

---

## 14. Offline Strategy

Mercury should be designed as **local-first**.

### Available offline

* cached articles
* saved articles
* previous summaries
* preferences
* reading history

### Not guaranteed offline

* fresh RSS refresh
* cloud sync
* external AI providers

### Ollama note

[Inferenza] If Ollama is running on a reachable local machine or environment, some AI features may still work without cloud APIs.

---

## 15. Error Handling

## Error categories

* RSS fetch failures
* XML parsing failures
* AI provider failures
* token/auth errors
* persistence failures
* sync failures

## UI behavior

* user-friendly errors
* non-blocking fallbacks
* partial success should still be accepted

Example:

* RSS works but AI fails → article still shown
* local save works but Firebase sync fails → app still usable

---

## 16. Scalability Notes

To keep the app maintainable:

* isolate each AI provider
* keep view models lightweight
* use repositories for persistence access
* avoid mixing SwiftUI logic with feed parsing
* avoid coupling Firebase to all app features

---

## 17. Recommended MVP Architecture Scope

For the first version, implement:

* SwiftUI + MVVM
* SwiftData local storage
* RSS ingestion
* one AI abstraction layer
* at least one working provider first
* basic preferences locally
* Firebase only for sync if truly needed

### Suggested rollout

1. local-only app
2. RSS + article persistence
3. AI summarization/categorization
4. provider switcher
5. personalization
6. Firebase sync

---

## 18. Future Extensions

* article clustering engine
* semantic search
* push notifications
* multi-device sync
* source reputation scoring
* per-country feed packs
* full offline AI workflows
* user-defined provider configurations

---

## 19. Final Recommendation

Recommended architecture for Mercury:

* **MVVM** for presentation
* **SwiftUI** for the full UI
* **SwiftData** as the main local persistence layer
* **Firebase** only as an optional cloud-sync/user backend
* **provider-agnostic AI layer** supporting ChatGPT, Claude, Gemini, and Ollama

This gives Mercury:

* a native iOS-first structure
* clean separation of concerns
* easy extensibility for AI providers
* a good balance between personal-tool flexibility and production readiness

```
```
