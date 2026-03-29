---
phase: 03-new-and-updated-skills
verified: 2026-03-28T00:00:00Z
status: gaps_found
score: 7/7 SKILL.md artifacts verified; 1 documentation gap
re_verification: false
gaps:
  - truth: "REQUIREMENTS.md checkbox and traceability table updated to reflect CMD-04, CMD-05, CMD-06 as complete"
    status: failed
    reason: "REQUIREMENTS.md still shows [ ] and 'Pending' for CMD-04, CMD-05, CMD-06 even though all three SKILL.md files fully implement the required artifact-writing sections"
    artifacts:
      - path: ".planning/REQUIREMENTS.md"
        issue: "CMD-04, CMD-05, CMD-06 show unchecked [ ] and 'Pending' in traceability table at lines 13, 14, 15 (commands section) and lines 132-134 (traceability table)"
    missing:
      - "Mark CMD-04 as [x] in REQUIREMENTS.md"
      - "Mark CMD-05 as [x] in REQUIREMENTS.md"
      - "Mark CMD-06 as [x] in REQUIREMENTS.md"
      - "Update traceability table entries for CMD-04, CMD-05, CMD-06 from 'Pending' to 'Complete'"
---

# Phase 3: New and Updated Skills — Verification Report

**Phase Goal:** All 7 `/cortex-*` commands are installed, callable, and produce the correct artifacts when invoked
**Verified:** 2026-03-28
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `/cortex-clarify <idea>` writes a clarify brief at `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md` | VERIFIED | `docs/cortex/clarify` appears 5x; `YYYYMMDDTHHMMSSZ` timestamp format present; template path `templates/cortex/clarify-brief.md` referenced |
| 2 | The clarify brief contains all six required sections | VERIFIED | `NON_GOALS`, `OPEN_QUESTIONS`, `NEXT_RESEARCH_STEPS` (and `GOAL`, `CONSTRAINTS`, `ASSUMPTIONS`, `IDEA`) all present in SKILL.md instructions |
| 3 | After writing the brief, `current-state.md` is updated and `.cortex/state.json` flips `clarify_complete` to true | VERIFIED | Both `current-state.md` (1 match) and `clarify_complete` (1 match) and `state.json` (2 matches) present |
| 4 | `/cortex-research` accepts `--phase concept|implementation|evals` and `--depth quick|standard|deep` flags | VERIFIED | `--phase` appears 8x, `--depth` 4x; arguments table present with correct values |
| 5 | `cortex-research` writes dossiers to `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | VERIFIED | `docs/cortex/research` appears 2x with correct path structure |
| 6 | `--phase evals` routes to eval-proposal template at `docs/cortex/evals/<slug>/eval-proposal.md` | VERIFIED | `eval-proposal` appears 3x with explicit branching logic |
| 7 | `cortex-research` updates `current-state.md` and flips `research_complete` gate | VERIFIED | Both `current-state.md` and `research_complete` present |
| 8 | `/cortex-spec` reads clarify brief and research dossiers, writes `spec.md`, `gsd-handoff.md`, and `contract-001.md` | VERIFIED | All three output paths present: `docs/cortex/specs` (6x), `docs/cortex/contracts` (6x), `gsd-handoff.md` (7x) |
| 9 | `cortex-spec` blocks if clarify brief or research dossier is absent | VERIFIED | Explicit block messages documented for both cases |
| 10 | `cortex-spec` does NOT auto-invoke GSD | VERIFIED | `does NOT` appears 1x with explicit prohibition |
| 11 | `cortex-spec` has mandatory `eval_plan` field on every contract | VERIFIED | `eval_plan` appears 2x with "mandatory" callout |
| 12 | `cortex-spec` flips `spec_complete` gate and updates `current-state.md` | VERIFIED | Both present |
| 13 | `/cortex-investigate` writes investigation artifact to `docs/cortex/investigations/<slug>/<timestamp>.md` | VERIFIED | `docs/cortex/investigations` appears 4x; `Store Results` section present; confirmation output line documented |
| 14 | `cortex-investigate` optionally writes repair contract to `docs/cortex/contracts/<slug>/contract-NNN.md` | VERIFIED | `contract-NNN` pattern present with increment logic |
| 15 | `cortex-investigate` updates `current-state.md` after writing artifact | VERIFIED | `current-state.md` appears 1x in update step |
| 16 | The Iron Law and all 5 investigation phases are preserved | VERIFIED | `Iron Law` appears 2x, `Phase 1` appears 5x; Phase 0 slug resolution added |
| 17 | `/cortex-review` writes review artifact to `docs/cortex/reviews/<slug>/<timestamp>.md` with contract compliance section | VERIFIED | `docs/cortex/reviews` appears 4x; `Contract Compliance` section present (2x); `active_contract` referenced 3x |
| 18 | Contract compliance section evaluates done criteria with `PASS/FAIL/PARTIAL` per criterion | VERIFIED | All three verdicts present; overall `COMPLIANT/NON-COMPLIANT` verdict present |
| 19 | `cortex-review` updates `current-state.md` after writing artifact | VERIFIED | `current-state.md` appears 2x |
| 20 | Anti-sycophancy rules and all 6 review protocol sections preserved | VERIFIED | `Anti-Sycophancy Rules (MANDATORY)` section present; `NEVER say` block preserved |
| 21 | `/cortex-audit` writes Security Posture Report to `docs/cortex/audits/<slug>/<timestamp>.md` | VERIFIED | `docs/cortex/audits` appears 4x; `Store Results` section with audit confirmation line present |
| 22 | Audit covers all 7 required lenses | VERIFIED | All 7 lenses explicitly listed: Authentication, Data handling, Secrets exposure, Unsafe tool usage, Input validation, Dependency risks, Misuse vectors |
| 23 | `cortex-audit` updates `current-state.md` after writing artifact | VERIFIED | `current-state.md` appears 1x |
| 24 | CSO persona and "do NOT make code changes" rule preserved | VERIFIED | `Chief Security Officer` (2x), `You do NOT make code changes` (1x) present |
| 25 | `/cortex-status` reads from `docs/cortex/handoffs/current-state.md` and `.cortex/state.json` only | VERIFIED | `current-state.md` appears 8x, `state.json` 6x; explicit "Does NOT read `.planning/STATE.md`" prohibition at line 115 |
| 26 | `cortex-status` scans `docs/cortex/` subdirectories and refreshes `current-state.md` and `next-prompt.md` | VERIFIED | All 8 subdirectories listed; `next-prompt.md` appears 3x |
| 27 | `cortex-status` outputs terminal continuity summary with slug/mode/gates/artifacts/open questions/blockers/next action | VERIFIED | Full `CORTEX STATUS` terminal block present with all required fields |
| 28 | Old system-health behavior absent from `cortex-status` | VERIFIED | Zero matches for `upstream/superpowers`, `TAVILY_API_KEY`, `claude-stack-env`; no API/layer/Python health checks |
| 29 | REQUIREMENTS.md CMD-04, CMD-05, CMD-06 marked complete | FAILED | Still shows `[ ]` unchecked and "Pending" in traceability table; SKILL.md implementations are complete but requirements tracking was not updated |

**Score:** 28/29 truths verified

### Required Artifacts

| Artifact | Expected | Lines | Status | Details |
|----------|----------|-------|--------|---------|
| `skills/cortex-clarify/SKILL.md` | New skill: cortex-clarify command definition (min 60) | 125 | VERIFIED | All phases, gate flips, artifact path, output format present |
| `skills/cortex-research/SKILL.md` | Updated skill: cortex-research with new flags and output paths (min 80) | 201 | VERIFIED | `--phase`/`--depth` flags, new output routing, evals branch, continuity update all present |
| `skills/cortex-spec/SKILL.md` | New skill: cortex-spec command definition (min 70) | 151 | VERIFIED | 9 mandatory sections, 3 artifact writes, GSD prohibition, eval_plan mandate |
| `skills/cortex-investigate/SKILL.md` | Updated skill with artifact writing added (min 80) | 160 | VERIFIED | Iron Law preserved, Store Results section added, repair contract logic |
| `skills/cortex-review/SKILL.md` | Updated skill with artifact writing and contract compliance (min 80) | 190 | VERIFIED | Anti-sycophancy preserved, contract compliance section added, artifact write |
| `skills/cortex-audit/SKILL.md` | Updated skill with artifact writing (min 90) | 212 | VERIFIED | CSO persona preserved, all 7 lenses, Store Results section added |
| `skills/cortex-status/SKILL.md` | Replacement skill: continuity reconstruction (min 60) | 118 | VERIFIED | Reads only correct sources, scans docs/cortex/, writes next-prompt.md, no legacy content |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `skills/cortex-clarify/SKILL.md` | `docs/cortex/clarify/<slug>/` | artifact write step | WIRED | `docs/cortex/clarify` pattern present (5 matches) |
| `skills/cortex-clarify/SKILL.md` | `.cortex/state.json` | gate flip step | WIRED | `clarify_complete` gate flip present |
| `skills/cortex-research/SKILL.md` | `docs/cortex/research/<slug>/` | artifact write step | WIRED | `docs/cortex/research` present (2 matches) |
| `skills/cortex-research/SKILL.md` | `docs/cortex/evals/<slug>/eval-proposal.md` | `--phase evals` branch | WIRED | `eval-proposal` present (3 matches) with explicit branch |
| `skills/cortex-spec/SKILL.md` | `docs/cortex/specs/<slug>/spec.md` | artifact write step | WIRED | `docs/cortex/specs` present (6 matches) |
| `skills/cortex-spec/SKILL.md` | `docs/cortex/contracts/<slug>/contract-001.md` | contract write step | WIRED | `docs/cortex/contracts` present (6 matches) |
| `skills/cortex-spec/SKILL.md` | GSD invocation | explicit prohibition | WIRED | `does NOT` prohibition present |
| `skills/cortex-status/SKILL.md` | `docs/cortex/handoffs/current-state.md` | primary read source | WIRED | `current-state.md` present (8 matches) |
| `skills/cortex-status/SKILL.md` | `.cortex/state.json` | machine-readable state read | WIRED | `state.json` present (6 matches) |
| `skills/cortex-investigate/SKILL.md` | `docs/cortex/investigations/<slug>/` | Store Results section | WIRED | `docs/cortex/investigations` present (4 matches) |
| `skills/cortex-review/SKILL.md` | `docs/cortex/reviews/<slug>/` | Store Results section | WIRED | `docs/cortex/reviews` present (4 matches) |
| `skills/cortex-review/SKILL.md` | `active_contract_path` in `current-state.md` | contract compliance section | WIRED | `active_contract` present (3 matches) |
| `skills/cortex-audit/SKILL.md` | `docs/cortex/audits/<slug>/` | Store Results section | WIRED | `docs/cortex/audits` present (4 matches) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CMD-01 | 03-01-PLAN.md | `/cortex-clarify` converts idea to clarify brief | SATISFIED | SKILL.md complete; all phases, sections, and state updates present |
| CMD-02 | 03-01-PLAN.md | `/cortex-research` with `--phase` and `--depth` flags | SATISFIED | SKILL.md complete; `--phase`/`--depth` interface, new output routing, evals branch all present |
| CMD-03 | 03-02-PLAN.md | `/cortex-spec` handoff pack | SATISFIED | SKILL.md complete; 9-section spec, 3 artifacts, GSD prohibition, eval_plan mandate |
| CMD-04 | 03-03-PLAN.md | `/cortex-investigate` writes to `docs/cortex/investigations/` | SATISFIED (SKILL.md) / NOT TRACKED (REQUIREMENTS.md) | SKILL.md fully implements artifact write; REQUIREMENTS.md checkbox and traceability row still show Pending |
| CMD-05 | 03-03-PLAN.md | `/cortex-review` writes to `docs/cortex/reviews/` with contract compliance | SATISFIED (SKILL.md) / NOT TRACKED (REQUIREMENTS.md) | SKILL.md fully implements contract compliance and artifact write; REQUIREMENTS.md not updated |
| CMD-06 | 03-03-PLAN.md | `/cortex-audit` writes to `docs/cortex/audits/` with 7 lenses | SATISFIED (SKILL.md) / NOT TRACKED (REQUIREMENTS.md) | SKILL.md fully implements 7-lens check and artifact write; REQUIREMENTS.md not updated |
| CMD-07 | 03-02-PLAN.md | `/cortex-status` reconstructs continuity state | SATISFIED | SKILL.md complete; reads correct sources, scans artifacts, writes continuity files |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | CMD-04, CMD-05, CMD-06 checkboxes unchecked and traceability rows show "Pending" despite complete SKILL.md implementations | Warning | Requirements tracking is stale; does not block skill invocation |

No stubs, empty implementations, or placeholder content found in any SKILL.md file.

### Human Verification Required

None — all behavioral checks are statically verifiable from SKILL.md content.

### Gaps Summary

One gap: REQUIREMENTS.md was not updated to mark CMD-04, CMD-05, and CMD-06 as complete after the 03-03 plan executed. The SKILL.md files for `cortex-investigate`, `cortex-review`, and `cortex-audit` are fully implemented with all required artifact-writing sections, slug resolution, and `current-state.md` update steps. However, the requirements tracking document at `.planning/REQUIREMENTS.md` still shows `[ ]` checkboxes and "Pending" status in the traceability table for these three commands.

This is a documentation consistency gap, not a functional gap. The phase goal — "all 7 commands are installed, callable, and produce the correct artifacts when invoked" — is met by the SKILL.md files. The REQUIREMENTS.md update is a tracking obligation.

Fix: Update `.planning/REQUIREMENTS.md` — change `[ ]` to `[x]` for CMD-04, CMD-05, CMD-06 (lines 13–15 of the Commands section) and change "Pending" to "Complete" for the three corresponding rows in the traceability table.

---

_Verified: 2026-03-28_
_Verifier: Claude (gsd-verifier)_
