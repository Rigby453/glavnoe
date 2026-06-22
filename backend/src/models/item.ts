import { randomUUID } from "node:crypto";
import type { Item, Prisma, Subtask } from "@prisma/client";

// Item с подгруженными подзадачами (Prisma include: { subtasks: true }).
export type ItemWithSubtasks = Item & { subtasks?: Subtask[] };

// Вход подзадачи из API (snake_case). id опционален для новых подзадач.
export interface SubtaskInput {
  id?: string;
  title: string;
  done?: boolean;
  sort_order?: number;
}

// Минимальный интерфейс tx/prisma-клиента для работы с подзадачами.
// Покрывает и обычный PrismaClient, и транзакционный tx (Prisma.TransactionClient).
type SubtaskDelegate = {
  subtask: {
    deleteMany: (args: {
      where: { itemId: string; id?: { notIn: string[] } };
    }) => Promise<unknown>;
    upsert: (args: {
      where: { id: string };
      create: Prisma.SubtaskUncheckedCreateInput;
      update: { title: string; done: boolean; sortOrder: number };
    }) => Promise<unknown>;
  };
};

/**
 * Синхронизирует набор подзадач задачи [itemId] с присланным массивом
 * (last-write-wins на наборе): создаёт новые, обновляет существующие по id,
 * удаляет те, что отсутствуют в присланном наборе.
 *
 * Вызывать внутри той же транзакции, что и create/update самой задачи.
 */
export async function syncSubtasks(
  client: SubtaskDelegate,
  itemId: string,
  incoming: SubtaskInput[]
): Promise<void> {
  // id новых подзадач генерирует БД (@default(uuid())), поэтому для upsert
  // нужен явный id. Для подзадач без id — генерируем здесь, чтобы знать набор
  // «оставленных» id и корректно удалить отсутствующие.
  const normalized = incoming.map((s, index) => ({
    id: s.id ?? randomUUID(),
    title: s.title,
    done: s.done ?? false,
    sortOrder: s.sort_order ?? index,
  }));

  const keepIds = normalized.map((s) => s.id);

  // Удаляем подзадачи, которых нет в присланном наборе.
  await client.subtask.deleteMany({
    where: {
      itemId,
      ...(keepIds.length > 0 ? { id: { notIn: keepIds } } : {}),
    },
  });

  // Создаём/обновляем присланные.
  for (const s of normalized) {
    await client.subtask.upsert({
      where: { id: s.id },
      create: {
        id: s.id,
        itemId,
        title: s.title,
        done: s.done,
        sortOrder: s.sortOrder,
      },
      update: {
        title: s.title,
        done: s.done,
        sortOrder: s.sortOrder,
      },
    });
  }
}

// Подзадача в ответе API — строго snake_case (контракт с app-агентом).
export interface SerializedSubtask {
  id: string;
  title: string;
  done: boolean;
  sort_order: number;
}

// Тип ответа для Item — строго по api-spec.yaml (snake_case)
export interface SerializedItem {
  id: string;
  user_id: string;
  title: string;
  type: string;
  priority: string;
  status: string;
  scheduled_at: string;
  duration_minutes: number;
  is_protected: boolean;
  recurrence_rule: string | null;
  // Напоминание: за сколько минут до scheduled_at (null = нет напоминания).
  reminder_minutes_before: number | null;
  created_at: string;
  updated_at: string;
  subtasks: SerializedSubtask[];
}

// Преобразует Prisma Subtask (camelCase) в snake_case ответ API.
export function serializeSubtask(subtask: Subtask): SerializedSubtask {
  return {
    id: subtask.id,
    title: subtask.title,
    done: subtask.done,
    sort_order: subtask.sortOrder,
  };
}

/**
 * Преобразует Prisma Item (camelCase) в snake_case ответ API.
 * Явный маппинг каждого поля — гарантирует соответствие api-spec.yaml.
 * Подзадачи (если подгружены) отдаются вложенным массивом, отсортированным
 * по sortOrder. Если subtasks не подгружены — отдаём пустой массив.
 */
export function serializeItem(item: ItemWithSubtasks): SerializedItem {
  const subtasks = (item.subtasks ?? [])
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map(serializeSubtask);

  return {
    id: item.id,
    user_id: item.userId,
    title: item.title,
    type: item.type,
    priority: item.priority,
    status: item.status,
    scheduled_at: item.scheduledAt.toISOString(),
    duration_minutes: item.durationMinutes,
    is_protected: item.isProtected,
    recurrence_rule: item.recurrenceRule ?? null,
    reminder_minutes_before: item.reminderMinutesBefore ?? null,
    created_at: item.createdAt.toISOString(),
    updated_at: item.updatedAt.toISOString(),
    subtasks,
  };
}
