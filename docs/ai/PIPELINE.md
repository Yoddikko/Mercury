# AI Pipeline

## Description

Defines how Mercury processes articles using AI.

The pipeline transforms raw article content into structured, enriched data.

---

## Pipeline Steps

1. Content Cleaning
2. Embedding Generation
3. Categorization
4. Summarization
5. Clustering (optional, uses embeddings)

---

## Step 1 — Content Cleaning

### Input

* rawContent

### Output

* cleanedContent

### Rules

* remove HTML
* remove ads/noise
* extract main text only
* normalize encoding

---

## Step 2 — Embedding Generation

### Input

* cleanedContent

### Output

* embedding_vector

### Purpose

* similarity comparison
* clustering
* semantic search
* personalization (future)

---

## Step 3 — Categorization

### Input

* cleanedContent

### Output

* category
* tags

### Notes

* must return one category
* must return multiple tags

---

## Step 4 — Summarization

### Input

* cleanedContent

### Output

* summaryShort
* summaryBullets

---

## Step 5 — Clustering (Optional)

### Input

* embedding_vector

### Output

* clusterID

### Logic

* compare similarity with existing embeddings
* assign to cluster or create new one

---

## Execution Strategy

### Async Processing

* AI steps should run asynchronously
* UI must not block

---

### Incremental Enrichment

Articles can be progressively enriched:

1. article created (basic data)
2. categorization
3. summarization
4. clustering

---

### Caching

* do not recompute results unnecessarily
* store AI outputs in SwiftData
* reuse cached results

---

## Failure Handling

If AI fails:

* do not block article creation
* skip failed step
* retry later if needed

---

## Ordering Constraints

* cleaning must happen before all AI steps
* embedding should happen before clustering
* summarization and categorization can run independently

---

## Notes

* pipeline must be modular
* each step should be independently testable
* future steps can be added without breaking existing flow
