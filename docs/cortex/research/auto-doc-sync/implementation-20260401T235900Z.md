# Research Dossier: auto-doc-sync — implementation

<!-- ART-02: Research Dossier Template — produced by /cortex-research -->

**Slug:** auto-doc-sync
**Phase:** implementation
**Timestamp:** 20260401T235900Z
**Depth:** standard

---

## Summary

The four unresolved implementation questions from the concept phase now have clear answers: (1) the source-to-doc mapping belongs in a dedicated config file (not embedded in the hook), structured as named tasks with source globs and an output target — the `llmake` JSON format is the closest prior art; (2) a single batched LLM call with structured JSON output is the only viable multi-file strategy, as three sequential calls at Haiku speeds (1–3s each) routinely exceed the 5-second practitioner threshold that causes developers to bypass hooks; (3) per-file skip-regeneration has no prior-art solution — a custom in-file skip marker (e.g., `<!-- auto-doc-sync:skip -->` in the doc file) or per-path config entry is the correct design choice; (4) if the target doc file is already staged when the hook runs, skip generation silently — this is the only safe conflict policy and aligns with the staged-as-intentional principle. Cost is not a constraint: Haiku 3 at ~$0.0006/commit is negligible.

---

## Findings

### 1. Source-to-Doc Mapping Config

- No native git hook or pre-commit framework mechanism provides "if source file X changes, update doc section Y" routing. The pre-commit `files:` key scopes which source files trigger a hook — it does not route output.
- Three approaches found in the wild: (a) **convention-based** (Sphinx autodoc — inline `.. automodule::` directives, no config file; relationship implicit in `.rst` file structure); (b) **glob-to-folder** (docfx `docfx.json` — coarse `files: glob` → `dest: folder` mapping; no per-section granularity); (c) **named-task + glob + prompt** (`llmake` JSON — each named task specifies source globs, a generation prompt, and an implied output target).
- The `llmake` pattern is the only one that names a specific doc artifact and the source files that trigger its update. Config structure: `{ "task-name": { "sources": ["glob/**/*.md"], "prompt": "...", "exclude": ["..."] } }`.
- For Cortex: a dedicated config file (e.g., `.auto-doc-sync.json`) with explicit per-entry mappings is correct. The Cortex doc surface is small and fully enumerable. Embedding the mapping table directly in hook script code (rather than a config file) is inflexible and should not be done.
- The mapping must be a config file, not convention-inferred, because Cortex's source files (SKILL.md, hook scripts, state.json) do not mirror the doc surface by path structure.

### 2. Multi-File Batching

- **Dominant industry pattern: single batched call** — `git diff --cached` pipes all staged diffs into one LLM call. Used by Harper Reed's hook, llm-commit, pre-commit-llm-code-review, chatgpt-pre-commit-hooks. Only Prism (chunked + bounded parallel) and RepoAgent (multi-threaded per-object) deviate.
- **Sequential calls are unviable for Cortex commits touching multiple SKILL.md files.** At Haiku 4.5 speeds (TTFT ~0.65s, total round-trip 1–3s per call), three sequential calls = 3–9 seconds. The practitioner-cited bypass threshold is 5 seconds. Sonnet is worse.
- **Single batched call with structured JSON output** (e.g., `[{ "target": "docs/COMMANDS.md", "section": "...", "content": "..." }]`) is the correct design: one API round-trip, full context for all changed files, total latency 2–4 seconds.
- Bash `&` + `wait` enables parallel shell API calls; Python `asyncio.gather()` with `AsyncAnthropic` client achieves parallel SDK calls. However, these are only needed if the single batched prompt exceeds safe token limits — the default should be one call.
- Context compression: hunk-level capping (≤10 changed lines per hunk, `@@ -n,m @@` markers retained) plus lockfile stripping achieves 40–60% token reduction with no loss of model comprehension. Hard ceiling: if compressed aggregate diff still exceeds ~4,000 tokens, fall back to grouping files into ≤3 batched calls.
- Fallback policy for oversized batched prompts: split into sub-batches of ≤3 files per call rather than truncating mid-diff. Truncated diffs produce hallucinated doc updates more frequently than shorter complete diffs.

### 3. Per-File Skip-Regeneration (Sentinel Mechanism)

- No prior-art tool implements per-file skip for generated documentation. The `SKIP=hook-id` env var (pre-commit framework) and `SKIP_LLM_GITHOOK` (Harper Reed) skip the entire hook — not a specific file.
- Commit message tags (`[skip-docs]`) are **not viable at the pre-commit stage** — the commit message does not exist yet when `pre-commit` runs. This is a hard constraint of the git hook lifecycle.
- Custom per-file sentinel options (must be built from scratch):
  - **In-file skip marker**: place `<!-- auto-doc-sync:skip -->` in the target doc file (e.g., in `COMMANDS.md`). The hook reads the target file before writing; if the marker is present, skip that entry.
  - **Config-level exclude list**: add a `skip: true` field to the relevant mapping entry in `.auto-doc-sync.json`. Requires manual config edit to activate.
  - **Sentinel file**: place `.auto-doc-sync-skip` in the directory of the target doc file. Simple filesystem check; no file-content dependency.
- **Recommended**: in-file skip marker (`<!-- auto-doc-sync:skip -->`) because it travels with the doc file, is visible in diffs, and does not require a separate file or config edit. The hook reads the first 50 lines of the target file for the marker before invoking any LLM call.
- **`SKIP_LLM_GITHOOK` env var** remains the correct mechanism for skipping the entire hook (CI, automated scripts, emergency bypasses). Document prominently.

### 4. Conflict Detection — Target Doc Already Staged

- `git diff --cached --name-only` is the canonical command to inspect staged files in a pre-commit hook.
- If the target doc file is listed in `git diff --cached --name-only` when the hook runs, the committer has already manually staged a doc change. **The hook must skip generation for that target and print a notice.** Rationale: staged edits represent deliberate human intent; overwriting them silently is strictly worse than skipping.
- `git status --short` → `MM` pattern indicates a file is staged AND has additional unstaged modifications. In this case, also skip generation — the file is in an ambiguous state.
- `git show :path/to/file` reads the staged version of a file without touching the working tree. Useful for comparing the existing staged doc content against what the hook would generate — but this comparison adds latency and is not needed if the skip-if-staged policy is in force.
- Force-override path: `FORCE_DOC_SYNC=1 git commit` bypasses the skip-if-staged check. Document this alongside `SKIP_LLM_GITHOOK`.
- lint-staged's partially-staged file problem (conflict on `git stash pop`) does not apply here because the hook does not write to staged files at all — it only writes to the working tree and lets the committer stage the result.

### 5. Token Costs and Latency

- **Claude Haiku 3** (cheapest): $0.25/MTok input, $1.25/MTok output → ~$0.0006/commit for a 1,500-token diff. Per-commit financial cost is not a constraint.
- **Claude Haiku 4.5**: $1.00/MTok input, $5.00/MTok output → ~$0.0025/commit. TTFT ~0.65s on Anthropic direct; total round-trip for a sub-2,000-token payload: 1–3 seconds.
- A typical 100–200 line diff: estimated 800–2,500 tokens (at ~4 chars/token, with diff overhead).
- **Model recommendation**: Haiku 3 for classification pass (zero-dollar cost at this scale); Haiku 4.5 for doc generation (best speed/quality ratio in the Haiku family). Do not use Sonnet in a pre-commit hook — at 3s TTFT, three-file commits will consistently exceed the 5-second threshold.
- Batch API (50% cost reduction): unsuitable — 24-hour turnaround makes it usable only for post-commit asynchronous workflows, not pre-commit blocking hooks.

---

## Trade-offs

### Option A: Config File for Source-to-Doc Mapping (`.auto-doc-sync.json`)
**Pros:** Explicit, enumerable, human-editable without touching hook code; survives hook script rewrites; can be committed alongside the hook; aligns with the `llmake` pattern.
**Cons:** Another config file to maintain; must be kept in sync with doc surface changes; initial enumeration of the full Cortex mapping table is a manual one-time task.
**Verdict:** selected — the only viable approach given that Cortex's source and doc paths have no convention-derivable relationship.

### Option B: Embedded Mapping in Hook Script
**Pros:** No separate file.
**Cons:** Inflexible; changing any mapping requires editing the hook script; fails code/config separation principle.
**Verdict:** rejected.

### Option A: Single Batched LLM Call (all changed files → one prompt, structured JSON response)
**Pros:** One API round-trip; total latency 2–4s even for 3-file commits; full context available for cross-file consistency; amortizes connection overhead.
**Cons:** More complex prompt engineering; JSON response parsing must be robust; if LLM produces invalid JSON, no partial recovery.
**Verdict:** selected — latency constraint makes sequential calls unviable.

### Option B: Sequential Per-File LLM Calls
**Pros:** Simpler prompt per call; independent failure modes; easier to debug.
**Cons:** 3 calls × 1–3s each = 3–9s; exceeds 5s bypass threshold for typical multi-file commits.
**Verdict:** rejected for the primary path; acceptable as a fallback when a single file is changed.

### Option C: Parallel Shell Calls (`&` + `wait`)
**Pros:** Parallel execution; total time = slowest single call.
**Cons:** Adds shell complexity; concurrent stdout output from multiple API calls is difficult to read; requires careful PID tracking and exit code aggregation.
**Verdict:** deferred — acceptable if sequential fallback is implemented and latency proves unacceptable in practice.

### Option A: In-File Skip Marker (`<!-- auto-doc-sync:skip -->`)
**Pros:** Travels with the doc file; visible in diffs; no extra file or config entry; grep-checkable.
**Cons:** Requires reading the doc file before writing; marker must survive manual doc edits.
**Verdict:** selected — best balance of visibility and simplicity.

### Option B: Per-Config Exclude Entry
**Pros:** Centralized in one place.
**Cons:** Requires editing `.auto-doc-sync.json` to activate; not co-located with the affected doc.
**Verdict:** deferred — appropriate for permanently-excluded targets, not for "I rejected this one update."

---

## Recommendations

- Implement the source-to-doc mapping as a **`.auto-doc-sync.json` config file** at repo root. Structure per entry: `{ "id": string, "source_glob": string, "target_doc": string, "target_section": string, "prompt_hint": string }`. The full mapping table for Cortex's doc surface (COMMANDS.md, HOOKS.md, CONTINUITY.md, AGENTS.md) must be enumerated during spec phase — this is a prerequisite for implementation.
- Use a **single batched LLM call** as the primary multi-file strategy. The prompt must request structured JSON output with one object per target doc. Implement robust JSON response validation (`jq empty`) and gracefully skip targets with unparseable output rather than blocking the commit.
- Use **Haiku 3 for the two-pass classifier** (heuristics → LLM classification, ~$0.0006 total) and **Haiku 4.5 for doc generation**. Never use Sonnet in a pre-commit hook.
- Cap diff input per file: strip lockfile hunks, cap each hunk at 10 changed lines. If the aggregate compressed prompt exceeds ~4,000 tokens, split into sub-batches of ≤3 files rather than truncating.
- Implement **in-file skip marker** (`<!-- auto-doc-sync:skip -->`) as the per-file skip mechanism. Hook reads the first 50 lines of each target doc file before invoking the LLM; if marker is found, skip that target.
- Implement **conflict detection via `git diff --cached --name-only`**: if the target doc file is already staged, skip generation and print a notice. Provide `FORCE_DOC_SYNC=1` env var as an override for committers who want to regenerate despite having manually staged a doc change.
- Document three escape hatches prominently: `SKIP_LLM_GITHOOK` (skip entire hook), `SKIP=auto-doc-sync` (pre-commit framework skip), `FORCE_DOC_SYNC=1` (override staged-doc skip).
- Start rollout in **warn-only mode** (as recommended in concept dossier): emit the structured JSON to stdout but do not write files. After 2–4 weeks of calibration, switch to stage-for-review mode.

---

## Open Questions

- **The complete Cortex source-to-doc mapping table is not yet enumerated.** Which specific SKILL.md entries map to which COMMANDS.md sections? Which hook scripts map to which HOOKS.md entries? Which state.json fields map to which CONTINUITY.md rows? This table must be produced before spec can proceed — it requires reading the actual Cortex doc surface files.
- What is the acceptable latency threshold for the Cortex team's commit workflow? The 5-second figure is a practitioner heuristic; the actual tolerance depends on commit frequency and whether hooks run in CI. This should be confirmed before choosing between Haiku 3 (slower, cheaper) and Haiku 4.5 (faster, 4x more expensive).
- How does the batched prompt handle cases where one LLM-generated doc update in the JSON response is clearly hallucinated (e.g., describes behavior not present in the diff)? Is there a lightweight self-assessment step ("confidence: high/low" in the JSON response) that triggers a warn-only fallback for that specific target?
- Should the in-file skip marker (`<!-- auto-doc-sync:skip -->`) be permanent (survives forever until manually removed) or commit-scoped (reset after one successful skip)? Commit-scoped is harder to implement but safer — prevents permanent silencing of a doc section after a single rejection.
- What is the correct behavior when the batched JSON response from the LLM contains a valid update for target A but invalid JSON for target B? Partial application (write A, skip B with warning) vs. all-or-nothing (skip both, warn)?

---

## Sources

- [llmake (Mintlify)](https://mintlify.com/cyrusnuevodia/llmake/guides/glob-patterns) — named-task + source-glob + prompt config pattern
- [pre-commit.com `files:` key](https://pre-commit.com/) — hook input scoping (one-directional, not routing)
- [docfx.json reference (Microsoft)](https://dotnet.github.io/docfx/reference/docfx-json-reference.html) — glob-to-folder mapping pattern
- [Sphinx autodoc](https://www.sphinx-doc.org/en/master/usage/extensions/autodoc.html) — convention-based inline directive pattern
- [Harper Reed's commit hook](https://harper.blog/2024/03/11/use-an-llm-to-automagically-generate-meaningful-git-commit-messages/) — single batched call, SKIP_LLM_GITHOOK pattern
- [llm-commit (nchagnet)](https://nchagnet.pages.dev/blog/commit-cli-tool-llm/) — 4096-char truncation, single call
- [pre-commit-llm-code-review (qdii)](https://github.com/qdii/pre-commit-llm-code-review) — single call, rate-limit risk acknowledgment
- [Prism (dshills)](https://github.com/dshills/prism) — only tool with chunked + bounded parallel calls
- [PocketFlow parallel LLM calls](https://medium.com/@zh2408/parallel-llm-calls-from-scratch-tutorial-for-dummies-using-pocketflow-383c74220056) — asyncio.gather() pattern, 5x speedup demonstrated
- [Adam Johnson — Git: How to skip hooks](https://adamj.eu/tech/2023/02/13/git-skip-hooks/) — SKIP env var, core.hooksPath=/dev/null
- [git-scm.com githooks docs](https://git-scm.com/docs/githooks) — hook lifecycle, message unavailability at pre-commit
- [olioapps.com — Automatic code formatting for partially-staged files](https://www.olioapps.com/blog/automatic-code-formatting) — git show :path, git update-index, staged-vs-working-tree patterns
- [Artificial Analysis — Claude Haiku 4.5 latency](https://artificialanalysis.ai/models/claude-4-5-haiku/providers) — TTFT 0.65s, 91.4 t/s throughput
- [Anthropic Claude API Pricing](https://platform.claude.com/docs/en/about-claude/pricing) — Haiku 3 $0.25/$1.25 MTok, Haiku 4.5 $1.00/$5.00 MTok
- [Precision Dissection of Git Diffs for LLM Consumption](https://medium.com/@yehezkieldio/precision-dissection-of-git-diffs-for-llm-consumption-7ce5d2ca5d47) — hunk-level capping, token estimation
- [deepchecks.com — 5 Approaches to Solve LLM Token Limits](https://www.deepchecks.com/5-approaches-to-solve-llm-token-limits/) — compact_diff() pattern, 40-60% reduction
- [pre-commit auto-staging policy](https://github.com/pre-commit/pre-commit/issues/806) — "pre-commit never modifies the staging area"
- Gemini 2.5 Flash cross-reference (20260401T235900Z) — batched-call recommendation confirmed; in-file skip marker and force-override gap flagged
- `/home/agent/projects/cortex/docs/cortex/clarify/auto-doc-sync/20260401T200000Z-clarify-brief.md` — constraints, open questions as research input
- `/home/agent/projects/cortex/docs/cortex/research/auto-doc-sync/concept-20260401T220000Z.md` — concept phase findings as context
