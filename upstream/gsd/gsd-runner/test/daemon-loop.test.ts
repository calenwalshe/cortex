import { describe, it, expect, vi, beforeEach } from 'vitest';
import { runLoop, actionToPrompt, _resetShutdownState } from '../src/index.js';
import type { GsdAction, RunnerConfig } from '../src/types.js';
import type { SessionResult } from '../src/session-runner.js';

const baseConfig: RunnerConfig = {
  projectDir: '/tmp/test-project',
  maxTurns: 75,
  maxBudgetUsd: 5,
  compactionThreshold: 2,
  logLevel: 'silent',
  stuckDetector: { windowSize: 20, threshold: 5, readOnlyMultiplier: 2 },
};

function makeResult(overrides: Partial<SessionResult> = {}): SessionResult {
  return {
    success: true,
    sessionId: 'test-session',
    compactionCount: 0,
    thresholdHit: false,
    costUsd: 0.5,
    resultSubtype: 'success',
    stuck: false,
    ...overrides,
  };
}

describe('actionToPrompt', () => {
  it('maps plan action to /gsd:plan-phase N', () => {
    expect(actionToPrompt({ type: 'plan', phase: 1 })).toBe('/gsd:plan-phase 1');
  });

  it('maps execute action to /gsd:execute-phase N', () => {
    expect(actionToPrompt({ type: 'execute', phase: 3 })).toBe('/gsd:execute-phase 3');
  });

  it('maps verify action to /gsd:verify-work', () => {
    expect(actionToPrompt({ type: 'verify', phase: 2 })).toBe('/gsd:verify-work');
  });

  it('maps resume action to /gsd:resume-work', () => {
    expect(actionToPrompt({ type: 'resume' })).toBe('/gsd:resume-work');
  });

  it('throws on done action', () => {
    expect(() => actionToPrompt({ type: 'done' })).toThrow();
  });

  it('throws on error action', () => {
    expect(() => actionToPrompt({ type: 'error', reason: 'test' })).toThrow();
  });
});

describe('runLoop', () => {
  let actions: GsdAction[];
  let results: SessionResult[];
  let mockDetermineNextAction: ReturnType<typeof vi.fn>;
  let mockRunGsdCommand: ReturnType<typeof vi.fn>;
  let mockRunCheckpoint: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    _resetShutdownState();
    actions = [];
    results = [];
    mockDetermineNextAction = vi.fn(() => actions.shift()!);
    mockRunGsdCommand = vi.fn(() => Promise.resolve(results.shift() ?? makeResult()));
    mockRunCheckpoint = vi.fn(() => Promise.resolve());
  });

  function deps() {
    return {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: mockRunGsdCommand,
      runCheckpoint: mockRunCheckpoint,
    };
  }

  it('full cycle: plan -> execute -> verify -> done', async () => {
    actions = [
      { type: 'plan', phase: 1 },
      { type: 'execute', phase: 1 },
      { type: 'verify', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult(), makeResult(), makeResult()];

    await runLoop(baseConfig, deps());

    expect(mockRunGsdCommand).toHaveBeenCalledTimes(3);
    expect(mockRunGsdCommand.mock.calls[0][0]).toBe('/gsd:plan-phase 1');
    expect(mockRunGsdCommand.mock.calls[1][0]).toBe('/gsd:execute-phase 1');
    expect(mockRunGsdCommand.mock.calls[2][0]).toBe('/gsd:verify-work');
  });

  it('runs checkpoint when compaction threshold hit', async () => {
    actions = [
      { type: 'execute', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult({ thresholdHit: true })];

    await runLoop(baseConfig, deps());

    expect(mockRunCheckpoint).toHaveBeenCalledTimes(1);
    expect(mockRunGsdCommand).toHaveBeenCalledTimes(1);
  });

  it('re-reads disk state after each session (N+1 calls for N sessions)', async () => {
    actions = [
      { type: 'execute', phase: 1 },
      { type: 'execute', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult(), makeResult()];

    await runLoop(baseConfig, deps());

    // 2 sessions + final done check = 3 calls
    expect(mockDetermineNextAction).toHaveBeenCalledTimes(3);
  });

  it('exits on done action without calling runGsdCommand', async () => {
    actions = [{ type: 'done' }];

    await runLoop(baseConfig, deps());

    expect(mockRunGsdCommand).not.toHaveBeenCalled();
  });

  it('throws on error action', async () => {
    actions = [{ type: 'error', reason: 'test error' }];

    await expect(runLoop(baseConfig, deps())).rejects.toThrow('test error');
    expect(mockRunGsdCommand).not.toHaveBeenCalled();
  });

  it('runs checkpoint on shutdown flag', async () => {
    actions = [
      { type: 'execute', phase: 1 },
      { type: 'done' },
    ];

    let setShutdown: (() => void) | undefined;
    await runLoop(baseConfig, {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: vi.fn(async () => {
        // Trigger shutdown after session completes
        if (setShutdown) setShutdown();
        return makeResult();
      }),
      runCheckpoint: mockRunCheckpoint,
    }, (fn: () => void) => { setShutdown = fn; });

    expect(mockRunCheckpoint).toHaveBeenCalledTimes(1);
  });
});

describe('runLoop with Telegram', () => {
  let actions: GsdAction[];
  let results: SessionResult[];
  let mockDetermineNextAction: ReturnType<typeof vi.fn>;
  let mockRunGsdCommand: ReturnType<typeof vi.fn>;
  let mockRunCheckpoint: ReturnType<typeof vi.fn>;
  let mockTelegram: {
    requestGateApproval: ReturnType<typeof vi.fn>;
    sendProgress: ReturnType<typeof vi.fn>;
    sendAlert: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    _resetShutdownState();
    actions = [];
    results = [];
    mockDetermineNextAction = vi.fn(() => actions.shift()!);
    mockRunGsdCommand = vi.fn(() => Promise.resolve(results.shift() ?? makeResult()));
    mockRunCheckpoint = vi.fn(() => Promise.resolve());
    mockTelegram = {
      requestGateApproval: vi.fn(() => Promise.resolve(true)),
      sendProgress: vi.fn(() => Promise.resolve()),
      sendAlert: vi.fn(() => Promise.resolve()),
    };
  });

  it('gate approval at verify step continues loop', async () => {
    actions = [
      { type: 'verify', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult()];
    mockTelegram.requestGateApproval.mockResolvedValue(true);

    await runLoop(baseConfig, {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: mockRunGsdCommand,
      runCheckpoint: mockRunCheckpoint,
      telegram: mockTelegram as any,
    });

    expect(mockTelegram.requestGateApproval).toHaveBeenCalledTimes(1);
    expect(mockRunGsdCommand).toHaveBeenCalledTimes(1);
    expect(mockRunGsdCommand.mock.calls[0][0]).toBe('/gsd:verify-work');
  });

  it('gate rejection at verify step halts loop', async () => {
    actions = [
      { type: 'verify', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult()];
    mockTelegram.requestGateApproval.mockResolvedValue(false);

    await runLoop(baseConfig, {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: mockRunGsdCommand,
      runCheckpoint: mockRunCheckpoint,
      telegram: mockTelegram as any,
    });

    expect(mockTelegram.requestGateApproval).toHaveBeenCalledTimes(1);
    // Should NOT have run the command because gate was rejected
    expect(mockRunGsdCommand).not.toHaveBeenCalled();
  });

  it('stuck detection aborts and sends alert', async () => {
    actions = [
      { type: 'execute', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult({ stuck: true, success: false, resultSubtype: 'stuck' })];

    await runLoop(baseConfig, {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: mockRunGsdCommand,
      runCheckpoint: mockRunCheckpoint,
      telegram: mockTelegram as any,
    });

    expect(mockTelegram.sendAlert).toHaveBeenCalledTimes(1);
    expect(mockTelegram.sendAlert.mock.calls[0][0]).toMatch(/stuck/i);
    // Loop should exit after stuck detection
    expect(mockDetermineNextAction).toHaveBeenCalledTimes(1);
  });

  it('Telegram is optional -- loop works without it', async () => {
    actions = [
      { type: 'execute', phase: 1 },
      { type: 'verify', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult(), makeResult()];

    // No telegram in deps
    await runLoop(baseConfig, {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: mockRunGsdCommand,
      runCheckpoint: mockRunCheckpoint,
    });

    // Should complete normally without errors
    expect(mockRunGsdCommand).toHaveBeenCalledTimes(2);
  });

  it('sends progress notifications at action start and completion', async () => {
    actions = [
      { type: 'execute', phase: 1 },
      { type: 'done' },
    ];
    results = [makeResult({ costUsd: 1.23 })];

    await runLoop(baseConfig, {
      determineNextAction: mockDetermineNextAction,
      runGsdCommand: mockRunGsdCommand,
      runCheckpoint: mockRunCheckpoint,
      telegram: mockTelegram as any,
    });

    expect(mockTelegram.sendProgress).toHaveBeenCalledTimes(2);
    expect(mockTelegram.sendProgress.mock.calls[0][0]).toMatch(/Starting/);
    expect(mockTelegram.sendProgress.mock.calls[1][0]).toMatch(/Completed/);
  });
});
