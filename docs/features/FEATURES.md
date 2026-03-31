# 🪽 Mercury — AI News Aggregator

## 1. Overview

**Mercury** is an AI-powered news aggregation application designed to reduce information overload by collecting, organizing, and transforming news from multiple sources into a personalized and structured experience.

The system retrieves articles from RSS feeds and enhances them using AI for:

-   categorization
    
-   summarization
    
-   clustering (event detection)
    
-   personalization
    

----------

## 2. Core Concepts

### 2.1 Article

Represents a single news item retrieved from RSS feeds.

**Fields:**

-   id
    
-   title
    
-   source
    
-   publish_date
    
-   url
    
-   raw_content
    
-   cleaned_content
    
-   summary
    
-   category
    
-   tags
    
-   embedding_vector
    

----------

### 2.2 Cluster (Event)

A group of articles referring to the same real-world event.

**Fields:**

-   id
    
-   title
    
-   articles[]
    
-   cluster_summary
    
-   main_topics
    
-   created_at
    

----------

### 2.3 User Profile

Represents user preferences and behavior.

**Fields:**

-   id
    
-   preferred_categories[]
    
-   preferred_topics[]
    
-   saved_articles[]
    
-   interaction_history
    
-   embedding_profile (optional)
    

----------

## 3. Feature Specifications

----------

## 3.1 RSS Aggregation

### Description

Mercury retrieves news from multiple RSS feeds and normalizes the data.

### Flow

1.  Fetch RSS feeds periodically
    
2.  Parse XML content
    
3.  Extract metadata:
    
    -   title
        
    -   link
        
    -   description
        
    -   publish date
        
4.  Store raw articles
    

### Output

-   Structured list of articles
    

----------

## 3.2 Content Cleaning

### Description

Prepares article content for AI processing.

### Steps

-   Remove HTML tags
    
-   Remove ads and irrelevant elements
    
-   Extract main textual content
    
-   Normalize encoding
    

----------

## 3.3 AI Categorization

### Description

Assigns a category and relevant topics to each article.

### Input

-   cleaned_content
    

### Output

-   category (single label)
    
-   tags (multiple keywords)
    

### Example

-   Category: Technology
    
-   Tags: AI, Apple, Startups
    

----------

## 3.4 AI Summarization

### Description

Generates concise summaries to improve readability.

### Modes

-   Short summary (2–3 sentences)
    
-   Bullet points
    
-   TL;DR
    

### Input

-   cleaned_content
    

### Output

-   summary_text
    

----------

## 3.5 Embedding Generation

### Description

Transforms articles into vector representations.

### Purpose

-   similarity detection
    
-   clustering
    
-   personalization
    

### Input

-   cleaned_content
    

### Output

-   embedding_vector
    

----------

## 3.6 Clustering (Event Detection)

### Description

Groups articles referring to the same event.

### Logic

-   Compare embedding similarity
    
-   Apply similarity threshold
    
-   Assign to existing cluster or create new one
    

### Output

-   Clusters of related articles
    

----------

## 3.7 Multi-Article Summarization

### Description

Generates a unified summary for each cluster.

### Input

-   articles within a cluster
    

### Output

-   cluster_summary
    
-   key points shared across sources
    

----------

## 3.8 Personalized Feed

### Description

Ranks and displays articles based on user preferences.

### Inputs

-   article metadata
    
-   user profile
    
-   interaction history
    

### Ranking Factors

-   category relevance
    
-   topic relevance
    
-   recency
    
-   engagement signals
    
-   diversity (optional)
    

### Output

-   ordered feed
    

----------

## 3.9 User Preference Initialization

### Description

Initial onboarding where users select interests.

### Inputs

-   categories
    
-   topics
    

### Output

-   initialized user profile
    

----------

## 3.10 Behavior Tracking

### Description

Tracks user interactions to refine personalization.

### Tracked Events

-   article opened
    
-   reading time
    
-   scroll depth
    
-   saved/bookmarked articles
    

----------

## 3.11 Semantic Search

### Description

Allows users to search using natural language.

### Input

-   user query
    

### Process

-   convert query into embedding
    
-   compare with article embeddings
    

### Output

-   ranked relevant articles
    

----------

## 3.12 Explain News (Optional)

### Description

Provides simplified explanations of complex news.

### Output

-   simplified explanation
    
-   clarified key concepts
    

----------

## 3.13 Time-Based Mode

### Description

Adapts content based on available user time.

### Modes

-   1 minute → key summaries only
    
-   5 minutes → extended overview
    

----------

## 4. Data Flow

1.  Fetch RSS feeds
    
2.  Store raw articles
    
3.  Clean content
    
4.  Generate:
    
    -   embeddings
        
    -   categories
        
    -   summaries
        
5.  Perform clustering
    
6.  Generate cluster summaries
    
7.  Store enriched data
    
8.  Serve personalized feed
    

----------

## 5. Non-Functional Requirements

### Performance

-   Fast feed loading (cached)
    
-   AI processing handled asynchronously
    

### Scalability

-   Modular AI pipeline
    
-   decoupled services
    

### Maintainability

-   separation of concerns:
    
    -   ingestion
        
    -   processing
        
    -   presentation
        

----------

## 6. Future Extensions

-   adaptive user embeddings
    
-   real-time trending detection
    
-   cross-language summarization
    
-   offline AI models
    

----------

## 7. MVP Scope (Thesis Version)

-   RSS aggregation
    
-   content cleaning
    
-   AI categorization
    
-   AI summarization
    
-   basic clustering
    
-   basic personalization
    

----------

## 8. Vision

Mercury aims to transform the way users consume news by:

-   reducing redundancy
    
-   increasing clarity
    
-   adapting information to individual needs
    

The system acts as an intelligent layer between raw information and human understanding.# 🪽 Mercury — AI News Aggregator