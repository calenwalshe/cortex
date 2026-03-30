'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const MANIFEST_PATH = path.join(REPO_ROOT, 'runtime-manifest.json');

function loadRuntimeManifest() {
  if (!fs.existsSync(MANIFEST_PATH)) {
    throw new Error(`Runtime manifest not found: ${MANIFEST_PATH}`);
  }

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
  } catch (err) {
    throw new Error(`Failed to parse runtime manifest: ${MANIFEST_PATH}\n${err.message}`);
  }

  validateManifest(manifest);
  return manifest;
}

function validateManifest(manifest) {
  const requiredArrays = ['skills', 'agents', 'hooks', 'hook_events'];
  for (const key of requiredArrays) {
    if (!Array.isArray(manifest[key])) {
      throw new Error(`Invalid runtime manifest schema in ${MANIFEST_PATH}: expected array at \"${key}\"`);
    }
  }

  if (!manifest.runtime_roots || typeof manifest.runtime_roots !== 'object') {
    throw new Error(`Invalid runtime manifest schema in ${MANIFEST_PATH}: missing \"runtime_roots\" object`);
  }

  if (!manifest.settings_profiles || typeof manifest.settings_profiles !== 'object') {
    throw new Error(`Invalid runtime manifest schema in ${MANIFEST_PATH}: missing \"settings_profiles\" object`);
  }

  const knownHookFiles = new Set(manifest.hooks.map(h => h.file));
  for (const hook of manifest.hooks) {
    if (!hook || typeof hook.file !== 'string') {
      throw new Error(`Invalid runtime manifest hook entry in ${MANIFEST_PATH}: each hook needs string \"file\"`);
    }
    if (!['global', 'manual'].includes(hook.wiring)) {
      throw new Error(`Invalid runtime manifest hook entry in ${MANIFEST_PATH}: unknown wiring \"${hook.wiring}\" for ${hook.file}`);
    }
  }

  for (const evt of manifest.hook_events) {
    if (!evt || typeof evt.event !== 'string' || typeof evt.hook_file !== 'string') {
      throw new Error(`Invalid runtime manifest hook_events entry in ${MANIFEST_PATH}: each event needs string \"event\" and \"hook_file\"`);
    }
    if (!knownHookFiles.has(evt.hook_file)) {
      throw new Error(`Invalid runtime manifest hook_events entry in ${MANIFEST_PATH}: hook_file \"${evt.hook_file}\" is not present in hooks[]`);
    }
  }

  for (const [profileName, profile] of Object.entries(manifest.settings_profiles)) {
    if (!profile || typeof profile.hook_root !== 'string') {
      throw new Error(`Invalid runtime manifest settings_profiles entry in ${MANIFEST_PATH}: profile \"${profileName}\" must define string \"hook_root\"`);
    }
    if (!Object.prototype.hasOwnProperty.call(manifest.runtime_roots, profile.hook_root)) {
      throw new Error(`Invalid runtime manifest settings_profiles entry in ${MANIFEST_PATH}: profile \"${profileName}\" references unknown runtime root \"${profile.hook_root}\"`);
    }
  }
}

function buildSettings(manifest, profileName) {
  const profile = manifest.settings_profiles[profileName];
  if (!profile) {
    throw new Error(`Unknown settings profile \"${profileName}\"`);
  }

  const hookRoot = manifest.runtime_roots[profile.hook_root];
  const hooks = {};

  for (const { event, hook_file, matcher, timeout, async } of manifest.hook_events) {
    const hookEntry = {
      type: 'command',
      command: `\"${hookRoot}/hooks/${hook_file}\"`
    };
    if (typeof timeout === 'number') hookEntry.timeout = timeout;
    if (typeof async === 'boolean') hookEntry.async = async;

    const eventEntry = { hooks: [hookEntry] };
    if (matcher) eventEntry.matcher = matcher;
    hooks[event] = [eventEntry];
  }

  return { hooks };
}

module.exports = {
  loadRuntimeManifest,
  buildSettings,
  MANIFEST_PATH,
};
