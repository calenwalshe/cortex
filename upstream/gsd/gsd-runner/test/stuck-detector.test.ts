import { describe, it, expect } from 'vitest';
import { StuckDetector } from '../src/stuck-detector.js';

describe('StuckDetector', () => {
  const defaultConfig = { windowSize: 10, threshold: 3, readOnlyMultiplier: 2 };

  it('returns false when tool calls are diverse', () => {
    const sd = new StuckDetector(defaultConfig);
    expect(sd.record('Edit', '{"file":"a.ts"}')).toBe(false);
    expect(sd.record('Write', '{"file":"b.ts"}')).toBe(false);
    expect(sd.record('Bash', '{"cmd":"ls"}')).toBe(false);
  });

  it('returns true when same tool+args appears >= threshold times', () => {
    const sd = new StuckDetector(defaultConfig);
    expect(sd.record('Edit', '{"file":"a.ts"}')).toBe(false);
    expect(sd.record('Edit', '{"file":"a.ts"}')).toBe(false);
    expect(sd.record('Edit', '{"file":"a.ts"}')).toBe(true); // 3rd = threshold
  });

  it('read-only tools require higher threshold (2x)', () => {
    const sd = new StuckDetector(defaultConfig);
    // Read is read-only, threshold = 3 * 2 = 6
    for (let i = 0; i < 5; i++) {
      expect(sd.record('Read', '{"file":"x.ts"}')).toBe(false);
    }
    expect(sd.record('Read', '{"file":"x.ts"}')).toBe(true); // 6th hit
  });

  it('Glob and Grep are also read-only', () => {
    const sd = new StuckDetector(defaultConfig);
    for (let i = 0; i < 5; i++) {
      expect(sd.record('Glob', '{"pattern":"*"}')).toBe(false);
    }
    expect(sd.record('Glob', '{"pattern":"*"}')).toBe(true);
  });

  it('reset() clears the window', () => {
    const sd = new StuckDetector(defaultConfig);
    sd.record('Edit', '{"file":"a.ts"}');
    sd.record('Edit', '{"file":"a.ts"}');
    sd.reset();
    // After reset, count restarts
    expect(sd.record('Edit', '{"file":"a.ts"}')).toBe(false);
  });

  it('window evicts oldest entries when full', () => {
    const sd = new StuckDetector({ windowSize: 4, threshold: 3, readOnlyMultiplier: 2 });
    sd.record('Edit', '{"file":"a.ts"}'); // slot 0
    sd.record('Edit', '{"file":"a.ts"}'); // slot 1
    // Fill with different calls to push old ones out
    sd.record('Write', '{"file":"b.ts"}'); // slot 2
    sd.record('Bash', '{"cmd":"ls"}');     // slot 3 -- window full, next evicts slot 0
    sd.record('Write', '{"file":"c.ts"}'); // evicts first Edit
    // Now only 1 Edit remains in window
    expect(sd.record('Edit', '{"file":"a.ts"}')).toBe(false); // count = 2, not 3
  });
});
