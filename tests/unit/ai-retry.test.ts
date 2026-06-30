/**
 * Issue #18: withAiRetry (backend/src/ai/retry.ts) — generic retry-with-backoff
 * behaviour, decoupled from any specific AI feature module. Uses AiError
 * directly (backend/src/ai/aiErrors.ts) so each scenario is unambiguous about
 * which failure kind it represents — no string-matching guesswork.
 *
 * NODE_ENV=test (set by backend/jest.setup.ts) makes retry.ts use zero-delay
 * backoff, so these tests run fast without needing fake timers.
 */
import { withAiRetry } from '../../backend/src/ai/retry';
import { AiError } from '../../backend/src/ai/aiErrors';

describe('withAiRetry — transient errors are retried', () => {
  test.each(['quota_rate', 'overloaded', 'invalid_response', 'network'] as const)(
    '%s: retries up to 3 attempts total, then rethrows if always failing',
    async (kind) => {
      const op = jest.fn(async () => {
        throw new AiError(kind, `boom: ${kind}`);
      });

      await expect(withAiRetry(op)).rejects.toThrow(`boom: ${kind}`);
      expect(op).toHaveBeenCalledTimes(3); // 1 first try + 2 retries (default attempts=3)
    }
  );

  test('succeeds after one transient failure (self-heals, no error surfaced)', async () => {
    let calls = 0;
    const op = jest.fn(async () => {
      calls++;
      if (calls === 1) throw new AiError('quota_rate', 'momentary RPM throttle');
      return 'recovered';
    });

    await expect(withAiRetry(op)).resolves.toBe('recovered');
    expect(op).toHaveBeenCalledTimes(2);
  });

  test('succeeds on first try → no retry overhead at all', async () => {
    const op = jest.fn(async () => 'ok');
    await expect(withAiRetry(op)).resolves.toBe('ok');
    expect(op).toHaveBeenCalledTimes(1);
  });

  test('respects a custom attempts count', async () => {
    const op = jest.fn(async () => {
      throw new AiError('overloaded', 'still overloaded');
    });
    await expect(withAiRetry(op, { attempts: 5 })).rejects.toThrow('still overloaded');
    expect(op).toHaveBeenCalledTimes(5);
  });
});

describe('withAiRetry — permanent errors are NOT retried', () => {
  test.each(['region', 'quota_daily', 'unknown'] as const)(
    '%s: fails immediately on the first attempt, no wasted calls',
    async (kind) => {
      const op = jest.fn(async () => {
        throw new AiError(kind, `permanent: ${kind}`);
      });

      await expect(withAiRetry(op)).rejects.toThrow(`permanent: ${kind}`);
      expect(op).toHaveBeenCalledTimes(1); // no retry — would be wasted (e.g. daily quota stays exhausted)
    }
  );

  test('quota_daily does not retry even when wrapped with extra attempts configured', async () => {
    const op = jest.fn(async () => {
      throw new AiError('quota_daily', 'daily cap hit');
    });
    await expect(withAiRetry(op, { attempts: 5 })).rejects.toThrow('daily cap hit');
    expect(op).toHaveBeenCalledTimes(1);
  });
});

describe('withAiRetry — plain (non-AiError) errors classified by message text', () => {
  test('"Gemini API error 429: quota exceeded" → treated as transient, retried', async () => {
    const op = jest.fn(async () => {
      throw new Error('Gemini API error 429: quota exceeded');
    });
    await expect(withAiRetry(op)).rejects.toThrow('quota exceeded');
    expect(op).toHaveBeenCalledTimes(3);
  });

  test('"User location is not supported" → treated as permanent, not retried', async () => {
    const op = jest.fn(async () => {
      throw new Error('User location is not supported for the API use.');
    });
    await expect(withAiRetry(op)).rejects.toThrow('User location is not supported');
    expect(op).toHaveBeenCalledTimes(1);
  });

  test('unrecognized plain error → not retried (conservative default)', async () => {
    const op = jest.fn(async () => {
      throw new Error('Something completely unexpected happened.');
    });
    await expect(withAiRetry(op)).rejects.toThrow('Something completely unexpected happened.');
    expect(op).toHaveBeenCalledTimes(1);
  });
});
