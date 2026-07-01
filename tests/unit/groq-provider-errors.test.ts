/**
 * backend/src/ai/provider.ts — classification of real Groq (OpenAI-compatible)
 * error response bodies (429 daily vs per-minute quota, 503 overload) into
 * AiError, mirroring tests/unit/gemini-provider-errors.test.ts.
 *
 * No real network calls anywhere: global.fetch is mocked. GROQ_API_KEY takes
 * priority over GEMINI_API_KEY/ANTHROPIC_API_KEY (see activeProvider()), so
 * setting it alone is enough to route generateText() through groqGenerate().
 */
import { AiError } from '../../backend/src/ai/aiErrors';
import { generateText } from '../../backend/src/ai/provider';

const ORIGINAL_FETCH = global.fetch;
const ORIGINAL_GROQ_KEY = process.env['GROQ_API_KEY'];
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
  process.env['GROQ_API_KEY'] = 'test-groq-key';
  delete process.env['GEMINI_API_KEY'];
  delete process.env['ANTHROPIC_API_KEY'];
});

afterAll(() => {
  global.fetch = ORIGINAL_FETCH;
  if (ORIGINAL_GROQ_KEY === undefined) delete process.env['GROQ_API_KEY'];
  else process.env['GROQ_API_KEY'] = ORIGINAL_GROQ_KEY;
  if (ORIGINAL_GEMINI_KEY === undefined) delete process.env['GEMINI_API_KEY'];
  else process.env['GEMINI_API_KEY'] = ORIGINAL_GEMINI_KEY;
  if (ORIGINAL_ANTHROPIC_KEY === undefined) delete process.env['ANTHROPIC_API_KEY'];
  else process.env['ANTHROPIC_API_KEY'] = ORIGINAL_ANTHROPIC_KEY;
});

const call = () => generateText({ system: 'sys', user: 'usr', maxTokens: 100 });

describe('Groq 429 — per-minute rate-limit vs daily quota', () => {
  test('generic rate-limit message → AiError kind=quota_rate (retryable)', async () => {
    mockFetchError(429, {
      error: {
        message: 'Rate limit reached for requests, please slow down.',
        type: 'rate_limit_exceeded',
        code: 'rate_limit_exceeded',
      },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('quota_rate');
    expect((err as AiError).retryable).toBe(true);
  });

  test('"requests per day" message → AiError kind=quota_daily (NOT retryable)', async () => {
    mockFetchError(429, {
      error: {
        message: 'You have exceeded your requests per day quota for this model.',
        type: 'rate_limit_exceeded',
        code: 'rate_limit_exceeded',
      },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('quota_daily');
    expect((err as AiError).retryable).toBe(false);
  });

  test('"tokens per day" (TPD) message → AiError kind=quota_daily', async () => {
    mockFetchError(429, {
      error: {
        message: 'Rate limit reached — tokens per day (TPD) limit exceeded.',
        type: 'rate_limit_exceeded',
      },
    });

    const err = await call().catch((e: unknown) => e);
    expect((err as AiError).kind).toBe('quota_daily');
  });
});

describe('Groq overload (503/502)', () => {
  test('503 → AiError kind=overloaded (retryable)', async () => {
    mockFetchError(503, {
      error: { message: 'The model is temporarily overloaded.', type: 'service_unavailable' },
    });

    const err = await call().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AiError);
    expect((err as AiError).kind).toBe('overloaded');
    expect((err as AiError).retryable).toBe(true);
  });

  test('502 → AiError kind=overloaded (retryable)', async () => {
    mockFetchError(502, { error: { message: 'Bad gateway.', type: 'service_unavailable' } });
    const err = await call().catch((e: unknown) => e);
    expect((err as AiError).kind).toBe('overloaded');
  });
});

describe('Groq error body that is not valid JSON (proxy/HTML error page)', () => {
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

describe('Groq priority over Gemini/Anthropic', () => {
  test('GROQ_API_KEY set alongside GEMINI_API_KEY/ANTHROPIC_API_KEY → Groq is called (no Gemini fallback path)', async () => {
    process.env['GEMINI_API_KEY'] = 'test-gemini-key';
    process.env['ANTHROPIC_API_KEY'] = 'test-anthropic-key';
    mockFetchError(429, { error: { message: 'Rate limit reached.', type: 'rate_limit_exceeded' } });

    const err = await call().catch((e: unknown) => e);
    // If Gemini's URL/shape were hit instead, the mock (Groq-shaped body) would
    // still classify via generic message heuristics, but the fetch call itself
    // proves routing: assert it went to the Groq endpoint.
    const fetchMock = global.fetch as jest.Mock;
    expect(fetchMock.mock.calls[0]?.[0]).toBe('https://api.groq.com/openai/v1/chat/completions');
    expect((err as AiError).kind).toBe('quota_rate');
  });
});
