import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { RunnerConfig } from '../src/types.js';

// Mock the Agent SDK before importing session-runner
const mockQuery = vi.fn();
vi.mock('@anthropic-ai/claude-agent-sdk', () => ({
  query: mockQuery,
}));

// Import after mock setup
const { runGsdCommand } = await import('../src/session-runner.js');
const { loadConfig } = await import('../src/config.js');

// Helper: create an async generator that yields a sequence of SDK messages
async function* mockMessageStream(messages: Record<string, unknown>[]) {
  for (const msg of messages) {
    yield msg;
  }
}

function makeInitMessage(sessionId = 'test-session-123') {
  return {
    type: 'system',
    subtype: 'init',
    session_id: sessionId,
    uuid: 'uuid-init',
    apiKeySource: 'env',
    claude_code_version: '1.0.0',
    cwd: '/tmp',
    tools: [],
    mcp_servers: [],
  };
}

function makeCompactBoundaryMessage() {
  return {
    type: 'system',
    subtype: 'compact_boundary',
    compact_metadata: { trigger: 'auto', pre_tokens: 100000, post_tokens: 50000 },
    uuid: 'uuid-compact',
    session_id: 'test-session-123',
  };
}

function makeResultMessage(
  subtype: 'success' | 'error_max_turns' = 'success',
  opts: { totalCost?: number; sessionId?: string } = {},
) {
  const base = {
    type: 'result',
    subtype,
    duration_ms: 5000,
    duration_api_ms: 4000,
    is_error: subtype !== 'success',
    num_turns: 10,
    total_cost_usd: opts.totalCost ?? 0.25,
    usage: { input_tokens: 1000, output_tokens: 500, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 },
    modelUsage: {},
    permission_denials: [],
    uuid: 'uuid-result',
    session_id: opts.sessionId ?? 'test-session-123',
  };
  if (subtype === 'success') {
    return { ...base, result: 'Done', stop_reason: 'end_turn' };
  }
  return base;
}

function defaultConfig(overrides: Partial<RunnerConfig> = {}): RunnerConfig {
  return {
    projectDir: '/tmp/test-project',
    maxTurns: 75,
    maxBudgetUsd: 5.0,
    compactionThreshold: 2,
    ...overrides,
  };
}

describe('loadConfig', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  it('throws if PROJECT_DIR is not set', () => {
    delete process.env.PROJECT_DIR;
    expect(() => loadConfig()).toThrow(/PROJECT_DIR/);
  });

  it('reads PROJECT_DIR from environment', () => {
    process.env.PROJECT_DIR = '/my/project';
    const config = loadConfig();
    expect(config.projectDir).toBe('/my/project');
  });

  it('uses default maxTurns=75 when not set', () => {
    process.env.PROJECT_DIR = '/my/project';
    const config = loadConfig();
    expect(config.maxTurns).toBe(75);
  });

  it('uses default maxBudgetUsd=5 when not set', () => {
    process.env.PROJECT_DIR = '/my/project';
    const config = loadConfig();
    expect(config.maxBudgetUsd).toBe(5.0);
  });

  it('uses default compactionThreshold=2 when not set', () => {
    process.env.PROJECT_DIR = '/my/project';
    const config = loadConfig();
    expect(config.compactionThreshold).toBe(2);
  });

  it('reads MAX_TURNS from environment', () => {
    process.env.PROJECT_DIR = '/my/project';
    process.env.MAX_TURNS = '100';
    const config = loadConfig();
    expect(config.maxTurns).toBe(100);
  });

  it('reads MAX_BUDGET_USD from environment', () => {
    process.env.PROJECT_DIR = '/my/project';
    process.env.MAX_BUDGET_USD = '10.5';
    const config = loadConfig();
    expect(config.maxBudgetUsd).toBe(10.5);
  });

  it('reads COMPACTION_THRESHOLD from environment', () => {
    process.env.PROJECT_DIR = '/my/project';
    process.env.COMPACTION_THRESHOLD = '3';
    const config = loadConfig();
    expect(config.compactionThreshold).toBe(3);
  });
});

describe('runGsdCommand', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  it('calls query with correct maxTurns from config', async () => {
    const config = defaultConfig({ maxTurns: 50 });
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage(),
    ]));

    await runGsdCommand('test prompt', config, new AbortController());

    expect(mockQuery).toHaveBeenCalledOnce();
    const callArgs = mockQuery.mock.calls[0][0];
    expect(callArgs.options.maxTurns).toBe(50);
  });

  it('sets permissionMode to bypassPermissions', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage(),
    ]));

    await runGsdCommand('test', defaultConfig(), new AbortController());

    const callArgs = mockQuery.mock.calls[0][0];
    expect(callArgs.options.permissionMode).toBe('bypassPermissions');
    expect(callArgs.options.allowDangerouslySkipPermissions).toBe(true);
  });

  it('sets settingSources to [\'project\']', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage(),
    ]));

    await runGsdCommand('test', defaultConfig(), new AbortController());

    const callArgs = mockQuery.mock.calls[0][0];
    expect(callArgs.options.settingSources).toEqual(['project']);
  });

  it('passes abortController to query options', async () => {
    const controller = new AbortController();
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage(),
    ]));

    await runGsdCommand('test', defaultConfig(), controller);

    const callArgs = mockQuery.mock.calls[0][0];
    expect(callArgs.options.abortController).toBe(controller);
  });

  it('captures session ID from init message', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage('my-session-42'),
      makeResultMessage('success', { sessionId: 'my-session-42' }),
    ]));

    const result = await runGsdCommand('test', defaultConfig(), new AbortController());
    expect(result.sessionId).toBe('my-session-42');
  });

  it('counts compaction events', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeCompactBoundaryMessage(),
      makeCompactBoundaryMessage(),
      makeResultMessage(),
    ]));

    const result = await runGsdCommand('test', defaultConfig(), new AbortController());
    expect(result.compactionCount).toBe(2);
  });

  it('sets thresholdHit when compaction count >= threshold', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeCompactBoundaryMessage(),
      makeCompactBoundaryMessage(),
      makeCompactBoundaryMessage(),
      makeResultMessage(),
    ]));

    const result = await runGsdCommand('test', defaultConfig({ compactionThreshold: 2 }), new AbortController());
    expect(result.thresholdHit).toBe(true);
  });

  it('thresholdHit false when below threshold', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeCompactBoundaryMessage(),
      makeResultMessage(),
    ]));

    const result = await runGsdCommand('test', defaultConfig({ compactionThreshold: 2 }), new AbortController());
    expect(result.thresholdHit).toBe(false);
  });

  it('returns success=true for successful result', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage('success'),
    ]));

    const result = await runGsdCommand('test', defaultConfig(), new AbortController());
    expect(result.success).toBe(true);
    expect(result.resultSubtype).toBe('success');
  });

  it('returns success=false for max_turns result', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage('error_max_turns'),
    ]));

    const result = await runGsdCommand('test', defaultConfig(), new AbortController());
    expect(result.success).toBe(false);
    expect(result.resultSubtype).toBe('error_max_turns');
  });

  it('throws when stream ends without result', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
    ]));

    await expect(runGsdCommand('test', defaultConfig(), new AbortController()))
      .rejects.toThrow(/result/i);
  });

  it('extracts cost from result message', async () => {
    mockQuery.mockReturnValue(mockMessageStream([
      makeInitMessage(),
      makeResultMessage('success', { totalCost: 1.75 }),
    ]));

    const result = await runGsdCommand('test', defaultConfig(), new AbortController());
    expect(result.costUsd).toBe(1.75);
  });
});
