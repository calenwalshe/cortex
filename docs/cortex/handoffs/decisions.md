# Decisions

**slug:** (none)

## Decision Log

### 2026-04-10 — cortex-clarify Phase 1 slug rule contradiction fixed

Benchmark-driven fix landing as commit `abf1295`. Phase 1 rules told the LLM to "lowercase, replace spaces with hyphens" while the worked example showed a 3-word distillation (`smart-retry-logic` for a longer input). LLMs following the rules literally shipped 120-155 character slugs under benchmark. Rewrote Phase 1 to emphasize distillation with a ≤40 char rule of thumb, good/bad examples, and explicit guidance that the idea's length has no bearing on the slug's length. Measured via `skill-creator-benchmarking` pilot iteration-2: 100% pass / stddev 0 (new) vs 87.5% pass / stddev 18% (old, high variance — some runs spotted the contradiction via the example and self-corrected, others followed rules literally and produced monster slugs).

### 2026-04-10 — Skills transmit convention, not intelligence (design lens)

Benchmark pilot found that baselines without skills produce substantive analysis — they just don't know the specific artifact format. Skills' measured "lift" is really a format-compliance delta, not an intelligence delta. Time/token savings come from convergence (no exploration), not compression. **Implication for future skill design:** for first-step tools like `cortex-clarify`, the skill should preserve/encourage baseline's investigative depth, not just enforce format. Concrete action: iteration-3 of `cortex-clarify` to add "answer codebase-type questions by reading files first" instruction.

## Design Decisions

### 2026-04-13 — cortex-vault: inbox/promotion constraint overturned by research

Clarify brief constraint: "Vault writes must go through the inbox/promotion model from the Drive doc, not directly to the durable store." Research (Q2 audit) found: inbox/promotion extractors (`episodic_extractor.py`, `procedural_extractor.py`) expect session JSONL format (turns), not structured Cortex artifacts. Sending a dossier through the pipeline would require LLM reclassification of content that is already classified by artifact section — adding noise, not value. Decision: use `add_fact()` direct import instead. Constraint was based on the assumption that Cortex writes would be "raw events"; research showed they are structured, reviewed artifacts with explicit classification. Authorized by: research evidence + user approval of spec (2026-04-13T14:30:00Z).

### 2026-04-13 — cortex-vault: fact_store.py import method

Open question in dossier: "Can `fact_store.py` be imported from cortex repo scripts directory?" Resolution: verified no relative imports in fact_store.py (only stdlib + third-party). Direct import via `sys.path.insert` is safe. fact_store.py has no CLI interface — its `__main__` is a test harness. The spec initially specified subprocess as the "required pattern" (incorrect); corrected post-audit to direct import.

## Autonomy Decisions

<!-- Auto-appended by Cortex skills when a gate is auto-skipped (autonomy preset != supervised) -->
<!-- Format: - {timestamp} | gate: {name} | value: false (auto-skipped) | preset: {preset} | command: /cortex-{cmd} -->

- 2026-04-03T22:45:00Z | gate: slug_conflict | value: false (auto-skipped) | preset: full-auto | command: /cortex-clarify
- 2026-04-13T19:00:00Z | gate: necessity | verdict: BUILD | confidence: 0.85 | slug: structural-map-layer | command: /cortex-spec
- 2026-04-03T22:55:00Z | gate: critical_uncertainty | value: false (auto-skipped) | preset: full-auto | command: /cortex-spec
- 2026-04-03T22:55:00Z | gate: evidence_backing | value: false (auto-skipped) | preset: full-auto | command: /cortex-spec
- 2026-04-03T22:55:00Z | gate: contract_approval | value: false (auto-skipped) | preset: full-auto | command: /cortex-spec
- 2026-04-03T23:30:00Z | gate: slug_conflict | value: false (auto-skipped) | preset: full-auto | command: /cortex-clarify

## Archive Index

<!-- Each entry records a slug that was archived via /cortex-close -->
<!-- Entry format: - {ISO8601} | {slug} | closed | terminal: {name} | contract: {path} | eval-plan: {path} -->
<!-- Legacy entries without terminal: field remain valid (backward compatible) -->

- 2026-04-01T18:06:49Z | cortex-discovery-loop | closed | contract: docs/cortex/contracts/cortex-discovery-loop/contract-001.md | eval-plan: (none)
- 2026-04-04T00:30:00Z | semantic-retrieval | closed | contract: docs/cortex/contracts/semantic-retrieval/contract-001.md | eval-plan: (none)
- 2026-04-04T01:00:00Z | llm-judge-calibration | closed | contract: docs/cortex/contracts/llm-judge-calibration/contract-001.md | eval-plan: (none)
- 2026-04-05T06:30:00Z | necessity-gate | closed | contract: docs/cortex/contracts/necessity-gate/contract-001.md | eval-plan: (none)
- 2026-04-05T08:00:00Z | policy-loop | closed | contract: docs/cortex/contracts/policy-loop/contract-001.md | eval-plan: (none)
- 2026-04-06T20:30:00Z | parallel-builds | closed | contract: docs/cortex/contracts/parallel-builds/contract-001.md | eval-plan: (none)
- 2026-04-06T22:00:00Z | human-reports | closed | contract: (none) | eval-plan: (none)
- 2026-04-07T06:50:00Z | kalshi-adaptive-loop | closed | contract: docs/cortex/contracts/kalshi-adaptive-loop/contract-001.md | eval-plan: docs/cortex/evals/kalshi-adaptive-loop/eval-plan.md
- 2026-04-09T19:30:00Z | gate: necessity | verdict: BUILD | confidence: 0.9 | slug: system-decomposition-map | command: /cortex-spec
- 2026-04-10T00:15:00Z | gate: necessity | verdict: BUILD | confidence: 0.9 | slug: research-depth-routing | command: /cortex-spec
- 2026-04-09T20:00:00Z | system-decomposition-map | closed | contract: docs/cortex/contracts/system-decomposition-map/contract-001.md | eval-plan: (none)
- 2026-04-10T01:30:00Z | claude-code-status-line | closed | contract: docs/cortex/contracts/claude-code-status-line/contract-001.md | eval-plan: (none)
- 2026-04-10T02:00:00Z | gate: necessity | verdict: BUILD | confidence: 0.97 | slug: eval-system-refactor | command: /cortex-spec
- 2026-04-10T02:35:00Z | drive: /gsd:drive | row: 8 | slug: eval-system-refactor | mode: execute | reasoning: .planning/STATE.md exists with 6 incomplete phases — handing execution to GSD
- 2026-04-11T23:41:36Z | eval-system-refactor | closed | contract: docs/cortex/contracts/eval-system-refactor/contract-001.md | eval-plan: (none)
- 2026-04-12T01:30:00Z | gate: necessity | verdict: BUILD | confidence: 0.9 | slug: clarify-research-loop | command: /cortex-spec
- 2026-04-12T03:40:00Z | drive: evaluate_decision_table | row: 8 | slug: clarify-research-loop | mode: execute | reasoning: .planning/STATE.md exists with 5 incomplete phases — row 8 dispatches /gsd:drive
- 2026-04-12T03:40:00Z | drive: stop_environment | slug: clarify-research-loop | mode: execute | reasoning: /gsd:drive skill not available in current Claude Code environment — cannot dispatch to GSD. User must invoke /gsd:drive at harness level OR execute contract deliverables manually.
- 2026-04-12T04:15:00Z | drive: gsd-phase-loop | row: 8 | slug: clarify-research-loop | mode: execute | reasoning: .planning/STATE.md exists with 5 incomplete phases — cortex orchestrating GSD directly via plan-phase/execute-phase loop
- 2026-04-12T05:30:00Z | clarify-research-loop | closed | terminal: commit-to-build | contract: docs/cortex/contracts/clarify-research-loop/contract-001.md | eval-plan: docs/cortex/evals/clarify-research-loop/eval-plan.md
- 2026-04-12T06:30:00Z | gate: necessity | verdict: BUILD | confidence: 0.95 | slug: report-clarity | command: /cortex-spec
- 2026-04-12T08:00:00Z | report-clarity | closed | terminal: commit-to-build | contract: docs/cortex/contracts/report-clarity/contract-001.md | eval-plan: (none)
- 2026-04-12T09:00:00Z | gate: necessity | verdict: BUILD | confidence: 0.92 | slug: gate-critique | command: /cortex-spec
- 2026-04-12T09:30:00Z | gate: contract_approval | value: true (approved by owner) | preset: supervised | command: /cortex-spec
- 2026-04-12T10:00:00Z | gate-critique | closed | terminal: commit-to-build | contract: docs/cortex/contracts/gate-critique/contract-001.md | eval-plan: (none)
- 2026-04-13T15:30:00Z | cortex-vault | closed | terminal: commit-to-build | contract: docs/cortex/contracts/cortex-vault/contract-001.md | eval-plan: (none)
- 2026-04-13T08:00:00Z | system-map-memory | closed | terminal: commit-to-build | contract: docs/cortex/contracts/system-map-memory/contract-001.md | eval-plan: (none)
- 2026-04-13T19:30:00Z | structural-map-layer | closed | terminal: commit-to-build | contract: docs/cortex/contracts/structural-map-layer/contract-001.md | eval-plan: (none)
- 20260413T075000Z | gate: human_critique | value: false (auto-skipped) | preset: full-auto | slug: system-map-memory | gate-point: spec
- 20260413T075000Z | gate: contract_approval | value: false (auto-skipped) | preset: full-auto | command: /cortex-spec
- 2026-04-13T19:35:00Z | gate: necessity | verdict: BUILD | confidence: 0.88 | slug: operational-map-layer | command: /cortex-spec
- 2026-04-14T00:00:00Z | drive: gsd-phase-loop | row: 8 | slug: operational-map-layer | mode: execute | reasoning: .planning/STATE.md exists with 2 incomplete phases — cortex orchestrating GSD directly via plan-phase/execute-phase loop
- 2026-04-14T01:15:00Z | ship | PR #17 opened for slug operational-map-layer | https://github.com/calenwalshe/cortex/pull/17
- 2026-04-14T01:20:00Z | operational-map-layer | closed | terminal: commit-to-build | contract: docs/cortex/contracts/operational-map-layer/contract-001.md | eval-plan: (none)
- 2026-04-14T04:00:00Z | ship | PR #18 opened for slug communication-judge-loop | https://github.com/calenwalshe/cortex/pull/18

## Autonomy Decisions

- 2026-04-20T03:35:00Z | gate: critical_uncertainty | value: false (auto-skipped) | preset: supervised (invocation override) | command: /cortex-spec
- 2026-04-20T03:35:00Z | gate: evidence_backing | value: false (auto-skipped) | preset: supervised (invocation override) | command: /cortex-spec
- 2026-04-20T03:35:00Z | gate: necessity | value: false (auto-skipped) | preset: supervised (invocation override) | command: /cortex-spec
