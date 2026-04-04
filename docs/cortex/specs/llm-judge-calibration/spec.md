# Spec: llm-judge-calibration

**Slug:** llm-judge-calibration
**Timestamp:** 20260404T005000Z
**Status:** approved

---

## 1. Problem

Cortex contracts contain `[judgment]` validators that require human review — the only manual bottleneck in an otherwise automated pipeline. There is no way to get automated scoring on subjective quality criteria (semantic relevance, warning clarity, UX taste), which means every contract closure blocks on a human reviewer. The system needs an LLM judge that scores these validators against rubrics, with a calibration loop where human corrections improve the judge over time.

---

## 2. Scope

### In Scope

- `cortex-judge.py` CLI that scores `[judgment]` validators against rubrics via Claude Haiku 4.5
- YAML rubric format in `docs/cortex/rubrics/{slug}/` files
- Calibration storage in `~/.cortex/calibration/` (global, JSONL, keyed by rubric hash)
- `cortex-judge correct` subcommand for human corrections that feed back as few-shot examples
- Judge report output to `docs/cortex/evals/{slug}/judge-report.md`
- Confidence-based auto-pass (>=0.7) vs flag-for-review (<0.7)

### Out of Scope

- Replacing human judgment entirely (humans remain final authority on flagged items)
- Scoring `[external]` validators (deterministic, don't need judgment)
- Fine-tuning or training models (few-shot calibration only)
- UI for calibration review
- Integration with external eval platforms
- Modifying gate-check skill (judge runs separately)
- Local-only judging (phi3 proven unusable — API required)

---

## 3. Architecture Decision

**Chosen approach:** Claude Haiku 4.5 via Anthropic API as sole judge, with YAML rubrics and JSONL calibration storage.

**Rationale:** phi3:3.8b benchmarked at 45s with hallucination — no viable local option. Haiku delivers 1.7s latency, $0.003/judgment, perfect JSON compliance, and correct reasoning. Calibration loop validated: human corrections as few-shot examples measurably shift judge behavior.

### Alternatives Considered

- **ollama phi3:3.8b (local):** Rejected — 45s latency, hallucinated mid-JSON output. 3.8B params insufficient for structured judgment tasks.
- **Inline rubrics in contracts:** Rejected — bloats contract format. Separate files allow versioning and reuse.
- **Per-project calibration:** Rejected — cross-project learning is more valuable. Rubrics are domain-agnostic.
- **Integrated into gate-check:** Rejected — would add 1.7s API calls to every gate-check run. Judge runs separately.

---

## 4. Interfaces

- **Anthropic API** (`api.anthropic.com/v1/messages`) — reads: judge responses. Requires `ANTHROPIC_API_KEY` env var.
- **`docs/cortex/rubrics/{slug}/*.rubric.md`** — new files. YAML frontmatter with criteria, markdown body with context.
- **`~/.cortex/calibration/{rubric-hash}.jsonl`** — new global files. Append-only calibration corrections.
- **`docs/cortex/contracts/{slug}/contract-*.md`** — reads `[judgment]` validators. Does not modify.
- **`docs/cortex/evals/{slug}/judge-report.md`** — new file. Judge output report per slug.
- **`scripts/cortex/cortex-judge.py`** — new CLI. Entry point for all judge operations.

---

## 5. Dependencies

- **anthropic Python SDK or urllib** — for Claude API calls. Use urllib (no extra dependency).
- **PyYAML or manual YAML parsing** — for rubric frontmatter. Use simple regex parser (no pip dependency).
- **ANTHROPIC_API_KEY** — environment variable. Already present on target machine.
- **Existing contracts** — reads `[judgment]` validators via grep/parse.

---

## 6. Risks

- **API key missing or invalid** — Mitigation: check at startup, clear error message with setup instructions.
- **Haiku model deprecated** — Mitigation: model name configurable via env var `CORTEX_JUDGE_MODEL`.
- **Rubric doesn't exist for a validator** — Mitigation: judge generates a default rubric from the validator text, warns user to review.
- **Calibration data grows large** — Mitigation: JSONL append-only, prune oldest entries beyond 50 per rubric.
- **API cost runaway** — Mitigation: at $0.003/judgment, even 1000 judgments = $3. Not a real risk.

---

## 7. Sequencing

1. **Rubric parser** — Write YAML frontmatter parser for .rubric.md files. Verify: parse a sample rubric.
2. **Judge core** — Write judge function that takes rubric + validator output, calls Haiku, returns structured verdict. Verify: judge one validator.
3. **CLI interface** — Write `cortex-judge.py` with `run` and `correct` subcommands. Verify: CLI invocation works.
4. **Calibration loop** — Write calibration storage (JSONL) and few-shot injection. Verify: correction shifts scores.
5. **Contract parser** — Extract `[judgment]` validators from contract files. Verify: finds validators in semantic-retrieval contract.
6. **Report generation** — Write judge-report.md output. Verify: report generated after judging.
7. **Tests** — Cover judge, calibration, rubric parsing, degradation.

---

## 8. Tasks

- [ ] Write rubric YAML parser (extract criteria, levels, thresholds from .rubric.md frontmatter)
- [ ] Write `scripts/cortex/cortex-judge.py` with `run <slug>` subcommand — finds contract, extracts [judgment] validators, loads rubrics, calls Haiku, outputs verdicts
- [ ] Write `cortex-judge.py correct <slug> <validator-index> <field>=<value> --reason "..."` — appends calibration entry to `~/.cortex/calibration/`
- [ ] Write calibration loader — reads JSONL, injects as few-shot examples into judge prompt
- [ ] Write contract parser — extracts [judgment] validators from contract markdown
- [ ] Write judge report generator — outputs `docs/cortex/evals/{slug}/judge-report.md`
- [ ] Create sample rubric for semantic-retrieval [judgment] validators
- [ ] Write tests for rubric parsing, judge call, calibration loop, contract parsing
- [ ] Verify end-to-end: judge semantic-retrieval contract, produce report

---

## 9. Acceptance Criteria

- [ ] `cortex-judge.py run <slug>` finds all [judgment] validators in the active contract and scores each
- [ ] Each judgment produces `{pass, confidence, scores, reasoning}` as structured output
- [ ] Judgments with confidence >= 0.7 are auto-passed/failed; below 0.7 are flagged for human review
- [ ] `cortex-judge.py correct` appends a calibration entry to `~/.cortex/calibration/{hash}.jsonl`
- [ ] Subsequent judge calls for the same rubric include calibration examples as few-shot context
- [ ] Judge report written to `docs/cortex/evals/{slug}/judge-report.md`
- [ ] Works without rubric files (generates default rubric from validator text with warning)
- [ ] Clear error when ANTHROPIC_API_KEY is missing
- [ ] All tests pass
