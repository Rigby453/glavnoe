import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { serializeItem, syncSubtasks } from "../models/item.js";
import { requireAuth } from "./middleware/auth.js";
import { checkAndUpdateStreak } from "../engine/streaks.js";

// Zod-схема для подзадачи на входе (snake_case). id опционален для новых.
const subtaskInputSchema = z.object({
  id: z.string().uuid().optional(),
  title: z.string().min(1),
  done: z.boolean().default(false),
  sort_order: z.number().int().default(0),
});

// Zod-схема для создания Item (ITEMS-01)
const createItemSchema = z.object({
  title: z.string().min(1),
  type: z.enum(["task", "event", "exam", "deadline"]),
  scheduled_at: z.string().datetime({ offset: true }),
  priority: z.enum(["low", "medium", "high", "main"]).default("medium"),
  duration_minutes: z.number().int().default(30),
  is_protected: z.boolean().optional(),
  recurrence_rule: z.string().nullable().optional(),
  // Напоминание: за N минут до scheduled_at (null/0 = нет; макс. 10080 = неделя).
  reminder_minutes_before: z.number().int().min(0).max(10080).nullable().optional(),
  subtasks: z.array(subtaskInputSchema).optional(),
});

// Zod-схема для обновления Item (ITEMS-03) — все поля опциональные
const updateItemSchema = z.object({
  title: z.string().min(1).optional(),
  type: z.enum(["task", "event", "exam", "deadline"]).optional(),
  priority: z.enum(["low", "medium", "high", "main"]).optional(),
  status: z.enum(["pending", "done", "skipped"]).optional(),
  scheduled_at: z.string().datetime({ offset: true }).optional(),
  duration_minutes: z.number().int().optional(),
  is_protected: z.boolean().optional(),
  recurrence_rule: z.string().nullable().optional(),
  reminder_minutes_before: z.number().int().min(0).max(10080).nullable().optional(),
  subtasks: z.array(subtaskInputSchema).optional(),
});

// Zod-схема для query-параметров (ITEMS-02)
const listItemsQuerySchema = z.object({
  from: z.string().datetime({ offset: true }).optional(),
  to: z.string().datetime({ offset: true }).optional(),
});

const itemsRoutes: FastifyPluginAsync = async (fastify) => {
  // ITEMS-01: POST /api/v1/items — создать задачу
  fastify.post(
    "/api/v1/items",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = createItemSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const data = parsed.data;
      const userId = request.user.userId;

      // Если priority=main → is_protected принудительно true
      const isProtected =
        data.priority === "main" ? true : (data.is_protected ?? false);

      const item = await prisma.$transaction(async (tx) => {
        const created = await tx.item.create({
          data: {
            userId,
            title: data.title,
            type: data.type,
            priority: data.priority,
            scheduledAt: new Date(data.scheduled_at),
            durationMinutes: data.duration_minutes,
            isProtected,
            recurrenceRule: data.recurrence_rule ?? null,
            reminderMinutesBefore: data.reminder_minutes_before ?? null,
          },
        });

        if (data.subtasks !== undefined) {
          await syncSubtasks(tx, created.id, data.subtasks);
        }

        // Перечитываем с подзадачами для ответа (snake_case, отсортированы по sortOrder)
        return tx.item.findUniqueOrThrow({
          where: { id: created.id },
          include: { subtasks: true },
        });
      });

      return reply.status(201).send(serializeItem(item));
    }
  );

  // ITEMS-02: GET /api/v1/items?from=&to= — список задач в диапазоне дат
  fastify.get(
    "/api/v1/items",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsedQuery = listItemsQuerySchema.safeParse(request.query);
      if (!parsedQuery.success) {
        return reply.status(400).send({
          error:
            parsedQuery.error.issues[0]?.message ?? "Invalid query parameters",
        });
      }

      const { from, to } = parsedQuery.data;
      const userId = request.user.userId;

      const items = await prisma.item.findMany({
        where: {
          userId,
          ...(from !== undefined || to !== undefined
            ? {
                scheduledAt: {
                  ...(from !== undefined ? { gte: new Date(from) } : {}),
                  ...(to !== undefined ? { lte: new Date(to) } : {}),
                },
              }
            : {}),
        },
        orderBy: { scheduledAt: "asc" },
        include: { subtasks: true },
      });

      return reply.status(200).send(items.map(serializeItem));
    }
  );

  // ITEMS-03: PATCH /api/v1/items/:id — частичное обновление задачи
  fastify.patch(
    "/api/v1/items/:id",
    { preHandler: requireAuth },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const userId = request.user.userId;

      // Валидируем тело запроса
      const parsed = updateItemSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      // Проверяем существование и владение — если нет или чужая → 404
      // (api-spec.yaml: NotFound "also returned for items owned by another user")
      const existing = await prisma.item.findUnique({ where: { id } });
      if (!existing || existing.userId !== userId) {
        return reply.status(404).send({ error: "Not found" });
      }

      const data = parsed.data;

      // Строим объект для частичного обновления (snake_case → camelCase)
      const updateData: {
        title?: string;
        type?: string;
        priority?: string;
        status?: string;
        scheduledAt?: Date;
        durationMinutes?: number;
        isProtected?: boolean;
        recurrenceRule?: string | null;
        reminderMinutesBefore?: number | null;
      } = {};

      if (data.title !== undefined) updateData.title = data.title;
      if (data.type !== undefined) updateData.type = data.type;
      if (data.priority !== undefined) {
        updateData.priority = data.priority;
        // Если priority=main → is_protected принудительно true
        if (data.priority === "main") {
          updateData.isProtected = true;
        }
      }
      if (data.status !== undefined) updateData.status = data.status;
      if (data.scheduled_at !== undefined)
        updateData.scheduledAt = new Date(data.scheduled_at);
      if (data.duration_minutes !== undefined)
        updateData.durationMinutes = data.duration_minutes;
      if (data.is_protected !== undefined)
        updateData.isProtected = data.is_protected;
      if ("recurrence_rule" in data)
        updateData.recurrenceRule = data.recurrence_rule ?? null;
      if ("reminder_minutes_before" in data)
        updateData.reminderMinutesBefore = data.reminder_minutes_before ?? null;

      const updated = await prisma.$transaction(async (tx) => {
        await tx.item.update({
          where: { id },
          data: updateData,
        });

        // Подзадачи: если присланы — синхронизируем набор (upsert + удаление отсутствующих).
        if (data.subtasks !== undefined) {
          await syncSubtasks(tx, id, data.subtasks);
        }

        // Перечитываем с подзадачами для ответа
        return tx.item.findUniqueOrThrow({
          where: { id },
          include: { subtasks: true },
        });
      });

      // Если status изменился на 'done' — обновляем серию (детерминированно, до ответа)
      if (data.status === "done" && existing.status !== "done") {
        // Используем scheduledAt обновлённой задачи как дату для streak
        const itemDate = updated.scheduledAt;
        // Ошибка пересчёта серии не должна ронять уже успешный PATCH — логируем и продолжаем
        try {
          await checkAndUpdateStreak(userId, itemDate);
        } catch (err: unknown) {
          fastify.log.error(
            { err },
            "checkAndUpdateStreak failed for userId=%s",
            userId
          );
        }
      }

      return reply.status(200).send(serializeItem(updated));
    }
  );

  // ITEMS-04: DELETE /api/v1/items/:id — удалить задачу (только владелец)
  fastify.delete(
    "/api/v1/items/:id",
    { preHandler: requireAuth },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const userId = request.user.userId;

      // Проверяем существование и владение — если нет или чужая → 404
      const existing = await prisma.item.findUnique({ where: { id } });
      if (!existing || existing.userId !== userId) {
        return reply.status(404).send({ error: "Not found" });
      }

      await prisma.item.delete({ where: { id } });

      // Надгробие — чтобы удаление доехало до других устройств через /sync.
      await prisma.tombstone.upsert({
        where: { userId_itemId: { userId, itemId: id } },
        create: { userId, itemId: id },
        update: {},
      });

      // 204 No Content — без тела
      return reply.status(204).send();
    }
  );
};

export default itemsRoutes;
