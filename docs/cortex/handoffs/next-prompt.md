# Next Prompt

We are working on **cortex-install-profiles** in **execute** mode. Implementation is complete and committed (eefe007).

## Active Contract
`docs/cortex/contracts/cortex-install-profiles/contract-001.md`

**Objective:** `--profile=core|full` flag in the Cortex installer. Core = framework skills only (firewall-safe). Full = framework + tool skills.

## What Was Built
- `bin/install.js` — `--profile` flag, skill filter, `.cortex-profile` marker writer, gated API key output
- `runtime-manifest.json` — migrated from `string[]` to tagged objects with `profiles` membership
- `skills/web,ai,google,cli/SKILL.md` — tool skills moved into repo as canonical source
- `test/installer.test.sh` — 9 new profile tests (18/18 passing)
- `DOWNSTREAM.md` — arc diff workflow + `.arcconfig` template for Meta fork users

## Gate State
- clarify_complete: true
- research_complete: true
- spec_complete: true
- contract_approved: true

## Next Steps
1. Run evals from `docs/cortex/evals/cortex-install-profiles/eval-plan.md`
2. Check off each passing dimension in the Results section of the eval plan
3. Once all 6 dimensions pass, advance mode to `validate`

Run `/cortex-status` to reconstruct full context.
