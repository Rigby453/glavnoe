/**
 * Тонкий HTTP-клиент API ЮKassa — создание платежа (ADR-067, live integration).
 *
 * БЕЗ новых npm-зависимостей: используем глобальный fetch (Node 18+, проект на
 * Node 22 — тот же паттерн, что и backend/src/lib/email.ts и
 * backend/src/food/openFoodFacts.ts).
 *
 * Документация: https://yookassa.ru/developers/api#create_payment
 *
 * Auth: Basic <base64(shopId:secretKey)>.
 * Idempotence-Key обязателен для POST /v3/payments (защита от дублей при
 * повторной отправке одного и того же запроса — retry на клиенте/сети).
 */

import crypto from "node:crypto";

/**
 * Временная цена-заглушка за месяц Premium — юнит-экономика ещё не просчитана
 * (см. docs/STATUS.md, раздел «Pricing model TODO»). Значение — строка вида
 * "999.99" (формат amount.value ЮKassa, до 2 знаков после запятой).
 */
export const kPremiumMonthlyRub = "399.00";

const YOOKASSA_PAYMENTS_URL = "https://api.yookassa.ru/v3/payments";
const REQUEST_TIMEOUT_MS = 15_000;

/** Бросается, если YOOKASSA_SHOP_ID / YOOKASSA_SECRET_KEY / YOOKASSA_RETURN_URL не заданы в env. */
export class BillingNotConfiguredError extends Error {
  constructor(missing: string) {
    super(`YooKassa billing is not configured: ${missing} is not set`);
    this.name = "BillingNotConfiguredError";
  }
}

export interface CreatePaymentParams {
  userId: string;
  description: string;
  /** По умолчанию kPremiumMonthlyRub. Строка формата "999.99". */
  amountValue?: string;
}

export interface CreatePaymentResult {
  id: string;
  confirmationUrl: string;
  status: string;
}

interface YookassaConfirmationResponse {
  type?: string;
  confirmation_url?: string;
}

interface YookassaPaymentResponse {
  id: string;
  status: string;
  confirmation?: YookassaConfirmationResponse;
}

interface YookassaCredentials {
  shopId: string;
  secretKey: string;
  returnUrl: string;
}

/** Читает и проверяет обязательные env-переменные. Бросает BillingNotConfiguredError, если чего-то нет. */
function getCredentials(): YookassaCredentials {
  const shopId = process.env["YOOKASSA_SHOP_ID"];
  if (!shopId) throw new BillingNotConfiguredError("YOOKASSA_SHOP_ID");

  const secretKey = process.env["YOOKASSA_SECRET_KEY"];
  if (!secretKey) throw new BillingNotConfiguredError("YOOKASSA_SECRET_KEY");

  const returnUrl = process.env["YOOKASSA_RETURN_URL"];
  if (!returnUrl) throw new BillingNotConfiguredError("YOOKASSA_RETURN_URL");

  return { shopId, secretKey, returnUrl };
}

/**
 * Создаёт платёж в ЮKassa (redirect-подтверждение) на сумму kPremiumMonthlyRub
 * (или явно переданную amountValue), возвращает id платежа и URL, куда
 * редиректить пользователя для оплаты.
 *
 * Бросает:
 *  - BillingNotConfiguredError — если ключи/return url не заданы (роут → 503).
 *  - Error — любой сетевой сбой / не-2xx ответ / некорректный ответ API.
 */
export async function createPayment(
  params: CreatePaymentParams
): Promise<CreatePaymentResult> {
  const { shopId, secretKey, returnUrl } = getCredentials();
  const amountValue = params.amountValue ?? kPremiumMonthlyRub;
  const idempotenceKey = crypto.randomUUID();
  const auth = Buffer.from(`${shopId}:${secretKey}`, "utf-8").toString("base64");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(YOOKASSA_PAYMENTS_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${auth}`,
        "Idempotence-Key": idempotenceKey,
      },
      body: JSON.stringify({
        amount: { value: amountValue, currency: "RUB" },
        capture: true,
        confirmation: { type: "redirect", return_url: returnUrl },
        description: params.description,
        metadata: { user_id: params.userId },
      }),
      signal: controller.signal,
    });
  } catch (err) {
    if (err instanceof Error && err.name === "AbortError") {
      throw new Error("YooKassa createPayment timed out");
    }
    throw new Error(
      `YooKassa createPayment request failed: ${err instanceof Error ? err.message : String(err)}`
    );
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(
      `YooKassa createPayment failed: HTTP ${response.status} ${text.slice(0, 500)}`
    );
  }

  const data = (await response.json()) as YookassaPaymentResponse;
  const confirmationUrl = data.confirmation?.confirmation_url;
  if (!confirmationUrl) {
    throw new Error("YooKassa createPayment response is missing confirmation_url");
  }

  return { id: data.id, confirmationUrl, status: data.status };
}
