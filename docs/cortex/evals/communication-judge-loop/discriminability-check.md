# Discriminability Check — drive-summary Rubric

**Date:** 2026-04-14
**Rubric:** docs/cortex/rubrics/communication-judge-loop/drive-summary.yaml
**Purpose:** Validate that the rubric produces both PASS and FAIL verdicts across a representative sample of summaries with different quality levels. A rubric that always passes or always fails is uninformative.

## Method

10 sample messages were crafted to span the quality spectrum: clear FAIL, borderline, and clear PASS. Per-dimension scores were assigned by a human evaluator. Scoring logic was applied inline (rejection rule + aggregate threshold) to determine the verdict. No API calls were made.

**Scoring logic:**
- Rejection rule: if `calibrated_uncertainty < 2`, verdict = FAIL regardless of aggregate
- Aggregate: `mean(scores) / 4.0`; if aggregate >= 0.7, verdict = PASS; else FAIL

---

## Sample Messages and Scores

### Sample 1 — Clear FAIL (missing all formula bullets)

**Message:**
> semantic-retrieval — COMPLETE. The retrieval system has been improved. It is faster now.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 3 | Status line is clear |
| actionability | 1 | No next step; owner can't tell what to do |
| evidence_traceability | 0 | No artifacts or findings referenced |
| completeness | 0 | Missing all 3 formula bullets |
| calibrated_uncertainty | 3 | No false confidence but nothing meaningful to caveat |

Aggregate: (3+1+0+0+3)/(5×4) = 7/20 = **0.35** → **FAIL**

---

### Sample 2 — Clear FAIL (rejection rule: calibrated_uncertainty = 1)

**Message:**
> smart-retry-logic — COMPLETE. Retry logic is now fully operational with zero known issues. The system handles all edge cases perfectly. Owner can deploy immediately with full confidence.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 4 | Clear |
| actionability | 4 | Explicit owner action stated |
| evidence_traceability | 2 | Some implicit references |
| completeness | 3 | 3 bullets present |
| calibrated_uncertainty | 1 | "zero known issues", "all edge cases", "full confidence" — extreme overconfidence |

Aggregate would be (4+4+2+3+1)/(5×4) = 14/20 = 0.70, but **rejection rule fires**: calibrated_uncertainty=1 < 2 → **FAIL** (regardless of aggregate)

---

### Sample 3 — Clear FAIL (evidence_traceability=0, completeness=1)

**Message:**
> auth-middleware — STOPPED. We found some problems with the middleware and couldn't finish. There are still things to do.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 2 | "some problems" and "things to do" are ambiguous referents |
| actionability | 1 | Owner has no specific next step |
| evidence_traceability | 0 | No specific artifacts or findings referenced |
| completeness | 1 | Status line present, but no delta bullets and no risk line |
| calibrated_uncertainty | 3 | Appropriately uncertain |

Aggregate: (2+1+0+1+3)/(5×4) = 7/20 = **0.35** → **FAIL**

---

### Sample 4 — Borderline FAIL (just below aggregate threshold)

**Message:**
> report-clarity — COMPLETE. Owner summaries now include a structured format. The output format was changed. Future reports may still need adjustment depending on context.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 3 | Mostly clear |
| actionability | 2 | Vague — "may need adjustment" doesn't specify next step |
| evidence_traceability | 1 | "The output format" — no specific file or artifact |
| completeness | 2 | Status line + 1 delta bullet; no explicit risk line |
| calibrated_uncertainty | 3 | Appropriately hedged |

Aggregate: (3+2+1+2+3)/(5×4) = 11/20 = **0.55** → **FAIL**

---

### Sample 5 — Borderline FAIL (calibrated_uncertainty = 2, passes rejection rule; aggregate low)

**Message:**
> cortex-vault — COMPLETE. The vault now stores typed facts. Retrieval was added. Some edge cases around stale entries remain unclear.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 3 | Clear enough |
| actionability | 1 | No specific owner ask stated |
| evidence_traceability | 1 | No artifact references |
| completeness | 2 | Status + 2 bullets, no risk line |
| calibrated_uncertainty | 2 | One caveat ("some edge cases remain unclear") — passes rejection rule |

Aggregate: (3+1+1+2+2)/(5×4) = 9/20 = **0.45** → **FAIL** (rejection rule does NOT apply; aggregate is the decider)

---

### Sample 6 — Borderline PASS (exactly at threshold)

**Message:**
> gate-critique — COMPLETE. LLM critique now runs before research_complete is set. The `cortex-phase-guard.sh` hook was updated to check for a critique receipt before advancing. Known gap: the critique-dossier gate only fires when ANTHROPIC_API_KEY is present; local dev without the key bypasses it.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 4 | Clear, no ambiguous referents |
| actionability | 2 | No explicit owner ask (completed, no action needed) |
| evidence_traceability | 3 | Specific file named (cortex-phase-guard.sh) |
| completeness | 3 | Status + 1 delta bullet + risk line (the known gap) |
| calibrated_uncertainty | 2 | Known limitation explicitly stated — passes rejection rule |

Aggregate: (4+2+3+3+2)/(5×4) = 14/20 = **0.70** → **PASS** (exactly at threshold)

---

### Sample 7 — Clear PASS (full formula, good evidence)

**Message:**
> eval-system-refactor — COMPLETE. Eval execution pipeline is now fully wired: owners can run `/cortex-eval-run <slug>` to score judgment validators without manual Codex invocation.

**Changes:**
- `scripts/cortex/codex-eval-executor.sh` now runs evals in isolation and writes results to `/tmp/eval-result-{slug}-{timestamp}.json`
- `scripts/cortex/format-eval-results.py` converts raw JSON to human-readable markdown
- 61 tests added covering executor, formatter, and schema validation

**Risk:** Anti-sycophancy cross-vendor validation (Haiku vs Sonnet agreement) has not been tested end-to-end; a model update could shift verdicts without triggering test failures.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 4 | Plain language, no jargon |
| actionability | 4 | Owner knows exactly what command to run |
| evidence_traceability | 4 | Specific file names for every claim |
| completeness | 4 | All 3 formula bullets present |
| calibrated_uncertainty | 4 | Specific risk named with mechanism |

Aggregate: (4+4+4+4+4)/(5×4) = 20/20 = **1.00** → **PASS**

---

### Sample 8 — Clear PASS (complete, well-cited, appropriate uncertainty)

**Message:**
> communication-judge-loop — COMPLETE. Drive completion summaries are now quality-gated before delivery; a 5-dimension rubric evaluates each summary and triggers a rewrite loop when it fails.

**Changes:**
- `judge_communication()` added to `scripts/cortex/cortex-judge.py`; evaluates summaries against `docs/cortex/rubrics/communication-judge-loop/drive-summary.yaml`
- Retry loop in `cortex-drive/SKILL.md` Phase 6: up to 3 attempts with critique-guided rewrites
- JSONL calibration log written to `~/.cortex/calibration/comm-judge-{hash}.jsonl` on every attempt

**Risk:** Rubric discriminability was validated on crafted samples, not real production summaries; the thresholds may need adjustment after first month of real usage.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 4 | Clear |
| actionability | 3 | No explicit owner ask (complete); risk line implies monitoring |
| evidence_traceability | 4 | Specific file names for every change |
| completeness | 4 | All 3 formula bullets |
| calibrated_uncertainty | 4 | Known limitation named with specific trigger for future revision |

Aggregate: (4+3+4+4+4)/(5×4) = 19/20 = **0.95** → **PASS**

---

### Sample 9 — Borderline PASS (one weak dimension, passes threshold)

**Message:**
> semantic-retrieval — COMPLETE. Fact retrieval now returns semantically relevant results. The `cortex-vault-extractor.py` embedding pipeline was updated to use cosine similarity with a 0.7 threshold. Open: cold-start performance (first query after deploy hits no cache) needs owner decision on acceptable latency.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 4 | Clear |
| actionability | 3 | Owner ask present (cold-start decision) |
| evidence_traceability | 3 | File named for the change |
| completeness | 3 | Status + delta + open question as risk |
| calibrated_uncertainty | 3 | Open question explicitly surfaced |

Aggregate: (4+3+3+3+3)/(5×4) = 16/20 = **0.80** → **PASS**

---

### Sample 10 — Borderline FAIL (calibrated_uncertainty exactly 2, aggregate just below)

**Message:**
> system-map-memory — COMPLETE. System map now includes memory components. The map file was updated. The completeness of the new components is not fully verified.

| Dimension | Score | Notes |
|-----------|-------|-------|
| clarity | 3 | Mostly clear |
| actionability | 1 | No next step for owner |
| evidence_traceability | 1 | "The map file" — no path |
| completeness | 2 | Status + 1 vague delta; no explicit risk line format |
| calibrated_uncertainty | 2 | One hedge present — passes rejection rule |

Aggregate: (3+1+1+2+2)/(5×4) = 9/20 = **0.45** → **FAIL**

---

## Summary

| Sample | Type | Verdict | Aggregate | Rejection Rule |
|--------|------|---------|-----------|----------------|
| 1 | Clear FAIL — missing formula | FAIL | 0.35 | N |
| 2 | Clear FAIL — overconfident | FAIL | 0.70* | Y (calibrated_uncertainty=1) |
| 3 | Clear FAIL — vague, no evidence | FAIL | 0.35 | N |
| 4 | Borderline FAIL | FAIL | 0.55 | N |
| 5 | Borderline FAIL | FAIL | 0.45 | N (calibrated_uncertainty=2) |
| 6 | Borderline PASS | PASS | 0.70 | N |
| 7 | Clear PASS — perfect | PASS | 1.00 | N |
| 8 | Clear PASS — production-quality | PASS | 0.95 | N |
| 9 | Borderline PASS | PASS | 0.80 | N |
| 10 | Borderline FAIL | FAIL | 0.45 | N |

*Aggregate shown for reference; verdict driven by rejection rule.

**Distribution: 6 FAIL, 4 PASS**

## Conclusion

The rubric discriminates. It produces both PASS and FAIL verdicts across the sample set. Key observations:

1. **Rejection rule fires correctly**: Sample 2 would have passed on aggregate (0.70) but is blocked by the calibrated_uncertainty=1 rejection rule. This is the intended behavior.
2. **Threshold is meaningful**: The 0.70 aggregate threshold separates samples with clear formula compliance and evidence from those that are vague or incomplete.
3. **Borderline cases cluster around completeness + evidence_traceability**: Summaries that have status lines but lack specific artifact references or explicit risk lines consistently fall into the 0.45-0.55 range.
4. **Calibrated_uncertainty = 2 passes the rejection rule but may still fail on aggregate**: Sample 5 and 10 show that avoiding false confidence is necessary but not sufficient.

Rubric is ready for production use. Recommend re-running discriminability after first month of real production verdicts to calibrate thresholds against actual output distribution.
