import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { serializeItem } from "../models/item.js";
import { requireAuth } from "./middleware/auth.js";
import { checkAndUpdateStreak } from "../engine/streaks.js";

// Zod-схема для одного Item в теле sync-запроса
// Принимаем полную форму Item (все поля опциональны кроме id)
const syncItemSchema = z.object({
  id: z.string().uuid(),
  // user_id игнорируется (сервер берёт userId из JWT). Не требуем uuid —
  // офлайн-клиент до первой авторизации шлёт 'local'.
  user_id: z.string().optional(),
  title: z.string().min(1).optional(),
  type: z.enum(["task", "event", "exam", "deadline"]).optional(),
  priority: z.enum(["low", "medium", "high", "main"]).optional(),
  status: z.enum(["pending", "done", "skipped"]).optional(),
  scheduled_at: z.string().datetime({ offset: true }).optional(),
  duration_minutes: z.number().int().optional(),
  is_protected: z.boolean().optional(),
  recurrence_rule: z.string().nullable().optional(),
  created_at: z.string().datetime({ offset: true }).optional(),
  updated_at: z.string().datetime({ offset: true }).optional(),
});

// Zod-схема для тела sync-запроса
const syncRequestSchema = z.object({
  items: z.array(syncItemSchema),
  last_sync_at: z.string().datetime({ offset: true }),
});

const syncRoutes: FastifyPluginAsync = async (fastify) => {
  // SYNC-01: POST /api/v1/sync — last-write-wins синхронизация
  fastify.post(
    "/api/v1/sync",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = syncRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const { items: incomingItems, last_sync_at } = parsed.data;
      const userId = request.user.userId;

      // Валидируем last_sync_at — уже гарантировано Zod, но Date() может дать NaN
      const lastSyncDate = new Date(last_sync_at);
      if (isNaN(lastSyncDate.getTime())) {
        return reply.status(400).send({ error: "Invalid last_sync_at" });
      }

      // Дни (по дате scheduledAt), в которые main-задача перешла в 'done' в этом
      // sync. После коммита по ним пересчитаем серию (rule-based, как в PATCH).
      const completedMainDays: Date[] = [];

      // Обрабатываем каждый incoming item в транзакции
      await prisma.$transaction(async (tx) => {
        for (const incoming of incomingItems) {
          const existing = await tx.item.findUnique({
            where: { id: incoming.id },
          });

          if (existing) {
            // Если принадлежит другому пользователю — пропускаем (безопасность)
            if (existing.userId !== userId) continue;

            // Сравниваем updated_at: если входящее новее — обновляем сервер
            if (incoming.updated_at !== undefined) {
              const incomingUpdatedAt = new Date(incoming.updated_at);
              if (
                !isNaN(incomingUpdatedAt.getTime()) &&
                incomingUpdatedAt > existing.updatedAt
              ) {
                // Обновляем только поля которые пришли (и не пустые)
                await tx.item.update({
                  where: { id: incoming.id },
                  data: {
                    ...(incoming.title !== undefined
                      ? { title: incoming.title }
                      : {}),
                    ...(incoming.type !== undefined
                      ? { type: incoming.type }
                      : {}),
                    ...(incoming.priority !== undefined
                      ? {
                          priority: incoming.priority,
                          // Если priority=main → is_protected принудительно true
                          ...(incoming.priority === "main"
                            ? { isProtected: true }
                            : {}),
                        }
                      : {}),
                    ...(incoming.status !== undefined
                      ? { status: incoming.status }
                      : {}),
                    ...(incoming.scheduled_at !== undefined
                      ? { scheduledAt: new Date(incoming.scheduled_at) }
                      : {}),
                    ...(incoming.duration_minutes !== undefined
                      ? { durationMinutes: incoming.duration_minutes }
                      : {}),
                    ...(incoming.is_protected !== undefined &&
                    incoming.priority !== "main"
                      ? { isProtected: incoming.is_protected }
                      : {}),
                    ...("recurrence_rule" in incoming
                      ? { recurrenceRule: incoming.recurrence_rule ?? null }
                      : {}),
                  },
                });

                // Переход main-задачи в 'done' → запоминаем день для пересчёта серии.
                // Эффективные значения: если поле не пришло — берём серверное.
                const effPriority = incoming.priority ?? existing.priority;
                if (
                  incoming.status === "done" &&
                  existing.status !== "done" &&
                  effPriority === "main"
                ) {
                  completedMainDays.push(
                    incoming.scheduled_at !== undefined
                      ? new Date(incoming.scheduled_at)
                      : existing.scheduledAt
                  );
                }
              }
              // Иначе: серверная версия новее или равна → ничего не делаем
            }
          } else {
            // Item не существует — создаём, user_id из токена (игнорируем payload user_id)
            // Требуются минимальные поля: title, type, scheduled_at
            if (
              incoming.title !== undefined &&
              incoming.type !== undefined &&
              incoming.scheduled_at !== undefined
            ) {
              const isProtected =
                incoming.priority === "main"
                  ? true
                  : (incoming.is_protected ?? false);

              await tx.item.create({
                data: {
                  id: incoming.id, // сохраняем клиентский UUID для идемпотентности
                  userId, // всегда из токена
                  title: incoming.title,
                  type: incoming.type,
                  priority: incoming.priority ?? "medium",
                  status: incoming.status ?? "pending",
                  scheduledAt: new Date(incoming.scheduled_at),
                  durationMinutes: incoming.duration_minutes ?? 30,
                  isProtected,
                  recurrenceRule: incoming.recurrence_rule ?? null,
                },
              });

              // Новая main-задача, созданная сразу как 'done' → день для пересчёта серии.
              if (incoming.status === "done" && incoming.priority === "main") {
                completedMainDays.push(new Date(incoming.scheduled_at));
              }
            }
            // Если нет обязательных полей — пропускаем некорректный item
          }
        }
      });

      // После коммита пересчитываем серию по затронутым дням (rule-based, без AI).
      // Дедуплицируем по UTC-дню и идём по возрастанию, чтобы backlog (вчера→сегодня)
      // считался в правильном порядке. Ошибка пересчёта не должна ронять sync.
      if (completedMainDays.length > 0) {
        const uniqueDays = new Map<string, Date>();
        for (const d of completedMainDays) {
          if (isNaN(d.getTime())) continue;
          const key = d.toISOString().slice(0, 10);
          if (!uniqueDays.has(key)) uniqueDays.set(key, d);
        }
        const sortedDays = [...uniqueDays.values()].sort(
          (a, b) => a.getTime() - b.getTime()
        );
        for (const day of sortedDays) {
          try {
            await checkAndUpdateStreak(userId, day);
          } catch (err: unknown) {
            request.log.error(
              { err },
              "checkAndUpdateStreak (sync) failed for userId=%s",
              userId
            );
          }
        }
      }

      // Возвращаем все items этого пользователя обновлённые после last_sync_at
      const serverUpdated = await prisma.item.findMany({
        where: {
          userId,
          updatedAt: { gt: lastSyncDate },
        },
        orderBy: { scheduledAt: "asc" },
      });

      return reply.status(200).send({
        updated_items: serverUpdated.map(serializeItem),
      });
    }
  );
};

export default syncRoutes;
