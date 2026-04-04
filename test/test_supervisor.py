#!/usr/bin/env python3
"""Tests for cortex-health.py supervisor."""

import json
import os
import subprocess
import sys
import tempfile

import pytest

SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'cortex')
HEALTH_SCRIPT = os.path.join(SCRIPTS_DIR, 'cortex-health.py')


class TestHealthReport:
    def test_produces_output(self):
        result = subprocess.run(
            [sys.executable, HEALTH_SCRIPT],
            capture_output=True, text=True, timeout=10)
        assert result.returncode == 0
        assert '# Cortex Health Report' in result.stdout
        assert '## Inventory' in result.stdout
        assert '## Coherence' in result.stdout

    def test_json_output(self):
        result = subprocess.run(
            [sys.executable, HEALTH_SCRIPT, '--json'],
            capture_output=True, text=True, timeout=10)
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert 'inventory' in report
        assert 'coherence' in report
        assert 'pipeline' in report
        assert 'total_issues' in report

    def test_inventory_counts(self):
        result = subprocess.run(
            [sys.executable, HEALTH_SCRIPT, '--json'],
            capture_output=True, text=True, timeout=10)
        report = json.loads(result.stdout)
        inv = report['inventory']
        assert inv['hooks'] >= 13
        assert inv['scripts'] >= 3
        assert inv['skills'] >= 10

    def test_coherence_checks_present(self):
        result = subprocess.run(
            [sys.executable, HEALTH_SCRIPT, '--json'],
            capture_output=True, text=True, timeout=10)
        report = json.loads(result.stdout)
        checks = report['coherence']
        assert 'Artifact existence' in checks
        assert 'Gate monotonicity' in checks
        assert 'State file sync' in checks
        assert 'Embedding freshness' in checks
        assert 'Archive completeness' in checks
        assert 'Contract deliverables' in checks


class TestCoherenceChecks:
    def test_artifact_existence_passes(self):
        result = subprocess.run(
            [sys.executable, '-c', '''
import importlib.util, json
spec = importlib.util.spec_from_file_location("health", "scripts/cortex/cortex-health.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

state = json.load(open(".cortex/state.json"))
issues = mod.check_artifact_existence(state)
# Current artifacts should exist
for a in state.get("artifacts", []):
    assert a not in [i for i in issues], f"Unexpected missing: {a}"
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'

    def test_gate_monotonicity_catches_violation(self):
        result = subprocess.run(
            [sys.executable, '-c', '''
import importlib.util
spec = importlib.util.spec_from_file_location("health", "scripts/cortex/cortex-health.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# Craft a bad state
bad = {"gates": {"clarify_complete": False, "research_complete": True}}
issues = mod.check_gate_monotonicity(bad)
assert len(issues) == 1
assert "research_complete without clarify_complete" in issues[0]
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'

    def test_gate_monotonicity_passes_good_state(self):
        result = subprocess.run(
            [sys.executable, '-c', '''
import importlib.util
spec = importlib.util.spec_from_file_location("health", "scripts/cortex/cortex-health.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

good = {"gates": {"clarify_complete": True, "research_complete": True, "spec_complete": True, "contract_approved": True}}
issues = mod.check_gate_monotonicity(good)
assert len(issues) == 0
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'


class TestEventLog:
    def test_events_logged(self):
        """Supervisor.jsonl should have events from instrumented hooks."""
        log_path = '.cortex/supervisor.jsonl'
        assert os.path.exists(log_path), 'No supervisor.jsonl found'
        events = [json.loads(l) for l in open(log_path) if l.strip()]
        assert len(events) > 0, 'No events in supervisor.jsonl'
        # Every event should have required fields
        for e in events:
            assert 'ts' in e
            assert 'event' in e
            assert 'hook' in e

    def test_event_structure(self):
        """Events should have ts, event, hook, slug, mode."""
        log_path = '.cortex/supervisor.jsonl'
        events = [json.loads(l) for l in open(log_path) if l.strip()]
        for e in events:
            assert isinstance(e['ts'], str)
            assert len(e['ts']) > 0
            assert e['event'] in ('hook_fire', 'hook_error', 'state_transition', 'gate_eval')


class TestLogRotation:
    def test_rotation_skips_small_file(self, tmp_path):
        result = subprocess.run(
            [sys.executable, '-c', f'''
import importlib.util, os
spec = importlib.util.spec_from_file_location("health", "scripts/cortex/cortex-health.py")
mod = importlib.util.module_from_spec(spec)
mod.SUPERVISOR_LOG = str("{tmp_path}/test.jsonl")
spec.loader.exec_module(mod)
mod.SUPERVISOR_LOG = str("{tmp_path}/test.jsonl")

# Create small log
with open(mod.SUPERVISOR_LOG, "w") as f:
    for i in range(100):
        f.write('{{"ts":"test","event":"test"}}\\n')

rotated = mod.rotate_log()
assert not rotated
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'
