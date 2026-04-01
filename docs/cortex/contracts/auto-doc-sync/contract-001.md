# Contract: auto-doc-sync — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->

**ID:** auto-doc-sync-001
**Slug:** auto-doc-sync
**Phase:** execute
**Created:** 20260402T001500Z
**Status:** approved

---

## Objective

Build a git pre-commit hook that auto-generates documentation updates for `docs/COMMANDS.md`, `docs/HOOKS.md`, and `docs/CONTINUITY.md` whenever their corresponding source files are modified, so that Cortex documentation stays synchronized with implementation without manual audits.

---

## Deliverables

- `.auto-doc-sync.json` — source-to-doc mapping config (22 entries)
- `hooks/auto-doc-sync.sh` — pre-commit hook script
- `hooks/auto-doc-sync-prompt.md` — LLM prompt template
- `test/auto-doc-sync.test.sh` — shell test suite
- Updated `bin/install.js` — installer integration
- Updated `runtime-manifest.json` — manifest entries
- Updated `docs/HOOKS.md` — hook documentation entry

---

## Scope

### In Scope

- Pre-commit hook script with full pipeline (filter → classify → detect → call → parse → write)
- JSON mapping config for all 22 source-to-doc relationships
- Stage-for-review write mode (working tree only, no `git add`)
- Warn-only fallback for API failures
- Two-pass heuristic + LLM change classifier
- Conflict detection (skip if target already staged)
- Per-file skip marker support
- Three escape hatches (`SKIP_LLM_GITHOOK`, `SKIP=auto-doc-sync`, `FORCE_DOC_SYNC=1`)
- Installer wiring
- Shell tests for core paths

### Out of Scope

- Generating docs for brand-new skills or hooks
- Syncing docs to external platforms
- Updating `AGENTS.md`, `.planning/`, or GSD state
- Auto-staging or auto-committing generated updates
- Downstream doc dependency cascades
- Confidence scoring or self-assessment

---

## Write Roots

- `hooks/auto-doc-sync.sh`
- `hooks/auto-doc-sync-prompt.md`
- `.auto-doc-sync.json`
- `test/auto-doc-sync.test.sh`
- `bin/install.js`
- `runtime-manifest.json`
- `docs/HOOKS.md`
- `docs/COMMANDS.md` (Flag Reference section only, if new flags are added)

---

## Done Criteria

- [ ] `.auto-doc-sync.json` exists at repo root, passes `jq empty`, and contains exactly 22 mapping entries covering all 8 COMMANDS.md sections, 12 HOOKS.md sections, and 2 CONTINUITY.md targets
- [ ] `hooks/auto-doc-sync.sh` is executable, passes `shellcheck`, and implements the full pipeline
- [ ] Hook exits 0 immediately when `SKIP_LLM_GITHOOK=1` is set, with no API call made
- [ ] Hook exits 0 with no action when no staged files match any `.auto-doc-sync.json` entry
- [ ] Hook skips a target doc and prints a notice when that doc is already in `git diff --cached --name-only`
- [ ] Hook skips a target doc when `<!-- auto-doc-sync:skip -->` is found in its first 50 lines
- [ ] Hook soft-fails (exit 0, warning to stdout) when `ANTHROPIC_API_KEY` is unset
- [ ] Hook soft-fails (exit 0, warning to stdout) when the API call times out or returns an error
- [ ] Hook writes updated doc content to the correct target file in the working tree without calling `git add`
- [ ] Hook prints a unified diff of the changes to stdout for human review
- [ ] For a 3-file commit touching 3 SKILL.md files, the hook makes exactly 1 API call (batched), not 3
- [ ] Heuristic classifier correctly identifies comment-only and whitespace-only diffs and skips the LLM call for them
- [ ] `FORCE_DOC_SYNC=1` overrides the skip-if-staged check
- [ ] `node bin/install.js --dry-run` includes the auto-doc-sync hook in its output
- [ ] All tests in `test/auto-doc-sync.test.sh` pass
- [ ] `docs/HOOKS.md` contains a complete `### auto-doc-sync` entry with all required subsections

---

## Validators

- [ ] `jq empty .auto-doc-sync.json` — config is valid JSON
- [ ] `jq '.| length' .auto-doc-sync.json` returns 22
- [ ] `shellcheck hooks/auto-doc-sync.sh` — no errors
- [ ] `bash test/auto-doc-sync.test.sh` — all tests pass
- [ ] `node bin/install.js --dry-run` — output includes auto-doc-sync hook
- [ ] `bash scripts/verify-fast.sh` — no regressions in existing tests
- [ ] `grep -c '### auto-doc-sync' docs/HOOKS.md` returns 1

---

## Eval Plan

docs/cortex/evals/auto-doc-sync/eval-plan.md

---

## Approvals

- [x] Contract approval
- [x] Evals approval

---

## Rollback Hints

- Delete `hooks/auto-doc-sync.sh`
- Delete `hooks/auto-doc-sync-prompt.md`
- Delete `.auto-doc-sync.json`
- Delete `test/auto-doc-sync.test.sh`
- Revert `bin/install.js` to pre-auto-doc-sync state (`git checkout HEAD~1 -- bin/install.js`)
- Revert `runtime-manifest.json` to pre-auto-doc-sync state
- Remove `### auto-doc-sync` entry and Hook Overview row from `docs/HOOKS.md`
- Remove auto-doc-sync hook entry from `.claude/settings.json` in target projects
