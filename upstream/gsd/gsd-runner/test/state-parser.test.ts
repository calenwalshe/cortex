import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseStateFile, parseRoadmapFile } from '../src/state-parser.js';

const FIXTURES = join(import.meta.dirname, 'fixtures');

function readFixture(name: string): string {
  return readFileSync(join(FIXTURES, name), 'utf-8');
}

describe('parseStateFile', () => {
  it('parses valid STATE.md with phase and plan info', () => {
    const result = parseStateFile(readFixture('state-planning.md'));
    expect(result.currentPhase).toBe(1);
    expect(result.totalPhases).toBe(2);
    expect(result.plansInPhase).toBe(3);
    expect(result.plansComplete).toBe(0);
    expect(result.status).toBe('Ready to plan');
  });

  it('parses STATE.md with different statuses', () => {
    const result = parseStateFile(readFixture('state-executing.md'));
    expect(result.currentPhase).toBe(1);
    expect(result.totalPhases).toBe(2);
    expect(result.plansInPhase).toBe(3);
    expect(result.plansComplete).toBe(2);
    expect(result.status).toBe('Executing plan 02');
  });

  it('returns defaults for empty string', () => {
    const result = parseStateFile('');
    expect(result.currentPhase).toBe(0);
    expect(result.totalPhases).toBe(0);
    expect(result.plansInPhase).toBe(0);
    expect(result.plansComplete).toBe(0);
    expect(result.status).toBe('unknown');
  });

  it('returns defaults for malformed input', () => {
    const result = parseStateFile('This is not a valid STATE.md file\nJust random text.');
    expect(result.currentPhase).toBe(0);
    expect(result.totalPhases).toBe(0);
    expect(result.status).toBe('unknown');
  });
});

describe('parseRoadmapFile', () => {
  it('parses roadmap with mixed complete/incomplete phases', () => {
    const result = parseRoadmapFile(readFixture('roadmap-partial.md'));
    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({ number: 1, name: 'Core Engine', complete: true });
    expect(result[1]).toEqual({ number: 2, name: 'Telegram and Observability', complete: false });
  });

  it('parses roadmap with all phases complete', () => {
    const result = parseRoadmapFile(readFixture('roadmap-all-complete.md'));
    expect(result).toHaveLength(2);
    expect(result.every((p) => p.complete)).toBe(true);
  });

  it('returns empty array for malformed roadmap', () => {
    const result = parseRoadmapFile(readFixture('roadmap-malformed.md'));
    expect(result).toEqual([]);
  });
});
