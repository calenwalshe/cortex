#!/usr/bin/env python3
"""Tests for the necessity gate in /cortex-spec.

Tests the necessity attack prompt against known ground-truth cases
to verify it produces correct BUILD/NARROW/DEFER/REJECT verdicts.
"""

import json
import os
import re
import sys
import urllib.request

import pytest

ANTHROPIC_API_KEY = os.environ.get('ANTHROPIC_API_KEY')
MODEL = 'claude-haiku-4-5-20251001'
API_URL = 'https://api.anthropic.com/v1/messages'

NECESSITY_PROMPT = """You are an adversarial necessity reviewer. Your job is to determine whether a proposed piece of work should exist at all.

Read the clarify brief and research dossier below. Try to prove ONE of these four things:
1. REJECT: This solves a problem that doesn't actually exist, or the "problem" is already handled by the existing system
2. NARROW: The scope is too broad — a smaller version would deliver the same value
3. DEFER: There isn't enough evidence yet — more research is needed before committing
4. BUILD: This is a real problem with a viable solution that should proceed to spec

Be adversarial. The default should be skepticism, not approval. Ask yourself:
- Who actually has this problem? Is it the human user, or is the system solving its own problem?
- Does the existing system already handle this adequately, even if imperfectly?
- Would a human notice if this didn't exist?
- Is this a "solution looking for a problem"?
- Could the same value be achieved with a simpler approach that doesn't require a new tool?

CLARIFY BRIEF:
\"\"\"
{clarify}
\"\"\"

RESEARCH FINDINGS:
\"\"\"
{research}
\"\"\"

KEY CONTEXT:
{context}

Respond with EXACTLY this JSON format:
{{"verdict": "BUILD|NARROW|DEFER|REJECT", "confidence": 0.0-1.0, "reasoning": "2-3 sentences", "evidence": ["point 1", "point 2", "point 3"]}}"""


def call_necessity_check(clarify, research, context):
    """Call the necessity check and return parsed verdict."""
    if not ANTHROPIC_API_KEY:
        pytest.skip('ANTHROPIC_API_KEY not set')

    prompt = NECESSITY_PROMPT.format(clarify=clarify, research=research, context=context)

    data = json.dumps({
        'model': MODEL,
        'max_tokens': 300,
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
    }).encode()

    req = urllib.request.Request(API_URL, data=data, headers={
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
    })

    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())

    text = result['content'][0]['text'].strip()
    text = re.sub(r'^```json\s*\n?', '', text)
    text = re.sub(r'\n?\s*```.*$', '', text)
    # Find outermost JSON
    depth = 0
    start_idx = None
    for i, ch in enumerate(text):
        if ch == '{':
            if depth == 0:
                start_idx = i
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0 and start_idx is not None:
                text = text[start_idx:i+1]
                break

    return json.loads(text)


class TestNecessityGate:
    def test_rejects_verifier_harness(self):
        """The gate that would have saved us from building a useless tool."""
        verdict = call_necessity_check(
            clarify='Slug: verifier-harness. Goal: A single cortex-verify.py run <slug> command reads a validators.json manifest from the contract directory, executes all validators, and produces a structured pass/fail report.',
            research='Audited 14 contracts: only 3 have typed validators (21 total). Parser prototype correctly extracts all 21 validators. External validator execution tested: 6/6 pass, 17s total.',
            context='The validators are written by the AI assistant during /cortex-spec, not by the human user. The AI also runs the validators during execution — it has the contract open and copy-pastes them. The entire validator lifecycle is already automated by the AI within a single session.')
        assert verdict['verdict'] == 'REJECT'
        assert verdict['confidence'] >= 0.7

    def test_approves_semantic_retrieval(self):
        """Real problem with proven solution should BUILD."""
        verdict = call_necessity_check(
            clarify='Slug: semantic-retrieval. Goal: Any Cortex hook or skill can query the fact store with a natural language question and get back the top-K most relevant facts in <2 seconds.',
            research='Currently 53 facts loaded exhaustively every session. Two-phase architecture works: embed async at compaction, retrieve via numpy (<79ms). ollama nomic-embed-text available, 768-dim.',
            context='The fact store will grow over time. Currently ALL facts are loaded into context at session start. Token costs are a real concern.')
        assert verdict['verdict'] == 'BUILD'
        assert verdict['confidence'] >= 0.7

    def test_approves_execution_supervisor(self):
        """Real observability gap should BUILD."""
        verdict = call_necessity_check(
            clarify='Slug: execution-supervisor. Goal: A supervision layer that observes Cortex operations and maintains a structured log for human review.',
            research='13 hooks with zero observability. Hooks exit silently on error. State transitions not logged. JSONL append <2ms overhead. Health report prototype runs in <100ms.',
            context='The human user explicitly said they are concerned about system complexity and need to check if things are working correctly.')
        assert verdict['verdict'] == 'BUILD'
        assert verdict['confidence'] >= 0.7

    def test_narrows_bloated_scope(self):
        """Over-engineered scope should NARROW."""
        verdict = call_necessity_check(
            clarify='Slug: full-observability-platform. Goal: Build a complete observability platform with real-time dashboard, alerting, anomaly detection, analytics, and automated remediation.',
            research='Current system has 13 hooks with no logging. Token-ledger.db exists with cost data. No dashboards or alerting exist.',
            context='The system has 13 hooks and 3 scripts. The human checks logs infrequently (daily or weekly). There are no external users.')
        assert verdict['verdict'] == 'NARROW'
        assert verdict['confidence'] >= 0.7

    def test_verdict_has_required_fields(self):
        """Every verdict must include confidence, reasoning, and evidence."""
        verdict = call_necessity_check(
            clarify='Slug: test-slug. Goal: Test the verdict format.',
            research='No research conducted.',
            context='This is a test case for field validation.')
        assert 'verdict' in verdict
        assert verdict['verdict'] in ('BUILD', 'NARROW', 'DEFER', 'REJECT')
        assert 'confidence' in verdict
        assert isinstance(verdict['confidence'], (int, float))
        assert 'reasoning' in verdict
        assert isinstance(verdict['reasoning'], str)
        assert 'evidence' in verdict
        assert isinstance(verdict['evidence'], list)


class TestAutonomyConfig:
    def test_necessity_gate_in_supervised_preset(self):
        """Necessity gate should be true in supervised preset."""
        result = os.popen('node -e "const m = require(\'./scripts/cortex/resolve-autonomy.js\'); const r = m.resolveAutonomy({}); console.log(JSON.stringify(r.gates.necessity))"').read().strip()
        assert result == 'true'

    def test_necessity_gate_in_full_auto_preset(self):
        """Necessity gate should be false in full-auto preset."""
        result = os.popen('node -e "const m = require(\'./scripts/cortex/resolve-autonomy.js\'); const r = m.resolveAutonomy({invocationFlags:{preset:\'full-auto\'}}); console.log(JSON.stringify(r.gates.necessity))"').read().strip()
        assert result == 'false'

    def test_necessity_gate_overridable(self):
        """Necessity gate should be overridable via invocation flags."""
        result = os.popen('node -e "const m = require(\'./scripts/cortex/resolve-autonomy.js\'); const r = m.resolveAutonomy({invocationFlags:{gates:{necessity:false}}}); console.log(JSON.stringify(r.gates.necessity))"').read().strip()
        assert result == 'false'
