#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { loadRuntimeManifest, buildSettings } = require('./runtime-manifest');

const manifest = loadRuntimeManifest();
const output = JSON.stringify(buildSettings(manifest, 'project'), null, 2) + '\n';
const outputPath = process.argv[2];

if (outputPath) {
  fs.writeFileSync(path.resolve(outputPath), output);
} else {
  process.stdout.write(output);
}
