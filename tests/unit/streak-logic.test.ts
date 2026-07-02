/**
 * QA-03: Streak logic (unit).
 * Тестирует checkAndUpdateStreak напрямую: сеем main-задачи и предсостояние
 * Streak через prisma, вызываем хелпер, проверяем результат.
 */
import { checkAndUpdateStreak } from '../../backend/src/engine/streaks';
import prisma from '../../backend/src/models/prisma';
import { cleanupUser } from '../helpers';

const today = new Date('2026-06-10T12:00:00.000Z');
const yesterdayUtc = new Date(Date.UTC(2026, 5, 9));
const threeDaysAgoUtc = new Date(Date.UTC(2026, 5, 7));

async function createUserDirect(): Promise<string> {
  const user = await prisma.user.create({
    data: {
      email: `streak_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`,
      passwordHash: 'x',
      name: 'Streak Test',
    },
  });
  return user.id;
}

async function createMainItem(
  userId: string,
  status: 'pending' | 'done'
): Promise<void> {
  await prisma.item.create({
    data: {
      userId,
      title: 'main task',
      type: 'task',
      priority: 'main',
      status,
      scheduledAt: new Date(Date.UTC(2026, 5, 10, 9, 0, 0)),
      isProtected: true,
    },
  });
}

/**
 * Предикат «день завершён» v2 (docs/TASKS-2026-07-02.md §8): смотрит на ВСЕ
 * items дня (любой priority), не только priority=main. Универсальный хелпер
 * для тестов ниже — произвольный priority/status на дату 2026-06-10
 * (переменная `today`).
 */
async function createItem(
  userId: string,
  priority: 'low' | 'medium' | 'high' | 'main',
  status: 'pending' | 'done' | 'skipped'
): Promise<void> {
  await prisma.item.create({
    data: {
      userId,
      title: `${priority} task`,
      type: 'task',
      priority,
      status,
      scheduledAt: new Date(Date.UTC(2026, 5, 10, 9, 0, 0)),
      isProtected: priority === 'main',
    },
  });
}

/**
 * Создаёт [count] задач на день 2026-06-10: первые [doneCount] — 'done',
 * остальные — restStatus (default 'pending'). Для тестов forgiveness v2
 * (недоделанных <= max(1, floor(counted.length * 0.1))) и skipped-денаминатора.
 */
async function createBatch(
  userId: string,
  count: number,
  doneCount: number,
  opts: {
    priority?: 'low' | 'medium' | 'high' | 'main';
    restStatus?: 'pending' | 'skipped';
  } = {}
): Promise<void> {
  const priority = opts.priority ?? 'medium';
  const restStatus = opts.restStatus ?? 'pending';
  for (let i = 0; i < count; i++) {
    await createItem(userId, priority, i < doneCount ? 'done' : restStatus);
  }
}

describe('checkAndUpdateStreak', () => {
  const users: string[] = [];

  afterAll(async () => {
    for (const id of users) {
      await cleanupUser(id);
    }
    await prisma.$disconnect();
  });

  test('all main items done → current increments to 1, lastCompletedDate = today', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(1);
    expect(streak?.lastCompletedDate?.toISOString().slice(0, 10)).toBe('2026-06-10');
  });

  test('partial main items done → streak NOT updated', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await createMainItem(userId, 'done');
    await createMainItem(userId, 'pending');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    // Хелпер выходит до создания/обновления streak, если не все main выполнены
    expect(streak).toBeNull();
  });

  test('no main items today → streak NOT updated', async () => {
    const userId = await createUserDirect();
    users.push(userId);

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak).toBeNull();
  });

  test('consecutive day (last = yesterday) → current += 1 and longest tracks', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await prisma.streak.create({
      data: {
        userId,
        current: 2,
        longest: 2,
        freezeCount: 0,
        lastCompletedDate: yesterdayUtc,
      },
    });
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(3);
    expect(streak?.longest).toBe(3);
  });

  test('missed day with freeze available → streak holds, freeze decremented', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await prisma.streak.create({
      data: {
        userId,
        current: 5,
        longest: 5,
        freezeCount: 1,
        lastCompletedDate: threeDaysAgoUtc,
      },
    });
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(5); // серия сохранена
    expect(streak?.freezeCount).toBe(0);
    expect(streak?.lastCompletedDate?.toISOString().slice(0, 10)).toBe('2026-06-10');
  });

  test('missed day without freeze → current resets to 1', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await prisma.streak.create({
      data: {
        userId,
        current: 5,
        longest: 5,
        freezeCount: 0,
        lastCompletedDate: threeDaysAgoUtc,
      },
    });
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(1);
    expect(streak?.longest).toBe(5); // рекорд не уменьшается
  });

  // ---------------------------------------------------------------------------
  // Предикат «день завершён» v2 (docs/TASKS-2026-07-02.md §8): если среди
  // не-skipped items дня есть priority=main — день засчитан, если ВСЕ main
  // done (не-main не блокирует); если main нет — засчитан, если недоделанных
  // не больше max(1, floor(counted.length * 0.1)). Skipped «не мешает»
  // (исключается из счёта), но день, где ВСЕ items skipped — нейтральный (не
  // засчитан), как и день без задач вовсе.
  // ---------------------------------------------------------------------------
  describe('checkAndUpdateStreak — предикат "день завершён" v2', () => {
    test('нет main: все задачи done → серия засчитывается', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createItem(userId, 'low', 'done');
      await createItem(userId, 'medium', 'done');

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak?.current).toBe(1);
    });

    test('main done + не-main НЕ done → ЗАСЧИТАНО (не-main не блокирует при наличии main)', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createItem(userId, 'main', 'done');
      await createItem(userId, 'low', 'pending'); // не блокирует — main важнее

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak?.current).toBe(1);
    });

    test('хотя бы один main НЕ done → НЕ засчитано, даже если остальные (включая другой main) done', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createItem(userId, 'main', 'done');
      await createItem(userId, 'main', 'pending');
      await createItem(userId, 'low', 'done');

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak).toBeNull();
    });

    test('нет main: 10 задач, 1 недоделана → ЗАСЧИТАНО (прощение <=10%)', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createBatch(userId, 10, 9);

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak?.current).toBe(1);
    });

    test('нет main: 10 задач, 2 недоделаны → НЕ засчитано (превышен порог 10%)', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createBatch(userId, 10, 8);

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak).toBeNull();
    });

    test('нет main: короткий день (2 задачи), 1 недоделана → ЗАСЧИТАНО (max(1, floor(2*0.1))=1 всегда прощает минимум одну)', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createBatch(userId, 2, 1);

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak?.current).toBe(1);
    });

    test('нет main: skipped исключаются из знаменателя — 10 skipped + 10 counted (2 недоделаны) → НЕ засчитано (порог 10% от 10 counted, а не от 20)', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createBatch(userId, 10, 0, { restStatus: 'skipped' });
      await createBatch(userId, 10, 8);

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak).toBeNull();
    });

    test('skipped "не мешает": done + skipped → засчитано', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createItem(userId, 'medium', 'done');
      await createItem(userId, 'low', 'skipped');

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak?.current).toBe(1);
    });

    test('ВСЕ задачи дня skipped (ни одной done) → нейтральный день, НЕ засчитано', async () => {
      const userId = await createUserDirect();
      users.push(userId);
      await createItem(userId, 'medium', 'skipped');
      await createItem(userId, 'low', 'skipped');

      await checkAndUpdateStreak(userId, today);

      const streak = await prisma.streak.findUnique({ where: { userId } });
      expect(streak).toBeNull();
    });
  });
});
