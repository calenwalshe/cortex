#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const manifestPath = path.join(REPO_ROOT, 'runtime-manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

function buildSettings(projectRootExpression) {
  const hooks = {};

  for (const { event, hook_file, matcher, timeout, async } of manifest.hook_events) {
    const hookEntry = {
      type: 'command',
      command: `"${projectRootExpression}/hooks/${hook_file}"`
    };
    if (typeof timeout === 'number') hookEntry.timeout = timeout;
    if (typeof async === 'boolean') hookEntry.async = async;

    const eventEntry = { hooks: [hookEntry] };
    if (matcher) eventEntry.matcher = matcher;
    hooks[event] = [eventEntry];
  }

  return { hooks };
}

const output = JSON.stringify(buildSettings('$CLAUDE_PROJECT_DIR/.claude'), null, 2) + '\n';
const outputPath = process.argv[2];

if (outputPath) {
  fs.writeFileSync(path.resolve(outputPath), output);
} else {
  process.stdout.write(output);
}
