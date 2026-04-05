# Cortex Evolution — Consolidated Ideas

Extracted from autonomous-builder-analysis.md. Organized by category, prioritized within each.

---

## A. Bugs & Inconsistencies to Fix Now

These are broken or contradictory things in the current repo. No design work needed, just fixes.

| # | Issue | Fix |
|---|-------|-----|
| A1 | README says 7 commands, CORTEX.md says 8, manifest installs cortex-bridge | Pick 8. Make all three files identical. |
| A2 | token-ledger.js points to `../scripts/cortex/pricing.json` — path doesn't exist | Fix the path or move the file |
| A3 | CORTEX.md says "Cortex never writes to .planning/" but cortex-bridge generates .planning/ scaffold | Document bridge as the one sanctioned exception, or move scaffold to adapter layer |
| A4 | COMMANDS.md says spec needs "one research dossier"; EVALS.md says contracts without eval plans are incomplete | Make it deterministic: eval plan required before contract closes, not before spec |
| A5 | eval results written to both results-{timestamp}.md and eval-plan.md ## Results section | Pick one canonical location |

---

## B. Autonomy — Making Cortex Run Unattended

Three missing pieces to go from supervised workflow to 10-hour autonomous builder.

| # | Idea | What It Does |
|---|------|-------------|
| B1 | **Outer policy loop** | Reads current-state.md + state.json, chooses the next Cortex/GSD action automatically. Today the human decides. |
| B2 | **Adaptive research escalation** | Agent picks research depth (quick/standard/deep) and tracks (concept/implementation/evals) based on uncertainty and blast radius — not user flags. |
| B3 | **Automatic GSD import boundary** | Narrow bridge that crosses the Cortex→GSD seam without human import step. Cortex stays intelligence layer, GSD stays executor. |

---

## C. Adversarial Correctness — New Gates

Three new adversarial gates at specific lifecycle points.

| # | Gate | When | What It Does |
|---|------|------|-------------|
| C1 | **Necessity attack** | Before spec | Critic tries to prove: not needed / should be smaller / can reuse existing / needs more evidence. Returns build/narrow/defer/reject. |
| C2 | **Contract falsification** | Before GSD handoff | Every done criterion must be falsifiable. Every risky area maps to an eval dimension. Every deliverable has a validator. |
| C3 | **Done gate** | Before close | Green review + green evals + no critical audit findings + no unresolved compliance failures. All must pass. |

---

## D. Owner Intent & Goal Alignment

Cortex tracks execution state but has no first-class artifact for stable owner intent.

| # | Idea | What It Does |
|---|------|-------------|
| D1 | **owner-intent.md** | Durable outcomes, success metrics, non-negotiables, tradeoff preferences, kill criteria. The "why" that survives across slugs. |
| D2 | **Objective hierarchy** | mission → objective → initiative → slug → contract → phase → task. Every slug points upward to the objective it serves. |
| D3 | **preferences.json** | Owner preferences with scope, strength, confidence, source, last_confirmed. Captures both short-term and long-term tendencies. |
| D4 | **/cortex-sync (reconciliation command)** | Reads intent + state + contract + eval-status + planner state. Writes drift report: objective drift, scope drift, acceptance drift, preference drift, evidence drift. |
| D5 | **cortex-goal-steward agent** | New agent owning alignment layer. Write scope: owner-intent.md, objectives/, preferences.json, plan-sync.md. Read-only for product code. |

---

## E. Memory Architecture

Five-layer memory model for self-learning knowledge engine.

| # | Layer | Purpose | Implementation |
|---|-------|---------|----------------|
| E1 | Working memory | Current reasoning | Context window + scratchpad (existing: current-state.md, next-prompt.md) |
| E2 | Episodic store | Append-only with provenance | MemGPT/Mem0 pattern (existing: facts.jsonl + semantic retrieval) |
| E3 | Semantic memory | Relations + multi-hop reasoning | Hybrid vector + graph (GraphRAG for relations, vanilla RAG for detail) |
| E4 | Procedural/lesson memory | Tactics, failures, countermeasures | Typed memory: observation, claim, relation, procedure, lesson |
| E5 | Slow consolidation | Stable patterns | Parametric path (ELLA/SERAC) — future, not immediate |

**Adversarial memory security:**
- Trust-aware retrieval/sanitization
- Consensus validation
- Separate negative-memory store
- A-MemGuard pattern (>95% attack reduction)

---

## F. Self-Healing Documentation

Make docs work like Cortex continuity: machine-readable truth, generated reference, merge-blocking drift checks.

| # | Idea | What It Does |
|---|------|-------------|
| F1 | **Machine-readable command registry** | One spec per command (syntax, inputs, outputs, state effects). Generate docs from it. |
| F2 | **Bridge registry** | Machine-readable registry of adapters. GSD is adapter #1. |
| F3 | **Generated reference docs** | commands.generated.md, runtime.generated.md, state.generated.md, bridges.generated.md |
| F4 | **check-doc-drift script** | Merge-blocking check: documented ≠ installed = fail. Covers skills, hooks, manifest, installer flags. |
| F5 | **Reference integrity eval dimension** | Docs truthfulness as a gate, not just doc polish. |
| F6 | **Thin README** | Onboarding + architecture summary only. Living reference in generated docs. |

---

## G. MVP & Packaging for Multi-Product

Cortex as a portable kernel that compiles fuzzy goals into execution contracts.

| # | Idea | What It Does |
|---|------|-------------|
| G1 | **Generic contract schema** | Contract is the truth. GSD-specific handoff becomes a rendering, not the core artifact. |
| G2 | **Three-layer packaging** | Core (schemas, templates, state machine, 4 commands) / Runtime (hooks, guards, validators) / Adapters (GSD first, then others) |
| G3 | **Frozen kernel interface** | `objective + deliverables + requirements + tasks + done_criteria + write_roots + validators + state + eval_plan` — this stays stable. |
| G4 | **Adapter roadmap** | Planner → Executor → CI/Eval → Docs/Wiki → Approval (priority order) |

---

## H. Missing Tools for Full Autonomy

External capabilities Cortex needs but doesn't have.

| # | Tool | Priority | Why |
|---|------|----------|-----|
| H1 | GitHub platform (typed PR/issue/check ops) | High | Most important single addition for autonomous building |
| H2 | Executor/sandbox runner | High | Most important internal capability — process supervision, budgets, resume |
| H3 | CI/eval results ingestion | High | Start runs, fetch logs, download artifacts, ingest JUnit/coverage |
| H4 | Browser verification (Playwright) | Medium | UI adversarial verifier |
| H5 | Observability (Sentry/Datadog-style) | Medium | Live runtime truth for investigate/repair |
| H6 | Feature flags (LaunchDarkly-style) | Medium | Ship behind flags, canary, instant disable |
| H7 | Dependency intelligence (OSV) | Medium | Supply-chain triage for audit flow |
| H8 | Product analytics | Low | Answer "is this needed?" with behavior data |
| H9 | Task tracker (Issues/Linear) | Low | Typed blockers and follow-ups |

---

## Priority Stack (what to build first)

If I had to order everything above into a build sequence:

1. **Fix A1-A5** — bugs and contradictions. No design needed, just consistency.
2. **D1 + D3** — owner-intent.md + preferences.json. Gives Cortex a "why" layer.
3. **C1** — Necessity attack gate before spec. Prevents building things that shouldn't exist.
4. **G1** — Generic contract schema. Decouples kernel from GSD.
5. **B1** — Outer policy loop. Enables unattended runs.
6. **F1 + F4** — Command registry + doc drift check. Self-healing docs.
7. **B3** — Automatic GSD import boundary. Closes the autonomy seam.
8. **E3 + E4** — Semantic memory + procedural/lesson memory. Knowledge engine.
9. **D4** — /cortex-sync reconciliation command.
10. **H1 + H2** — GitHub platform tool + executor/sandbox. Full autonomy.
