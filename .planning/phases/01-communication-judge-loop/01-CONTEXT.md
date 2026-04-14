# Phase 1: Judge Functions and Rubric - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Implement `build_communication_judge_prompt()` and `judge_communication()` in `scripts/cortex/cortex-judge.py`, write the 5-dimension drive-summary rubric YAML, validate rubric discriminability on 10 historical summaries, wire the judge into cortex-drive Phase 6 (completion summary output), and write a test suite covering all behaviors.

</domain>

<decisions>
## Implementation Decisions

### Settled by Cortex research (do not revisit)

- **Judge model:** Haiku 4.5 (`claude-haiku-4-5-20251001`) — settled; do not change
- **Reuse `call_judge(prompt)`** — generic function in `cortex-judge.py`; takes any string prompt; returns structured JSON. Do NOT modify it.
- **New `build_communication_judge_prompt(message_text, rubric)`** — system prompt must declare "communication quality judge" (not "code quality judge"); include 5 dimensions and explicit rejection rule in prompt body
- **New `judge_communication(message, rubric_path, max_retries=3)`** — retry loop: call build_prompt → call_judge → if fail: build critique-guided rewrite prompt → call judge model for rewrite → retry; on cap: return escalation struct; write JSONL on every attempt
- **Retry cap = 3** — hard-coded, not a parameter
- **Explicit rejection rule:** `calibrated_uncertainty < 2` → FAIL regardless of aggregate score (0-4 dimension scale)
- **Aggregate threshold:** mean of dimension scores normalized to 0-1; ≥0.7 to pass
- **JSONL schema:** `{timestamp, slug, surface, judge_model, rubric_hash, original_message, rewrite_attempt, per_dimension_scores, aggregate_score, verdict, critique, rewrite_diff, confidence, calibration_corrections_applied}`
- **Rubric format:** YAML, same structure as existing rubrics in `docs/cortex/rubrics/{slug}/`

### Claude's Discretion

- Exact Python function signatures (beyond the required parameters above)
- Whether `judge_communication()` is in the same file as `call_judge()` or a thin wrapper module that imports it
- Rewrite prompt construction details (beyond: must include critique findings and instruct preservation of uncertainty markers)
- Test fixture approach (real API calls vs. mocked `call_judge()`)
- Discriminability check implementation (script vs. inline test)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/communication-judge-loop/spec.md
- docs/cortex/specs/communication-judge-loop/gsd-handoff.md
- docs/cortex/contracts/communication-judge-loop/contract-001.md
- docs/cortex/research/communication-judge-loop/concept-20260414T023306Z.md
- docs/cortex/clarify/communication-judge-loop/20260414T021615Z-clarify-brief.md
- scripts/cortex/cortex-judge.py (existing — read before modifying)

</canonical_refs>

<specifics>
## Specific Ideas

**`build_communication_judge_prompt()` structure:**
```
ROLE: You are a communication quality judge evaluating an AI-generated summary for an owner.
REJECTION RULE: If calibrated_uncertainty < 2, verdict MUST be FAIL regardless of other scores.
DIMENSIONS (score 0-4 each):
  - clarity: single reading comprehension; no ambiguous referents
  - actionability: owner can derive next step without follow-up
  - evidence_traceability: every claim references a specific artifact or finding
  - completeness: all 3 formula bullets present (what found / what changes / what's open)
  - calibrated_uncertainty: caveats and open questions preserved; no false confidence
THRESHOLD: aggregate (mean, normalized 0-1) >= 0.7 to pass
OUTPUT: JSON with {verdict, per_dimension_scores, aggregate_score, critique}
MESSAGE TO EVALUATE: {message_text}
```

**Rubric YAML structure** (`docs/cortex/rubrics/communication-judge-loop/drive-summary.yaml`):
```yaml
rubric: drive-summary
version: 1
surface: drive_completion_summary
dimensions:
  - name: clarity
    description: "Single reading comprehension; no ambiguous referents"
    threshold: 3
    scale: 4
  - name: actionability
    description: "Owner can derive next step without follow-up question"
    threshold: 3
    scale: 4
  - name: evidence_traceability
    description: "Every claim references a specific artifact or finding"
    threshold: 2
    scale: 4
  - name: completeness
    description: "All 3 formula bullets present (what found / what changes / what's open)"
    threshold: 3
    scale: 4
  - name: calibrated_uncertainty
    description: "Caveats and open questions preserved; no false confidence"
    threshold: 3
    scale: 4
aggregate_threshold: 0.7
rejection_rules:
  - dimension: calibrated_uncertainty
    condition: "< 2"
    verdict: FAIL
    note: "Applies regardless of aggregate score"
```

**cortex-drive Phase 6 integration point:**
In the SKILL.md Phase 6 section (completion summary output), wrap summary generation:
```
After generating the Level 1 summary, call judge_communication(summary, rubric_path).
If verdict == pass: deliver summary as-is.
If verdict == fail and attempts < 3: rewrite with critique guidance, retry.
If attempts == 3 and still fail: escalate — present original + final rewrite + critique to owner; do NOT deliver silently.
```

</specifics>

<deferred>
## Deferred Ideas

- Gate transition messages (clarify/spec/contract gates) — v2 surface
- Eval result summaries — v2 surface
- Best-of-N generation (generate 3 candidates, pick best) — viable v2 upgrade over sequential critique-revise
- Rubric editing GUI
- Model-agnostic judge infrastructure

</deferred>

---

*Phase: 01-communication-judge-loop*
*Context gathered: 2026-04-14 via /cortex-bridge*
