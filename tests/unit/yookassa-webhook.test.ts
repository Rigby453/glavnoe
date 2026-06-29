/**
 * Unit-тесты: verifyYookassaWebhook + computeYookassaSignature (ADR-058).
 * Запуск: npx jest tests/unit/yookassa-webhook.test.ts --runInBand
 * Не требует БД, реальных ключей, сетевых вызовов.
 */

import crypto from "node:crypto";
import {
  verifyYookassaWebhook,
  computeYookassaSignature,
} from "../../backend/src/billing/yookassaWebhook";

const TEST_SECRET = "test-yookassa-hmac-secret-12345";

const TEST_BODY = JSON.stringify({
  type: "notification",
  event: "payment.succeeded",
  object: {
    id: "pay-unit-001",
    status: "succeeded",
    amount: { value: "990.00", currency: "RUB" },
    metadata: { user_id: "user-uuid-001", plan: "premium_monthly" },
  },
});

/** Удобный хелпер: строит заголовки с нужной подписью или без неё. */
function makeHeaders(
  signature?: string
): Record<string, string | undefined> {
  return signature
    ? { "x-yookassa-signature": signature }
    : {};
}

describe("verifyYookassaWebhook", () => {
  let savedSecret: string | undefined;

  beforeEach(() => {
    // Сохраняем исходное значение env и сбрасываем перед каждым тестом
    savedSecret = process.env["YOOKASSA_WEBHOOK_SECRET"];
    delete process.env["YOOKASSA_WEBHOOK_SECRET"];
  });

  afterEach(() => {
    // Восстанавливаем env
    if (savedSecret === undefined) {
      delete process.env["YOOKASSA_WEBHOOK_SECRET"];
    } else {
      process.env["YOOKASSA_WEBHOOK_SECRET"] = savedSecret;
    }
  });

  // ── Dev-режим (нет секрета) ─────────────────────────────────────────────

  test("dev-mode: секрет не задан → всегда true (пустые заголовки)", () => {
    expect(verifyYookassaWebhook(TEST_BODY, {})).toBe(true);
  });

  test("dev-mode: секрет не задан → всегда true (любой заголовок)", () => {
    expect(
      verifyYookassaWebhook(TEST_BODY, {
        "x-yookassa-signature": "totally-wrong",
      })
    ).toBe(true);
  });

  // ── Корректная подпись ──────────────────────────────────────────────────

  test("верная подпись строкой → true", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    const sig = computeYookassaSignature(TEST_BODY, TEST_SECRET);
    expect(verifyYookassaWebhook(TEST_BODY, makeHeaders(sig))).toBe(true);
  });

  test("верная подпись Buffer → true", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    const buf = Buffer.from(TEST_BODY, "utf-8");
    const sig = computeYookassaSignature(buf, TEST_SECRET);
    expect(verifyYookassaWebhook(buf, makeHeaders(sig))).toBe(true);
  });

  test("Buffer и строка с одним содержимым → одна подпись", () => {
    const sigFromString = computeYookassaSignature(TEST_BODY, TEST_SECRET);
    const sigFromBuffer = computeYookassaSignature(
      Buffer.from(TEST_BODY, "utf-8"),
      TEST_SECRET
    );
    expect(sigFromString).toBe(sigFromBuffer);
  });

  // ── Некорректная подпись ────────────────────────────────────────────────

  test("неверная подпись → false", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    expect(
      verifyYookassaWebhook(TEST_BODY, makeHeaders("bad-signature"))
    ).toBe(false);
  });

  test("отсутствующий заголовок подписи → false", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    expect(verifyYookassaWebhook(TEST_BODY, {})).toBe(false);
  });

  test("тело изменено (tampering) → false", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    const sig = computeYookassaSignature(TEST_BODY, TEST_SECRET);
    const tampered = TEST_BODY + " tampered!";
    expect(verifyYookassaWebhook(tampered, makeHeaders(sig))).toBe(false);
  });

  test("другой секрет → false", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    const sig = computeYookassaSignature(TEST_BODY, "other-secret");
    expect(verifyYookassaWebhook(TEST_BODY, makeHeaders(sig))).toBe(false);
  });

  test("пустая строка подписи → false", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    expect(verifyYookassaWebhook(TEST_BODY, makeHeaders(""))).toBe(false);
  });

  // ── computeYookassaSignature совместима с node:crypto напрямую ──────────

  test("computeYookassaSignature === crypto.createHmac('sha256')", () => {
    const expected = crypto
      .createHmac("sha256", TEST_SECRET)
      .update(TEST_BODY)
      .digest("hex");
    expect(computeYookassaSignature(TEST_BODY, TEST_SECRET)).toBe(expected);
  });

  test("computeYookassaSignature возвращает hex-строку (длина 64 символа)", () => {
    const sig = computeYookassaSignature(TEST_BODY, TEST_SECRET);
    expect(sig).toMatch(/^[0-9a-f]{64}$/);
  });

  // ── Заголовок как массив (Fastify может вернуть string[]) ───────────────

  test("заголовок-массив: первый элемент используется для проверки", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    const sig = computeYookassaSignature(TEST_BODY, TEST_SECRET);
    const headers: Record<string, string | string[] | undefined> = {
      "x-yookassa-signature": [sig, "second-ignored"],
    };
    expect(verifyYookassaWebhook(TEST_BODY, headers)).toBe(true);
  });

  test("заголовок-массив с неверным первым элементом → false", () => {
    process.env["YOOKASSA_WEBHOOK_SECRET"] = TEST_SECRET;
    const headers: Record<string, string | string[] | undefined> = {
      "x-yookassa-signature": ["wrong", "also-wrong"],
    };
    expect(verifyYookassaWebhook(TEST_BODY, headers)).toBe(false);
  });
});
