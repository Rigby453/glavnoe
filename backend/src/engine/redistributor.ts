import type { Item } from "@prisma/client";
import prisma from "../models/prisma.js";

// Веса приоритетов для сортировки: main=4, high=3, medium=2, low=1
const PRIORITY_WEIGHT: Record<string, number> = {
  main: 4,
  high: 3,
  medium: 2,
  low: 1,
};

/**
 * Возвращает начало дня (00:00:00.000 UTC) для переданной даты.
 */
function startOfDayUTC(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 0, 0, 0, 0)
  );
}

/**
 * Возвращает конец дня (23:59:59.999 UTC) для переданной даты.
 */
function endOfDayUTC(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 23, 59, 59, 999)
  );
}

/**
 * Генерирует 30-минутные слоты для target day в диапазоне 08:00–22:00 UTC.
 * Итого: (22 - 8) * 2 = 28 слотов.
 */
function generateDaySlots(targetDate: Date): Date[] {
  const slots: Date[] = [];
  const y = targetDate.getUTCFullYear();
  const m = targetDate.getUTCMonth();
  const d = targetDate.getUTCDate();

  // Окно 08:00–21:30 — последний слот начинается в 21:30, заканчивается в 22:00
  for (let hour = 8; hour < 22; hour++) {
    slots.push(new Date(Date.UTC(y, m, d, hour, 0, 0, 0)));
    slots.push(new Date(Date.UTC(y, m, d, hour, 30, 0, 0)));
  }

  return slots;
}

/**
 * Округляет время вниз до ближайшего 30-минутного слота (UTC).
 * Например: 09:17 → 09:00, 09:45 → 09:30.
 */
function floorToSlot(date: Date): Date {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth();
  const d = date.getUTCDate();
  const h = date.getUTCHours();
  const min = date.getUTCMinutes() < 30 ? 0 : 30;
  return new Date(Date.UTC(y, m, d, h, min, 0, 0));
}

/**
 * ENGINE-01: Предлагает перераспределение просроченных pending-задач на target day.
 *
 * Логика:
 * 1. Получаем все pending-задачи пользователя с scheduledAt < startOfDay(targetDate).
 * 2. Сортируем по весу приоритета DESC, при равенстве — по scheduledAt ASC (stable).
 * 3. Получаем задачи целевого дня, строим множество занятых 30-минутных слотов.
 * 4. Генерируем кандидаты 08:00–22:00 UTC (28 слотов), вычитаем занятые.
 * 5. Итерируем в порядке приоритета:
 *    - is_protected → skipped.
 *    - Есть свободный слот → proposed (с новым scheduledAt), слот потребляем.
 *    - Нет слотов → skipped.
 * 6. Возвращаем { proposed, skipped }. НИЧЕГО не сохраняется в БД.
 *
 * @param userId - идентификатор пользователя
 * @param targetDate - целевой день (время игнорируется, используется только дата)
 */
export async function proposeRedistribution(
  userId: string,
  targetDate: Date
): Promise<{ proposed: Item[]; skipped: Item[] }> {
  const start = startOfDayUTC(targetDate);
  const end = endOfDayUTC(targetDate);

  // 1. Просроченные pending-задачи (scheduledAt строго до начала target day)
  const pendingItems = await prisma.item.findMany({
    where: {
      userId,
      status: "pending",
      scheduledAt: {
        lt: start,
      },
    },
    orderBy: { scheduledAt: "asc" }, // вторичная сортировка при одинаковом приоритете
  });

  // 2. Стабильная сортировка по весу приоритета DESC (tie-break: scheduledAt ASC уже установлен выше)
  pendingItems.sort(
    (a, b) =>
      (PRIORITY_WEIGHT[b.priority] ?? 0) - (PRIORITY_WEIGHT[a.priority] ?? 0)
  );

  // 3. Задачи целевого дня — нужны для определения занятых слотов.
  //    Берём и длительность: каждая задача занимает ceil(duration/30) слотов.
  const dayItems = await prisma.item.findMany({
    where: {
      userId,
      scheduledAt: {
        gte: start,
        lte: end,
      },
    },
    select: { scheduledAt: true, durationMinutes: true },
  });

  // Сколько подряд идущих 30-мин слотов перекрывает задача по длительности
  // (минимум 1). duration null/0 → 1 слот (30 мин).
  const slotsFor = (durationMinutes: number | null | undefined): number => {
    const d = durationMinutes ?? 0;
    return d <= 0 ? 1 : Math.ceil(d / 30);
  };

  // Все стартовые слоты окна 08:00–21:30 (последний кончается в 22:00).
  const allSlots = generateDaySlots(targetDate);

  // 4. Множество занятых слотов: помечаем ВСЕ слоты, перекрываемые каждой
  //    уже стоящей на дне задачей по её длительности (а не один слот).
  const occupiedSlotKeys = new Set<string>();
  const occupyRun = (startSlot: Date, count: number): void => {
    for (let k = 0; k < count; k++) {
      const slot = new Date(startSlot.getTime() + k * 30 * 60_000);
      occupiedSlotKeys.add(slot.toISOString());
    }
  };
  for (const i of dayItems) {
    occupyRun(floorToSlot(i.scheduledAt), slotsFor(i.durationMinutes));
  }

  // Проверка: свободны ли count подряд идущих слотов начиная с allSlots[startIdx],
  // и влезают ли они целиком в окно (до 22:00).
  const runFree = (startIdx: number, count: number): boolean => {
    if (startIdx + count > allSlots.length) return false;
    for (let k = 0; k < count; k++) {
      if (occupiedSlotKeys.has(allSlots[startIdx + k]!.toISOString())) {
        return false;
      }
    }
    return true;
  };

  // 5. Распределяем задачи: для каждой ищем первый старт, где свободны все
  //    нужные ей подряд идущие слоты внутри окна.
  const proposed: Item[] = [];
  const skipped: Item[] = [];

  for (const item of pendingItems) {
    if (item.isProtected) {
      // Защищённые задачи никогда не перемещаются
      skipped.push(item);
      continue;
    }

    const need = slotsFor(item.durationMinutes);
    let placed = false;
    for (let startIdx = 0; startIdx + need <= allSlots.length; startIdx++) {
      if (runFree(startIdx, need)) {
        const assignedSlot = allSlots[startIdx]!;
        occupyRun(assignedSlot, need); // резервируем все занятые слоты
        // Копия Prisma-типа с новым scheduledAt (НЕ сохраняем в БД)
        proposed.push({ ...item, scheduledAt: assignedSlot });
        placed = true;
        break;
      }
    }

    if (!placed) {
      // Нет окна нужной длины — задача не влезла в день
      skipped.push(item);
    }
  }

  return { proposed, skipped };
}
