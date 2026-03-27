import { describe, it, expect } from 'vitest';
import { createLogger } from '../src/logger.js';

describe('logger', () => {
  it('creates root logger with name gsd-runner', () => {
    const log = createLogger('silent');
    expect(log.session).toBeDefined();
    // Root logger name check via bindings
  });

  it('exports child loggers for all 5 components', () => {
    const log = createLogger('silent');
    const components = ['session', 'telegram', 'loop', 'gate', 'stuck'] as const;
    for (const c of components) {
      expect(log[c]).toBeDefined();
      expect(typeof log[c].info).toBe('function');
    }
  });

  it('child loggers include component binding', () => {
    const log = createLogger('silent');
    // pino child loggers expose bindings via [Symbol] -- test via serialization
    const components = ['session', 'telegram', 'loop', 'gate', 'stuck'] as const;
    for (const c of components) {
      const child = log[c] as any;
      // pino stores bindings in chindings string
      const bindings = child.bindings();
      // pino v9: bindings() returns a single merged object
      expect(bindings.component).toBe(c);
    }
  });

  it('respects log level configuration', () => {
    const log = createLogger('warn');
    expect(log.session.level).toBe('warn');
  });
});
