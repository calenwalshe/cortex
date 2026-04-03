# Current State

**slug:** semantic-retrieval

**mode:** clarify

**approval_status:** pending

**active_contract_path:** (none)

**recent_artifacts:**
- docs/cortex/clarify/semantic-retrieval/20260403T233000Z-clarify-brief.md

**open_questions:**
- Storage format for embeddings (npy vs SQLite vs JSONL+base64)
- Model choice (MiniLM-L6-v2 vs mpnet-base-v2 vs ollama)
- Cold start problem for hooks
- Query interface design (Python CLI vs Node wrapper)
- Embedding staleness tracking
- Retrieval consumer surface (which hooks/skills)

**blockers:**
- (none)

**next_action:** Run /cortex-research --phase concept to begin concept research
