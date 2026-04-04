---
validator: Review that retrieval returns semantically relevant facts
pass_threshold: 3
max_score: 6
criteria:
  - name: relevance
    range: [0, 3]
    levels:
      0: No facts relate to the query
      1: One fact is marginally relevant
      2: Most facts are relevant
      3: All facts are clearly relevant to the query topic
  - name: ranking
    range: [0, 2]
    levels:
      0: Random ordering
      1: Somewhat ordered by relevance
      2: Best match is ranked first
  - name: no_garbage
    range: [0, 1]
    levels:
      0: Contains clearly irrelevant noise results
      1: All results are at least tangentially related
---

## Context

This validator checks the semantic retrieval system (`cortex-retrieve.py`).
The system embeds facts via ollama nomic-embed-text and retrieves top-K by cosine similarity.
A good result returns facts that a human would also consider relevant to the query, with the most relevant fact ranked highest.
