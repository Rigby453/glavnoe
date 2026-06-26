/**
 * QA-04: Rule redistribution engine (unit).
 * Тестирует proposeRedistribution напрямую с засевом данных через prisma.
 * Движок ориентируется на item.isProtected (а не на priority), поэтому
 * для проверки сортировки сеем main/high/low с isProtected=false.
 */
import { proposeRedistribution } from '../../backend/src/engine/redistributor';
import prisma from '../../backend/src/models/prisma';
import { cleanupUser } from '../helpers';

const target = new Date('2026-06-10T00:00:00.000Z');
const overdue = new Date('2026-06-09T10:00:00.000Z');

async function createUserDirect(): Promise<string> {
  const user = await prisma.user.create({
    data: {
      email: `engine_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`,
      passwordHash: 'x',
      name: 'Engine Test',
    },
  });
  return user.id;
}

async function seedPending(
  userId: string,
  priority: string,
  isProtected: boolean,
  durationMinutes = 30
): Promise<string> {
  const item = await prisma.item.create({
    data: {
      userId,
      title: `${priority} task`,
      type: 'task',
      priority,
      status: 'pending',
      scheduledAt: overdue,
      isProtected,
      durationMinutes,
    },
  });
  return item.id;
}

describe('proposeRedistribution', () => {
  const users: string[] = [];

  afterAll(async () => {
    for (const id of users) {
      await cleanupUser(id);
    }
    await prisma.$disconnect();
  });

  test('orders proposed by priority: main > high > low', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await seedPending(userId, 'low', false);
    await seedPending(userId, 'main', false);
    await seedPending(userId, 'high', false);

    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(skipped).toHaveLength(0);
    expect(proposed.map((i) => i.priority)).toEqual(['main', 'high', 'low']);
  });

  test('is_protected item goes to skipped, not proposed', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    const protectedId = await seedPending(userId, 'main', true);
    const movableId = await seedPending(userId, 'high', false);

    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(skipped.map((i) => i.id)).toContain(protectedId);
    expect(proposed.map((i) => i.id)).toContain(movableId);
    expect(proposed.map((i) => i.id)).not.toContain(protectedId);
  });

  test('enough free slots → all non-protected proposed with valid target-day slots', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await seedPending(userId, 'medium', false);
    await seedPending(userId, 'medium', false);

    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(skipped).toHaveLength(0);
    expect(proposed).toHaveLength(2);
    for (const p of proposed) {
      // На целевом дне и в окне 08:00–22:00 UTC
      expect(p.scheduledAt.toISOString().slice(0, 10)).toBe('2026-06-10');
      const hour = p.scheduledAt.getUTCHours();
      expect(hour).toBeGreaterThanOrEqual(8);
      expect(hour).toBeLessThan(22);
    }
    // Слоты не пересекаются между собой
    const slotKeys = proposed.map((p) => p.scheduledAt.toISOString());
    expect(new Set(slotKeys).size).toBe(slotKeys.length);
  });

  test('no free slots (day fully occupied) → pending items skipped', async () => {
    const userId = await createUserDirect();
    users.push(userId);

    // Занимаем все 28 слотов целевого дня (08:00–21:30, шаг 30 мин)
    const dayItems = [];
    for (let h = 8; h < 22; h++) {
      for (const m of [0, 30]) {
        dayItems.push({
          userId,
          title: `busy ${h}:${m}`,
          type: 'event',
          priority: 'low',
          status: 'pending',
          scheduledAt: new Date(Date.UTC(2026, 5, 10, h, m, 0, 0)),
          isProtected: false,
        });
      }
    }
    await prisma.item.createMany({ data: dayItems });

    const overdueId = await seedPending(userId, 'high', false);
    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(proposed).toHaveLength(0);
    expect(skipped.map((i) => i.id)).toContain(overdueId);
  });

  test('long task (300 min) reserves its whole span — next starts after it', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    // Тренировка 5ч (300 мин = 10 слотов), high → раскладывается первой.
    await seedPending(userId, 'high', false, 300);
    // Обычная задача 30 мин, medium → после длинной.
    await seedPending(userId, 'medium', false, 30);

    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(skipped).toHaveLength(0);
    expect(proposed).toHaveLength(2);

    const long = proposed.find((i) => i.priority === 'high')!;
    const next = proposed.find((i) => i.priority === 'medium')!;

    // long встаёт на 08:00 и занимает 10 слотов до 13:00.
    expect(long.scheduledAt.toISOString()).toBe('2026-06-10T08:00:00.000Z');
    const longStart = long.scheduledAt.getTime();
    const longEnd = longStart + 300 * 60_000;
    // next НЕ должна попасть ВНУТРЬ интервала длинной задачи.
    expect(next.scheduledAt.getTime()).toBeGreaterThanOrEqual(longEnd);
    expect(next.scheduledAt.toISOString()).toBe('2026-06-10T13:00:00.000Z');
  });

  test('two movable tasks with duration never overlap', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    // Две переносимые задачи по 90 мин (3 слота каждая).
    await seedPending(userId, 'medium', false, 90);
    await seedPending(userId, 'medium', false, 90);

    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(skipped).toHaveLength(0);
    expect(proposed).toHaveLength(2);

    const [a, b] = proposed;
    const aStart = a!.scheduledAt.getTime();
    const aEnd = aStart + (a!.durationMinutes ?? 30) * 60_000;
    const bStart = b!.scheduledAt.getTime();
    const bEnd = bStart + (b!.durationMinutes ?? 30) * 60_000;
    // Интервалы [start, end) не пересекаются.
    const overlap = aStart < bEnd && bStart < aEnd;
    expect(overlap).toBe(false);
  });

  test('no pending items → empty proposed and skipped', async () => {
    const userId = await createUserDirect();
    users.push(userId);

    const { proposed, skipped } = await proposeRedistribution(userId, target);

    expect(proposed).toEqual([]);
    expect(skipped).toEqual([]);
  });
});
