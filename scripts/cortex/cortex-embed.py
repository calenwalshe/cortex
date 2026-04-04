#!/usr/bin/env python3
"""cortex-embed.py — Batch-embed facts.jsonl via ollama nomic-embed-text.

Reads .cortex/facts.jsonl, embeds all facts (or only new ones if incremental),
writes .cortex/fact-embeddings.npy + fact-index.json + fact-embeddings.meta.json.

Called by async PostCompact hook. Exits 0 on all errors (never blocks compaction).
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error

import numpy as np

CORTEX_DIR = os.environ.get('CORTEX_DIR', os.path.join(
    os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd()), '.cortex'))

FACTS_PATH = os.path.join(CORTEX_DIR, 'facts.jsonl')
EMBEDDINGS_PATH = os.path.join(CORTEX_DIR, 'fact-embeddings.npy')
INDEX_PATH = os.path.join(CORTEX_DIR, 'fact-index.json')
META_PATH = os.path.join(CORTEX_DIR, 'fact-embeddings.meta.json')

OLLAMA_URL = os.environ.get('OLLAMA_URL', 'http://localhost:11434')
MODEL = 'nomic-embed-text'
EMBED_DIM = 768


def load_facts():
    """Load all facts from facts.jsonl."""
    facts = []
    with open(FACTS_PATH, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                facts.append(json.loads(line))
    return facts


def load_meta():
    """Load embedding metadata, or return defaults."""
    try:
        with open(META_PATH, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {'last_embedded_count': 0, 'model': MODEL, 'timestamp': None}


def embed_texts(texts):
    """Embed a list of texts via ollama /api/embed (batch)."""
    data = json.dumps({'model': MODEL, 'input': texts}).encode()
    req = urllib.request.Request(
        f'{OLLAMA_URL}/api/embed',
        data=data,
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())
    return result['embeddings']


def main():
    if not os.path.exists(FACTS_PATH):
        print('[cortex-embed] No facts.jsonl found, skipping', file=sys.stderr)
        return

    facts = load_facts()
    if not facts:
        print('[cortex-embed] facts.jsonl is empty, skipping', file=sys.stderr)
        return

    meta = load_meta()
    total_facts = len(facts)
    last_count = meta.get('last_embedded_count', 0)

    # Load existing embeddings if doing incremental
    existing_embeddings = None
    if last_count > 0 and last_count <= total_facts and os.path.exists(EMBEDDINGS_PATH):
        try:
            existing_embeddings = np.load(EMBEDDINGS_PATH)
            if existing_embeddings.shape[0] != last_count:
                existing_embeddings = None
                last_count = 0
        except Exception:
            existing_embeddings = None
            last_count = 0

    if last_count >= total_facts and existing_embeddings is not None:
        print(f'[cortex-embed] All {total_facts} facts already embedded, skipping', file=sys.stderr)
        return

    # Determine which facts to embed
    if existing_embeddings is not None and last_count > 0:
        new_facts = facts[last_count:]
        print(f'[cortex-embed] Incremental: embedding {len(new_facts)} new facts '
              f'(total: {total_facts})', file=sys.stderr)
    else:
        new_facts = facts
        existing_embeddings = None
        print(f'[cortex-embed] Full embed: {total_facts} facts', file=sys.stderr)

    # Embed new facts
    texts = [f['text'] for f in new_facts]
    start = time.time()
    new_embeddings_list = embed_texts(texts)
    elapsed = time.time() - start
    print(f'[cortex-embed] Embedded {len(texts)} facts in {elapsed:.2f}s '
          f'({len(texts)/elapsed:.1f} facts/sec)', file=sys.stderr)

    new_embeddings = np.array(new_embeddings_list, dtype=np.float32)

    # Combine with existing if incremental
    if existing_embeddings is not None:
        all_embeddings = np.vstack([existing_embeddings, new_embeddings])
    else:
        all_embeddings = new_embeddings

    # Build index: fact_id -> row index
    index = {fact['id']: i for i, fact in enumerate(facts)}

    # Write outputs
    np.save(EMBEDDINGS_PATH, all_embeddings)

    with open(INDEX_PATH, 'w') as f:
        json.dump(index, f, indent=2)

    meta = {
        'last_embedded_count': total_facts,
        'model': MODEL,
        'timestamp': time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()),
        'dimensions': EMBED_DIM,
        'embedding_time_seconds': round(elapsed, 2),
    }
    with open(META_PATH, 'w') as f:
        json.dump(meta, f, indent=2)

    print(f'[cortex-embed] Wrote {all_embeddings.shape[0]}x{all_embeddings.shape[1]} '
          f'embeddings to {EMBEDDINGS_PATH}', file=sys.stderr)


if __name__ == '__main__':
    try:
        main()
    except urllib.error.URLError as e:
        print(f'[cortex-embed] ollama unreachable ({e}), skipping embedding', file=sys.stderr)
    except Exception as e:
        print(f'[cortex-embed] Error (non-fatal): {e}', file=sys.stderr)
    sys.exit(0)
