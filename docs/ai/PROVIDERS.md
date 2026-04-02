# AI Providers

## Description

Defines how Mercury integrates multiple AI providers.

Supported providers:

* OpenAI (ChatGPT)
* Anthropic (Claude)
* Google (Gemini)
* Ollama (local)

---

## Design Principle

All providers must implement a common interface.

The app must not depend on a single provider.

---

## Provider Interface

```swift id="7d2k9x"
protocol AIProvider {
    var id: AIProviderID { get }
    
    func summarizeArticle(_ content: String, requestID: String?) async throws -> AISummaryResult
    func categorizeArticle(_ content: String, requestID: String?) async throws -> AICategoryResult
    func generateTags(_ content: String, requestID: String?) async throws -> [String]
}
```

---

## Provider Selection

The active provider is selected based on:

* user settings
* available API tokens
* valid provider configuration

---

## Supported Providers

### OpenAI

* supports: summarization, categorization, tags

---

### Claude

* supports: summarization, categorization
* supports: tags

---

### Gemini

* supports: summarization, categorization, tags

---

### Ollama

* local model support
* requires local endpoint
* token optional

---

## Token Management

Each provider requires:

* model name
* timeout
* endpoint (Ollama only)
* token for OpenAI, Claude, and Gemini

Suggested storage:

* Keychain for tokens
* settings store for non-sensitive values

---

## Error Handling

* handle timeouts
* handle invalid tokens
* handle rate limits
* map provider responses into shared `AIProviderError`

---

## Fallback Strategy

`AIService` is fail-fast by design:

* no automatic provider switch
* no implicit mock fallback
* caller decides retries or provider changes

---

## Rules

* never call providers directly from UI
* always go through AIService
* normalize outputs across providers
* keep output deterministic (`shortSummary`, `bullets`, `category`, `tags`)

---

## Notes

* providers may differ in response shape
* abstraction layer hides provider-specific request/response details
* no default models are assumed; every provider model must be explicitly configured
