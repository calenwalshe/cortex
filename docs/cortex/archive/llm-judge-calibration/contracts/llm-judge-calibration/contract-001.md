# Contract: llm-judge-calibration — execute

**ID:** llm-judge-calibration-001
**Slug:** llm-judge-calibration
**Phase:** execute
**Created:** 20260404T005000Z
**Status:** approved
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build an LLM judge CLI that scores [judgment] contract validators against rubrics via Claude Haiku 4.5, with calibration loop for continuous improvement through human corrections.

---

## Deliverables

- `scripts/cortex/cortex-judge.py` — judge CLI
- `docs/cortex/rubrics/semantic-retrieval/relevance.rubric.md` — sample rubric
- `docs/cortex/rubrics/semantic-retrieval/degradation.rubric.md` — sample rubric
- `docs/cortex/evals/semantic-retrieval/judge-report.md` — generated report
- `test/test_llm_judge.py` — test suite

---

## Scope

### In Scope

- Judge CLI with `run` and `correct` subcommands
- YAML rubric parser
- Claude Haiku 4.5 API integration
- Calibration JSONL storage and few-shot injection
- Contract [judgment] validator extraction
- Judge report generation
- Default rubric generation when no rubric file exists
- Tests

### Out of Scope

- Local model judging, gate-check integration, UI, external eval platforms

---

## Write Roots

- `scripts/cortex/cortex-judge.py`
- `docs/cortex/rubrics/`
- `docs/cortex/evals/`
- `~/.cortex/calibration/`
- `test/test_llm_judge.py`

---

## Done Criteria

- [ ] `cortex-judge.py run <slug>` scores all [judgment] validators in the contract
- [ ] Each judgment produces {pass, confidence, scores, reasoning} as structured output
- [ ] Confidence >= 0.7 auto-passes/fails; < 0.7 flags for human review
- [ ] `cortex-judge.py correct` appends calibration JSONL to ~/.cortex/calibration/
- [ ] Subsequent judge calls include calibration examples as few-shot context
- [ ] Judge report written to docs/cortex/evals/{slug}/judge-report.md
- [ ] Works without rubric files (generates default rubric from validator text)
- [ ] Clear error when ANTHROPIC_API_KEY is missing
- [ ] All tests pass

---

## Validators

- [ ] [external] `python3 scripts/cortex/cortex-judge.py run semantic-retrieval 2>&1 | head -5` — runs without crash
- [ ] [external] `test -f docs/cortex/evals/semantic-retrieval/judge-report.md && echo OK` — report generated
- [ ] [external] `python3 -m pytest test/test_llm_judge.py -v` — all tests pass
- [ ] [judgment] Review that judge reasoning is coherent and scores match the rubric criteria
- [ ] [judgment] Review that calibration corrections actually shift subsequent judge behavior

---

## Eval Plan

docs/cortex/evals/llm-judge-calibration/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: llm-judge-calibration-001 COMPLETE -->

---

## Failed Approaches

<!-- Initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/cortex/cortex-judge.py`
- Delete `docs/cortex/rubrics/semantic-retrieval/`
- Delete `docs/cortex/evals/semantic-retrieval/judge-report.md`
- Delete `~/.cortex/calibration/` contents
- Delete `test/test_llm_judge.py`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
