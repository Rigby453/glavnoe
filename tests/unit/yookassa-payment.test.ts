/**
 * Unit-тесты: validateYookassaPayment + идемпотентность (ADR-058).
 * Запуск: npx jest tests/unit/yookassa-payment.test.ts --runInBand
 * Не требует БД, реальных ключей, сетевых вызовов.
 */

import {
  validateYookassaPayment,
  isPaymentProcessed,
  markPaymentProcessed,
  resetProcessedPayments,
  type PaymentValidationSuccess,
  type PaymentValidationFailure,
} from "../../backend/src/billing/yookassaPayment";

// Корректный объект уведомления ЮKassa (эталон)
const VALID_NOTIFICATION = {
  type: "notification",
  event: "payment.succeeded",
  object: {
    id: "pay-unit-aaa-001",
    status: "succeeded",
    amount: { value: "990.00", currency: "RUB" },
    metadata: { user_id: "user-uuid-unit-001", plan: "premium_monthly" },
  },
};

beforeEach(() => {
  resetProcessedPayments();
});

// ────────────────────────────────────────────────────────────────────────────
// validateYookassaPayment — корректные случаи
// ────────────────────────────────────────────────────────────────────────────

describe("validateYookassaPayment — успешная валидация", () => {
  test("корректное уведомление → valid=true со всеми полями", () => {
    const result = validateYookassaPayment(VALID_NOTIFICATION);
    expect(result.valid).toBe(true);
    const r = result as PaymentValidationSuccess;
    expect(r.paymentId).toBe("pay-unit-aaa-001");
    expect(r.userId).toBe("user-uuid-unit-001");
    expect(r.plan).toBe("premium_monthly");
    expect(r.amountValue).toBe("990.00");
    expect(r.currency).toBe("RUB");
    expect(r.event).toBe("payment.succeeded");
  });

  test("plan необязателен — valid=true даже без plan в metadata", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        metadata: { user_id: "user-uuid-unit-002" },
      },
    };
    const result = validateYookassaPayment(body);
    expect(result.valid).toBe(true);
    const r = result as PaymentValidationSuccess;
    expect(r.plan).toBeUndefined();
  });

  test("amount.value — целое число без десятичных тоже валидно ('1000')", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        amount: { value: "1000", currency: "RUB" },
      },
    };
    expect(validateYookassaPayment(body).valid).toBe(true);
  });

  test("валюта не RUB (USD) тоже принимается схемой", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        amount: { value: "9.99", currency: "USD" },
      },
    };
    expect(validateYookassaPayment(body).valid).toBe(true);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// validateYookassaPayment — некорректные случаи
// ────────────────────────────────────────────────────────────────────────────

describe("validateYookassaPayment — ошибки валидации", () => {
  test("неподдерживаемое событие (payment.canceled) → valid=false + Unsupported event", () => {
    const body = { ...VALID_NOTIFICATION, event: "payment.canceled" };
    const result = validateYookassaPayment(body) as PaymentValidationFailure;
    expect(result.valid).toBe(false);
    expect(result.error).toContain("Unsupported event");
  });

  test("неподдерживаемое событие (refund.succeeded) → valid=false", () => {
    const body = { ...VALID_NOTIFICATION, event: "refund.succeeded" };
    const result = validateYookassaPayment(body) as PaymentValidationFailure;
    expect(result.valid).toBe(false);
  });

  test("status !== 'succeeded' (pending) → valid=false + not succeeded", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: { ...VALID_NOTIFICATION.object, status: "pending" },
    };
    const result = validateYookassaPayment(body) as PaymentValidationFailure;
    expect(result.valid).toBe(false);
    expect(result.error).toContain("not succeeded");
  });

  test("status === 'canceled' → valid=false", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: { ...VALID_NOTIFICATION.object, status: "canceled" },
    };
    expect(validateYookassaPayment(body).valid).toBe(false);
  });

  test("отсутствующий metadata.user_id → valid=false + user_id", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        metadata: { plan: "premium_monthly" }, // нет user_id
      },
    };
    const result = validateYookassaPayment(body) as PaymentValidationFailure;
    expect(result.valid).toBe(false);
    expect(result.error).toContain("user_id");
  });

  test("metadata полностью отсутствует → valid=false + user_id", () => {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { metadata: _m, ...objectWithoutMeta } = VALID_NOTIFICATION.object;
    const body = { ...VALID_NOTIFICATION, object: objectWithoutMeta };
    const result = validateYookassaPayment(body) as PaymentValidationFailure;
    expect(result.valid).toBe(false);
    expect(result.error).toContain("user_id");
  });

  test("type !== 'notification' → valid=false (Schema validation)", () => {
    const body = { ...VALID_NOTIFICATION, type: "event" };
    expect(validateYookassaPayment(body).valid).toBe(false);
  });

  test("отсутствует amount.value → valid=false", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        amount: { currency: "RUB" }, // нет value
      },
    };
    expect(validateYookassaPayment(body).valid).toBe(false);
  });

  test("amount.value не десятичное число → valid=false", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        amount: { value: "not-a-number", currency: "RUB" },
      },
    };
    expect(validateYookassaPayment(body).valid).toBe(false);
  });

  test("amount.value с тремя знаками после запятой → valid=false", () => {
    const body = {
      ...VALID_NOTIFICATION,
      object: {
        ...VALID_NOTIFICATION.object,
        amount: { value: "9.999", currency: "RUB" },
      },
    };
    expect(validateYookassaPayment(body).valid).toBe(false);
  });

  test("null → valid=false", () => {
    expect(validateYookassaPayment(null).valid).toBe(false);
  });

  test("пустой объект {} → valid=false", () => {
    expect(validateYookassaPayment({}).valid).toBe(false);
  });

  test("строка → valid=false", () => {
    expect(validateYookassaPayment("just a string").valid).toBe(false);
  });

  test("массив → valid=false", () => {
    expect(validateYookassaPayment([]).valid).toBe(false);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// Идемпотентность
// ────────────────────────────────────────────────────────────────────────────

describe("idempotency — isPaymentProcessed / markPaymentProcessed", () => {
  test("новый payment_id → isPaymentProcessed === false", () => {
    expect(isPaymentProcessed("pay-new-001")).toBe(false);
  });

  test("после markPaymentProcessed → isPaymentProcessed === true", () => {
    markPaymentProcessed("pay-new-002");
    expect(isPaymentProcessed("pay-new-002")).toBe(true);
  });

  test("resetProcessedPayments очищает всё хранилище", () => {
    markPaymentProcessed("pay-x");
    markPaymentProcessed("pay-y");
    resetProcessedPayments();
    expect(isPaymentProcessed("pay-x")).toBe(false);
    expect(isPaymentProcessed("pay-y")).toBe(false);
  });

  test("разные payment_id независимы друг от друга", () => {
    markPaymentProcessed("pay-a");
    expect(isPaymentProcessed("pay-a")).toBe(true);
    expect(isPaymentProcessed("pay-b")).toBe(false);
  });

  test("markPaymentProcessed идемпотентен (двойной вызов безопасен)", () => {
    markPaymentProcessed("pay-double");
    markPaymentProcessed("pay-double");
    expect(isPaymentProcessed("pay-double")).toBe(true);
  });

  test("beforeEach сбросил хранилище — payment из предыдущего теста не виден", () => {
    // Этот тест намеренно проверяет что beforeEach сработал корректно
    expect(isPaymentProcessed("pay-new-001")).toBe(false);
    expect(isPaymentProcessed("pay-new-002")).toBe(false);
    expect(isPaymentProcessed("pay-a")).toBe(false);
  });
});
