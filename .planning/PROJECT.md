# Communication Judge Loop — Drive Summary Quality Gate

## What This Is

Cortex delivers owner-facing messages at three key moments — drive completion summaries, gate transition messages, and eval result summaries — but generates these messages without any quality gate. The drive completion summary is the owner's primary signal that work is done and what changed; a hedged, caveat-dropping, or incomplete summary causes the owner to open the next slug based on incorrect premises. This milestone adds a quality gate to drive completion summaries: before delivery, a judge evaluates the message against a 5-dimension rubric, rewrites failures with structured critique guidance (up to 3 attempts), and escalates to the owner when the retry cap is exhausted.

## Core Value

Owners receive drive completion summaries that meet a minimum quality bar before delivery — judge-scored, critique-guided rewrites where needed, bounded retries, and clear escalation when the system cannot produce a passing message on its own.

## Requirements

### Active

- None formalized

### Out of Scope

- Gate transition messages (clarify/spec/contract gates) — v2 surface
- Eval result summaries — v2 surface
- Rubric editing GUI
- Internal machine-to-machine messages (routing logs, state transitions)
- Changes to gate-critique, which reviews artifacts
- Unbounded self-rewrite loops
- Model-agnostic judge infrastructure (Haiku 4.5 is settled)

## Context

See docs/cortex/clarify/communication-judge-loop/20260414T021615Z-clarify-brief.md for the full clarify brief and docs/cortex/research/communication-judge-loop/concept-20260414T023306Z.md for research findings.

**Baseline:** Drive summaries generated without quality gate; gate-critique covers artifacts only; report-clarity defined 3-bullet formula but does not enforce it.
**Target:** Drive summaries are judge-evaluated before delivery; failures are rewritten up to 3 times; escalation path exists for persistent failures.

## Constraints

- Drive completion summary quality gate only — v1 does not touch gate transitions or eval results
- `call_judge()` from `scripts/cortex/cortex-judge.py` must be reused; no new judge infrastructure
- Retry cap is exactly 3 — hard cap, not configurable at call time
- Explicit rejection rule: `calibrated_uncertainty < 2` → FAIL regardless of aggregate score
- Haiku 4.5 is the settled judge model — do not change
- JSONL persistence at `~/.cortex/calibration/` is mandatory on every judge attempt

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrap `call_judge()`, not new script | Avoids duplicate judge entry points; `call_judge()` is already generic | New `build_communication_judge_prompt()` + `judge_communication()` in `cortex-judge.py` |
| Sequential critique-revise over best-of-N | Simpler, cheaper; 3x latency of best-of-N not justified for v1 | Max 3 retry attempts, escalate on cap |
| Drive summaries first, not all 3 surfaces | Highest owner visibility + highest quality variance; clearest rubric target | v1 scope: drive summaries only |
| 5-dimension rubric (0-4 scale) with explicit rejection rule | G-Eval standard; prevents judge from rewarding polish over substance | calibrated_uncertainty < 2 → FAIL regardless |
