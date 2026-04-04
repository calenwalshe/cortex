#!/usr/bin/env python3
"""cortex-health.py — On-demand health report for Cortex operations.

Usage: cortex-health.py [--json] [--rotate]

Runs 6 coherence checks, summarizes the event log, and reports pipeline status.
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import time
from collections import Counter
from datetime import datetime, timedelta

PROJECT_DIR = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())
CORTEX_DIR = os.path.join(PROJECT_DIR, '.cortex')
SUPERVISOR_LOG = os.path.join(CORTEX_DIR, 'supervisor.jsonl')
STATE_JSON = os.path.join(CORTEX_DIR, 'state.json')
CURRENT_STATE = os.path.join(PROJECT_DIR, 'docs', 'cortex', 'handoffs', 'current-state.md')
DECISIONS_MD = os.path.join(PROJECT_DIR, 'docs', 'cortex', 'handoffs', 'decisions.md')
FACTS_PATH = os.path.join(CORTEX_DIR, 'facts.jsonl')
META_PATH = os.path.join(CORTEX_DIR, 'fact-embeddings.meta.json')
ARCHIVE_DIR = os.path.join(PROJECT_DIR, 'docs', 'cortex', 'archive')
TOKEN_LEDGER = os.path.expanduser('~/.cortex/token-ledger.db')

MAX_LOG_LINES = 10000


# ── Coherence Checks ────────────────────────────────────────────────────────

def check_artifact_existence(state):
    """Every path in state.json artifacts[] must exist on disk."""
    issues = []
    for a in state.get('artifacts', []):
        if not os.path.exists(a):
            issues.append(f'Missing artifact: {a}')
    return issues


def check_gate_monotonicity(state):
    """Gates must advance in order: clarify -> research -> spec -> contract."""
    issues = []
    gates = state.get('gates', {})
    if gates.get('research_complete') and not gates.get('clarify_complete'):
        issues.append('Gate violation: research_complete without clarify_complete')
    if gates.get('spec_complete') and not gates.get('research_complete'):
        issues.append('Gate violation: spec_complete without research_complete')
    if gates.get('contract_approved') and not gates.get('spec_complete'):
        issues.append('Gate violation: contract_approved without spec_complete')
    return issues


def check_state_sync(state):
    """state.json slug must match current-state.md slug."""
    issues = []
    try:
        with open(CURRENT_STATE) as f:
            content = f.read()
        m = re.search(r'\*\*slug:\*\*\s*(.*)', content)
        if m:
            cs_slug = m.group(1).strip()
            sj_slug = str(state['slug']) if state.get('slug') else '(none)'
            if cs_slug != sj_slug and not (cs_slug == '(none)' and state.get('slug') is None):
                issues.append(f'State drift: state.json slug={sj_slug}, current-state.md slug={cs_slug}')
    except FileNotFoundError:
        pass
    return issues


def check_embedding_freshness(state):
    """Embedded fact count must match facts.jsonl line count."""
    issues = []
    try:
        facts_count = sum(1 for line in open(FACTS_PATH) if line.strip())
        meta = json.load(open(META_PATH))
        embedded = meta.get('last_embedded_count', 0)
        if embedded < facts_count:
            issues.append(f'Stale embeddings: {embedded} embedded vs {facts_count} facts')
    except FileNotFoundError:
        pass
    return issues


def check_archive_completeness():
    """Every dir in archive/ must have a decisions.md entry."""
    issues = []
    try:
        decisions = open(DECISIONS_MD).read()
        for slug in os.listdir(ARCHIVE_DIR):
            if os.path.isdir(os.path.join(ARCHIVE_DIR, slug)):
                if slug not in decisions:
                    issues.append(f'Archive entry missing from decisions.md: {slug}')
    except FileNotFoundError:
        pass
    return issues


def check_contract_deliverables(state):
    """Active contract deliverables should exist on disk."""
    issues = []
    contract_path = state.get('active_contract')
    if not contract_path or not os.path.exists(contract_path):
        return issues

    try:
        with open(contract_path) as f:
            content = f.read()
        in_deliverables = False
        for line in content.split('\n'):
            if line.strip() == '## Deliverables':
                in_deliverables = True
                continue
            if in_deliverables and line.startswith('## '):
                break
            if in_deliverables and line.strip().startswith('- `'):
                m = re.match(r'- `([^`]+)`', line.strip())
                if m:
                    fpath = m.group(1)
                    # Skip glob patterns and home-relative paths
                    if '*' in fpath or '~' in fpath:
                        continue
                    if not os.path.exists(fpath):
                        issues.append(f'Missing deliverable: {fpath}')
    except Exception:
        pass
    return issues


def run_all_checks(state):
    """Run all 6 coherence checks, return list of (name, issues)."""
    return [
        ('Artifact existence', check_artifact_existence(state)),
        ('Gate monotonicity', check_gate_monotonicity(state)),
        ('State file sync', check_state_sync(state)),
        ('Embedding freshness', check_embedding_freshness(state)),
        ('Archive completeness', check_archive_completeness()),
        ('Contract deliverables', check_contract_deliverables(state)),
    ]


# ── Event Log ────────────────────────────────────────────────────────────────

def load_events(since_hours=24):
    """Load events from supervisor.jsonl within the time window."""
    events = []
    if not os.path.exists(SUPERVISOR_LOG):
        return events

    from datetime import timezone
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=since_hours)).strftime('%Y%m%dT%H%M%SZ')
    with open(SUPERVISOR_LOG) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
                if event.get('ts', '') >= cutoff:
                    events.append(event)
            except json.JSONDecodeError:
                continue
    return events


def summarize_events(events):
    """Summarize events into counts by type and hook."""
    by_type = Counter(e.get('event', 'unknown') for e in events)
    by_hook = Counter(e.get('hook', 'unknown') for e in events)
    errors = [e for e in events if e.get('event') == 'hook_error']
    transitions = [e for e in events if e.get('event') == 'state_transition']
    return by_type, by_hook, errors, transitions


# ── Token Ledger Activity ────────────────────────────────────────────────────

def get_recent_activity():
    """Get recent activity from token-ledger.db."""
    if not os.path.exists(TOKEN_LEDGER):
        return []
    try:
        result = subprocess.run(['node', '-e', '''
const Database = require("better-sqlite3");
const db = new Database(process.argv[1], {readonly: true});
const rows = db.prepare(
    "SELECT date, SUM(cost_usd) as cost, SUM(turn_count) as turns FROM daily_rollup GROUP BY date ORDER BY date DESC LIMIT 7"
).all();
console.log(JSON.stringify(rows));
db.close();
''', TOKEN_LEDGER], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return json.loads(result.stdout)
    except Exception:
        pass
    return []


# ── Inventory ────────────────────────────────────────────────────────────────

def get_inventory():
    """Count system components."""
    hooks = glob.glob(os.path.join(PROJECT_DIR, '.claude', 'hooks', 'cortex-*'))
    scripts = glob.glob(os.path.join(PROJECT_DIR, 'scripts', 'cortex', 'cortex-*.py'))
    skills = [d for d in glob.glob(os.path.join(PROJECT_DIR, 'skills', 'cortex-*/'))
              if os.path.isdir(d)]
    archives = []
    try:
        archives = [d for d in os.listdir(ARCHIVE_DIR)
                    if os.path.isdir(os.path.join(ARCHIVE_DIR, d))]
    except FileNotFoundError:
        pass

    return {
        'hooks': len(hooks),
        'scripts': len(scripts),
        'skills': len(skills),
        'archived_slugs': len(archives),
    }


# ── Log Rotation ─────────────────────────────────────────────────────────────

def rotate_log():
    """Rotate supervisor.jsonl if it exceeds MAX_LOG_LINES."""
    if not os.path.exists(SUPERVISOR_LOG):
        return False

    line_count = sum(1 for _ in open(SUPERVISOR_LOG))
    if line_count <= MAX_LOG_LINES:
        return False

    backup = SUPERVISOR_LOG + '.1'
    if os.path.exists(backup):
        os.remove(backup)
    os.rename(SUPERVISOR_LOG, backup)
    print(f'[cortex-health] Rotated supervisor.jsonl ({line_count} lines -> .1)', file=sys.stderr)
    return True


# ── Report ───────────────────────────────────────────────────────────────────

def generate_report(as_json=False):
    """Generate the full health report."""
    ts = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())

    # Load state
    try:
        state = json.load(open(STATE_JSON))
    except (FileNotFoundError, json.JSONDecodeError):
        state = {}

    # Run checks
    checks = run_all_checks(state)
    total_issues = sum(len(issues) for _, issues in checks)

    # Events
    events = load_events(since_hours=24)
    by_type, by_hook, errors, transitions = summarize_events(events)

    # Activity
    activity = get_recent_activity()

    # Inventory
    inventory = get_inventory()

    if as_json:
        report = {
            'timestamp': ts,
            'inventory': inventory,
            'coherence': {name: {'pass': len(issues) == 0, 'issues': issues}
                         for name, issues in checks},
            'total_issues': total_issues,
            'events_24h': {
                'total': len(events),
                'by_type': dict(by_type),
                'errors': errors,
                'transitions': transitions,
            },
            'activity': activity,
            'pipeline': {
                'slug': state.get('slug'),
                'mode': state.get('mode'),
                'gates': state.get('gates', {}),
                'contract': state.get('active_contract'),
            },
        }
        json.dump(report, sys.stdout, indent=2)
        print()
        return

    # Markdown report
    lines = [
        f'# Cortex Health Report',
        f'**Generated:** {ts}',
        '',
        f'## Inventory',
        f'- Hooks: {inventory["hooks"]}',
        f'- Scripts: {inventory["scripts"]}',
        f'- Skills: {inventory["skills"]}',
        f'- Archived slugs: {inventory["archived_slugs"]}',
        '',
        f'## Coherence ({total_issues} issue{"s" if total_issues != 1 else ""})',
    ]

    for name, issues in checks:
        if issues:
            lines.append(f'- **{name}:** FAIL')
            for issue in issues:
                lines.append(f'  - {issue}')
        else:
            lines.append(f'- **{name}:** OK')

    lines.extend(['', '## Event Log (last 24h)'])
    if events:
        lines.append(f'- Total events: {len(events)}')
        for event_type, count in by_type.most_common():
            lines.append(f'- {event_type}: {count}')
        if errors:
            lines.append(f'- **Errors ({len(errors)}):**')
            for e in errors[-5:]:
                lines.append(f'  - [{e.get("ts", "?")}] {e.get("hook", "?")} — {e.get("error", "?")}')
        if transitions:
            lines.append(f'- **State transitions ({len(transitions)}):**')
            for t in transitions[-5:]:
                lines.append(f'  - [{t.get("ts", "?")}] {t.get("from_mode", "?")} -> {t.get("to_mode", "?")}')
    else:
        lines.append('- No events recorded (supervisor.jsonl empty or missing)')

    lines.extend(['', '## Recent Activity'])
    if activity:
        for row in activity:
            lines.append(f'- {row["date"]} | {row["turns"]} turns | ${row["cost"]:.2f}')
    else:
        lines.append('- Token ledger unavailable')

    lines.extend([
        '',
        '## Pipeline Status',
        f'- Active slug: {state.get("slug") or "(none)"}',
        f'- Mode: {state.get("mode", "unknown")}',
        f'- Gates: {json.dumps(state.get("gates", {}))}',
        f'- Contract: {state.get("active_contract") or "(none)"}',
        '',
    ])

    print('\n'.join(lines))


def main():
    parser = argparse.ArgumentParser(description='Cortex Health Report')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--rotate', action='store_true', help='Rotate log if oversized')
    args = parser.parse_args()

    if args.rotate:
        rotate_log()

    generate_report(as_json=args.json)


if __name__ == '__main__':
    main()
