# Roadmap: communication-judge-loop — Drive Summary Quality Gate

## Overview

Add `judge_communication()` to `cortex-judge.py` and wire it into cortex-drive's completion summary output so that drive summaries are evaluated against a 5-dimension rubric, rewritten on failure (max 3 attempts), and escalated to the owner when the retry cap is exhausted.

## Phases

### Phase 1: Judge Functions and Rubric

**Goal**: Implement `build_communication_judge_prompt()` and `judge_communication()` in `cortex-judge.py`, write the drive-summary rubric YAML, validate rubric discriminability on historical summaries, wire into cortex-drive Phase 6, and write tests.
**Depends on**: Nothing
**Requirements**: None formalized
**Success Criteria** (what must be TRUE):
1. A drive completion summary that omits any of the 3 required formula elements (what was found, what it changes, what is still open) is blocked from delivery and rewritten before being shown to the owner
2. A drive completion summary that drops a caveat or uncertainty scores < 2/4 on `calibrated_uncertainty` and is blocked from delivery (explicit rejection rule; applies regardless of aggregate score)
3. A message that fails the rubric receives structured critique, is rewritten, and retried — up to a hard cap of 3 attempts
4. When the retry cap is exhausted, the system escalates to the owner with the original message, the final rewrite attempt, and the critique — it does not silently deliver any version
5. Each judge run is persisted to `~/.cortex/calibration/comm-judge-{rubric-hash}.jsonl` with: original message, per-dimension scores, aggregate score, verdict, rewrite diff, and judge model version
6. The rubric file lives at `docs/cortex/rubrics/communication-judge-loop/drive-summary.yaml` and is human-editable
7. The judge uses `call_judge()` from `scripts/cortex/cortex-judge.py` via a new `build_communication_judge_prompt()` function — no new judge infrastructure is introduced
8. The communication judge does not gate internal machine-to-machine messages or v2 surfaces — only drive completion summaries in v1
**Research**: Unlikely — all design decisions resolved in Cortex research phase
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Judge Functions and Rubric | 0/0 | Not started | - |
