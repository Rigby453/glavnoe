/**
 * Верификация входящего вебхука ЮKassa — HMAC-SHA256 стаб (ADR-058).
 *
 * ЮKassa (реальный API) НЕ шлёт HMAC-заголовок по умолчанию.
 * Настоящая защита при наличии живых ключей — два слоя:
 *   1. IP-allowlist: 185.71.76.0/27, 185.71.77.0/27, 77.75.153.0/25,
 *      77.75.156.11, 77.75.156.35, 54.229.237.51, 54.245.1.84, 101.128.40.0/24
 *   2. Повторный GET-запрос к API ЮKassa (/v3/payments/{id}) для верификации
 *      объекта платежа (Basic Auth: shopId:secretKey).
 *
 * Стаб: если задан YOOKASSA_WEBHOOK_SECRET, вычисляем HMAC-SHA256 от rawBody
 * и сравниваем с заголовком x-yookassa-signature (timing-safe).
 * Если секрет НЕ задан → dev-режим, всегда возвращаем true.
 *
 * При подключении живых ключей (YOOKASSA_SHOP_ID + YOOKASSA_SECRET_KEY):
 *   - Добавить проверку IP запроса (req.ip / x-forwarded-for) по allowlist выше.
 *   - Добавить повторный GET к https://api.yookassa.ru/v3/payments/{payment_id}
 *     с Basic Auth для верификации payment.id и status.
 *   - YOOKASSA_WEBHOOK_SECRET можно оставить как доп. слой или убрать.
 *
 * Env-переменные:
 *   YOOKASSA_WEBHOOK_SECRET — HMAC-секрет (stub). При отсутствии: dev-режим.
 *   YOOKASSA_SHOP_ID        — ID магазина (для API-запросов при реальных ключах; TODO).
 *   YOOKASSA_SECRET_KEY     — Секретный ключ API ЮKassa (TODO).
 */

import crypto from "node:crypto";

/** Имя заголовка подписи (наш stub-конвент; реальная ЮKassa его не шлёт). */
const SIGNATURE_HEADER = "x-yookassa-signature";

/**
 * Верифицирует вебхук ЮKassa по HMAC-SHA256 (stub-режим).
 *
 * @param rawBody   — тело запроса (Buffer или строка; HMAC считается от байтового представления UTF-8)
 * @param headers   — заголовки запроса (ключи в нижнем регистре, как у Fastify/Node)
 * @returns true, если подпись верна ИЛИ YOOKASSA_WEBHOOK_SECRET не задан (dev-режим)
 */
export function verifyYookassaWebhook(
  rawBody: Buffer | string,
  headers: Record<string, string | string[] | undefined>
): boolean {
  const secret = process.env["YOOKASSA_WEBHOOK_SECRET"];

  // Dev-режим: секрет не задан → пропускаем всё (аналогично BILLING_WEBHOOK_SECRET в billing.ts)
  if (!secret) {
    return true;
  }

  // Извлекаем заголовок подписи (первое значение, если массив)
  const raw = headers[SIGNATURE_HEADER];
  const signatureHeader = Array.isArray(raw) ? raw[0] : raw;
  if (!signatureHeader) {
    return false;
  }

  // Вычисляем ожидаемую HMAC-SHA256 подпись
  const body =
    typeof rawBody === "string" ? Buffer.from(rawBody, "utf-8") : rawBody;
  const expected = crypto
    .createHmac("sha256", secret)
    .update(body)
    .digest("hex");

  // Timing-safe сравнение для защиты от timing-атак
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signatureHeader, "utf-8"),
      Buffer.from(expected, "utf-8")
    );
  } catch {
    // Буферы разного размера → гарантированно не совпадают
    return false;
  }
}

/**
 * Вычисляет ожидаемую HMAC-SHA256 подпись для rawBody и заданного секрета.
 * Используется в тестах (и в теории — на стороне сервиса, который шлёт вебхук).
 *
 * @param rawBody — тело запроса (Buffer или строка)
 * @param secret  — HMAC-секрет
 * @returns hex-строка подписи
 */
export function computeYookassaSignature(
  rawBody: Buffer | string,
  secret: string
): string {
  const body =
    typeof rawBody === "string" ? Buffer.from(rawBody, "utf-8") : rawBody;
  return crypto.createHmac("sha256", secret).update(body).digest("hex");
}
