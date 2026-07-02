/**
 * ADR-041: заглушки вебхуков биллинга — каркас серверного entitlement.
 * ADR-067: YooKassa вышла из заглушки на реальную интеграцию (см. блок ниже).
 *
 * Каналы-заглушки: apple | google | rustore | stripe
 * Тело (snake_case): { user_id, product_id?, expires_at (ISO) }
 * Действие: выставить User.premiumUntil = expires_at, User.premiumSource = <канал>.
 *
 * ВАЖНО: реальные вебхуки требуют проверки подписи каждого провайдера.
 * TODO при появлении ключей (ADR-041):
 *   - Apple: проверить подпись JWS App Store Server Notifications V2
 *   - Google: проверить JWT от Google Play с ключом сервисного аккаунта
 *   - RuStore: проверить HMAC-подпись по BILLING_RUSTORE_SECRET
 *   - Stripe: проверить Stripe-Signature через stripe.webhooks.constructEvent
 *
 * Защита каркаса: если задан env BILLING_WEBHOOK_SECRET,
 * требуем заголовок x-webhook-secret равный ему (иначе 401).
 * Если env не задан — пропускаем (dev-режим).
 */

import type { FastifyPluginAsync, FastifyRequest, FastifyReply } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { requireAuth } from "./middleware/auth.js";
import {
  createPayment,
  kPremiumMonthlyRub,
  BillingNotConfiguredError,
} from "../billing/yookassaClient.js";
import { verifyYookassaWebhook } from "../billing/yookassaWebhook.js";
import {
  validateYookassaPayment,
  isPaymentProcessed,
  markPaymentProcessed,
} from "../billing/yookassaPayment.js";
import { webhookRateLimiter, publicRateLimiter } from "../lib/rateLimiter.js";

// Каналы оплаты, поддерживаемые заглушкой (ADR-040/041). YooKassa живёт своей
// жизнью ниже (ADR-067) — реальный API, реальная подпись, не тот же каркас.
type BillingChannel = "apple" | "google" | "rustore" | "stripe";

// Срок начисляемого premium за один успешный платёж YooKassa — 31 день
// (месяц с запасом; ADR-067). Продлевает от max(now, текущий premiumUntil).
const PREMIUM_PERIOD_MS = 31 * 24 * 60 * 60 * 1000;

// Схема входящего payload от любого канала (общий каркас).
// expires_at — ISO 8601 строка; конвертируем в Date для premiumUntil.
const webhookBodySchema = z.object({
  user_id: z.string().min(1),
  product_id: z.string().optional(),
  // Принимаем стандартный ISO 8601 (с Z или +offset)
  expires_at: z.string().refine(
    (s) => !isNaN(new Date(s).getTime()),
    { message: "expires_at must be a valid ISO 8601 date-time string" }
  ),
});

const billingRoutes: FastifyPluginAsync = async (fastify) => {
  // Хелпер: проверка каркасного x-webhook-secret (не реальная подпись провайдера)
  function checkSecret(request: FastifyRequest, reply: FastifyReply): boolean {
    const secret = process.env["BILLING_WEBHOOK_SECRET"];
    if (!secret) {
      // Env не задан — dev-режим, пропускаем проверку
      return true;
    }
    const header = request.headers["x-webhook-secret"];
    if (header !== secret) {
      void reply.status(401).send({ error: "Invalid webhook secret" });
      return false;
    }
    return true;
  }

  // Хелпер: общая логика обработки вебхука
  async function handleWebhook(
    request: FastifyRequest,
    reply: FastifyReply,
    channel: BillingChannel
  ) {
    if (!checkSecret(request, reply)) return reply;

    const parsed = webhookBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: parsed.error.issues[0]?.message ?? "Validation error",
      });
    }

    const { user_id, expires_at } = parsed.data;
    const expiresDate = new Date(expires_at);

    const user = await prisma.user.findUnique({ where: { id: user_id } });
    if (!user) {
      return reply.status(404).send({ error: "User not found" });
    }

    // Выставляем срочный premium: premiumUntil и premiumSource
    await prisma.user.update({
      where: { id: user_id },
      data: {
        premiumUntil: expiresDate,
        premiumSource: channel,
      },
    });

    return reply.status(200).send({ ok: true });
  }

  // POST /api/v1/billing/webhook/apple
  fastify.post(
    "/api/v1/billing/webhook/apple",
    async (request, reply) => handleWebhook(request, reply, "apple")
  );

  // POST /api/v1/billing/webhook/google
  fastify.post(
    "/api/v1/billing/webhook/google",
    async (request, reply) => handleWebhook(request, reply, "google")
  );

  // POST /api/v1/billing/webhook/rustore
  fastify.post(
    "/api/v1/billing/webhook/rustore",
    async (request, reply) => handleWebhook(request, reply, "rustore")
  );

  // POST /api/v1/billing/webhook/stripe
  fastify.post(
    "/api/v1/billing/webhook/stripe",
    async (request, reply) => handleWebhook(request, reply, "stripe")
  );

  // ──────────────────────────────────────────────────────────────────────
  // ADR-067: YooKassa — реальная интеграция (не заглушка выше).
  // ──────────────────────────────────────────────────────────────────────

  // POST /api/v1/billing/yookassa/create-payment — создаёт платёж на месяц
  // Premium для текущего пользователя, возвращает confirmation_url для редиректа.
  fastify.post(
    "/api/v1/billing/yookassa/create-payment",
    { preHandler: requireAuth },
    async (request, reply) => {
      // Rate-limit по userId (не по IP — авторизованный эндпоинт).
      const rl = publicRateLimiter.check(`create-payment:${request.user.userId}`);
      if (!rl.allowed) {
        return reply.status(429).send({
          error: "Too many payment attempts — please try again in a minute.",
        });
      }

      try {
        const payment = await createPayment({
          userId: request.user.userId,
          description: "Kaizen Premium — 1 month",
          amountValue: kPremiumMonthlyRub,
        });
        return reply.status(200).send({
          payment_id: payment.id,
          confirmation_url: payment.confirmationUrl,
        });
      } catch (err) {
        if (err instanceof BillingNotConfiguredError) {
          fastify.log.warn(err.message);
          return reply.status(503).send({ error: "Billing is not configured" });
        }
        fastify.log.error(err, "YooKassa createPayment failed");
        return reply.status(502).send({
          error: "Could not start payment right now — please try again.",
        });
      }
    }
  );

  // POST /api/v1/billing/webhook/yookassa — реальные нотификации YooKassa
  // (type=notification/event=payment.succeeded/...). URL сохранён прежним
  // (было заглушкой в ADR-041), тело/проверка теперь другие.
  fastify.post("/api/v1/billing/webhook/yookassa", async (request, reply) => {
    // (a) rate-limit по IP — защита от флуда чужими запросами
    const rl = webhookRateLimiter.check(request.ip);
    if (!rl.allowed) {
      return reply.status(429).send({ error: "Too many requests" });
    }

    // (b) верификация подписи по СЫРОМУ телу (см. addContentTypeParser в app.ts).
    // Dev-режим (YOOKASSA_WEBHOOK_SECRET не задан) — verifyYookassaWebhook всегда true.
    const rawBody = request.rawBody ?? "";
    if (!verifyYookassaWebhook(rawBody, request.headers)) {
      fastify.log.warn("YooKassa webhook: signature verification failed");
      return reply.status(401).send({ error: "Invalid signature" });
    }

    // (c) валидация структуры нотификации (Zod) + фильтр по event/status.
    const result = validateYookassaPayment(request.body);
    if (!result.valid) {
      // canceled / waiting_for_capture / refund.succeeded / битая схема —
      // не трогаем premium, просто подтверждаем получение, чтобы YooKassa
      // не ретраила нотификацию бесконечно.
      fastify.log.info(`YooKassa webhook ignored: ${result.error}`);
      return reply.status(200).send({ ok: true, ignored: true });
    }

    // (d) идемпотентность — один payment_id обрабатываем ровно один раз.
    if (isPaymentProcessed(result.paymentId)) {
      return reply.status(200).send({ ok: true, idempotent: true });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: result.userId },
        select: { id: true, premiumUntil: true },
      });
      if (!user) {
        fastify.log.warn(`YooKassa webhook: unknown user_id ${result.userId}`);
        // Всегда 200 — иначе YooKassa бесконечно ретраит нотификацию.
        return reply.status(200).send({ ok: true, ignored: true });
      }

      // Продлеваем от максимума (now, текущий premiumUntil) — последовательные
      // платежи копятся, а не перезаписывают друг друга (ADR-041 pattern).
      const now = new Date();
      const base = user.premiumUntil && user.premiumUntil > now ? user.premiumUntil : now;
      const premiumUntil = new Date(base.getTime() + PREMIUM_PERIOD_MS);

      await prisma.user.update({
        where: { id: user.id },
        data: { premiumUntil, premiumSource: "yookassa" },
      });

      // Помечаем ПОСЛЕ успешного апдейта — не до (см. yookassaPayment.ts JSDoc).
      markPaymentProcessed(result.paymentId);

      return reply.status(200).send({ ok: true });
    } catch (err) {
      fastify.log.error(err, "YooKassa webhook processing failed");
      // Всегда 200 — ошибка залогирована; YooKassa не должна ретраить вечно.
      return reply.status(200).send({ ok: true, error: "internal" });
    }
  });
};

export default billingRoutes;
