#!/usr/bin/env node
'use strict';

/**
 * resolve-autonomy.js — Cortex autonomy config resolver
 *
 * Implements 4-layer config resolution with mandatory gate enforcement.
 * Resolution order (highest to lowest precedence):
 *   1. invocation flags  (--autonomy, --gate CLI options)
 *   2. project config    (.cortex/autonomy.json)
 *   3. global config     (~/.claude/cortex-autonomy.json)
 *   4. preset defaults   (supervised | gates-only | full-auto)
 *
 * Mandatory gates are forced true AFTER full merge regardless of any input.
 */

// ── Mandatory gates — cannot be disabled by any config or override ─────────────
const MANDATORY_GATES = ['ux_taste_eval', 'human_action', 'reclarify'];

// ── Preset defaults ─────────────────────────────────────────────────────────────
// Each preset maps gate name → boolean default value.
// supervised: all 13 gates active (backward-compatible current behavior)
// gates-only: approval gates active, review gates inactive
// full-auto:  mandatory gates only (approval and review gates inactive)
const PRESET_DEFAULTS = {
  supervised: {
    ux_taste_eval:        true,
    human_action:         true,
    reclarify:            true,
    contract_approval:    true,
    spec_approval:        true,
    eval_approval:        true,
    slug_conflict:        true,
    eval_proposal:        true,
    critical_uncertainty: true,
    evidence_backing:     true,
    compliance_verdict:   true,
    eval_validation:      true,
    security_verdict:     true,
  },
  'gates-only': {
    ux_taste_eval:        true,
    human_action:         true,
    reclarify:            true,
    contract_approval:    true,
    spec_approval:        true,
    eval_approval:        true,
    slug_conflict:        false,
    eval_proposal:        false,
    critical_uncertainty: false,
    evidence_backing:     false,
    compliance_verdict:   false,
    eval_validation:      false,
    security_verdict:     false,
  },
  'full-auto': {
    ux_taste_eval:        true,
    human_action:         true,
    reclarify:            true,
    contract_approval:    false,
    spec_approval:        false,
    eval_approval:        false,
    slug_conflict:        false,
    eval_proposal:        false,
    critical_uncertainty: false,
    evidence_backing:     false,
    compliance_verdict:   false,
    eval_validation:      false,
    security_verdict:     false,
  },
};

/**
 * resolveAutonomy(options) → { preset, gates }
 *
 * @param {object} options
 * @param {object} [options.invocationFlags] - CLI-level overrides { preset?, gates? }
 * @param {object} [options.projectConfig]   - Project .cortex/autonomy.json content
 * @param {object} [options.globalConfig]    - Global ~/.claude/cortex-autonomy.json content
 * @returns {{ preset: string, gates: object }}
 */
function resolveAutonomy(options) {
  const { invocationFlags = null, projectConfig = null, globalConfig = null } = options || {};

  // 1. Resolve active preset (invocation wins, then project, then global, then 'supervised')
  const preset =
    invocationFlags?.preset ??
    projectConfig?.preset ??
    globalConfig?.preset ??
    'supervised';

  // Validate preset
  if (!PRESET_DEFAULTS[preset]) {
    throw new Error(`Unknown preset: "${preset}". Valid presets: ${Object.keys(PRESET_DEFAULTS).join(', ')}`);
  }

  // 2. Start from preset defaults
  const resolved = Object.assign({}, PRESET_DEFAULTS[preset]);

  // 3. Apply global config gate overrides (lowest config layer)
  if (globalConfig && globalConfig.gates) {
    Object.assign(resolved, globalConfig.gates);
  }

  // 4. Apply project config gate overrides (overrides global)
  if (projectConfig && projectConfig.gates) {
    Object.assign(resolved, projectConfig.gates);
  }

  // 5. Apply invocation gate flags (highest precedence)
  if (invocationFlags && invocationFlags.gates) {
    Object.assign(resolved, invocationFlags.gates);
  }

  // 6. Mandatory gate enforcement — forced true LAST, after all merge layers
  for (const gate of MANDATORY_GATES) {
    resolved[gate] = true;
  }

  return { preset, gates: resolved };
}

/**
 * resolveAutonomyWithSources(options) → { preset, gates, sources }
 *
 * Same as resolveAutonomy but also returns a `sources` object mapping each gate
 * name to the layer that set its final value:
 *   "preset" | "global" | "project" | "invocation" | "mandatory"
 *
 * @param {object} options - Same as resolveAutonomy
 * @returns {{ preset: string, gates: object, sources: object }}
 */
function resolveAutonomyWithSources(options) {
  const { invocationFlags = null, projectConfig = null, globalConfig = null } = options || {};

  // 1. Resolve active preset
  const preset =
    invocationFlags?.preset ??
    projectConfig?.preset ??
    globalConfig?.preset ??
    'supervised';

  if (!PRESET_DEFAULTS[preset]) {
    throw new Error(`Unknown preset: "${preset}". Valid presets: ${Object.keys(PRESET_DEFAULTS).join(', ')}`);
  }

  // 2. Start from preset defaults — all sources are "preset"
  const resolved = Object.assign({}, PRESET_DEFAULTS[preset]);
  const sources = {};
  for (const gate of Object.keys(resolved)) {
    sources[gate] = 'preset';
  }

  // 3. Apply global config gate overrides
  if (globalConfig && globalConfig.gates) {
    for (const [gate, val] of Object.entries(globalConfig.gates)) {
      resolved[gate] = val;
      sources[gate] = 'global';
    }
  }

  // 4. Apply project config gate overrides
  if (projectConfig && projectConfig.gates) {
    for (const [gate, val] of Object.entries(projectConfig.gates)) {
      resolved[gate] = val;
      sources[gate] = 'project';
    }
  }

  // 5. Apply invocation gate flags
  if (invocationFlags && invocationFlags.gates) {
    for (const [gate, val] of Object.entries(invocationFlags.gates)) {
      resolved[gate] = val;
      sources[gate] = 'invocation';
    }
  }

  // 6. Mandatory gate enforcement — forced true LAST
  for (const gate of MANDATORY_GATES) {
    resolved[gate] = true;
    sources[gate] = 'mandatory';
  }

  return { preset, gates: resolved, sources };
}

// ── Exports ──────────────────────────────────────────────────────────────────
module.exports = { resolveAutonomy, resolveAutonomyWithSources, PRESET_DEFAULTS, MANDATORY_GATES };

// ── CLI mode — accept JSON from stdin, output resolved config ─────────────────
if (require.main === module) {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { input += chunk; });
  process.stdin.on('end', () => {
    try {
      const opts = input.trim() ? JSON.parse(input) : {};

      // --dry-run mode: print human-readable gate table
      if (opts._dry_run) {
        const { preset, gates, sources } = resolveAutonomyWithSources(opts);
        const LINE = '\u2550'.repeat(40);
        const SEP  = '\u2500'.repeat(22);
        console.log('AUTONOMY DRY-RUN');
        console.log(LINE);
        console.log(`Preset: ${preset}`);
        console.log('');
        console.log(
          'Gate                    Value   Source'
        );
        console.log(`${SEP}  \u2500\u2500\u2500\u2500\u2500   \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500`
        );
        for (const [gate, val] of Object.entries(gates)) {
          const src = sources[gate] || 'preset';
          const name = gate.padEnd(22);
          const value = String(val).padEnd(5);
          console.log(`${name}  ${value}   ${src}`);
        }
        console.log('');
        console.log('Bridge preview:');
        console.log('  Would generate: PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, config.json, CONTEXT.md');
        console.log('  Would sync: workflow.skip_discuss_cortex to config.json');
        console.log(LINE);
        return;
      }

      // --sources mode: return JSON with sources object
      if (opts._sources) {
        const result = resolveAutonomyWithSources(opts);
        console.log(JSON.stringify(result));
        return;
      }

      // Default: JSON output (existing behavior — no regression)
      const result = resolveAutonomy(opts);
      console.log(JSON.stringify(result));
    } catch (err) {
      console.error(err.message);
      process.exit(1);
    }
  });
}
