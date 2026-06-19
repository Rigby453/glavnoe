import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { serializeUser } from "../models/user.js";
import { resolveEntitlement } from "../models/entitlement.js";
import { requireAuth } from "./middleware/auth.js";

// DEV-переключение тарифа без реальной оплаты. Реальные платежи (RevenueCat)
// — Phase 1. Эндпоинт нужен, чтобы тестировать premium-фичи (AI) до интеграции
// платежей. В production он недоступен (404).
const devUpgradeSchema = z.object({
  tier: z.enum(["free", "premium"]).default("premium"),
});

const subscriptionRoutes: FastifyPluginAsync = async (fastify) => {
  // DEV-only: переключение тарифа без реальной оплаты (ADR-018).
  fastify.post(
    "/api/v1/subscription/dev-upgrade",
    { preHandler: requireAuth },
    async (request, reply) => {
      // Жёсткий гейт: только вне production.
      if (process.env["NODE_ENV"] === "production") {
        return reply.status(404).send({ error: "Not found" });
      }

      const parsed = devUpgradeSchema.safeParse(request.body ?? {});
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const updated = await prisma.user.update({
        where: { id: request.user.userId },
        data: { subscriptionTier: parsed.data.tier },
      });

      return reply.status(200).send(serializeUser(updated));
    }
  );

  // ADR-041: GET /subscription/status — единый «am I premium?» эндпоинт.
  // Приложение вызывает при старте и после попытки покупки.
  // Не зависит от канала оплаты: смотрит через resolveEntitlement.
  fastify.get(
    "/api/v1/subscription/status",
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = await prisma.user.findUnique({
        where: { id: request.user.userId },
        select: {
          subscriptionTier: true,
          premiumUntil: true,
          premiumSource: true,
        },
      });
      if (!user) {
        return reply.status(404).send({ error: "Not found" });
      }

      const { isPremium, premiumUntil, source } = resolveEntitlement(user);
      return reply.status(200).send({
        is_premium: isPremium,
        premium_until: premiumUntil ? premiumUntil.toISOString() : null,
        source,
      });
    }
  );
};

export default subscriptionRoutes;
