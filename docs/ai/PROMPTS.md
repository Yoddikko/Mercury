# AI Prompts

## Description

Defines how prompts are structured for AI tasks.

---

## General Rules

* be explicit
* avoid ambiguity
* constrain output format
* avoid hallucinations

---

## Summarization Prompt

### Goal

Generate concise summary

### Template

```id="k9s1hd"
Summarize the following article.

Rules:
- Use only the provided content
- Do not add external information
- Keep it concise (max 3 sentences)

Article:
{{content}}
```

---

## Bullet Summary Prompt

```id="a7c0pz"
Summarize the article into bullet points.

Rules:
- 3 to 5 bullet points
- Each bullet must be short
- No repetition

Article:
{{content}}
```

---

## Categorization Prompt

```id="d91mxf"
Classify the article into one category and extract tags.

Categories:
Technology, Business, Politics, Economy, Science, World, Sports, Culture, Health

Rules:
- Return exactly one category
- Return 3–8 tags
- Tags must be short

Article:
{{content}}
```

---

## Output Format (Important)

All responses should be structured:

```json id="c8slq3"
{
  "category": "...",
  "tags": ["..."],
  "summary": "...",
  "bullets": ["..."]
}
```

---

## Rules

* never return unstructured text
* always respect format
* discard invalid responses

---

## Notes

* prompts may evolve
* should be versioned if changed significantly
* keep prompts simple and deterministic
