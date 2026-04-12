# gate-critique — Adversarial Gate Critique

## What This Is

Cortex's intelligence pipeline (clarify → research → spec → contract) advances through gates that check structural conditions — does a contract exist? are assumptions backed? is there a slug conflict? — but none challenge whether the artifact being reviewed is actually correct, well-framed, or free of subtle errors. Bad framing at the clarify stage propagates undetected through research, spec, and contract before execution begins. The owner is currently the only adversarial voice at gates, but they review AI-generated artifacts without any independent critique to react to — they are approving in a vacuum. This slug adds a structured dual-critique step at each gate transition: an AI adversarial critique (Codex CLI, exec mode, explicit adversarial prompt) that always runs, followed by an owner plain-language response gate (skippable in full-auto), so bad assumptions and poor framing are caught before they become expensive execution work.

## Core Value

Every Cortex gate has a structured dual-critique step so bad assumptions and poor framing are caught before they propagate downstream into expensive work — the owner no longer approves AI-generated artifacts in a vacuum.

## Requirements

### Active

- None formalized

### Out of Scope

- cortex-drive gate critique (follow-on slug after Phase 1 validates)
- Critique of code or implementation output (domain of cortex-review and cortex-audit)
- Full security red-team or STRIDE threat model pass
- Hard-blocking gate advancement based solely on AI critique — AI informs, human decides; STOP severity surfaces prominently but does not veto
- Retroactive critique of artifacts from prior closed slugs
- Calibration tooling for critique thresholds (post-launch concern, enabled by findings register)

## Context

**Current baseline:** Gates check structural conditions only — does a contract exist? are assumptions backed? No gate challenges whether the artifact is correct or well-framed.

**Target:** Each gate transition runs an adversarial AI critique (Codex CLI exec mode + adversarial prompt) before the gate advances. In supervised mode the owner sees findings in plain language. In full-auto the critique runs and persists but the human gate is skipped.

**Ownership contract:** docs/cortex/contracts/gate-critique/contract-001.md

## Constraints

- Disk is truth — critique findings must be persisted as artifacts, not only shown inline in chat
- No code without contract — critique cannot delay contract approval to the point where execution begins without an approved contract
- AI critique must be adversarial — a critique that only confirms what the artifact says is worthless
- AI critique is implemented via Codex CLI with `codex exec --full-auto --profile llm --skip-git-repo-check --cd /tmp "<prompt>"`
- Human critique must be lightweight — AI findings must be surfaced in plain language before asking for owner response
- AI critique always runs — not gated by autonomy preset; human_critique is the only autonomy-conditional gate
- Critique must complete in a single pass — cannot spawn research sub-loops

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| New `/cortex-critique` skill (not extending cortex-review) | cortex-review is built for git diff inputs; extending it to prose artifacts would muddle scope | New standalone skill keeps critique dimensions versioned independently |
| Codex CLI exec mode (not cortex-critic subagent) | Subagent shares parent conversation context — risks confirmation bias; Codex exec creates genuinely separate invocation context | `codex exec --full-auto --profile llm --skip-git-repo-check --cd /tmp "<adversarial-prompt>"` |
| Three-tier severity STOP/CAUTION/GO (not binary pass/fail) | Binary gate fails via threshold drift; tiers give fine-grained routing | STOP surfaces prominently, CAUTION advances with receipt, GO silent |
| Separate critique artifact per gate (not inline) | Gate brief artifacts serve a specific structural role; mixing critique into them muddies artifact type | `docs/cortex/reviews/{slug}/critique-{gate}.md` per invocation |
| `claude -p` fallback when codex unavailable | Codex CLI not installed in all environments | Same adversarial prompt via `claude -p` subprocess, fallback logged in critique artifact header |
