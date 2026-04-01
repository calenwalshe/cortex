# Spec: auto-doc-sync

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** auto-doc-sync
**Timestamp:** 20260402T001500Z
**Status:** approved

---

## 1. Problem

Cortex documentation (`docs/COMMANDS.md`, `docs/HOOKS.md`, `docs/CONTINUITY.md`) drifts from the source files it describes (`skills/cortex-*/SKILL.md`, `.claude/hooks/cortex-*.sh`, `.cortex/state.json`) because there is no automated feedback loop between code changes and doc updates. Today, a developer can change a SKILL.md's arguments table or a hook script's trigger conditions and commit without touching the corresponding doc section. The resulting drift is discovered only during periodic manual audits (the most recent being the `cortex-documentation-audit` slug). A pre-commit hook that detects relevant source file changes, invokes an LLM to generate the corresponding doc update, and writes it to disk for human review before commit would close this loop without requiring manual vigilance.

---

## 2. Scope

### In Scope

- A git pre-commit hook script (`hooks/auto-doc-sync.sh`) that runs on every commit
- A JSON config file (`.auto-doc-sync.json`) enumerating the 22 source-to-doc mappings
- An LLM prompt template (`hooks/auto-doc-sync-prompt.md`) for generating doc updates
- Stage-for-review mode: hook writes updated doc section to disk, does not stage it, prints a diff to stdout
- Warn-only fallback mode when `ANTHROPIC_API_KEY` is unset or API call fails
- Two-pass change classifier: heuristic pass (zero LLM cost) + LLM classification pass (Haiku 3)
- Single batched LLM call for multi-file commits with structured JSON response
- Conflict detection: skip generation if target doc is already staged
- Per-file skip marker (`<!-- auto-doc-sync:skip -->`) in target doc files
- Escape hatches: `SKIP_LLM_GITHOOK`, `SKIP=auto-doc-sync`, `FORCE_DOC_SYNC=1`
- Installer integration: `bin/install.js` wires the hook into `.claude/settings.json`
- Shell test coverage for the hook's core paths

### Out of Scope

- Generating docs from scratch for brand-new skills or hooks (initial authoring remains manual)
- Syncing docs to external platforms (that is `cortex-distribute`'s job)
- Updating GSD planning files (`.planning/`, `REQUIREMENTS.md`, `ROADMAP.md`)
- Updating `AGENTS.md` (not mechanically derivable from source file changes)
- Auto-staging or auto-committing generated doc updates (violates pre-commit framework policy)
- Downstream doc dependency cascades (e.g., SKILL.md change also updating AGENTS.md) — deferred to v2
- Linting or style enforcement on documentation content
- Confidence scoring or self-assessment on generated output — deferred to v2

---

## 3. Architecture Decision

**Chosen approach:** A shell-based git pre-commit hook that reads `git diff --cached`, filters for mapped source files via `.auto-doc-sync.json`, runs a two-pass classifier (heuristic then LLM), generates doc updates via a single batched `curl` call to the Anthropic API, and writes updated doc sections to disk without staging them.

**Rationale:** Shell + curl is the most portable invocation mechanism (no runtime dependency beyond `curl` and `jq`). A single batched call keeps latency under 5 seconds for typical multi-file commits. Stage-for-review mode satisfies both the pre-commit framework's "never modify the staging area" policy and the clarify brief's hard constraint that incorrect docs must never be silently committed.

### Alternatives Considered

- **`claude -p` CLI invocation:** Higher convenience but requires `claude` CLI installed on every machine. Not portable. Exit code behavior undocumented. Rejected for primary mechanism; acceptable as optional convenience alias.
- **Python SDK script:** Richest feature set but requires `anthropic` package installed in active Python environment. Breaks in virtualenv-free contexts. Rejected for portability reasons.
- **Auto-commit mode (RepoAgent pattern):** Zero friction but violates pre-commit framework hard policy and removes human checkpoint. Rejected — contradicts the clarify brief's core constraint.
- **Warn-only mode as default:** Safest but highest friction; suggestions are ignored in practice. Deferred to fallback/pilot phase; stage-for-review is the production default.
- **Sequential per-file LLM calls:** Simpler per-call prompts but 3 files × 1–3s each = 3–9s total, exceeding the 5-second developer bypass threshold. Rejected.

---

## 4. Interfaces

- **Anthropic Messages API** (`https://api.anthropic.com/v1/messages`) — external; owned by Anthropic. This spec reads nothing from the API at startup; at hook runtime, sends POST requests with the staged diff and mapping context, receives JSON with generated doc content. Auth: `ANTHROPIC_API_KEY` env var in `x-api-key` header.
- **Git staging area** — read via `git diff --cached` and `git diff --cached --name-only`. This spec reads the staging area; it never writes to it (`git add` is never called by the hook).
- **`.auto-doc-sync.json`** — new file, owned by this spec. Read by the hook at runtime to determine source-to-doc mappings. Written once during installation; maintained manually thereafter.
- **`docs/COMMANDS.md`** — existing file, owned by Cortex. This spec writes updated sections to this file (working tree only, not staged).
- **`docs/HOOKS.md`** — existing file, owned by Cortex. Same write pattern as COMMANDS.md.
- **`docs/CONTINUITY.md`** — existing file, owned by Cortex. Same write pattern as COMMANDS.md.
- **`bin/install.js`** — existing file, owned by Cortex installer. This spec modifies the installer to wire the new hook into `.claude/settings.json`.

---

## 5. Dependencies

- **`curl`** — HTTP client for Anthropic API calls. Expected to be pre-installed on all macOS/Linux developer machines.
- **`jq`** — JSON parser for prompt construction (`jq -n --arg`) and response extraction (`jq -r`). Expected to be pre-installed.
- **`git`** — for `git diff --cached`, `git diff --cached --name-only`, `git status --short`. Required by any git hook.
- **Anthropic API access** — requires `ANTHROPIC_API_KEY` environment variable set at commit time. Models used: `claude-3-haiku-20240307` (classifier), `claude-haiku-4-5-20241022` (doc generation).
- **`.auto-doc-sync.json`** — config file produced by this spec. Must exist at repo root for the hook to operate.
- **Clarify brief** — `docs/cortex/clarify/auto-doc-sync/20260401T200000Z-clarify-brief.md`
- **Research dossiers** — concept, implementation, and mapping table dossiers in `docs/cortex/research/auto-doc-sync/`

---

## 6. Risks

- **LLM hallucination produces incorrect doc content** — Mitigation: stage-for-review mode ensures the human sees the diff before staging; warn-only fallback if confidence is low; pilot with warn-only mode for 2–4 weeks before enabling writes.
- **API latency exceeds 5-second developer tolerance** — Mitigation: use Haiku models (TTFT ~0.65s); single batched call instead of sequential; `--max-time 30` curl timeout; `SKIP_LLM_GITHOOK` escape hatch documented prominently.
- **API unavailability blocks commits** — Mitigation: hook soft-fails (exit 0) when API is unreachable; emits warning to stdout; never blocks the commit on API failure.
- **Mapping config becomes stale when skills/hooks are added or removed** — Mitigation: installer regenerates `.auto-doc-sync.json` from the runtime manifest; hook warns when a source file matches no config entry.
- **Generated update overwrites manual doc edit in working tree** — Mitigation: conflict detection via `git diff --cached --name-only`; skip generation if target doc is already staged; `FORCE_DOC_SYNC=1` override for intentional regeneration.
- **Token cost scales with commit frequency** — Mitigation: two-pass classifier skips LLM call entirely for trivial changes (comment-only, whitespace-only); Haiku 3 at ~$0.0006/commit is negligible even at high frequency.

---

## 7. Sequencing

1. Create `.auto-doc-sync.json` with all 22 mapping entries (8 COMMANDS.md, 12 HOOKS.md, 2 CONTINUITY.md). Checkpoint: config file passes `jq empty` validation.
2. Write `hooks/auto-doc-sync-prompt.md` — the LLM prompt template for doc generation. Checkpoint: prompt template exists and contains all required placeholders.
3. Write `hooks/auto-doc-sync.sh` — the pre-commit hook script implementing the full pipeline (escape hatch check → source file filtering → heuristic classifier → conflict detection → batched LLM call → response parsing → file write → stdout diff). Checkpoint: script is executable and passes shellcheck.
4. Write shell tests for the hook's core paths (`test/auto-doc-sync.test.sh`). Checkpoint: tests pass for skip-if-no-key, skip-if-no-mapped-files, skip-if-target-staged, mock-api-response-parsing.
5. Update `bin/install.js` to wire the hook into `.claude/settings.json` and copy `.auto-doc-sync.json` to the target project. Checkpoint: `node bin/install.js --dry-run` shows the new hook in output.
6. Update `docs/HOOKS.md` with a new `### auto-doc-sync` entry. Checkpoint: entry documents all trigger conditions, inputs, outputs, and side effects.
7. Update `docs/COMMANDS.md` Flag Reference if any new flags are added. Checkpoint: flag table is accurate.

---

## 8. Tasks

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

## 9. Acceptance Criteria

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
