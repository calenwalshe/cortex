#!/usr/bin/env bash
set -euo pipefail

echo "[verify-fast] installer dry-run smoke test"
node bin/install.js --dry-run

echo "[verify-fast] installer shell test suite"
bash test/installer.test.sh
