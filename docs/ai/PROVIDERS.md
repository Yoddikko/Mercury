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
    var name: String { get }
    
    func summarize(_ text: String) async throws -> SummaryResult
    func categorize(_ text: String) async throws -> CategoryResult
    func generateEmbedding(_ text: String) async throws -> [Float]
}
```

---

## Provider Selection

The active provider is selected based on:

* user settings
* available API tokens
* fallback logic (optional)

---

## Supported Providers

### OpenAI

* supports: summarization, categorization, embeddings

---

### Claude

* supports: summarization, categorization
* [Inferenza] embedding support may vary

---

### Gemini

* supports: summarization, categorization, embeddings

---

### Ollama

* local model support
* requires local endpoint

---

## Token Management

Each provider requires:

* API key or endpoint configuration

Suggested storage:

* Keychain (for sensitive data)

---

## Error Handling

* handle timeouts
* handle invalid tokens
* handle rate limits

---

## Fallback Strategy (Optional)

If provider fails:

* retry
* switch provider (if configured)

---

## Rules

* never call providers directly from UI
* always go through AIService
* normalize outputs across providers

---

## Notes

* providers may differ in capabilities
* abstraction layer must hide differences
