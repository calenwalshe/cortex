# Phase 1: Core Docs and Architecture Alignment - Research

**Researched:** 2026-03-28
**Domain:** Technical documentation authoring for a Claude Code skills/agents framework (vNext architecture)
**Confidence:** HIGH

---

## Summary

Phase 1 is a pure documentation phase. No code is written. The deliverable is a set of six markdown files
(plus two updated existing files) that together constitute a complete architecture reference for Cortex vNext.
A reader who has never touched the code should exit with a clear mental model of: the 7-command surface,
the sequential intelligence spine, the artifact root contract, the continuity strategy, the eval lifecycle,
and the agent roster.

The technical domain here is documentation engineering, not software engineering. The primary research
questions are therefore: (1) what does the current repo actually contain vs. what the spec requires, (2)
what exact content each document must carry based on the requirements, and (3) where there are gaps between
the old architecture documented in CORTEX.md/README.md and the vNext design.

The gap analysis is the most important output of this research. CORTEX.md and README.md currently describe
a 3-layer harmonisation wrapper with 5 utility commands. vNext adds a full lifecycle intelligence layer: 7
commands, hidden orchestration, contract-gated execution, compaction-proof continuity, and an eval
subsystem. Everything in the current docs is either wrong or incomplete relative to vNext.

**Primary recommendation:** Write all six new docs from the spec/requirements as authoritative sources,
then update CORTEX.md and README.md to agree with them — not the other way around.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DOCS-01 | `CORTEX.md` updated to reflect vNext architecture | Gap analysis below shows exactly what must change |
| DOCS-02 | `docs/INTELLIGENCE_FLOW.md` — sequential spine with loops | Spine is fully specified in requirements + spec context |
| DOCS-03 | `docs/COMMANDS.md` — 7 commands with inputs, outputs, rules | All 7 commands defined in REQUIREMENTS.md CMD-01..07 |
| DOCS-04 | `docs/CONTINUITY.md` — continuity strategy and artifact schemas | Schemas defined in REQUIREMENTS.md CONT-01..04, ART-08 |
| DOCS-05 | `docs/EVALS.md` — eval lifecycle, matrix, harness guide | Lifecycle defined in REQUIREMENTS.md EVAL-01..05 |
| DOCS-06 | `docs/AGENTS.md` — agent roster, tools, permission modes | Roster defined in REQUIREMENTS.md AGNT-01..04 |
| DOCS-07 | README updated; source tree, docs, installer all agree with vNext | Gap analysis below shows stale sections |
</phase_requirements>

---

## Standard Stack

This phase produces only markdown files. No library dependencies, no build tooling, no test harness.

| Artifact | Format | Location |
|----------|--------|----------|
| CORTEX.md | Markdown | `/home/agent/projects/cortex/CORTEX.md` (overwrite) |
| README.md | Markdown | `/home/agent/projects/cortex/README.md` (overwrite) |
| docs/INTELLIGENCE_FLOW.md | Markdown | `/home/agent/projects/cortex/docs/INTELLIGENCE_FLOW.md` (new) |
| docs/COMMANDS.md | Markdown | `/home/agent/projects/cortex/docs/COMMANDS.md` (new) |
| docs/CONTINUITY.md | Markdown | `/home/agent/projects/cortex/docs/CONTINUITY.md` (new) |
| docs/EVALS.md | Markdown | `/home/agent/projects/cortex/docs/EVALS.md` (new) |
| docs/AGENTS.md | Markdown | `/home/agent/projects/cortex/docs/AGENTS.md` (new) |

The `docs/` directory currently contains only `index.html`. All six new markdown files are net-new.

---

## Architecture Patterns

### Current State vs. vNext — The Gap

This is the core finding. Every doc file needs to bridge from the old architecture to the new one.

**What CORTEX.md currently says (old):**
- Cortex is a 3-layer harmonisation wrapper (Workflow/GSD, Discipline/Superpowers, Thinking/GStack)
- 5 skills: cortex-status, cortex-review, cortex-investigate, cortex-audit, cortex-research
- Layers separated by concern, collision prevention via namespace
- Upstream tracking via git submodules
- File structure: layers/, skills/, agents/(empty), hooks/, bin/, upstream/

**What vNext requires (new):**
- Cortex is a lifecycle intelligence system with 7 user commands
- GSD still owns workflow; Cortex adds an intelligence layer on top
- 7 commands: clarify, research, spec, investigate, review, audit, status
- Two new commands missing from current skills dir: cortex-clarify, cortex-spec
- Runtime artifact roots: `docs/cortex/` (human-readable) and `.cortex/` (machine state) in the TARGET repo
- Sequential spine: clarify → research → spec → [GSD execute] → validate → repair → assure → done
- Contract-gated execution: no product code before spec+contract+approval
- Continuity stack: repo-local artifacts survive /clear and compaction
- 4 agents: specifier, critic, scribe, eval-designer
- 10 hooks: session-start, phase-guard, validator-trigger, task-created, task-completed, teammate-idle, precompact, postcompact, session-end, sync
- Eval subsystem as first-class lifecycle component

**Ownership boundary (critical for docs):**
- GSD owns: `.planning/`, STATE.md, phases, milestones, roadmaps
- Cortex owns: `docs/cortex/` and `.cortex/` in the TARGET repo (not the cortex repo itself)
- This is a hard constraint, not a recommendation

### Recommended Document Content Structure

#### CORTEX.md (rewrite)
Sections required:
1. What Cortex is — one-paragraph executive summary of the lifecycle intelligence system
2. Architecture table — 3 layers (Workflow/GSD, Intelligence/Cortex, Discipline+Thinking)
3. 7-command surface — table with command, purpose, output artifact
4. Artifact roots — `docs/cortex/` and `.cortex/` with what each contains
5. Ownership boundary — explicit GSD vs Cortex separation
6. Sequential spine — the clarify→done state machine in prose
7. Continuity model — how context survives /clear
8. Layer activation rules (updated to include Cortex intelligence layer)
9. File structure (updated to reflect actual repo + vNext additions)
10. Collision prevention rules (updated)

#### docs/INTELLIGENCE_FLOW.md (new)
Sections required:
1. The spine — ASCII diagram of: clarify → research → spec → [GSD execute] → validate → repair → assure → done
2. Phase descriptions — what happens in each phase, who owns it
3. Loop structure — where repair feeds back (repair → validate, not repair → clarify)
4. Gate conditions — what must be true to advance (contract approval, eval pass, etc.)
5. GSD handoff — exactly where the boundary is between Cortex and GSD
6. Continuity touchpoints — which artifacts are written at each spine node

#### docs/COMMANDS.md (new)
Sections required per command (all 7):
- Invocation syntax
- Purpose / what it does
- Inputs (flags, arguments)
- Outputs (artifact path, artifact schema summary)
- Rules / constraints (e.g. phase-guard restrictions, approval gates)
- Example invocation

Commands to document:
1. `/cortex-clarify` — CMD-01: fuzzy idea → clarify brief at docs/cortex/clarify/<slug>/
2. `/cortex-research` — CMD-02: phases (concept/implementation/evals), depths (quick/standard/deep), --team
3. `/cortex-spec` — CMD-03: clarify+research → spec.md + gsd-handoff.md + contract
4. `/cortex-investigate` — CMD-04: investigation artifacts → docs/cortex/investigations/, repair contract handoff
5. `/cortex-review` — CMD-05: review artifacts → docs/cortex/reviews/, contract compliance lens
6. `/cortex-audit` — CMD-06: audit artifacts → docs/cortex/audits/, required lenses (auth/data/secrets/unsafe/input/deps/misuse)
7. `/cortex-status` — CMD-07: state reconstruction from repo-local artifacts, updates continuity handoff files

#### docs/CONTINUITY.md (new)
Sections required:
1. Why continuity matters — /clear and compaction destroy chat history; repo-local artifacts are the only durable state
2. The continuity stack — SessionStart hydration, PreCompact/PostCompact hooks, SessionEnd hook
3. Artifact schema — current-state.md field definitions (slug, mode, approval status, active contract path, recent artifacts, open questions, blockers, next action)
4. next-prompt.md — purpose and format (short restart prompt a human can paste after /clear)
5. .cortex/state.json — machine-state schema (mode, artifacts, approvals, gates)
6. last-compact-summary.md — what gets written on compaction
7. Resume protocol — step-by-step: /cortex-status → reads current-state.md + next-prompt.md + active contract
8. Compaction flow — PreCompact snapshot → PostCompact refresh
9. Full continuity file list — all 8 files with purposes

#### docs/EVALS.md (new)
Sections required:
1. Why evals are first-class — every contract must reference an eval plan
2. Eval lifecycle — proposal → human approval → plan → execution → results → repair/assure
3. Candidate eval matrix — 8 dimensions: functional correctness, regression, integration, safety/security, performance, resilience, style, UX/taste
4. When human approval is mandatory — subjective, high-stakes, or ambiguous eval criteria
5. Repair loop — failed eval → repair recommendation or repair contract (never silent failure)
6. How to invoke — /cortex-research --phase evals produces the eval proposal
7. Artifact paths — eval-proposal.md and eval-plan.md under docs/cortex/evals/<slug>/

#### docs/AGENTS.md (new)
Sections required:
1. Agent roster — all 4 agents: cortex-specifier, cortex-critic, cortex-scribe, cortex-eval-designer
2. Per agent: role description, tools available, write permission scope, read permission scope
3. Permission model — write-restricted vs read-only
4. Invocation — how agents are invoked (sub-agent mode, team mode via --team)
5. Installation path — ~/.claude/agents/

Agent permission summary (from requirements):
- cortex-specifier: drafts specs/contracts from research; write-restricted to docs/cortex
- cortex-critic: adversarial reviewer of specs, contracts, decisions; read-only
- cortex-scribe: maintains continuity artifacts; write-restricted to docs/cortex + .cortex
- cortex-eval-designer: proposes eval suites, rubrics, fixtures, thresholds; write scope TBD (likely docs/cortex/evals)

#### README.md (update)
Sections that must change:
1. Opening description — currently "harmonises GSD+Superpowers+GStack", needs to become lifecycle intelligence system framing
2. The Problem/Solution section — still accurate at high level but needs vNext scope
3. Quick Start — currently `npx github:calenwalshe/cortex`; verify this still holds, add /cortex-clarify as "start here" example
4. Structure section — currently shows old file tree; needs vNext file tree including docs/cortex/, .cortex/, all 7 skills
5. Command list — needs to replace 5-command list with 7-command list

### Anti-Patterns to Avoid

- **Writing forward-looking docs for Phase 4+ features as if they exist now.** Hooks and agents are Phase 4. AGENTS.md and parts of CONTINUITY.md describe a planned system — docs must be clearly forward-looking specifications, not claims of current functionality.
- **Circular architecture.** The current cortex-sync.sh uses a credential-bearing remote URL (`https://calenwalshe:${GH_TOKEN}@...`). HOOK-10 in requirements calls this a known bug. Do not document the current hook behavior as canonical.
- **Conflating Cortex repo structure with target repo structure.** `docs/cortex/` and `.cortex/` live in the TARGET project repo where Cortex is used, not in the Cortex repo itself. This distinction must be explicit in every doc that mentions these paths.
- **Documenting agents/ directory as populated.** It is currently empty. AGENTS.md documents the intended agent schemas for Phase 4.

---

## Don't Hand-Roll

This phase has no code. The "don't hand-roll" principle applies to documentation structure:

| Problem | Don't Write | Use Instead |
|---------|-------------|-------------|
| Command argument syntax | Invented flag formats | Match the existing skill conventions from cortex-research SKILL.md (--quick/--deep flags, --phase argument) |
| Artifact path conventions | Invented slug formats | Follow ART-01..08 exactly: `docs/cortex/<type>/<slug>/<timestamp>-<name>.md` |
| Continuity file schemas | Invented fields | Use the schema fields specified in CONT-02 and ART-08 verbatim |
| Eval dimension names | Invented taxonomy | Use the 8 dimensions from EVAL-05 verbatim |

---

## Common Pitfalls

### Pitfall 1: Mixing Cortex-repo paths with target-repo paths
**What goes wrong:** Reader thinks `docs/cortex/` is a directory in the cortex repo, not in their project repo.
**Why it happens:** The cortex repo does have a `docs/` directory (containing index.html). Easy to conflate.
**How to avoid:** Every reference to `docs/cortex/` and `.cortex/` must include language like "in the target project repo" or "in the repo where Cortex is installed."
**Warning signs:** If a doc says "see docs/cortex/..." without qualifying which repo, it's ambiguous.

### Pitfall 2: Documenting Phase 4 artifacts as if they are live
**What goes wrong:** AGENTS.md or CONTINUITY.md presents hooks and agents as active enforcements when they don't exist yet.
**Why it happens:** The spec is written in present-tense imperative mood.
**How to avoid:** The docs in Phase 1 are architectural specifications. They should describe the INTENDED system. Add a note in AGENTS.md and CONTINUITY.md that the enforcement layer (hooks, agents) is delivered in Phase 4.

### Pitfall 3: Leaving README Quick Start pointing at outdated install command
**What goes wrong:** `npx github:calenwalshe/cortex` may or may not match the vNext installer (Phase 6 overhauls the installer).
**Why it happens:** README was written for the old system.
**How to avoid:** Flag the Quick Start section as "pending Phase 6 installer update" or keep it at the conceptual level. Do not promise specific installer behavior that Phase 6 may change.

### Pitfall 4: Missing the GSD handoff boundary in INTELLIGENCE_FLOW.md
**What goes wrong:** Reader doesn't understand that Cortex hands off to GSD for execution — they think Cortex does the executing.
**Why it happens:** The spine includes an "execute" node that's actually owned by GSD.
**How to avoid:** The INTELLIGENCE_FLOW.md must clearly mark the GSD boundary: everything up to and including spec is Cortex; execution is GSD; validate/repair/assure are Cortex again.

### Pitfall 5: cortex-research SKILL.md uses different flag conventions than vNext
**What goes wrong:** Current cortex-research uses `--quick`, `--deep` flags and stores output in `~/research/`. vNext requires `--phase concept|implementation|evals` and `--depth quick|standard|deep` writing to `docs/cortex/research/<slug>/`.
**Why it happens:** The current skill predates the vNext redesign.
**How to avoid:** docs/COMMANDS.md must document the vNext interface, not the current SKILL.md interface. The two will diverge until Phase 3 brings the skill into alignment.

---

## Code Examples

### Artifact Path Convention (from REQUIREMENTS.md)
```
# Clarify
docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md

# Research
docs/cortex/research/<slug>/<phase>-<timestamp>.md

# Spec
docs/cortex/specs/<slug>/spec.md
docs/cortex/specs/<slug>/gsd-handoff.md

# Contract
docs/cortex/contracts/<slug>/contract-001.md

# Evals
docs/cortex/evals/<slug>/eval-proposal.md
docs/cortex/evals/<slug>/eval-plan.md

# Operational
docs/cortex/investigations/<slug>/...
docs/cortex/reviews/<slug>/...
docs/cortex/audits/<slug>/...
```

### Continuity File List (from REQUIREMENTS.md ART-08, CONT-02, CONT-03)
```
.cortex/
├── state.json                    # machine state: mode, artifacts, approvals, gates
└── compaction/
    └── precompact-<timestamp>.md # pre-compaction snapshot

# In the project root (or docs/cortex/.cortex/ — location TBD in Phase 2):
current-state.md                  # slug, mode, approval status, active contract path,
                                   # recent artifacts, open questions, blockers, next action
open-questions.md
next-prompt.md                    # short restart prompt for paste-after-/clear
decisions.md
eval-status.md
last-compact-summary.md
```

### Intelligence Spine (from REQUIREMENTS.md LOOP-04 and spec context)
```
clarify → research → spec → [GSD execute] → validate → repair → assure → done
                              ↑                             ↓
                              └────────────────────────────┘ (repair loop)
```

### Command Surface (from REQUIREMENTS.md CMD-01..07)
```
/cortex-clarify <idea>
/cortex-research [<topic>] [--phase concept|implementation|evals] [--depth quick|standard|deep] [--team]
/cortex-spec
/cortex-investigate
/cortex-review
/cortex-audit
/cortex-status
```

---

## Repo State (Current vs. vNext Required)

| Area | Current State | vNext Required | Gap |
|------|--------------|----------------|-----|
| CORTEX.md | 3-layer wrapper, 5 skills | Lifecycle system, 7 commands, artifact roots | Full rewrite |
| README.md | Harmonisation framing, 5 commands | vNext framing, 7 commands, source tree | Significant update |
| docs/ | index.html only | 5 new markdown files | All 5 are new |
| skills/ | 5 skills (status, review, investigate, audit, research) | 7 skills (+ clarify, spec) | 2 missing (Phase 3) |
| agents/ | Empty directory | 4 agents (Phase 4) | Phase 4 deliverable |
| hooks/ | cortex-sync.sh (has bugs per HOOK-10), session-start.md | 10 hooks (Phase 4) | Phase 4 deliverable |
| bin/ | install.js, sync-upstream.sh | Updated installer (Phase 6) | Phase 6 deliverable |

---

## Validation Architecture

Per config.json `workflow.nyquist_validation: true`, validation applies.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — documentation phase only |
| Config file | N/A |
| Quick run command | Manual review against checklist |
| Full suite command | Manual review against all 7 success criteria from ROADMAP.md |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-01 | CORTEX.md describes 7-command surface, artifact roots, ownership boundary, layer architecture | manual | `grep -c "cortex-clarify\|cortex-spec" /home/agent/projects/cortex/CORTEX.md` (should return >0) | ❌ Wave 0 |
| DOCS-02 | docs/INTELLIGENCE_FLOW.md exists with spine diagram | manual | `test -f /home/agent/projects/cortex/docs/INTELLIGENCE_FLOW.md && echo OK` | ❌ Wave 0 |
| DOCS-03 | docs/COMMANDS.md documents all 7 commands | manual | `grep -c "cortex-clarify\|cortex-research\|cortex-spec\|cortex-investigate\|cortex-review\|cortex-audit\|cortex-status" /home/agent/projects/cortex/docs/COMMANDS.md` (should be 7) | ❌ Wave 0 |
| DOCS-04 | docs/CONTINUITY.md exists with correct schemas | manual | `test -f /home/agent/projects/cortex/docs/CONTINUITY.md && echo OK` | ❌ Wave 0 |
| DOCS-05 | docs/EVALS.md exists with eval lifecycle | manual | `test -f /home/agent/projects/cortex/docs/EVALS.md && echo OK` | ❌ Wave 0 |
| DOCS-06 | docs/AGENTS.md exists with 4 agents | manual | `test -f /home/agent/projects/cortex/docs/AGENTS.md && echo OK` | ❌ Wave 0 |
| DOCS-07 | README updated, source tree agrees | manual | `grep -c "cortex-clarify\|cortex-spec" /home/agent/projects/cortex/README.md` (should return >0) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Verify the specific file(s) written contain required sections
- **Per wave merge:** All 7 success criteria from ROADMAP.md Phase 1 checked
- **Phase gate:** All 7 docs exist, no stale references to old architecture remain

### Wave 0 Gaps
- [ ] All 7 docs are net-new or rewrites — no existing infrastructure to validate against
- [ ] Success criteria are entirely manual review (documentation, not code)
- [ ] Suggest planner defines a "stale reference check" task that greps for old command names (cortex-review invoked as standalone, old layer architecture language) after all docs are written

---

## Open Questions

1. **Where exactly do the 8 continuity files live in the target repo?**
   - What we know: CONT-02 says `current-state.md`, `next-prompt.md`, etc. CONT-04 says `.cortex/state.json`
   - What's unclear: Are the human-readable continuity files (`current-state.md`, `open-questions.md`, etc.) in the repo root, in `docs/cortex/`, or inside `.cortex/`?
   - Recommendation: Document them as `.cortex/` residents for now (alongside state.json). Phase 2 will establish the canonical schema. Flag this in CONTINUITY.md.

2. **Does README Quick Start stay as `npx github:calenwalshe/cortex`?**
   - What we know: Phase 6 overhauls the installer. The current package.json exists.
   - What's unclear: Whether the npx entrypoint will survive Phase 6 changes.
   - Recommendation: Keep Quick Start at the conceptual level in Phase 1. Add a note that the installer is being updated. Phase 6 will finalize the exact command.

3. **Should CORTEX.md still document the 3-layer architecture?**
   - What we know: GSD/Discipline/Thinking layers still exist. The upstream submodules are unchanged.
   - What's unclear: Whether the layer model is still the primary mental model or whether the lifecycle intelligence spine has superseded it.
   - Recommendation: Keep the layer table but reframe it. The lifecycle spine is the primary model; the 3 layers describe how behavioral rules are organized within execution. Both are true simultaneously.

---

## Sources

### Primary (HIGH confidence)
- `/home/agent/projects/cortex/.planning/REQUIREMENTS.md` — all DOCS-XX, CMD-XX, CONT-XX, ART-XX, EVAL-XX, AGNT-XX requirements
- `/home/agent/projects/cortex/.planning/ROADMAP.md` — Phase 1 success criteria, phase dependency chain
- `/home/agent/projects/cortex/CORTEX.md` — current state of primary architecture doc
- `/home/agent/projects/cortex/README.md` — current state of README
- `/home/agent/projects/cortex/skills/cortex-status/SKILL.md` — current skill interface patterns
- `/home/agent/projects/cortex/skills/cortex-research/SKILL.md` — current flag conventions, output paths
- `/home/agent/projects/cortex/hooks/cortex-sync.sh` — evidence of HOOK-10 bug (credential URL)

### Secondary (MEDIUM confidence)
- `/home/agent/projects/cortex/upstream/gstack/AGENTS.md` — skill/agent documentation pattern reference
- `/home/agent/projects/cortex/upstream/gstack/ARCHITECTURE.md` — architecture doc structure patterns (how gstack documents its own system)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Gap analysis (current vs. vNext): HIGH — derived from direct file inspection
- Content requirements per doc: HIGH — derived from REQUIREMENTS.md directly
- Exact continuity file locations: MEDIUM — ambiguous between root, docs/cortex/, and .cortex/
- README Quick Start survivability: LOW — depends on Phase 6 decisions

**Research date:** 2026-03-28
**Valid until:** Stable — this is a pure documentation phase with no external library dependencies. Valid indefinitely unless REQUIREMENTS.md changes.
