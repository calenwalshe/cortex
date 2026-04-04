#!/usr/bin/env python3
"""cortex-judge.py — LLM judge for [judgment] contract validators.

Usage:
  cortex-judge.py run <slug>                    Score all [judgment] validators
  cortex-judge.py correct <slug> <index> <field>=<value> --reason "..."
                                                 Record human correction

Scores validators against rubrics via Claude Haiku 4.5.
Calibration corrections feed back as few-shot examples.
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
import subprocess
import urllib.request
import urllib.error

PROJECT_DIR = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())
CORTEX_DIR = os.path.join(PROJECT_DIR, '.cortex')
CALIBRATION_DIR = os.path.expanduser('~/.cortex/calibration')
RUBRICS_DIR = os.path.join(PROJECT_DIR, 'docs', 'cortex', 'rubrics')
EVALS_DIR = os.path.join(PROJECT_DIR, 'docs', 'cortex', 'evals')
CONTRACTS_DIR = os.path.join(PROJECT_DIR, 'docs', 'cortex', 'contracts')

API_URL = 'https://api.anthropic.com/v1/messages'
MODEL = os.environ.get('CORTEX_JUDGE_MODEL', 'claude-haiku-4-5-20251001')
CONFIDENCE_THRESHOLD = 0.7


# ── Rubric Parser ────────────────────────────────────────────────────────────

def parse_rubric(filepath):
    """Parse YAML frontmatter from .rubric.md file."""
    with open(filepath, 'r') as f:
        content = f.read()

    # Extract YAML frontmatter between --- delimiters
    match = re.match(r'^---\n(.*?)\n---\n?(.*)', content, re.DOTALL)
    if not match:
        return None

    yaml_text = match.group(1)
    body = match.group(2).strip()

    rubric = {'_body': body, '_raw_yaml': yaml_text}

    # Simple YAML parser for our specific format
    rubric['validator'] = _yaml_value(yaml_text, 'validator')
    rubric['pass_threshold'] = int(_yaml_value(yaml_text, 'pass_threshold') or '3')
    rubric['max_score'] = int(_yaml_value(yaml_text, 'max_score') or '6')
    rubric['confidence_threshold'] = float(
        _yaml_value(yaml_text, 'confidence_threshold') or str(CONFIDENCE_THRESHOLD))

    # Parse criteria
    rubric['criteria'] = _parse_criteria(yaml_text)

    return rubric


def _yaml_value(text, key):
    """Extract a simple scalar value from YAML text."""
    match = re.search(rf'^{key}:\s*["\']?(.*?)["\']?\s*$', text, re.MULTILINE)
    return match.group(1) if match else None


def _parse_criteria(yaml_text):
    """Parse criteria list from YAML."""
    criteria = []
    # Find criteria block
    in_criteria = False
    current = None
    in_levels = False

    for line in yaml_text.split('\n'):
        if line.strip() == 'criteria:':
            in_criteria = True
            continue
        if not in_criteria:
            continue
        # New top-level key ends criteria
        if re.match(r'^[a-z]', line) and ':' in line:
            break

        if re.match(r'^\s+- name:', line):
            if current:
                criteria.append(current)
            name = line.split('name:')[1].strip().strip('"\'')
            current = {'name': name, 'range': [0, 3], 'levels': {}}
            in_levels = False
        elif current and 'range:' in line:
            nums = re.findall(r'\d+', line)
            if len(nums) >= 2:
                current['range'] = [int(nums[0]), int(nums[1])]
        elif current and line.strip() == 'levels:':
            in_levels = True
        elif current and in_levels and re.match(r'^\s+\d+:', line):
            parts = line.strip().split(':', 1)
            level = int(parts[0].strip())
            desc = parts[1].strip().strip('"\'')
            current['levels'][level] = desc

    if current:
        criteria.append(current)

    return criteria


def rubric_hash(rubric):
    """Hash rubric content for calibration keying."""
    content = rubric.get('validator', '') + json.dumps(rubric.get('criteria', []), sort_keys=True)
    return hashlib.md5(content.encode()).hexdigest()[:8]


# ── Contract Parser ──────────────────────────────────────────────────────────

def find_contract(slug):
    """Find the active contract for a slug."""
    contract_dir = os.path.join(CONTRACTS_DIR, slug)
    if not os.path.isdir(contract_dir):
        return None
    files = sorted([f for f in os.listdir(contract_dir) if f.startswith('contract-')])
    if not files:
        return None
    return os.path.join(contract_dir, files[-1])


def extract_judgment_validators(contract_path):
    """Extract [judgment] validators from a contract file."""
    with open(contract_path, 'r') as f:
        content = f.read()

    validators = []
    in_validators = False
    for line in content.split('\n'):
        if line.strip() == '## Validators':
            in_validators = True
            continue
        if in_validators and line.startswith('## '):
            break
        if in_validators and '[judgment]' in line:
            text = re.sub(r'^-\s*\[.\]\s*\[judgment\]\s*', '', line.strip())
            validators.append(text)

    return validators


# ── Rubric Loader ────────────────────────────────────────────────────────────

def find_rubric(slug, validator_text):
    """Find a rubric file matching the validator, or return None."""
    rubric_dir = os.path.join(RUBRICS_DIR, slug)
    if not os.path.isdir(rubric_dir):
        return None

    for fname in os.listdir(rubric_dir):
        if not fname.endswith('.rubric.md'):
            continue
        rubric = parse_rubric(os.path.join(rubric_dir, fname))
        if rubric and rubric.get('validator', '').lower() in validator_text.lower():
            return rubric
        if rubric and validator_text.lower() in rubric.get('validator', '').lower():
            return rubric

    return None


def generate_default_rubric(validator_text):
    """Generate a default rubric from validator text."""
    return {
        'validator': validator_text,
        'criteria': [
            {'name': 'quality', 'range': [0, 3],
             'levels': {0: 'Fails completely', 1: 'Partially meets', 2: 'Mostly meets', 3: 'Fully meets'}},
            {'name': 'clarity', 'range': [0, 2],
             'levels': {0: 'Unclear', 1: 'Somewhat clear', 2: 'Clear and actionable'}},
        ],
        'pass_threshold': 3,
        'max_score': 5,
        'confidence_threshold': CONFIDENCE_THRESHOLD,
        '_body': '',
        '_default': True,
    }


# ── Calibration ──────────────────────────────────────────────────────────────

def load_calibration(rhash):
    """Load calibration examples for a rubric hash."""
    path = os.path.join(CALIBRATION_DIR, f'{rhash}.jsonl')
    examples = []
    try:
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    examples.append(json.loads(line))
    except FileNotFoundError:
        pass
    return examples[-10:]  # Last 10 corrections max


def save_calibration(rhash, entry):
    """Append a calibration entry."""
    os.makedirs(CALIBRATION_DIR, exist_ok=True)
    path = os.path.join(CALIBRATION_DIR, f'{rhash}.jsonl')
    with open(path, 'a') as f:
        f.write(json.dumps(entry) + '\n')


def format_calibration_context(examples):
    """Format calibration examples as few-shot context."""
    if not examples:
        return ''

    lines = ['\nCALIBRATION EXAMPLES (human-corrected — learn from these):']
    for ex in examples:
        judge = ex.get('judge_output', {})
        human = ex.get('human_correction', {})
        reason = ex.get('human_reasoning', '')
        lines.append(f'- Judge scored {json.dumps(judge)}, human corrected to {json.dumps(human)}.')
        if reason:
            lines.append(f'  Reason: "{reason}"')
    lines.append('')
    return '\n'.join(lines)


# ── Judge Core ───────────────────────────────────────────────────────────────

def collect_validator_evidence(validator_text):
    """Collect evidence for a judgment validator by running related commands."""
    evidence = []

    # For retrieval relevance validators, run a sample query
    if 'relevant' in validator_text.lower() and 'retriev' in validator_text.lower():
        try:
            result = subprocess.run(
                [sys.executable, os.path.join(PROJECT_DIR, 'scripts', 'cortex', 'cortex-retrieve.py'),
                 'hook performance budget', '--top-k', '3'],
                capture_output=True, text=True, timeout=10,
                env={**os.environ, 'CORTEX_DIR': CORTEX_DIR})
            if result.returncode == 0:
                evidence.append(f'Sample retrieval (query="hook performance budget"):\n{result.stdout}')
        except Exception:
            pass

    # For degradation validators, test with bad ollama URL
    if 'degradation' in validator_text.lower() or 'warning' in validator_text.lower():
        try:
            result = subprocess.run(
                [sys.executable, os.path.join(PROJECT_DIR, 'scripts', 'cortex', 'cortex-retrieve.py'),
                 'test query', '--top-k', '3'],
                capture_output=True, text=True, timeout=10,
                env={**os.environ, 'CORTEX_DIR': CORTEX_DIR,
                     'OLLAMA_URL': 'http://localhost:99999'})
            evidence.append(f'Degradation test (ollama unreachable):\nstdout: {result.stdout[:200]}\nstderr: {result.stderr}')
        except Exception:
            pass

    return '\n\n'.join(evidence) if evidence else '(No automated evidence collected)'


def build_judge_prompt(validator_text, rubric, evidence, calibration_ctx=''):
    """Build the judge prompt from rubric, evidence, and calibration context."""
    criteria_text = []
    for c in rubric['criteria']:
        levels_text = ', '.join(f'{k}: "{v}"' for k, v in sorted(c['levels'].items()))
        criteria_text.append(f"- {c['name']} ({c['range'][0]}-{c['range'][1]}): {levels_text}")

    prompt = f"""You are a code quality judge. Score the following validator based on the evidence provided.

VALIDATOR: "{validator_text}"

EVIDENCE:
{evidence}

RUBRIC CRITERIA:
{chr(10).join(criteria_text)}

Pass threshold: {rubric['pass_threshold']} out of {rubric['max_score']}
{calibration_ctx}
Respond ONLY with JSON (no markdown fences, no extra text):
{{"scores": {{{", ".join(f'"{c["name"]}": <integer {c["range"][0]}-{c["range"][1]}>' for c in rubric["criteria"])}}}, "total": <integer sum of scores>, "pass": <boolean true if total >= {rubric['pass_threshold']}>, "confidence": <float 0.0-1.0>, "reasoning": "<one sentence>"}}"""

    return prompt


def call_judge(prompt):
    """Call Claude Haiku to judge."""
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        print('ERROR: ANTHROPIC_API_KEY not set. Export it to use cortex-judge.', file=sys.stderr)
        sys.exit(1)

    data = json.dumps({
        'model': MODEL,
        'max_tokens': 300,
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
    }).encode()

    req = urllib.request.Request(API_URL, data=data, headers={
        'Content-Type': 'application/json',
        'x-api-key': api_key,
        'anthropic-version': '2023-06-01',
    })

    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())

    text = result['content'][0]['text'].strip()
    # Strip markdown code fences if present
    text = re.sub(r'^```json\s*\n?', '', text)
    text = re.sub(r'\n?\s*```$', '', text)
    # Find outermost JSON object (handles nested braces)
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

    return json.loads(text), result['usage']


# ── Commands ─────────────────────────────────────────────────────────────────

def cmd_run(slug):
    """Run judge on all [judgment] validators for a slug."""
    contract_path = find_contract(slug)
    if not contract_path:
        print(f'ERROR: No contract found for slug "{slug}"', file=sys.stderr)
        sys.exit(1)

    validators = extract_judgment_validators(contract_path)
    if not validators:
        print(f'No [judgment] validators found in {contract_path}', file=sys.stderr)
        return

    print(f'Judging {len(validators)} [judgment] validator(s) from {contract_path}',
          file=sys.stderr)

    results = []
    total_cost = 0.0

    for i, validator_text in enumerate(validators):
        rubric = find_rubric(slug, validator_text)
        is_default = False
        if not rubric:
            rubric = generate_default_rubric(validator_text)
            is_default = True
            print(f'  [{i+1}] WARNING: No rubric file found, using default rubric',
                  file=sys.stderr)

        rhash = rubric_hash(rubric)
        cal_examples = load_calibration(rhash)
        cal_ctx = format_calibration_context(cal_examples)

        print(f'  [{i+1}] Collecting evidence...', file=sys.stderr)
        evidence = collect_validator_evidence(validator_text)
        prompt = build_judge_prompt(validator_text, rubric, evidence, cal_ctx)

        start = time.time()
        verdict, usage = call_judge(prompt)
        elapsed = time.time() - start

        cost = usage['input_tokens'] * 0.80 / 1_000_000 + usage['output_tokens'] * 4.00 / 1_000_000
        total_cost += cost

        confidence = verdict.get('confidence', 0.0)
        threshold = rubric.get('confidence_threshold', CONFIDENCE_THRESHOLD)

        if confidence >= threshold:
            status = 'PASS' if verdict.get('pass') else 'FAIL'
        else:
            status = 'FLAG'

        result = {
            'index': i,
            'validator': validator_text,
            'verdict': verdict,
            'status': status,
            'rubric_hash': rhash,
            'default_rubric': is_default,
            'calibration_examples': len(cal_examples),
            'latency_ms': int(elapsed * 1000),
            'cost': round(cost, 5),
        }
        results.append(result)

        print(f'  [{i+1}] {status} (confidence={confidence:.2f}, '
              f'{elapsed:.1f}s, ${cost:.4f}) — {validator_text[:60]}',
              file=sys.stderr)

    # Write judge report
    report_dir = os.path.join(EVALS_DIR, slug)
    os.makedirs(report_dir, exist_ok=True)
    report_path = os.path.join(report_dir, 'judge-report.md')
    write_report(slug, contract_path, results, total_cost, report_path)

    # Output JSON to stdout
    json.dump(results, sys.stdout, indent=2)
    print()

    print(f'\nReport: {report_path}', file=sys.stderr)
    print(f'Total cost: ${total_cost:.4f}', file=sys.stderr)


def write_report(slug, contract_path, results, total_cost, report_path):
    """Write judge-report.md."""
    ts = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    lines = [
        f'# Judge Report: {slug}',
        '',
        f'**Generated:** {ts}',
        f'**Contract:** {contract_path}',
        f'**Model:** {MODEL}',
        f'**Total cost:** ${total_cost:.4f}',
        '',
        '---',
        '',
        '## Results',
        '',
    ]

    for r in results:
        v = r['verdict']
        lines.append(f'### [{r["index"]+1}] {r["status"]}: {r["validator"]}')
        lines.append('')
        lines.append(f'- **Scores:** {json.dumps(v.get("scores", {}))}')
        lines.append(f'- **Total:** {v.get("total", "?")} / pass threshold')
        lines.append(f'- **Pass:** {v.get("pass", "?")}')
        lines.append(f'- **Confidence:** {v.get("confidence", "?")}')
        lines.append(f'- **Status:** {r["status"]}')
        lines.append(f'- **Reasoning:** {v.get("reasoning", "N/A")}')
        if r['default_rubric']:
            lines.append(f'- **WARNING:** Default rubric used (no .rubric.md file found)')
        if r['calibration_examples'] > 0:
            lines.append(f'- **Calibration:** {r["calibration_examples"]} examples loaded')
        lines.append(f'- **Latency:** {r["latency_ms"]}ms | **Cost:** ${r["cost"]:.4f}')
        lines.append('')

    lines.append('---')
    lines.append('')
    lines.append('## Summary')
    lines.append('')
    passed = sum(1 for r in results if r['status'] == 'PASS')
    failed = sum(1 for r in results if r['status'] == 'FAIL')
    flagged = sum(1 for r in results if r['status'] == 'FLAG')
    lines.append(f'- **PASS:** {passed}')
    lines.append(f'- **FAIL:** {failed}')
    lines.append(f'- **FLAG (needs human review):** {flagged}')
    lines.append(f'- **Total cost:** ${total_cost:.4f}')
    lines.append('')

    with open(report_path, 'w') as f:
        f.write('\n'.join(lines))


def cmd_correct(slug, index, corrections, reason):
    """Record a human correction for calibration."""
    contract_path = find_contract(slug)
    if not contract_path:
        print(f'ERROR: No contract found for slug "{slug}"', file=sys.stderr)
        sys.exit(1)

    validators = extract_judgment_validators(contract_path)
    if index >= len(validators):
        print(f'ERROR: Validator index {index} out of range (0-{len(validators)-1})',
              file=sys.stderr)
        sys.exit(1)

    validator_text = validators[index]
    rubric = find_rubric(slug, validator_text) or generate_default_rubric(validator_text)
    rhash = rubric_hash(rubric)

    entry = {
        'timestamp': time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()),
        'rubric_hash': rhash,
        'validator': validator_text,
        'human_correction': corrections,
        'human_reasoning': reason,
        'project': os.path.basename(PROJECT_DIR),
        'slug': slug,
    }

    save_calibration(rhash, entry)
    print(f'Calibration saved to ~/.cortex/calibration/{rhash}.jsonl', file=sys.stderr)
    json.dump(entry, sys.stdout, indent=2)
    print()


# ── CLI ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Cortex LLM Judge')
    subparsers = parser.add_subparsers(dest='command')

    run_parser = subparsers.add_parser('run', help='Judge [judgment] validators')
    run_parser.add_argument('slug', help='Contract slug')

    correct_parser = subparsers.add_parser('correct', help='Record human correction')
    correct_parser.add_argument('slug', help='Contract slug')
    correct_parser.add_argument('index', type=int, help='Validator index (0-based)')
    correct_parser.add_argument('corrections', nargs='+', help='field=value pairs')
    correct_parser.add_argument('--reason', required=True, help='Why the correction was made')

    args = parser.parse_args()

    if args.command == 'run':
        cmd_run(args.slug)
    elif args.command == 'correct':
        corrections = {}
        for c in args.corrections:
            k, v = c.split('=', 1)
            try:
                v = json.loads(v)
            except (json.JSONDecodeError, ValueError):
                pass
            corrections[k] = v
        cmd_correct(args.slug, args.index, corrections, args.reason)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
