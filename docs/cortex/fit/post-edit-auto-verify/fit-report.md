# Fit Report: post-edit-auto-verify

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** post-edit-auto-verify
**Timestamp:** 20260330T183000Z
**Evaluated against:** Cortex v1.0 — .claude/hooks/cortex-validator-trigger.sh, cortex-task-completed.sh, .cortex/dirty-files.json, runtime-manifest.json
**Confidence:** high — full hook source read + research dossier at docs/cortex/research/cortex-ak-integration/concept-20260330T180000Z.md
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Adopt

**Justification:** The dirty-file tracking and completion-blocking scaffold is already 70% implemented; the only missing piece is executing the verifier and writing results.

---

## Gap

`cortex-validator-trigger.sh` explicitly notes in its header: "Does NOT run validators inline." It tracks dirty files but never runs anything. `.cortex/validator-results.json` does not exist — no schema, no write path. There is no config-driven verifier discovery (no lookup for `npm run cortex:verify:fast`, `make cortex-verify-fast`, or `.cortex/verify.sh`). `docs/cortex/handoffs/eval-status.md` is read by the task-completed hook but nothing currently writes to it during execute mode.

The gap is precise: the infrastructure pipeline from edit → track → run → record → gate exists except for the "run" and "record" steps.

---

## Overlap

The following components directly support this proposal and would be extended, not replaced:

- `cortex-validator-trigger.sh` — PostToolUse, Write|Edit, execute/repair mode only. The mode gating and dirty-file append logic stays as-is; the new block appends after it.
- `.cortex/dirty-files.json` — schema and write logic already present and correct.
- `cortex-task-completed.sh` — already reads eval-status.md and blocks on FAIL lines. No changes needed to this hook.
- The async PostToolUse + blocking TaskCompleted pattern — already wired in runtime-manifest.json. The timing contract (validator runs async, gate blocks at completion) is the correct design and requires no changes.

---

## Unique Contribution

The config-driven verifier discovery pattern: check `package.json` `cortex:verify:fast` → `Makefile` target → `.cortex/verify.sh` fallback → emit SKIP (not PASS) if nothing found. This pattern is genuinely new in cortex — no other hook or skill performs capability discovery against the target repo's build tooling before executing. It establishes a precedent for how cortex adapts to heterogeneous project environments without hardcoding a runner.

---

## Conflict

**Async timing (soft tension, already mitigated):** PostToolUse cannot block — the write has already happened before the hook fires. The validator runs after the write. If the validator is still running when TaskCompleted fires, the task-completed hook blocks because eval-status.md is absent or stale. This is correct behavior. No conflict — the existing hook contract handles it.

**Output size (soft tension, manageable):** Uncapped validator output in validator-results.json could grow unbounded on verbose test suites. Mitigation: cap stored stdout/stderr at 500 lines with a truncation notice. Not a blocking conflict.

**SKIP vs PASS semantics (design tension):** If no verifier is configured and the result is silently written as PASS, the gate becomes meaningless for unconfigured projects. SKIP must be a distinct status that the task-completed hook does not treat as passing. This requires a one-line change to the FAIL check in cortex-task-completed.sh (add: SKIP is not a blocker, but ABSENT verifier config emits a WARNING, not a PASS).

---

## Strategic Direction

**Alignment:** aligned

The execution quality loop is the one area where cortex has been explicitly weaker than comparable frameworks. This closes that gap in the most cortex-native way — through existing hooks and gates rather than a new command. The config-driven verifier discovery pattern also advances cortex's goal of being target-repo-agnostic.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Extend `cortex-validator-trigger.sh` to discover and run a project-defined fast verifier after each edit in execute/repair mode, write structured results to `.cortex/validator-results.json`, refresh `eval-status.md`, and let the existing `cortex-task-completed.sh` gate enforce pass/fail.

**Constraints:**
- PostToolUse is async — validator must not attempt to block the write; gate enforcement belongs in TaskCompleted only
- SKIP must be a distinct status from PASS — unconfigured projects must not silently pass the gate
- Output storage in validator-results.json must be capped (≤500 lines) to prevent unbounded growth
- cortex-task-completed.sh FAIL check logic must not be changed except to clarify SKIP semantics

**Open questions:**
- Verifier discovery order: package.json → Makefile → .cortex/verify.sh — is this the right precedence?
- Should a missing verifier emit a WARNING in eval-status.md (advisory, non-blocking) or a SKIP (no opinion)?
- Should validator-results.json be per-file or per-run? Per-run is simpler; per-file is more useful for targeted repair.

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify post-edit-auto-verify`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
