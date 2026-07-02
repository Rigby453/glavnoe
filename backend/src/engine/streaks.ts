import prisma from "../models/prisma.js";

/**
 * STREAK-02: Внутренний хелпер — обновляет серию за конкретный день.
 * Вызывается из PATCH /items/:id и из /sync, когда статус задачи меняется на 'done'.
 * Правила только rule-based, без AI.
 *
 * Решение владельца — стрик v2 (docs/TASKS-2026-07-02.md §8). ЗЕРКАЛО Dart-
 * реализации в app/lib/services/streak/streak_service.dart (_dayStatus) —
 * оба должны оставаться в лок-степе. Предикат «день завершён» смотрит на
 * не-skipped items дня ("counted"):
 * 1. Берём ВСЕ items (любой priority) за этот день.
 * 2. Нет ни одного item за день → день НЕЙТРАЛЬНЫЙ: не растит и не сбрасывает
 *    серию, выходим без изменений (просто отсутствие плана не должно карать
 *    пользователя).
 * 3. status='skipped' «не мешает»: skipped-items исключаются из counted. НО
 *    если после исключения skipped ничего не остаётся (то есть ВСЕ items дня
 *    были skipped, ни одного done) — день тоже нейтральный, а не засчитанный:
 *    иначе можно было бы «накрутить» серию, просто пропуская всё, ничего не
 *    сделав.
 * 4. Есть хотя бы один item priority='main' среди counted (mains) → день
 *    ЗАСЧИТАН, если сделаны ВСЕ mains (status='done'). Не-main items НЕ
 *    блокируют зачёт, когда main есть — «сделал главное» важнее полного
 *    списка.
 * 5. Mains нет вообще → день ЗАСЧИТАН, если недоделанных (status != 'done')
 *    среди counted не больше max(1, floor(counted.length * 0.1)) — то есть
 *    допускается «почти всё» (~90%+), но минимум одна задача прощается
 *    ВСЕГДА (короткие дни не наказываются строже длинных).
 * 6. Иначе — день НЕ завершён, выходим без изменений (пересчёт сработает
 *    позже, на следующем завершённом дне — freeze/грейс ниже не меняются).
 *
 * Далее (без изменений):
 * 7. Загружаем или создаём Streak.
 * 8. Сравниваем lastCompletedDate с today/yesterday:
 *    - Если уже today → idempotent, выходим.
 *    - Если yesterday → current += 1.
 *    - Если старше/null + freezeCount > 0 → freezeCount -= 1, current без изменений.
 *    - Иначе → current = 1.
 * 9. longest = max(longest, current). lastCompletedDate = today. Сохраняем.
 */
export async function checkAndUpdateStreak(
  userId: string,
  date: Date
): Promise<void> {
  // Вычисляем начало и конец дня по UTC
  const startOfDay = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 0, 0, 0, 0)
  );
  const endOfDay = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 23, 59, 59, 999)
  );

  // Получаем ВСЕ задачи/события за этот день (любой priority) — предикат v2
  // смотрит на priority, поэтому priority ОБЯЗАТЕЛЬНО в select (иначе ветка
  // "нет main" не сработает — см. doc-комментарий выше).
  const dayItems = await prisma.item.findMany({
    where: {
      userId,
      scheduledAt: {
        gte: startOfDay,
        lte: endOfDay,
      },
    },
    select: { id: true, status: true, priority: true },
  });

  // Нет запланированного на этот день — нейтральный день, серия не меняется.
  if (dayItems.length === 0) return;

  // skipped «не мешает»: исключаем из требования, но если ПОСЛЕ исключения
  // ничего не осталось (все задачи были skipped) — тоже нейтральный день, а
  // не засчитанный (см. комментарий выше, п.3).
  const countedItems = dayItems.filter((item) => item.status !== "skipped");
  if (countedItems.length === 0) return;

  // Предикат v2 (см. doc-комментарий выше, п.4-5): main-задачи гейтят день,
  // если есть хотя бы одна; иначе прощаем недоделанное в пределах ~10% (но
  // минимум одну задачу — всегда).
  const mains = countedItems.filter((item) => item.priority === "main");
  let dayComplete: boolean;
  if (mains.length > 0) {
    dayComplete = mains.every((item) => item.status === "done");
  } else {
    const undone = countedItems.filter((item) => item.status !== "done").length;
    const tenPercent = Math.floor(countedItems.length * 0.1);
    const forgiveness = Math.max(1, tenPercent);
    dayComplete = undone <= forgiveness;
  }
  if (!dayComplete) return;

  // Нормализуем дату (только день, без времени) для сравнения
  const todayStr = startOfDay.toISOString().slice(0, 10);
  const yesterdayDate = new Date(startOfDay);
  yesterdayDate.setUTCDate(yesterdayDate.getUTCDate() - 1);
  const yesterdayStr = yesterdayDate.toISOString().slice(0, 10);

  // Загружаем или создаём Streak
  let streak = await prisma.streak.findUnique({ where: { userId } });
  if (!streak) {
    streak = await prisma.streak.create({
      data: { userId, current: 0, longest: 0, freezeCount: 0 },
    });
  }

  // Если lastCompletedDate уже равна today → idempotent, не считаем повторно
  const lastStr = streak.lastCompletedDate
    ? streak.lastCompletedDate.toISOString().slice(0, 10)
    : null;

  if (lastStr === todayStr) return;

  let newCurrent = streak.current;
  let newFreezeCount = streak.freezeCount;

  if (lastStr === yesterdayStr) {
    // Вчера завершили — продолжаем серию
    newCurrent += 1;
  } else if (streak.freezeCount > 0) {
    // Пропустили день, но есть заморозка — используем её, серия сохраняется
    newFreezeCount -= 1;
    // current не меняется
  } else {
    // Давно не было или null и нет заморозки — серия сбрасывается до 1
    newCurrent = 1;
  }

  const newLongest = Math.max(streak.longest, newCurrent);

  // Сохраняем обновлённый streak
  await prisma.streak.update({
    where: { userId },
    data: {
      current: newCurrent,
      longest: newLongest,
      freezeCount: newFreezeCount,
      lastCompletedDate: startOfDay,
    },
  });
}
