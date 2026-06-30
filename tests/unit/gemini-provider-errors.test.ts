/**
 * Issue #18: backend/src/ai/provider.ts — classification of real Gemini error
 * response bodies (429 daily quota vs per-minute rate-limit vs region block vs
 * overload) into AiError, plus the Anthropic-fallback DECISION for permanent
 * Gemini failures.
 *
 * No real network calls anywhere: global.fetch is mocked (Gemini side), and
 * the Anthropic-fallback path is verified through the exported pure decision
 * function `shouldFallbackToAnthropic` rather than by actually invoking the
 * Anthropic SDK — every scenario here either never reaches anthropicGenerate()
 * (ANTHROPIC_API_KEY stays unset) or is checked at the decision-function level
 * (QA rule: never hit a real provider — including a real SDK client — in tests).
 */
import { AiError } from '../../backend/src/ai/aiErrors';
import { generateText, shouldFallbackToAnthropic } from '../../backend/src/ai/provider';

const ORIGINAL_FETCH = global.fetch;
const ORIGINAL_GEMINI_KEY = process.env['GEMINI_API_KEY'];
const ORIGINAL_ANTHROPIC_KEY = process.env['ANTHROPIC_API_KEY'];

function mockFetchError(status: number, body: unknown): void {
  global.fetch = jest.fn().mockResolvedValue({
    ok: false,
    status,
    text: async () => JSON.stringify(body),
  }) as unknown as typeof fetch;
}

beforeEach(() => {
  process.env['GEMINI_API_KEY'] = 'test-gemini-key';
  delete process.env['ANTHROPIC_API_KEY'];
});

afterAll(() => {
  global.fetch = ORIGINAL_FETCH;
  if (ORIGINAL_GEMINI_KEY === undefined) delete process.env['GEMINI_API_KEY'];
  else process.env['GEMINI_API_KEY'] = ORIGINAL_GEMINI_KEY;
  if (ORIGINAL_ANTHROPIC_KEY === undefined) delete process.env['ANTHROPIC_API_KEY'];
  else process.env['ANTHROPIC_API_KEY'] = ORIGINAL_ANTHROPIC_KEY;
});

const call = () => generateText({ system: 'sys', user: 'usr', maxTokens: 100 });

describe('Gemini 429 RESOURCE_EXHAUSTED — daily vs per-minute quota', () => {
  test('quotaId PerDay → AiError kind=quota_daily (NOT retryable)', async () => {
    mockFetchError(429, {
      error: {
        code: 429,
        message: 'You exceeded your current quota, please check your plan and billing details.',
        status: 'RESOURCE_EXHAUSTED',
        details: [
          {
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            violations: [
              {
                quotaMetric: 'generativelanguage.googleapis.com/generate_content_free_tier_requests',
                quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
              },
            ],
          },
        ],
      },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('quota_daily');
    expect((err as AiError).retryable).toBe(false);
  });

  test('quotaId PerMinute → AiError kind=quota_rate (retryable, short-lived)', async () => {
    mockFetchError(429, {
      error: {
        code: 429,
        message: 'You exceeded your current quota, please check your plan and billing details.',
        status: 'RESOURCE_EXHAUSTED',
        details: [
          {
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            violations: [
              {
                quotaMetric: 'generativelanguage.googleapis.com/generate_content_free_tier_requests',
                quotaId: 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier',
              },
            ],
          },
        ],
      },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('quota_rate');
    expect((err as AiError).retryable).toBe(true);
  });

  test('429 with no quota details at all → defaults to quota_rate (safer: assume short-lived)', async () => {
    mockFetchError(429, { error: { code: 429, message: 'Too many requests', status: 'RESOURCE_EXHAUSTED' } });
    const err = await call().catch((e: unknown) => e);
    expect((err as AiError).kind).toBe('quota_rate');
  });
});

describe('Gemini region block (FAILED_PRECONDITION)', () => {
  test('"User location is not supported" → AiError kind=region (NOT retryable)', async () => {
    mockFetchError(400, {
      error: {
        code: 400,
        message: 'User location is not supported for the API use.',
        status: 'FAILED_PRECONDITION',
      },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('region');
    expect((err as AiError).retryable).toBe(false);
  });
});

describe('Gemini overload (503 UNAVAILABLE)', () => {
  test('503 → AiError kind=overloaded (retryable)', async () => {
    mockFetchError(503, {
      error: { code: 503, message: 'The model is overloaded. Please try again later.', status: 'UNAVAILABLE' },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('overloaded');
    expect((err as AiError).retryable).toBe(true);
  });
});

describe('Gemini error body that is not valid JSON (proxy/HTML error page)', () => {
  test('falls back to raw text, still surfaces as an AiError without throwing a parse error itself', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 500,
      text: async () => '<html><body>502 Bad Gateway</body></html>',
    }) as unknown as typeof fetch;

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as Error).message).toContain('502 Bad Gateway');
  });
});

describe('errors WITHOUT ANTHROPIC_API_KEY configured → propagate unchanged (no fallback possible)', () => {
  test('region block, no key → rejects with kind=region', async () => {
    mockFetchError(400, {
      error: { code: 400, message: 'User location is not supported for the API use.', status: 'FAILED_PRECONDITION' },
    });
    await expect(call()).rejects.toMatchObject({ kind: 'region' });
  });

  test('daily quota exhausted, no key → rejects with kind=quota_daily', async () => {
    mockFetchError(429, {
      error: {
        code: 429,
        message: 'You exceeded your current quota.',
        status: 'RESOURCE_EXHAUSTED',
        details: [{ violations: [{ quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier' }] }],
      },
    });
    await expect(call()).rejects.toMatchObject({ kind: 'quota_daily' });
  });
});

/**
 * shouldFallbackToAnthropic — exercised directly as a pure function (no SDK,
 * no network) to verify the exact fallback decision matrix, since actually
 * invoking the Anthropic SDK from a unit test would mean a real network call.
 */
describe('shouldFallbackToAnthropic (pure decision function)', () => {
  test('no Anthropic key → never falls back, regardless of error kind', () => {
    expect(shouldFallbackToAnthropic(new AiError('region', 'x'), false)).toBe(false);
    expect(shouldFallbackToAnthropic(new AiError('quota_daily', 'x'), false)).toBe(false);
    expect(shouldFallbackToAnthropic(new AiError('quota_rate', 'x'), false)).toBe(false);
  });

  test('Anthropic key present + region block → falls back', () => {
    expect(shouldFallbackToAnthropic(new AiError('region', 'x'), true)).toBe(true);
  });

  test('Anthropic key present + daily quota exhausted → falls back', () => {
    expect(shouldFallbackToAnthropic(new AiError('quota_daily', 'x'), true)).toBe(true);
  });

  test('Anthropic key present + per-minute rate-limit → does NOT fall back (same-provider retry instead)', () => {
    expect(shouldFallbackToAnthropic(new AiError('quota_rate', 'x'), true)).toBe(false);
  });

  test('Anthropic key present + overloaded/invalid_response/network/unknown → does NOT fall back', () => {
    expect(shouldFallbackToAnthropic(new AiError('overloaded', 'x'), true)).toBe(false);
    expect(shouldFallbackToAnthropic(new AiError('invalid_response', 'x'), true)).toBe(false);
    expect(shouldFallbackToAnthropic(new AiError('network', 'x'), true)).toBe(false);
    expect(shouldFallbackToAnthropic(new AiError('unknown', 'x'), true)).toBe(false);
  });

  test('plain Error (string-classified) still works the same way', () => {
    expect(
      shouldFallbackToAnthropic(new Error('User location is not supported for the API use.'), true)
    ).toBe(true);
    expect(shouldFallbackToAnthropic(new Error('Gemini API error 429: quota exceeded'), true)).toBe(
      false
    );
  });
});
