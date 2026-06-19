/**
 * ADR-041: заглушки вебхуков биллинга — каркас серверного entitlement.
 *
 * Каналы: apple | google | rustore | stripe | yookassa
 * Тело (snake_case): { user_id, product_id?, expires_at (ISO) }
 * Действие: выставить User.premiumUntil = expires_at, User.premiumSource = <канал>.
 *
 * ВАЖНО: реальные вебхуки требуют проверки подписи каждого провайдера.
 * TODO при появлении ключей (ADR-041):
 *   - Apple: проверить подпись JWS App Store Server Notifications V2
 *   - Google: проверить JWT от Google Play с ключом сервисного аккаунта
 *   - RuStore: проверить HMAC-подпись по BILLING_RUSTORE_SECRET
 *   - Stripe: проверить Stripe-Signature через stripe.webhooks.constructEvent
 *   - YooKassa: проверить IP + SHA-1 подпись события
 *
 * Защита каркаса: если задан env BILLING_WEBHOOK_SECRET,
 * требуем заголовок x-webhook-secret равный ему (иначе 401).
 * Если env не задан — пропускаем (dev-режим).
 */

import type { FastifyPluginAsync, FastifyRequest, FastifyReply } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";

// Каналы оплаты, поддерживаемые entitlement-системой (ADR-040)
type BillingChannel = "apple" | "google" | "rustore" | "stripe" | "yookassa";

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

  // POST /api/v1/billing/webhook/yookassa
  fastify.post(
    "/api/v1/billing/webhook/yookassa",
    async (request, reply) => handleWebhook(request, reply, "yookassa")
  );
};

export default billingRoutes;
