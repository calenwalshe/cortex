import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, copyFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { determineNextAction } from '../src/state-machine.js';

const FIXTURES = join(import.meta.dirname, 'fixtures');

function readFixture(name: string): string {
  return readFileSync(join(FIXTURES, name), 'utf-8');
}

describe('determineNextAction', () => {
  let tempDir: string;
  let planningDir: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), 'gsd-test-'));
    planningDir = join(tempDir, '.planning');
    mkdirSync(planningDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  function writeState(fixtureName: string): void {
    writeFileSync(join(planningDir, 'STATE.md'), readFixture(fixtureName));
  }

  function writeRoadmap(fixtureName: string): void {
    writeFileSync(join(planningDir, 'ROADMAP.md'), readFixture(fixtureName));
  }

  function writeContinueHere(): void {
    copyFileSync(
      join(FIXTURES, 'continue-here-sample.md'),
      join(planningDir, '.continue-here.md'),
    );
  }

  it('returns plan action when phase has no plans', () => {
    writeState('state-ready-to-plan.md');
    writeRoadmap('roadmap-partial.md');

    const action = determineNextAction(tempDir);
    expect(action).toEqual({ type: 'plan', phase: 2 });
  });

  it('returns execute action when plans exist but incomplete', () => {
    writeState('state-executing.md');
    writeRoadmap('roadmap-partial.md');

    const action = determineNextAction(tempDir);
    expect(action).toEqual({ type: 'execute', phase: 1 });
  });

  it('returns verify action when all plans complete', () => {
    // Create a custom state where plans complete = plans in phase
    const verifyState = `# Project State

## Current Position

Phase: 1 of 2 (Core Engine)
Plan: 3 of 3 in current phase
Status: All plans complete
Last activity: 2026-03-09

Progress: [########--] 80%
`;
    writeFileSync(join(planningDir, 'STATE.md'), verifyState);
    writeRoadmap('roadmap-partial.md');

    const action = determineNextAction(tempDir);
    expect(action).toEqual({ type: 'verify', phase: 1 });
  });

  it('returns resume when .continue-here.md exists', () => {
    writeState('state-resume.md');
    writeRoadmap('roadmap-partial.md');
    writeContinueHere();

    const action = determineNextAction(tempDir);
    expect(action).toEqual({ type: 'resume' });
  });

  it('returns done when all phases complete', () => {
    writeState('state-executing.md');
    writeRoadmap('roadmap-all-complete.md');

    const action = determineNextAction(tempDir);
    expect(action).toEqual({ type: 'done' });
  });

  it('returns error for missing STATE.md', () => {
    // Empty planning dir -- no STATE.md
    const action = determineNextAction(tempDir);
    expect(action.type).toBe('error');
    if (action.type === 'error') {
      expect(action.reason).toContain('STATE.md');
    }
  });

  it('resume takes priority over other actions', () => {
    // Even with all-complete roadmap, continue-here should win
    writeState('state-executing.md');
    writeRoadmap('roadmap-all-complete.md');
    writeContinueHere();

    const action = determineNextAction(tempDir);
    expect(action).toEqual({ type: 'resume' });
  });
});
