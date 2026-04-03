# Eval Proposal: memory-extraction

**Slug:** memory-extraction
**Timestamp:** 20260403T230000Z
**Status:** draft

---

## Proposed Dimensions

### 1. Functional Correctness
**Applies because:** 9 done criteria, all mechanically verifiable — file existence, JSONL validity, field presence, dedup logic, performance.
**approval_required:** false

### 2. Regression
**Applies because:** 2 existing files modified (cortex-precompact.sh, runtime-manifest.json) + cortex-postcompact.sh replaced by .js. Existing behavior (last-compact-summary.md, next-prompt.md) must be preserved.
**approval_required:** false

### 3. Integration
**Applies because:** PreCompact fires before PostCompact — the enriched snapshot must be available for fact extraction. Hook registration in runtime-manifest.json + settings.json must be consistent.
**approval_required:** false

### 4. Safety/Security
**Applies because:** EXCLUDED. No auth, secrets, or untrusted input. Internal tooling on local artifacts.

### 5. Performance
**Applies because:** EXCLUDED via threshold. Contract specifies <5s but this is a soft check, not a measurable benchmark with variance.

### 6. Resilience
**Applies because:** EXCLUDED. No network calls, external APIs, or failure recovery paths.

### 7. Style
**Applies because:** New Node.js hook + enhanced bash script must follow existing hook conventions.
**approval_required:** false

### 8. UX/Taste
**Applies because:** EXCLUDED. No user-facing output changes — facts.jsonl is internal, existing outputs preserved verbatim.

---

## Document-Level Approval Flag

**approval_required:** false

**Reviewer:** (none required — all dimensions are mechanical)

**Approval Status:** approved
