# Feature: Categorization

## Description

Assigns a category and relevant topics (tags) to each article using AI.

This feature enables:

* content organization
* filtering
* personalization
* feed ranking

---

## Inputs

* cleanedContent

---

## Outputs

* category (string)
* tags (array of strings)

---

## Category Structure

### Main Categories (suggested)

* Technology
* Business
* Politics
* Economy
* Science
* World
* Sports
* Culture
* Health

---

## Tag Structure

Tags should be:

* specific
* short
* meaningful

### Examples

* AI
* Apple
* Startups
* EU
* Cybersecurity

---

## Flow

1. Article has cleanedContent
2. AI provider is selected
3. Categorization request is sent
4. Response is parsed
5. Article is updated with:

   * category
   * tags

---

## Rules

* Always return exactly **one category**
* Tags must be:

  * lowercase (recommended)
  * no duplicates
* Maximum tags: 5–10
* Do not invent information outside content

---

## Edge Cases

* unclear content → fallback category = "World"
* empty content → skip categorization
* AI failure → retry or leave empty
* malformed response → discard

---

## Notes

* Categorization is critical for:

  * feed ranking
  * filtering
  * personalization
* Should run asynchronously after article creation
* Results should be cached
