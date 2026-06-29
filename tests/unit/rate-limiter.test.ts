/**
 * Unit-тесты: InMemoryRateLimiter (ADR-058).
 * Запуск: npx jest tests/unit/rate-limiter.test.ts --runInBand
 * Не требует БД, сетевых вызовов, переменных окружения.
 */

import { InMemoryRateLimiter } from "../../backend/src/lib/rateLimiter";

describe("InMemoryRateLimiter", () => {
  let limiter: InMemoryRateLimiter;

  beforeEach(() => {
    // Окно 1 секунда, лимит 3 запроса
    limiter = new InMemoryRateLimiter({ windowMs: 1000, maxRequests: 3 });
  });

  // ── Базовая логика ───────────────────────────────────────────────────────

  test("первый запрос всегда разрешён", () => {
    const result = limiter.check("ip-001");
    expect(result.allowed).toBe(true);
  });

  test("первый запрос: remaining = maxRequests - 1", () => {
    const result = limiter.check("ip-002");
    expect(result.remaining).toBe(2);
  });

  test("запросы до лимита включительно — все разрешены", () => {
    expect(limiter.check("ip-003").allowed).toBe(true);
    expect(limiter.check("ip-003").allowed).toBe(true);
    expect(limiter.check("ip-003").allowed).toBe(true);
  });

  test("запрос сверх лимита — отклонён", () => {
    limiter.check("ip-004");
    limiter.check("ip-004");
    limiter.check("ip-004"); // 3й = лимит
    const result = limiter.check("ip-004"); // 4й = сверх
    expect(result.allowed).toBe(false);
    expect(result.remaining).toBe(0);
  });

  // ── Remaining декрементирует ──────────────────────────────────────────────

  test("remaining декрементируется с каждым запросом", () => {
    const r1 = limiter.check("ip-dec");
    expect(r1.remaining).toBe(2);
    const r2 = limiter.check("ip-dec");
    expect(r2.remaining).toBe(1);
    const r3 = limiter.check("ip-dec");
    expect(r3.remaining).toBe(0);
  });

  // ── Независимость ключей ─────────────────────────────────────────────────

  test("разные ключи независимы", () => {
    // ip-a превысил лимит
    limiter.check("ip-a");
    limiter.check("ip-a");
    limiter.check("ip-a");
    expect(limiter.check("ip-a").allowed).toBe(false);

    // ip-b начинает с нуля
    expect(limiter.check("ip-b").allowed).toBe(true);
  });

  // ── resetAt ──────────────────────────────────────────────────────────────

  test("resetAt в будущем", () => {
    const before = Date.now();
    const result = limiter.check("ip-time");
    expect(result.resetAt).toBeGreaterThan(before);
    expect(result.resetAt).toBeLessThanOrEqual(before + 1100); // окно = 1000ms + погрешность
  });

  test("resetAt одинаков в рамках одного окна", () => {
    const r1 = limiter.check("ip-same");
    const r2 = limiter.check("ip-same");
    expect(r1.resetAt).toBe(r2.resetAt);
  });

  // ── Методы reset / clear ─────────────────────────────────────────────────

  test("reset(key) освобождает конкретный ключ", () => {
    limiter.check("ip-r");
    limiter.check("ip-r");
    limiter.check("ip-r");
    expect(limiter.check("ip-r").allowed).toBe(false);

    limiter.reset("ip-r");
    expect(limiter.check("ip-r").allowed).toBe(true);
  });

  test("reset незатронутого ключа не бросает ошибку", () => {
    expect(() => limiter.reset("ip-nonexistent")).not.toThrow();
  });

  test("clear() освобождает все ключи", () => {
    limiter.check("ip-x");
    limiter.check("ip-x");
    limiter.check("ip-x");
    expect(limiter.check("ip-x").allowed).toBe(false);

    limiter.clear();
    expect(limiter.check("ip-x").allowed).toBe(true);
    expect(limiter.check("ip-y").allowed).toBe(true);
  });

  // ── Сброс окна по времени ────────────────────────────────────────────────

  test("окно сбрасывается после windowMs", async () => {
    // Используем короткое окно 50ms, чтобы не тормозить тест
    const fastLimiter = new InMemoryRateLimiter({
      windowMs: 50,
      maxRequests: 2,
    });

    fastLimiter.check("ip-t");
    fastLimiter.check("ip-t");
    expect(fastLimiter.check("ip-t").allowed).toBe(false); // заблокирован

    // Ждём пока окно истечёт
    await new Promise<void>((resolve) => setTimeout(resolve, 60));

    const result = fastLimiter.check("ip-t");
    expect(result.allowed).toBe(true); // новое окно — разрешён
    expect(result.remaining).toBe(1);
  }, 500); // таймаут теста 500ms — более чем достаточно

  // ── Крайние значения ─────────────────────────────────────────────────────

  test("лимит 1 — второй запрос отклонён", () => {
    const tightLimiter = new InMemoryRateLimiter({
      windowMs: 1000,
      maxRequests: 1,
    });
    expect(tightLimiter.check("ip-tight").allowed).toBe(true);
    expect(tightLimiter.check("ip-tight").allowed).toBe(false);
  });

  test("лимит 100 — первые 100 запросов разрешены", () => {
    const bigLimiter = new InMemoryRateLimiter({
      windowMs: 60000,
      maxRequests: 100,
    });
    for (let i = 0; i < 100; i++) {
      expect(bigLimiter.check("ip-big").allowed).toBe(true);
    }
    expect(bigLimiter.check("ip-big").allowed).toBe(false);
  });
});
