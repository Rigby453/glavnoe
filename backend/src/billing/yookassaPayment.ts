/**
 * Валидация платёжного объекта ЮKassa + идемпотентность (ADR-058).
 *
 * ЮKassa шлёт нотификации вида:
 * {
 *   "type": "notification",
 *   "event": "payment.succeeded",
 *   "object": {
 *     "id": "22d6d597-000f-5000-9000-145f6df21d6f",
 *     "status": "succeeded",
 *     "amount": { "value": "990.00", "currency": "RUB" },
 *     "description": "Kaizen Premium Monthly",
 *     "metadata": { "user_id": "<user-uuid>", "plan": "premium_monthly" },
 *     ...
 *   }
 * }
 *
 * Поддерживаемые события:
 *   "payment.succeeded" — оплата захвачена (нужно активировать подписку).
 * Остальные события (canceled, waiting_for_capture, refund.succeeded) —
 * возвращают valid=false (unsupported event); в маршруте можно ответить 200
 * и проигнорировать их.
 *
 * Идемпотентность: каждый payment.id обрабатывается ровно один раз.
 * Хранилище — in-memory Set (стаб).
 * В production → перенести в таблицу processed_payments / Redis:
 *   CREATE TABLE processed_payments (payment_id TEXT PRIMARY KEY, processed_at TIMESTAMPTZ DEFAULT now());
 *
 * Env-переменные (для справки; активируются при подключении живых ключей):
 *   YOOKASSA_SHOP_ID    — ID магазина для API-запросов
 *   YOOKASSA_SECRET_KEY — Секретный ключ API ЮKassa
 */

import { z } from "zod";

// ────────────────────────────────────────────────────────────────────────────
// Zod-схемы входящего уведомления ЮKassa
// ────────────────────────────────────────────────────────────────────────────

const yookassaAmountSchema = z.object({
  value: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, "amount.value must be a decimal string like '990.00'"),
  currency: z.string().min(3).max(3), // ISO 4217, напр. "RUB"
});

const yookassaObjectSchema = z.object({
  id: z.string().min(1),
  status: z.string(),
  amount: yookassaAmountSchema,
  metadata: z
    .object({
      user_id: z.string().min(1).optional(),
      plan: z.string().optional(),
    })
    .optional(),
});

const yookassaNotificationSchema = z.object({
  type: z.literal("notification"),
  event: z.string().min(1),
  object: yookassaObjectSchema,
});

// ────────────────────────────────────────────────────────────────────────────
// Публичные типы
// ────────────────────────────────────────────────────────────────────────────

export interface PaymentValidationSuccess {
  valid: true;
  paymentId: string;
  userId: string;
  plan: string | undefined;
  amountValue: string;
  currency: string;
  event: string;
}

export interface PaymentValidationFailure {
  valid: false;
  error: string;
}

export type PaymentValidationResult =
  | PaymentValidationSuccess
  | PaymentValidationFailure;

// ────────────────────────────────────────────────────────────────────────────
// Идемпотентность (in-memory; TODO → DB/Redis в production)
// ────────────────────────────────────────────────────────────────────────────

/** Хранит payment_id уже обработанных платежей. */
const processedPayments = new Set<string>();

/**
 * Возвращает true, если payment_id уже обрабатывался.
 * Используется для идемпотентной обработки повторных нотификаций.
 */
export function isPaymentProcessed(paymentId: string): boolean {
  return processedPayments.has(paymentId);
}

/**
 * Помечает payment_id как обработанный.
 * Вызывать ПОСЛЕ успешного обновления entitlement, не до.
 */
export function markPaymentProcessed(paymentId: string): void {
  processedPayments.add(paymentId);
}

/**
 * Сбрасывает хранилище обработанных платежей.
 * Использовать ТОЛЬКО в тестах (NODE_ENV=test) — в прогоне тестов между тестами.
 */
export function resetProcessedPayments(): void {
  processedPayments.clear();
}

// ────────────────────────────────────────────────────────────────────────────
// Основная валидация
// ────────────────────────────────────────────────────────────────────────────

/**
 * Валидирует входящий объект уведомления ЮKassa (тело вебхука POST).
 *
 * Возвращает PaymentValidationSuccess при:
 *   - корректной структуре (Zod-схема)
 *   - event === "payment.succeeded"
 *   - object.status === "succeeded"
 *   - наличии metadata.user_id (непустая строка)
 *
 * Возвращает PaymentValidationFailure с человекочитаемым описанием при:
 *   - невалидной схеме
 *   - неподдерживаемом событии
 *   - статусе, отличном от "succeeded"
 *   - отсутствующем / пустом user_id в metadata
 *
 * Идемпотентность НЕ проверяется здесь — вызывающий код должен проверить
 * isPaymentProcessed(result.paymentId) ДО вызова этой функции или сразу после.
 */
export function validateYookassaPayment(
  body: unknown
): PaymentValidationResult {
  const parsed = yookassaNotificationSchema.safeParse(body);
  if (!parsed.success) {
    const msg = parsed.error.issues[0]?.message ?? "unknown";
    return {
      valid: false,
      error: `Schema validation failed: ${msg}`,
    };
  }

  const notification = parsed.data;

  // Нас интересует только "payment.succeeded"; остальные события — игнорируемые
  if (notification.event !== "payment.succeeded") {
    return {
      valid: false,
      error: `Unsupported event: ${notification.event}`,
    };
  }

  // Статус объекта должен быть "succeeded" (ЮKassa может прислать "pending" и т.п.)
  if (notification.object.status !== "succeeded") {
    return {
      valid: false,
      error: `Payment status is not succeeded: ${notification.object.status}`,
    };
  }

  // Метаданные ДОЛЖНЫ содержать user_id, чтобы мы знали кому выдать подписку
  const userId = notification.object.metadata?.user_id;
  if (!userId) {
    return {
      valid: false,
      error: "metadata.user_id is missing or empty",
    };
  }

  return {
    valid: true,
    paymentId: notification.object.id,
    userId,
    plan: notification.object.metadata?.plan,
    amountValue: notification.object.amount.value,
    currency: notification.object.amount.currency,
    event: notification.event,
  };
}
