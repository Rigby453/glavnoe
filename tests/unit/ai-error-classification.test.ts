/**
 * Issue #18: «AI is temporarily unavailable (quota/region)» lumped together
 * daily-quota exhaustion, per-minute rate-limiting, region blocks, upstream
 * overload, and malformed model output into ONE message/retry bucket.
 *
 * These tests cover the new classifier (backend/src/ai/aiErrors.ts) in
 * isolation — pure functions, no network/provider involved.
 */
import {
  AiError,
  classifyAiError,
  userMessageFor,
  RETRYABLE_AI_ERROR_KINDS,
  type AiErrorKind,
} from '../../backend/src/ai/aiErrors';

describe('classifyAiError', () => {
  test('region block (Gemini geo-restriction) → region', () => {
    expect(
      classifyAiError(new Error('User location is not supported for the API use.'))
    ).toBe('region');
  });

  test('region check is case-insensitive', () => {
    expect(
      classifyAiError(new Error('USER LOCATION IS NOT SUPPORTED for the API use.'))
    ).toBe('region');
  });

  test('generic 429/quota message (no daily marker) → quota_rate', () => {
    expect(classifyAiError(new Error('Gemini API error 429: quota exceeded'))).toBe(
      'quota_rate'
    );
  });

  test('RESOURCE_EXHAUSTED with PerDay quotaId → quota_daily', () => {
    expect(
      classifyAiError(
        new Error(
          'Gemini API error 429 (RESOURCE_EXHAUSTED): You exceeded your current quota ' +
            '[quotaId=GenerateRequestsPerDayPerProjectPerModel-FreeTier]'
        )
      )
    ).toBe('quota_daily');
  });

  test('RESOURCE_EXHAUSTED with PerMinute quotaId → quota_rate (short-lived)', () => {
    expect(
      classifyAiError(
        new Error(
          'Gemini API error 429 (RESOURCE_EXHAUSTED): You exceeded your current quota ' +
            '[quotaId=GenerateRequestsPerMinutePerProjectPerModel-FreeTier]'
        )
      )
    ).toBe('quota_rate');
  });

  test('Anthropic-style rate_limit_error → quota_rate', () => {
    expect(classifyAiError(new Error('429 rate_limit_error: too many requests'))).toBe(
      'quota_rate'
    );
  });

  test('503 / overloaded / high demand → overloaded', () => {
    expect(classifyAiError(new Error('Gemini API error 503: The model is overloaded.'))).toBe(
      'overloaded'
    );
    expect(classifyAiError(new Error('Claude is currently experiencing high demand.'))).toBe(
      'overloaded'
    );
    expect(classifyAiError(new Error('529 overloaded_error'))).toBe('overloaded');
  });

  test('malformed/unexpected model output → invalid_response', () => {
    expect(classifyAiError(new Error('AI returned unparseable JSON for menu-build.'))).toBe(
      'invalid_response'
    );
    expect(classifyAiError(new Error('AI returned no usable menu.'))).toBe('invalid_response');
    expect(
      classifyAiError(new Error('AI returned an unexpected food-recognition shape.'))
    ).toBe('invalid_response');
  });

  test('network blips → network', () => {
    expect(classifyAiError(new Error('connect ETIMEDOUT'))).toBe('network');
    expect(classifyAiError(new Error('socket hang up ECONNRESET'))).toBe('network');
    expect(classifyAiError(new Error('fetch failed'))).toBe('network');
  });

  test('unrecognized error → unknown (conservative — not retried)', () => {
    expect(classifyAiError(new Error('GEMINI_API_KEY is not set.'))).toBe('unknown');
    expect(classifyAiError('plain string error')).toBe('unknown');
  });

  test('AiError instances report their own kind directly (no string parsing)', () => {
    const err = new AiError('quota_daily', 'irrelevant message text');
    expect(classifyAiError(err)).toBe('quota_daily');
  });
});

describe('AiError.retryable', () => {
  test.each<[AiErrorKind, boolean]>([
    ['quota_daily', false],
    ['quota_rate', true],
    ['region', false],
    ['overloaded', true],
    ['invalid_response', true],
    ['network', true],
    ['unknown', false],
  ])('%s → retryable=%s', (kind, expected) => {
    expect(new AiError(kind, 'msg').retryable).toBe(expected);
    expect(RETRYABLE_AI_ERROR_KINDS.has(kind)).toBe(expected);
  });
});

describe('userMessageFor', () => {
  test('every kind has a distinct, non-empty message', () => {
    const kinds: AiErrorKind[] = [
      'quota_daily',
      'quota_rate',
      'region',
      'overloaded',
      'invalid_response',
      'network',
      'unknown',
    ];
    const messages = kinds.map(userMessageFor);
    for (const m of messages) expect(m.length).toBeGreaterThan(0);
    // Раздельные формулировки — больше не один общий "quota/region" текст.
    expect(new Set(messages).size).toBe(kinds.length);
  });

  test('quota_daily message mentions waiting, not "try again later" alone', () => {
    expect(userMessageFor('quota_daily')).toMatch(/daily|24h|tomorrow/i);
  });

  test('quota_rate message implies a short wait (not a daily reset)', () => {
    expect(userMessageFor('quota_rate')).not.toMatch(/daily|24h/i);
  });
});
