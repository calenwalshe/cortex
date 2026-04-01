# GSD Handoff: auto-doc-sync

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->

**Slug:** auto-doc-sync
**Timestamp:** 20260402T001500Z
**Status:** draft

---

## Objective

Build a git pre-commit hook that detects changes to Cortex source files (SKILL.md files, hook scripts, state.json schema), generates corresponding documentation updates via the Anthropic API, and writes them to disk for human review — so that `docs/COMMANDS.md`, `docs/HOOKS.md`, and `docs/CONTINUITY.md` never drift from their source files without an explicit human decision.

---

## Deliverables

- `.auto-doc-sync.json` — mapping config file at repo root (22 entries: 8 COMMANDS.md, 12 HOOKS.md, 2 CONTINUITY.md)
- `hooks/auto-doc-sync.sh` — pre-commit hook script (shell, curl+jq)
- `hooks/auto-doc-sync-prompt.md` — LLM prompt template for doc generation
- `test/auto-doc-sync.test.sh` — shell test suite for hook core paths
- Updated `bin/install.js` — installer wires hook into settings and copies config
- Updated `runtime-manifest.json` — includes auto-doc-sync entries
- Updated `docs/HOOKS.md` — new `### auto-doc-sync` entry + Hook Overview table row

---

## Requirements

- None formalized

---

## Tasks

- [ ] Create `.auto-doc-sync.json` at repo root with 22 entries (source_glob, target_doc, target_section, prompt_hint per entry)
- [ ] Write `hooks/auto-doc-sync-prompt.md` with placeholders for diff, target_section, and mapping context
- [ ] Write `hooks/auto-doc-sync.sh` — escape hatch checks (`SKIP_LLM_GITHOOK`, `SKIP=auto-doc-sync`)
- [ ] Write `hooks/auto-doc-sync.sh` — source file filtering against `.auto-doc-sync.json` mappings
- [ ] Write `hooks/auto-doc-sync.sh` — heuristic classifier (comment-only, whitespace-only → skip LLM)
- [ ] Write `hooks/auto-doc-sync.sh` — conflict detection (`git diff --cached --name-only` check on target docs)
- [ ] Write `hooks/auto-doc-sync.sh` — per-file skip marker detection (`<!-- auto-doc-sync:skip -->`)
- [ ] Write `hooks/auto-doc-sync.sh` — batched LLM call via `curl` to Anthropic API with structured JSON response
- [ ] Write `hooks/auto-doc-sync.sh` — response parsing with `jq`, per-target file write, stdout diff output
- [ ] Write `hooks/auto-doc-sync.sh` — warn-only fallback when `ANTHROPIC_API_KEY` is unset or API fails
- [ ] Write `test/auto-doc-sync.test.sh` — test: exits 0 immediately when `SKIP_LLM_GITHOOK` is set
- [ ] Write `test/auto-doc-sync.test.sh` — test: exits 0 when no staged files match any mapping entry
- [ ] Write `test/auto-doc-sync.test.sh` — test: skips target when already staged
- [ ] Write `test/auto-doc-sync.test.sh` — test: skips target when skip marker is present
- [ ] Write `test/auto-doc-sync.test.sh` — test: parses valid JSON response and writes correct target file
- [ ] Write `test/auto-doc-sync.test.sh` — test: handles invalid JSON response gracefully (warn, no write)
- [ ] Update `bin/install.js` — add auto-doc-sync hook to settings wiring and config file copy
- [ ] Update `runtime-manifest.json` — add auto-doc-sync entries
- [ ] Update `docs/HOOKS.md` — add `### auto-doc-sync` entry with full hook documentation
- [ ] Update `docs/HOOKS.md` Hook Overview table — add auto-doc-sync row

---

## Acceptance Criteria

- [ ] `.auto-doc-sync.json` exists at repo root, passes `jq empty`, and contains exactly 22 mapping entries covering all 8 COMMANDS.md sections, 12 HOOKS.md sections, and 2 CONTINUITY.md targets
- [ ] `hooks/auto-doc-sync.sh` is executable, passes `shellcheck`, and implements the full pipeline: escape hatch → filter → classify → detect conflicts → LLM call → parse → write → diff
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

## Contract Link

docs/cortex/contracts/auto-doc-sync/contract-001.md
