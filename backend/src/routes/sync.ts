import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { serializeItem } from "../models/item.js";
import { serializeWaterLog } from "../models/waterLog.js";
import { serializeFoodLog } from "../models/foodLog.js";
import { serializeDayLog } from "../models/dayLog.js";
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

// Zod-схема для одного WaterLog (append-only событие)
const syncWaterLogSchema = z.object({
  id: z.string().uuid(),
  // user_id игнорируется (сервер берёт из JWT)
  user_id: z.string().optional(),
  amount_ml: z.number().int(),
  logged_at: z.string().datetime({ offset: true }),
});

// Zod-схема для одного DayLog (запись дневника; ключ — userId+date)
const dateOnly = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "must be YYYY-MM-DD");

// Zod-схема для одного FoodLog (append-only событие, ADR-024)
const syncFoodLogSchema = z.object({
  id: z.string().uuid(),
  // user_id игнорируется (сервер берёт из JWT)
  user_id: z.string().optional(),
  date: dateOnly,
  meal: z.enum(["breakfast", "lunch", "dinner", "snack"]),
  name: z.string().min(1),
  grams: z.number(),
  calories: z.number().nullable().optional(),
  protein: z.number().nullable().optional(),
  fat: z.number().nullable().optional(),
  carbs: z.number().nullable().optional(),
  sugar: z.number().nullable().optional(),
  fiber: z.number().nullable().optional(),
  created_at: z.string().datetime({ offset: true }),
});
const syncDayLogSchema = z.object({
  id: z.string().uuid().optional(),
  user_id: z.string().optional(),
  date: dateOnly,
  mood: z.number().int().min(1).max(5).nullable().optional(),
  note: z.string().nullable().optional(),
  updated_at: z.string().datetime({ offset: true }),
});

// Zod-схема для тела sync-запроса
const syncRequestSchema = z.object({
  items: z.array(syncItemSchema),
  water_logs: z.array(syncWaterLogSchema).optional(),
  food_logs: z.array(syncFoodLogSchema).optional(),
  day_logs: z.array(syncDayLogSchema).optional(),
  // id задач, удалённых на клиенте (offline-first tombstones) — сервер их удаляет
  deleted_item_ids: z.array(z.string().uuid()).optional(),
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

      const {
        items: incomingItems,
        water_logs: incomingWater,
        food_logs: incomingFood,
        day_logs: incomingDayLogs,
        deleted_item_ids: deletedItemIds,
        last_sync_at,
      } = parsed.data;
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

      // WaterLog — append-only: создаём отсутствующие, существующие не трогаем.
      if (incomingWater && incomingWater.length > 0) {
        await prisma.$transaction(async (tx) => {
          for (const w of incomingWater) {
            const existing = await tx.waterLog.findUnique({
              where: { id: w.id },
            });
            if (existing) continue; // идемпотентность: запись неизменяема
            await tx.waterLog.create({
              data: {
                id: w.id, // клиентский UUID для идемпотентности
                userId, // всегда из токена
                amountMl: w.amount_ml,
                loggedAt: new Date(w.logged_at),
              },
            });
          }
        });
      }

      // FoodLog — append-only (ADR-024): создаём отсутствующие, существующие
      // не трогаем (идемпотентность по клиентскому UUID, как water).
      if (incomingFood && incomingFood.length > 0) {
        await prisma.$transaction(async (tx) => {
          for (const f of incomingFood) {
            const existing = await tx.foodLog.findUnique({
              where: { id: f.id },
            });
            if (existing) continue; // запись неизменяема
            await tx.foodLog.create({
              data: {
                id: f.id, // клиентский UUID для идемпотентности
                userId, // всегда из токена
                date: new Date(`${f.date}T00:00:00.000Z`),
                meal: f.meal,
                name: f.name,
                grams: f.grams,
                calories: f.calories ?? null,
                protein: f.protein ?? null,
                fat: f.fat ?? null,
                carbs: f.carbs ?? null,
                sugar: f.sugar ?? null,
                fiber: f.fiber ?? null,
                createdAt: new Date(f.created_at),
              },
            });
          }
        });
      }

      // DayLog — одна запись на (userId, date); last-write-wins по updated_at.
      if (incomingDayLogs && incomingDayLogs.length > 0) {
        for (const d of incomingDayLogs) {
          const incomingUpdatedAt = new Date(d.updated_at);
          if (isNaN(incomingUpdatedAt.getTime())) continue;
          const dateObj = new Date(`${d.date}T00:00:00.000Z`);
          const existing = await prisma.dayLog.findUnique({
            where: { userId_date: { userId, date: dateObj } },
          });
          if (existing) {
            // Обновляем, только если входящая версия новее серверной.
            if (incomingUpdatedAt > existing.updatedAt) {
              await prisma.dayLog.update({
                where: { id: existing.id },
                data: {
                  ...(d.mood !== undefined ? { mood: d.mood } : {}),
                  ...(d.note !== undefined ? { note: d.note } : {}),
                },
              });
            }
          } else {
            await prisma.dayLog.create({
              data: {
                userId,
                date: dateObj,
                mood: d.mood ?? null,
                note: d.note ?? null,
              },
            });
          }
        }
      }

      // Удаления с клиента: убираем только свои задачи (ownership через userId)
      // и пишем надгробия, чтобы удаление доехало до других устройств.
      if (deletedItemIds && deletedItemIds.length > 0) {
        await prisma.item.deleteMany({
          where: { id: { in: deletedItemIds }, userId },
        });
        await prisma.tombstone.createMany({
          data: deletedItemIds.map((itemId) => ({ userId, itemId })),
          skipDuplicates: true,
        });
      }

      // Возвращаем все items этого пользователя обновлённые после last_sync_at
      const serverUpdated = await prisma.item.findMany({
        where: {
          userId,
          updatedAt: { gt: lastSyncDate },
        },
        orderBy: { scheduledAt: "asc" },
      });

      // WaterLog созданные после last_sync_at (loggedAt ≈ время создания)
      const serverUpdatedWater = await prisma.waterLog.findMany({
        where: {
          userId,
          loggedAt: { gt: lastSyncDate },
        },
        orderBy: { loggedAt: "asc" },
      });

      // FoodLog, созданные после last_sync_at (createdAt — маркер изменений)
      const serverUpdatedFood = await prisma.foodLog.findMany({
        where: {
          userId,
          createdAt: { gt: lastSyncDate },
        },
        orderBy: { createdAt: "asc" },
      });

      // DayLog, изменённые после last_sync_at
      const serverUpdatedDayLogs = await prisma.dayLog.findMany({
        where: {
          userId,
          updatedAt: { gt: lastSyncDate },
        },
        orderBy: { date: "asc" },
      });

      // Удаления, пришедшие с ДРУГИХ устройств после last_sync_at (надгробия).
      // Исключаем те, что прислал сам этот клиент в этом запросе.
      const incomingDeleteSet = new Set(deletedItemIds ?? []);
      const tombstones = await prisma.tombstone.findMany({
        where: { userId, deletedAt: { gt: lastSyncDate } },
        orderBy: { deletedAt: "asc" },
        select: { itemId: true },
      });
      const deletedToReturn = tombstones
        .map((t) => t.itemId)
        .filter((id) => !incomingDeleteSet.has(id));

      return reply.status(200).send({
        updated_items: serverUpdated.map(serializeItem),
        updated_water_logs: serverUpdatedWater.map(serializeWaterLog),
        updated_food_logs: serverUpdatedFood.map(serializeFoodLog),
        updated_day_logs: serverUpdatedDayLogs.map(serializeDayLog),
        deleted_item_ids: deletedToReturn,
      });
    }
  );
};

export default syncRoutes;
