#!/usr/bin/env python3
"""cortex-retrieve.py — Semantic fact retrieval via pre-computed embeddings.

Usage: cortex-retrieve.py <query> [--top-k N] [--threshold T]

Loads .cortex/fact-embeddings.npy, embeds query via ollama, computes cosine
similarity, returns top-K facts as JSON on stdout.

Graceful degradation: falls back to loading all facts when ollama is
unreachable or embeddings are missing.
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

import numpy as np

CORTEX_DIR = os.environ.get('CORTEX_DIR', os.path.join(
    os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd()), '.cortex'))

FACTS_PATH = os.path.join(CORTEX_DIR, 'facts.jsonl')
EMBEDDINGS_PATH = os.path.join(CORTEX_DIR, 'fact-embeddings.npy')
INDEX_PATH = os.path.join(CORTEX_DIR, 'fact-index.json')

OLLAMA_URL = os.environ.get('OLLAMA_URL', 'http://localhost:11434')
MODEL = 'nomic-embed-text'


def load_facts():
    """Load all facts from facts.jsonl."""
    facts = []
    try:
        with open(FACTS_PATH, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    facts.append(json.loads(line))
    except FileNotFoundError:
        pass
    return facts


def fallback_all_facts(reason):
    """Return all facts without scoring (degraded mode)."""
    print(f'[cortex-retrieve] WARNING: {reason} — returning all facts unranked',
          file=sys.stderr)
    facts = load_facts()
    return [{'id': f['id'], 'text': f['text'], 'score': 0.0} for f in facts]


def embed_query(query):
    """Embed a single query via ollama /api/embed."""
    data = json.dumps({'model': MODEL, 'input': query}).encode()
    req = urllib.request.Request(
        f'{OLLAMA_URL}/api/embed',
        data=data,
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
    return np.array(result['embeddings'][0], dtype=np.float32)


def retrieve(query, top_k=5, threshold=0.0):
    """Retrieve top-K facts by cosine similarity to query."""
    # Check embeddings exist
    if not os.path.exists(EMBEDDINGS_PATH):
        return fallback_all_facts(f'{EMBEDDINGS_PATH} not found')

    if not os.path.exists(FACTS_PATH):
        return []

    # Load pre-computed embeddings
    embeddings = np.load(EMBEDDINGS_PATH)
    facts = load_facts()

    if embeddings.shape[0] == 0 or len(facts) == 0:
        return []

    # If embedding count doesn't match facts, use min of both
    usable = min(embeddings.shape[0], len(facts))
    embeddings = embeddings[:usable]
    facts = facts[:usable]

    # Embed query via ollama
    try:
        query_vec = embed_query(query)
    except (urllib.error.URLError, ConnectionError, OSError):
        return fallback_all_facts('ollama unreachable')
    except Exception as e:
        return fallback_all_facts(f'query embedding failed: {e}')

    # Cosine similarity
    norms = np.linalg.norm(embeddings, axis=1)
    query_norm = np.linalg.norm(query_vec)
    similarities = np.dot(embeddings, query_vec) / (norms * query_norm + 1e-10)

    # Rank and filter
    ranked_indices = np.argsort(similarities)[::-1]
    results = []
    for idx in ranked_indices[:top_k]:
        score = float(similarities[idx])
        if score < threshold:
            break
        fact = facts[idx]
        results.append({
            'id': fact['id'],
            'text': fact['text'],
            'score': round(score, 4),
        })

    return results


def main():
    parser = argparse.ArgumentParser(description='Semantic fact retrieval')
    parser.add_argument('query', help='Natural language query')
    parser.add_argument('--top-k', type=int, default=5, help='Number of results (default: 5)')
    parser.add_argument('--threshold', type=float, default=0.0,
                        help='Minimum similarity score (default: 0.0)')
    parser.add_argument('--format', choices=['json', 'text'], default='json',
                        help='Output format (default: json)')
    args = parser.parse_args()

    results = retrieve(args.query, top_k=args.top_k, threshold=args.threshold)

    if args.format == 'text':
        for r in results:
            print(f"- {r['text']}")
    else:
        json.dump(results, sys.stdout, indent=2)
        print()


if __name__ == '__main__':
    main()
