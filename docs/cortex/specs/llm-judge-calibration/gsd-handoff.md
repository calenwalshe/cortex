# GSD Handoff: llm-judge-calibration

**Slug:** llm-judge-calibration
**Timestamp:** 20260404T005000Z
**Status:** ready

---

## Objective

Build an LLM judge that scores [judgment] contract validators against rubrics via Claude Haiku 4.5, with a calibration loop where human corrections feed back as few-shot examples — reducing the human bottleneck on subjective quality gates.

---

## Deliverables

- `scripts/cortex/cortex-judge.py` — judge CLI with `run` and `correct` subcommands
- `docs/cortex/rubrics/semantic-retrieval/*.rubric.md` — sample rubrics
- `docs/cortex/evals/semantic-retrieval/judge-report.md` — sample judge report
- `test/test_llm_judge.py` — test suite

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write rubric YAML parser
- [ ] Write `cortex-judge.py run <slug>` — find contract, extract [judgment] validators, load rubrics, call Haiku, output verdicts
- [ ] Write `cortex-judge.py correct` — append calibration JSONL
- [ ] Write calibration loader with few-shot injection
- [ ] Write contract [judgment] validator parser
- [ ] Write judge report generator
- [ ] Create sample rubrics for semantic-retrieval
- [ ] Write tests
- [ ] End-to-end verification

---

## Acceptance Criteria

- [ ] `cortex-judge.py run <slug>` scores all [judgment] validators
- [ ] Each judgment produces {pass, confidence, scores, reasoning}
- [ ] Confidence >= 0.7 auto-passes; < 0.7 flags for review
- [ ] `cortex-judge.py correct` appends calibration JSONL
- [ ] Subsequent calls include calibration as few-shot
- [ ] Judge report written to docs/cortex/evals/{slug}/
- [ ] Works without rubric files (default rubric with warning)
- [ ] Clear error when API key missing
- [ ] All tests pass

---

## Contract Link

docs/cortex/contracts/llm-judge-calibration/contract-001.md
