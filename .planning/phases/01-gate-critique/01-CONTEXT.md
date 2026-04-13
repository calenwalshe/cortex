# Phase 1: Build cortex-critique skill - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Write `skills/cortex-critique/SKILL.md` — the standalone critique engine. This is the foundation that all wiring in Phase 2 depends on. Nothing else can be built without it.

This phase is complete when the skill file exists and the 5 Phase 1 success criteria pass.

</domain>

<decisions>
## Implementation Decisions

### Codex CLI invocation (locked)
Invoke as: `codex exec --full-auto --profile llm --skip-git-repo-check --cd /tmp "<adversarial-prompt>"`
- `--cd /tmp` keeps Codex from treating the repo as its workspace
- `--skip-git-repo-check` avoids git detection errors when run outside a git root
- `--profile llm` uses the LLM-optimized execution profile
- The prompt is passed inline as the final positional argument

### Fallback when codex not found
Check `which codex` at invocation start. If absent, fall back to:
`claude -p "<adversarial-prompt>"` — same prompt, same JSON output schema expected.
Log the fallback in the critique artifact header: `> **Note:** Codex CLI not found. Used claude -p fallback.`

### Adversarial prompt structure (locked)
Must follow this order:
1. Role declaration: "You are an adversarial critic, not an assistant. Assume this artifact has at least 2 significant problems."
2. Minimum finding requirement: "You must produce at least 1 finding. If you genuinely find zero issues, explicitly justify this — do not produce empty findings."
3. Artifact-type-specific dimension list (see below)
4. JSON output schema
5. The artifact content to critique

### Artifact-type dimensions (locked)
- **brief**: completeness (are all open questions actionable?), unambiguity (can the spec be derived unambiguously from this?), consistency (do constraints contradict each other?), verifiability (are assumptions falsifiable?), framing attack (is the problem framed to guarantee a specific solution?)
- **dossier**: evidence adequacy (are claims backed by sources?), source authority (are sources high-tier?), finding-to-question traceability (does each finding answer a question from the brief?), assumption backing (are core assumptions supported?)
- **spec**: AC testability (can each AC be mechanically verified?), scope coherence (do in-scope items contradict out-of-scope items?), risk completeness (are mitigations specific and actionable?)
- **contract**: done criteria verifiability (can each criterion be checked without judgment?), validator coverage (do validators cover all done criteria?), write roots completeness (are write roots specific enough to prevent scope creep?)

### Three-tier severity (locked)
- **STOP** — serious structural flaw; surfaces prominently to owner, does NOT auto-block
- **CAUTION** — notable concern; gate advances with receipt recorded
- **GO** — minor or no issues; silent advance
Severity is per-finding, and the overall critique severity = worst finding tier.

### JSON output schema
```json
{
  "severity": "STOP|CAUTION|GO",
  "findings": [
    {
      "tier": "STOP|CAUTION|GO",
      "dimension": "<dimension name>",
      "finding": "<what is wrong>",
      "quote": "<verbatim quote from artifact>",
      "impact": "<what goes wrong downstream if this is not fixed>"
    }
  ],
  "summary": "<1-2 sentence plain language summary of the overall critique>"
}
```

### Gate receipt format
Append to `.cortex/state.json` `critique_receipts[]`:
```json
{
  "gate": "clarify|dossier|spec",
  "slug": "<slug>",
  "timestamp": "<ISO8601>",
  "severity": "STOP|CAUTION|GO",
  "finding_count": <N>,
  "artifact": "docs/cortex/reviews/<slug>/critique-<gate>.md"
}
```

### human_critique autonomy gate
Add to the autonomy gate table in the skill:
- Gate name: `human_critique`
- Full-auto: false (skipped — AI critique runs and persists, gate advances automatically)
- Supervised: true (active — owner sees AI findings in plain language before gate advances)
- When active: show findings as a plain-language summary (not raw JSON), then present AskUserQuestion

### Claude's Discretion
- Exact phrasing of the adversarial prompt beyond the locked structure
- How to render STOP findings prominently (bold header, emoji, box — implementation detail)
- Whether to show all findings or only STOP/CAUTION findings to the owner in supervised mode
- Error handling for malformed JSON output from Codex

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/gate-critique/spec.md
- docs/cortex/specs/gate-critique/gsd-handoff.md
- docs/cortex/contracts/gate-critique/contract-001.md
- docs/cortex/research/gate-critique/concept-20260412T071223Z.md
- docs/cortex/clarify/gate-critique/20260412T082000Z-clarify-brief.md

</canonical_refs>

<specifics>
## Specific Ideas

From spec §4 (Architecture Decision):
- Adversarial prompt explicitly states "you are a critic, not an assistant; assume this artifact has at least 2 significant problems; justify zero findings explicitly"
- Codex exec mode isolates the call from the generating skill's conversation history — this is the root cause fix for same-model confirmation bias
- Critique invocation is additive — if cortex-critique fails (non-zero exit), gate proceeds with `CRITIQUE_FAILED` warning in state.json rather than blocking

From spec §7 (Risks):
- **Codex output format varies**: wrap Codex call and parse JSON from stdout with regex boundary; if JSON parse fails, save raw output in critique artifact and default severity to CAUTION
- **Critique noise**: adversarial prompt requires minimum 1 finding or explicit zero-justification; three-tier routing prevents INFO noise
- **Weak adversarial prompt**: prompt must explicitly state "assume at least 2 significant problems"; Codex exec mode provides isolation

From research dossier:
- Same-model critique is a documented failure mode — Codex exec creates genuinely separate invocation context
- Hard-block bypass via threshold drift: reason binary gates fail; three-tier avoids this

</specifics>

<deferred>
## Deferred Ideas

- cortex-drive gate critique (out of scope — follow-on slug after Phase 1 validates)
- Critique of code or implementation output (domain of cortex-review and cortex-audit)
- Calibration tooling for critique thresholds (post-launch concern)
- Hard-blocking based solely on AI critique (AI informs; human decides — STOP does not veto)

</deferred>

---

*Phase: 01-gate-critique*
*Context gathered: 2026-04-12 via /cortex-bridge*
