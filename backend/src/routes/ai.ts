import type { FastifyInstance, FastifyPluginAsync, FastifyReply, FastifyRequest } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { requireAuth } from "./middleware/auth.js";
import { importScheduleFromPhoto } from "../ai/scheduleImport.js";
import { generateMorningMessage } from "../ai/morningMessage.js";
import { generateSmartPlans } from "../ai/smartRedistribute.js";
import { generateDiaryInsight } from "../ai/diaryInsight.js";

const dateOnly = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "must be YYYY-MM-DD");
const toneSchema = z.enum(["gentle", "harsh"]);

const scheduleImportSchema = z.object({
  image_base64: z.string().min(1),
  media_type: z.enum(["image/jpeg", "image/png"]),
  target_date: dateOnly,
});
const morningMessageSchema = z.object({
  pending_count: z.number().int().min(0),
  tone: toneSchema,
  user_name: z.string().optional(),
});
const redistributeSchema = z.object({ target_date: dateOnly });
const diaryInsightSchema = z.object({ tone: toneSchema });

/**
 * Premium-гейт: AI — платные фичи. Возвращает true, если можно продолжать;
 * иначе сам отправляет 403/404 и возвращает false.
 */
async function ensurePremium(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: request.user.userId },
    select: { subscriptionTier: true },
  });
  if (!user) {
    await reply.status(404).send({ error: "Not found" });
    return false;
  }
  if (user.subscriptionTier !== "premium") {
    await reply
      .status(403)
      .send({ error: "Premium feature — upgrade to use AI" });
    return false;
  }
  return true;
}

/** Ответ при сбое апстрима (нет ключа / ошибка Claude). */
function aiError(fastify: FastifyInstance, reply: FastifyReply, err: unknown, ctx: string) {
  fastify.log.error({ err }, `${ctx} AI call failed`);
  return reply
    .status(502)
    .send({ error: "AI service unavailable. Please try again later." });
}

function startOfDayUtc(d: string): Date {
  return new Date(`${d}T00:00:00.000Z`);
}

const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // AI-06: фото расписания → задачи (premium). Ничего не сохраняет.
  fastify.post(
    "/api/v1/ai/schedule-import",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = scheduleImportSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await importScheduleFromPhoto({
          imageBase64: parsed.data.image_base64,
          mediaType: parsed.data.media_type,
          targetDate: parsed.data.target_date,
        });
        return reply.status(200).send({
          items: result.items.map((i) => ({
            title: i.title,
            scheduled_at: i.scheduledAt,
          })),
        });
      } catch (err) {
        return aiError(fastify, reply, err, "schedule-import");
      }
    }
  );

  // AI-02: tone-aware утреннее сообщение (premium).
  fastify.post(
    "/api/v1/ai/morning-message",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = morningMessageSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await generateMorningMessage({
          pendingCount: parsed.data.pending_count,
          tone: parsed.data.tone,
          ...(parsed.data.user_name !== undefined
            ? { userName: parsed.data.user_name }
            : {}),
        });
        return reply.status(200).send({ message: result.message });
      } catch (err) {
        return aiError(fastify, reply, err, "morning-message");
      }
    }
  );

  // AI-01: умное перераспределение — 2-3 варианта плана (premium). Ничего не сохраняет.
  fastify.post(
    "/api/v1/ai/redistribute",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = redistributeSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      const userId = request.user.userId;
      const start = startOfDayUtc(parsed.data.target_date);
      const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

      // Просроченные pending-задачи и занятые слоты целевого дня
      const pending = await prisma.item.findMany({
        where: { userId, status: "pending", scheduledAt: { lt: start } },
        select: { id: true, title: true, priority: true, durationMinutes: true },
      });
      const dayItems = await prisma.item.findMany({
        where: { userId, scheduledAt: { gte: start, lt: end } },
        select: { scheduledAt: true },
      });
      const occupiedTimes = dayItems.map((i) =>
        i.scheduledAt.toISOString().slice(11, 16)
      );

      try {
        const { plans } = await generateSmartPlans({
          pendingItems: pending,
          occupiedTimes,
          targetDate: parsed.data.target_date,
        });
        return reply.status(200).send({
          plans: plans.map((p) => ({
            label: p.label,
            reason: p.reason,
            items: p.items.map((it) => ({
              id: it.id,
              scheduled_at: it.scheduledAt,
            })),
          })),
        });
      } catch (err) {
        return aiError(fastify, reply, err, "ai-redistribute");
      }
    }
  );

  // AI-04: инсайт по дневнику за последние записи (premium).
  fastify.post(
    "/api/v1/ai/diary-insight",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = diaryInsightSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      const logs = await prisma.dayLog.findMany({
        where: { userId: request.user.userId },
        orderBy: { date: "desc" },
        take: 7,
        select: { date: true, mood: true, note: true },
      });

      try {
        const { insight } = await generateDiaryInsight({
          tone: parsed.data.tone,
          logs: logs.map((l) => ({
            date: l.date.toISOString().slice(0, 10),
            mood: l.mood,
            note: l.note,
          })),
        });
        return reply.status(200).send({ insight });
      } catch (err) {
        return aiError(fastify, reply, err, "diary-insight");
      }
    }
  );
};

export default aiRoutes;
