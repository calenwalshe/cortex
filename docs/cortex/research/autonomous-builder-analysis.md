# Autonomous Builder & Knowledge Engine — Research Notes

Captured from extended design conversation, 2026-04-05.

---

## 1. Research Phase Architecture

The research phase is the evidence-building middle layer between clarify and spec.

**How it works:**
- Reads the active slug from `.cortex/state.json`, loads the corresponding clarify brief
- The clarify brief is the agenda — open questions and next research steps
- Three research tracks (not phases — they're lenses the agent can invoke):
  - **concept** = should we do this / what is the shape of the solution
  - **implementation** = how exactly should this be built
  - **evals** = how will we test and judge whether it worked
- Three depths: quick (one-shot), standard (multi-source), deep (gpt-researcher)

**What it outputs:**
- concept/implementation → `docs/cortex/research/{slug}/{phase}-{timestamp}.md`
- evals → `docs/cortex/evals/{slug}/eval-proposal.md` (optionally `eval-plan.md`)

**What research is for:**
- Turn vague framing into grounded evidence
- Surface tradeoffs, recommendations, open questions, sources
- Possibly trigger `reclarify_required: true` if evidence breaks the original frame
- Mark `gates.research_complete = true` so `/cortex-spec` can proceed

**Recommended rename:** concept → problem/approach, implementation → implementation, evals → verification design

**Gate ambiguity found:** COMMANDS.md says spec needs "at least one research dossier" but EVALS.md says contracts without eval plans are incomplete. Needs to be made deterministic for autonomy.

---

## 2. Autonomous 10-Hour Builder Assessment

**Current state:** Good skeleton, not finished autonomy. The system is a supervised contract workflow, not yet a self-directing long-running agent.

**What works for autonomy:**
- Durable state in repo-local artifacts
- Explicit lifecycle: clarify → research → spec → execute → validate → repair → assure → done
- Context restoration across /clear and compaction via hooks
- Hook-based enforcement (phase guard, task validation, eval gating)

**What's missing for unattended runs:**

1. **Outer policy loop** — something that chooses the next Cortex or GSD action from `current-state.md` and `state.json`. Today, the human decides what to run next.

2. **Adaptive research escalation** — research depth/track should be chosen by uncertainty, blast radius, and source conflict — not user flags.

3. **Automatic GSD import boundary** — Cortex explicitly says "do NOT run GSD commands from this skill." The handoff is a manual import step. An autonomous system needs to cross this seam automatically.

**Recommendation:** Keep GSD as execution substrate, Cortex as intelligence layer. Preserve that boundary. Automate only the seam (narrow bridge/import step).

---

## 3. Adversarial Correctness

Six adversarial passes already implied by the repo:

1. **Need/value adversary** — Research cross-references findings, can trigger reclarify. Seed of "do we even need this?" but implicit, not formalized.

2. **Spec/contract adversary** — cortex-specifier drafts, cortex-critic reviews (read-only). Good proposer/checker split.

3. **Implementation adversary** — /cortex-review applies engineering, security, YAGNI lenses. Anti-sycophantic review rules.

4. **Runtime adversary** — Eval plans as first-class artifacts. Candidate matrix spans correctness, regression, integration, safety, performance, resilience, style, UX.

5. **Abuse/security adversary** — /cortex-audit with 7 mandatory lenses, STRIDE, OWASP.

6. **Process adversary** — Hook layer enforces: write guards, task field requirements, eval-status gating.

**Still incomplete:**

- No mandatory "should this exist?" gate before spec. Critic can't return build/narrow/defer/reject.
- Validator execution not fully operationalized (cortex-validator-trigger only tracks dirty files, doesn't run validators).
- Data model mismatch on results location (results-{timestamp}.md vs eval-plan.md ## Results section).
- Autonomy controller is implicit — no scheduler decides when to invoke adversarial passes during unattended builds.

**Recommended additions:**
- Before spec: mandatory necessity attack (not needed / should be smaller / can reuse / needs more evidence)
- Before GSD handoff: contract falsification pass (every done criterion falsifiable, every risk maps to eval dimension)
- Before done: green review + green evals + no critical audit findings + no unresolved compliance failures

---

## 4. Missing First-Class Tools

**High priority (autonomy blockers):**

| Tool | Why |
|------|-----|
| Executor/sandbox runner | No named agent is a true long-running executor. Need checkout, process supervision, snapshot/resume, timeouts, budgets |
| GitHub platform tool | Typed operations for code search, branches, PRs, reviews, issues, checks, workflow runs, logs, artifacts |
| CI/eval results tool | Start runs, rerun failed jobs, fetch logs, download artifacts, ingest JUnit/coverage/traces |
| Browser/app verification (Playwright) | First-class UI adversarial verifier instead of inferring correctness from code |
| Observability tool (Sentry/Datadog-style) | Live runtime truth for investigate/repair loop |
| Feature flag/rollout control (LaunchDarkly-style) | Ship behind flags, canary, instant disable |
| Dependency intelligence (OSV/GitHub Security) | Automated supply-chain triage for audit flow |
| Reproducible dev environment | Environment drift kills 10-hour unattended builds |

**Medium priority:**
- Product analytics / user feedback — answer "is this actually needed?" with behavior data
- Task tracker surface (GitHub Issues / Linear) — typed blockers and follow-ups

**Not needed now:** More search/model providers. The research stack is rich enough. The bottleneck is inspection, execution, and runtime truth — not imagination.

**Permission model:** Read-only by default. Limited write for branches/PRs/issues/reruns/small rollouts. Human-gated for merges to main, production deploys, large rollouts, DB migrations, secrets.

---

## Key Insight

> Most important single addition: a typed GitHub + CI + artifact surface.
> Most important internal capability: a real executor/sandbox runner.
> Without those two, Cortex stays smart-but-supervised. With them, it starts to look like a serious autonomous builder.

---

## 5. Repo Self-Audit Findings

From saved project context analysis:

**Structure:** Substantial and intentional — README.md, CORTEX.md, runtime-manifest.json, bin/install.js, skills, hooks.

**Inconsistencies found:**
- **Command surface mismatch:** README.md lists 7 commands, CORTEX.md/COMMANDS.md list 8 (including /cortex-experiment), runtime-manifest.json installs /cortex-bridge.
- **Broken hook path:** token-ledger.js points to `../scripts/cortex/pricing.json` — previously flagged as non-existent.
- **`.planning/` ownership contradiction:** /cortex-bridge generates GSD `.planning/` scaffold, but CORTEX.md says Cortex does not write to `.planning/`.
- **Evals gate ambiguity:** /cortex-spec says "at least one research dossier" needed, EVALS.md says contracts without eval plans are incomplete and must not advance past spec.

**Best next fixes:**
1. Make runtime-manifest.json the source of truth for commands
2. Fix the broken hook path
3. Resolve the .planning/ contradiction
4. Clarify the evals gate so /cortex-spec handoff is unambiguous

---

## 6. Memory Models for Self-Learning Adversarial Knowledge Engine

State of the art as of April 2026. No single best memory model — the field is converging on **hybrid memory stacks**.

### Six Memory Approaches

**1. Working memory / long-context**
- Live context window + scratchpad for current reasoning
- BEAM's LIGHT improves long-dialogue with explicit episodic memory + scratchpad
- D-Mem adds Full Deliberation fallback when cheap retrieval isn't enough
- Should be treated as short-term reasoning memory, not lifelong storage

**2. Recurrent, compressive, and test-time neural memory**
- Memory inside the model's inference process
- Infini-attention: compressive memory for unbounded streaming context
- Mamba/Jamba: state-space backbones for long-context efficiency
- Titans/ATLAS: learn what to memorize at test time
- Best for monitoring huge traces, logs, documents continuously

**3. Retrieval-based persistent memory**
- Most practical production default
- MemGPT: OS-style hierarchical memory management
- LongMem/MemLong: decouple retrieval from frozen backbone
- Mem0: memory-centric architecture, beats baselines while cutting latency/tokens
- Best for persistent facts that can be added/removed/audited without retraining

**4. Structured semantic memory (graph + knowledge-graph)**
- For relations, entities, provenance chains, multi-hop reasoning
- GraphRAG not universally better than vanilla RAG — depends on query type
- Vanilla RAG strong on single-hop, detail-oriented retrieval
- GraphRAG helps on reasoning-intensive multi-hop QA
- Hybrid selection strategies usually work best

**5. Agentic, self-organizing, and typed memory**
- Closest to frontier for self-learning knowledge engines
- A-MEM: Zettelkasten-like dynamic note linking
- Nemori: self-organizes episodes, learns from prediction gaps
- MIRIX: 6 memory types — Core, Episodic, Semantic, Procedural, Resource, Knowledge Vault
- MemOS: treats parametric + activation + plaintext memory as managed resources with lifecycle governance
- The frontier has moved past "just put chunks in a vector DB"

**6. Parametric memory and slow consolidation**
- Memory in weights/adapters, not external stores
- ROME: edits specific factual associations
- MEMIT: scales to thousands of edits
- SERAC: stores edits in explicit memory, uses semi-parametrically
- ELLA: continual-learning adapter, 9.6% relative gains, 35x smaller footprint
- Useful when something should become durable model behavior

### Adversarial Memory Security

For an adversarial system, memory model and security model must be designed together:

**Attack vectors:**
- MINJA: query-only memory injection is possible
- PoisonedRAG: few malicious texts can corrupt retrieval with high success
- MemoryGraft: poisoned "successful experiences" create persistent behavioral drift
- GraphRAG changes but doesn't eliminate the attack surface

**Defenses:**
- Trust-aware retrieval/sanitization
- Consensus validation
- Separate lesson/negative-memory store
- A-MemGuard: reports >95% attack-success reduction

### Recommended Layered Design for Cortex

| Layer | Purpose | Best Fit |
|-------|---------|----------|
| Working memory | Current reasoning | Context window + scratchpad (LIGHT/D-Mem pattern) |
| Episodic store | Append-only with provenance | MemGPT/Mem0/LongMem for persistent retrieval |
| Semantic memory | Hybrid vector + graph | GraphRAG hybrids for relational knowledge |
| Procedural/lesson memory | Tactics, failures, countermeasures | MIRIX/A-MEM/Nemori/MemOS typed memory |
| Slow consolidation | Stable patterns → weights | ELLA/SERAC parametric path |

### Concrete Memory Objects for Cortex

Map into five types: **observation**, **claim**, **relation**, **procedure**, **lesson**.

---

## 7. Repo Self-Audit: Structural Findings

Direct repo inspection found:

**Biggest issue: command surface inconsistency.**
- README.md: 7-command surface
- CORTEX.md / COMMANDS.md: 8 commands (includes /cortex-experiment)
- runtime-manifest.json: installs cortex-bridge in core profile

**Layer/framing drift:** README presents Workflow/Intelligence/Discipline/Thinking layers; CORTEX.md has different numbering.

**Reads like an architecture thesis** — needs proof that a user can go from idea → spec → first contract in a dead-simple happy path.

**Recommended immediate fixes:**
1. Pick 1 canonical surface (probably 8 commands)
2. Make README.md, CORTEX.md, and command docs identical
3. Define minimum viable path: clarify → research → spec → GSD handoff
4. Treat review/audit/experiment/repair as secondary extensions in onboarding

---

## 8. Self-Healing Documentation Strategy

For Cortex, the right path is to make docs work the same way Cortex handles continuity: persistent artifacts, explicit state, deterministic reconstruction, and validators that catch drift.

### Architecture (Diátaxis model)

- **Reference:** Commands, artifacts, state transitions, bridge adapters (machine-generated)
- **Explanation:** Architecture rationale, design decisions (hand-written)
- **Tutorials/How-tos:** Separate from reference (user-facing)

### Source of Truth Model

Machine-readable specs should own the truth; human docs are generated/validated:

- `runtime-manifest.json` → installable skills, agents, hooks, events
- One machine-readable spec per command → syntax, inputs, outputs, state effects
- Machine-readable schema for `.cortex/state.json`
- Machine-readable registry for bridges/adapters

**Generated reference:**
- `docs/reference/commands.generated.md`
- `docs/reference/runtime.generated.md`
- `docs/reference/state.generated.md`
- `docs/reference/bridges.generated.md`

### Doc Invariants (enforce at merge time)

```yaml
doc_invariants:
  command_surface = command_specs.user_invocable
  installed_core_skills = runtime_manifest.skills[profile=core]
  hook_inventory = runtime_manifest.hooks
  hook_events = runtime_manifest.hook_events
  install_flags = installer.supported_flags
  bridges = bridge_registry
```

Every PR touching skills/, hooks/, manifest, installer, templates, or bridges runs a doc drift check. Fail if documented ≠ installed.

### LLM Role

LLM = repair worker, NOT source of truth. Structured files own facts (hook counts, command lists). LLM drafts changed prose, rewrites explanations, updates examples, summarizes diffs.

### Six Concrete Changes (priority order)

1. Declare canonical kernel: clarify, research, spec, contract, evals, continuity, bridge
2. Create machine-readable command registry → generate command surface docs
3. Create bridge registry, document GSD as first adapter
4. Add `check-doc-drift` script as required merge status check
5. Add "reference integrity" eval dimension (docs truthfulness as a gate)
6. Thin README to onboarding + architecture summary, move living reference to generated docs

---

## 9. Long-Term Goal Alignment & Plan Sync

### Missing Layer: Owner Intent

Cortex tracks execution state well (current-state.md, state.json, decisions.md) but has no first-class artifact for **stable owner intent** or **evolving preferences**.

**Recommended new artifacts:**
- `docs/cortex/owner-intent.md` — durable outcomes, success metrics, non-negotiables, tradeoff preferences, kill criteria
- `docs/cortex/objectives/current.md` — hierarchical plan: mission → objective → initiative → slug → contract → phase → task
- `.cortex/preferences.json` — coding/style/taste/process preferences with scope, strength, confidence, source, last_confirmed

**Intent precedence (reuse autonomy config pattern):**
one-session override > project intent > personal global preferences > defaults

### Memory Split for Long-Horizon Work

| Type | Contents | Examples |
|------|----------|---------|
| Working memory | Current context | current-state.md, next-prompt.md, active contract, dirty files |
| Long-term semantic | Durable knowledge | decisions.md, research findings, experiment results, patterns |
| Preference memory | Owner preferences | Coding style, tradeoff defaults, taste criteria |

Preference memory should capture both short-term fluctuations and long-term tendencies (PAMU pattern).

### Reconciliation Command: /cortex-sync or /cortex-realign

Reads: owner-intent.md, objective tree, state.json, current-state.md, active contract, eval-status.md, external planner state.

Writes: `docs/cortex/handoffs/plan-sync.md` with drift report:
- **Objective drift:** current slug no longer serves an active objective
- **Scope drift:** contract deliverables exceed or miss the stated plan
- **Acceptance drift:** downstream success criteria diverge from contract/eval plan
- **Preference drift:** recent decisions contradict explicit owner preferences
- **Evidence drift:** work "complete" but missing passing eval evidence

### Experiments as Controlled Plan Mutation

/cortex-experiment already models bounded hypothesis tests with promote/iterate/re-clarify/abandon outcomes. Strategic direction changes should happen through experiment outcomes, not slow erosion.

### New Agent: cortex-goal-steward

```
write scope:
  - docs/cortex/owner-intent.md
  - docs/cortex/objectives/
  - .cortex/preferences.json
  - docs/cortex/handoffs/plan-sync.md
```

Read-only for product code and GSD state. Owns alignment layer the way cortex-scribe owns continuity.

---

## 10. Cortex MVP for Multi-Product Deployment

### Core Insight

Best MVP = "compiler from fuzzy goal → portable execution contract + continuity state."

### Five Essential Capabilities

1. **Clarify** — fuzzy request → durable problem frame
2. **Research** — concept + implementation dossiers tied to slug
3. **Spec + Contract** — compress clarify + research into portable execution contract with done criteria, write roots, validators/eval references
4. **Status / Resume** — repo-local artifacts + state.json, reconstructable from files
5. **One adapter interface** — GSD as first adapter, not the identity of the core

### Key Architectural Change

Move GSD-specific artifact out of kernel. Core emits **generic contract schema**; GSD adapter generates gsd-handoff.md from that.

```
Kernel artifacts:          Adapter outputs:
  clarify.md/json            gsd-handoff.md
  research.md/json           .planning/*
  spec.md/json               linear-ticket-pack.json (future)
  contract.md + .json        execution-prompt.md (future)
  .cortex/state.json
  current-state.md
```

**Contract is the truth. Every product-specific surface is just a rendering.**

### Three-Layer Packaging

| Layer | Contents |
|-------|----------|
| **Cortex Core** | Schemas, templates, state machine, 4 commands: clarify, research, spec, status |
| **Cortex Runtime** | Optional hooks, write guards, compaction support, validator triggers, docs sync |
| **Cortex Adapters** | adapter-gsd first, then Linear, GitHub Projects, deployment planners, etc. |

### MVP Done Criteria

1. Same clarified idea exports to GSD + at least one other surface without redoing clarify/research/spec
2. /cortex-status reconstructs work from files only
3. Core runs with no external APIs and no product-specific workflow dependency
4. Every adapter consumes the same contract schema, only changes rendering

### Frozen Kernel Interface

```
objective + deliverables + requirements + tasks + done_criteria + 
write_roots + validators + state + eval_plan
```

---

## 11. Downstream Adapter Roadmap

### Compile Targets (what Cortex feeds)

| Target | What It Consumes | Current State |
|--------|-----------------|---------------|
| **Planner adapter** | objective, tasks, deliverables, requirements, done criteria | GSD bridge exists |
| **Generic executor** | contract as bounded work order, continuity for resume | Contract format exists |
| **CI/eval adapter** | eval-plan, validators, done criteria | Eval model exists |
| **Docs/wiki adapter** | specs, decisions, reviews, status | Artifact format exists |
| **Approval adapter** | approval state, human-gated evals | Approval model exists |
| **Repair/incident loop** | investigation, review, audit artifacts, follow-on contracts | Commands exist |

### Plug-In Connectors (what Cortex pulls from)

power-search, google, cli — already in full profile as optional tool skills. Correct shape: swappable connectors, not core kernel.

### Adapter Priority Order

1. Planner (GSD first, then any ticketing/planning surface)
2. Generic executor (plain work-order for any agent runtime)
3. CI/eval (consume eval-plan + validators + done criteria)
4. Docs/wiki (sync specs, decisions, reviews, status)
5. Approval (human signoff and governance)

### Design Rule

> Downstreams render Cortex artifacts. They do not redefine them.
