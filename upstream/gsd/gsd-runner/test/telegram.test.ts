import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { TelegramConfig } from '../src/types.js';

// --- grammY mock ---
const sendMessageMock = vi.fn().mockResolvedValue({ message_id: 1 });
const editMessageReplyMarkupMock = vi.fn().mockResolvedValue(true);
const answerCallbackQueryMock = vi.fn().mockResolvedValue(true);

type Handler = (ctx: Record<string, unknown>) => Promise<void>;
const registeredHandlers: { pattern: unknown; handler: Handler }[] = [];
let errorHandler: ((err: unknown) => void) | undefined;

const mockBot = {
  api: {
    sendMessage: sendMessageMock,
    editMessageReplyMarkup: editMessageReplyMarkupMock,
  },
  callbackQuery: vi.fn((pattern: unknown, handler: Handler) => {
    registeredHandlers.push({ pattern, handler });
  }),
  on: vi.fn((event: string, handler: Handler) => {
    registeredHandlers.push({ pattern: event, handler });
  }),
  start: vi.fn(),
  stop: vi.fn().mockResolvedValue(undefined),
  catch: vi.fn((handler: (err: unknown) => void) => {
    errorHandler = handler;
  }),
};

vi.mock('grammy', () => ({
  Bot: vi.fn(() => mockBot),
  InlineKeyboard: vi.fn().mockImplementation(() => {
    const kb = { _buttons: [] as { text: string; data: string }[] };
    kb.text = vi.fn((text: string, data: string) => {
      kb._buttons.push({ text, data });
      return kb;
    });
    return kb as unknown;
  }),
}));

// Import after mock
const { TelegramBot } = await import('../src/telegram.js');

const defaultConfig: TelegramConfig = {
  botToken: 'test-token',
  chatId: 12345,
  gateTimeoutMs: 500, // short for tests
  heartbeatIntervalMs: 100,
};

describe('TelegramBot', () => {
  let bot: InstanceType<typeof TelegramBot>;

  beforeEach(() => {
    vi.clearAllMocks();
    registeredHandlers.length = 0;
    bot = new TelegramBot(defaultConfig);
  });

  afterEach(async () => {
    bot.stopHeartbeat();
  });

  describe('gate controller', () => {
    function findGateHandler(): Handler | undefined {
      const entry = registeredHandlers.find(
        (h) => h.pattern instanceof RegExp,
      );
      return entry?.handler;
    }

    function makeCbCtx(data: string) {
      const match = data.match(/^gate:(approve|reject):(\d+)$/);
      return {
        match: match!,
        answerCallbackQuery: answerCallbackQueryMock,
        editMessageReplyMarkup: editMessageReplyMarkupMock,
      };
    }

    it('sends gate notification with inline keyboard', async () => {
      const promise = bot.requestGateApproval('Approve phase?');
      // Let the sendMessage call happen
      await vi.waitFor(() => expect(sendMessageMock).toHaveBeenCalled());
      expect(sendMessageMock).toHaveBeenCalledWith(
        12345,
        'Approve phase?',
        expect.objectContaining({ parse_mode: 'HTML' }),
      );
      // Simulate approval to resolve the promise
      const handler = findGateHandler()!;
      const gateId = sendMessageMock.mock.calls[0]?.[2]?.reply_markup?._buttons?.[0]?.data?.match(/\d+$/)?.[0];
      if (gateId) {
        await handler(makeCbCtx(`gate:approve:${gateId}`));
      }
      // Clean up
      try { await promise; } catch { /* timeout ok */ }
    });

    it('resolves true when approved', async () => {
      const promise = bot.requestGateApproval('Approve?');
      await vi.waitFor(() => expect(sendMessageMock).toHaveBeenCalled());

      const handler = findGateHandler()!;
      // Extract gateId from the keyboard built during requestGateApproval
      const callArgs = sendMessageMock.mock.calls[0];
      const keyboard = callArgs[2]?.reply_markup;
      const approveData = keyboard?._buttons?.[0]?.data as string;
      const gateId = approveData?.match(/\d+$/)?.[0];

      await handler(makeCbCtx(`gate:approve:${gateId}`));
      const result = await promise;
      expect(result).toBe(true);
      expect(answerCallbackQueryMock).toHaveBeenCalled();
    });

    it('resolves false when rejected', async () => {
      const promise = bot.requestGateApproval('Approve?');
      await vi.waitFor(() => expect(sendMessageMock).toHaveBeenCalled());

      const handler = findGateHandler()!;
      const callArgs = sendMessageMock.mock.calls[0];
      const keyboard = callArgs[2]?.reply_markup;
      const rejectData = keyboard?._buttons?.[1]?.data as string;
      const gateId = rejectData?.match(/\d+$/)?.[0];

      await handler(makeCbCtx(`gate:reject:${gateId}`));
      const result = await promise;
      expect(result).toBe(false);
    });

    it('rejects with timeout error', async () => {
      const promise = bot.requestGateApproval('Approve?');
      await expect(promise).rejects.toThrow(/timed out/i);
    });

    it('answers callback query always', async () => {
      const promise = bot.requestGateApproval('Approve?');
      await vi.waitFor(() => expect(sendMessageMock).toHaveBeenCalled());

      const handler = findGateHandler()!;
      const callArgs = sendMessageMock.mock.calls[0];
      const keyboard = callArgs[2]?.reply_markup;
      const approveData = keyboard?._buttons?.[0]?.data as string;
      const gateId = approveData?.match(/\d+$/)?.[0];

      await handler(makeCbCtx(`gate:approve:${gateId}`));
      await promise;
      expect(answerCallbackQueryMock).toHaveBeenCalled();
    });
  });

  describe('progress', () => {
    it('sends plain text message', async () => {
      await bot.sendProgress('Phase 1 started');
      expect(sendMessageMock).toHaveBeenCalledWith(12345, 'Phase 1 started');
    });
  });

  describe('alert', () => {
    it('sends alert with warning prefix', async () => {
      await bot.sendAlert('Agent stuck');
      expect(sendMessageMock).toHaveBeenCalledWith(
        12345,
        expect.stringContaining('Agent stuck'),
      );
    });
  });

  describe('heartbeat', () => {
    it('sends periodic messages', async () => {
      bot.startHeartbeat();
      await new Promise((r) => setTimeout(r, 350));
      bot.stopHeartbeat();
      expect(sendMessageMock.mock.calls.length).toBeGreaterThanOrEqual(2);
    });

    it('stops cleanly', () => {
      bot.startHeartbeat();
      bot.stopHeartbeat();
      // No error thrown
    });

    it('does not crash on send failure', async () => {
      sendMessageMock.mockRejectedValueOnce(new Error('Network error'));
      bot.startHeartbeat();
      await new Promise((r) => setTimeout(r, 150));
      bot.stopHeartbeat();
      // Should not throw
    });
  });

  describe('lifecycle', () => {
    it('start calls bot.start without awaiting', () => {
      bot.start();
      expect(mockBot.start).toHaveBeenCalled();
    });

    it('stop clears heartbeat and stops bot', async () => {
      bot.startHeartbeat();
      await bot.stop();
      expect(mockBot.stop).toHaveBeenCalled();
    });
  });
});
