/**
 * QA-05: Sync conflict resolution (last-write-wins by updated_at).
 */
import { randomUUID } from 'crypto';
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, createItem, cleanupUser } from '../helpers';

let app: FastifyInstance;
const userIds: string[] = [];

const EPOCH = '2000-01-01T00:00:00.000Z';

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  for (const id of userIds) {
    await cleanupUser(id);
  }
  await app.close();
});

function itemPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const now = new Date().toISOString();
  return {
    id: randomUUID(),
    user_id: 'local',
    title: 'Synced task',
    type: 'task',
    priority: 'low',
    status: 'pending',
    scheduled_at: '2026-06-15T10:00:00.000Z',
    duration_minutes: 30,
    is_protected: false,
    recurrence_rule: null,
    created_at: now,
    updated_at: now,
    ...overrides,
  };
}

async function sync(
  token: string,
  items: Array<Record<string, unknown>>,
  lastSyncAt: string,
  waterLogs: Array<Record<string, unknown>> = []
) {
  return app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    headers: { Authorization: `Bearer ${token}` },
    payload: { items, water_logs: waterLogs, last_sync_at: lastSyncAt },
  });
}

async function getStreak(token: string) {
  const res = await app.inject({
    method: 'GET',
    url: '/api/v1/streaks',
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.json<{ current: number; longest: number; last_completed_date: string | null }>();
}

test('local item newer than server → server item updated to local version', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, { title: 'Original' });

  // Локальная версия новее (updated_at в будущем)
  const res = await sync(
    user.token,
    [{ id: item.id, title: 'Updated locally', updated_at: '2030-01-01T00:00:00.000Z' }],
    EPOCH
  );
  expect(res.statusCode).toBe(200);

  const get = await app.inject({
    method: 'GET',
    url: '/api/v1/items',
    headers: { Authorization: `Bearer ${user.token}` },
  });
  const found = get.json<Array<{ id: string; title: string }>>().find((i) => i.id === item.id);
  expect(found?.title).toBe('Updated locally');
});

test('server item newer than local → server version kept and returned', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, { title: 'Server wins' });

  // Входящая версия старее серверной (updated_at в прошлом, но после last_sync_at)
  const res = await sync(
    user.token,
    [{ id: item.id, title: 'Stale local', updated_at: '2000-01-02T00:00:00.000Z' }],
    EPOCH
  );
  expect(res.statusCode).toBe(200);
  const updated = res.json<{ updated_items: Array<{ id: string; title: string }> }>().updated_items;
  const found = updated.find((i) => i.id === item.id);
  expect(found?.title).toBe('Server wins'); // серверная версия не перезаписана
});

test('local item not on server → created and returned in updated_items', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const newItem = itemPayload({ title: 'Brand new' });

  const res = await sync(user.token, [newItem], EPOCH);
  expect(res.statusCode).toBe(200);
  const updated = res.json<{ updated_items: Array<{ id: string; user_id: string }> }>().updated_items;
  const found = updated.find((i) => i.id === newItem['id']);
  expect(found).toBeDefined();
  // Сервер привязывает к userId из токена, игнорируя 'local'
  expect(found?.user_id).toBe(user.userId);
});

test('empty items array → returns server-side items newer than last_sync_at', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, { title: 'Server side' });

  const res = await sync(user.token, [], EPOCH);
  expect(res.statusCode).toBe(200);
  const updated = res.json<{ updated_items: Array<{ id: string }> }>().updated_items;
  expect(updated.map((i) => i.id)).toContain(item.id);
});

test('sync without auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    payload: { items: [], last_sync_at: EPOCH },
  });
  expect(res.statusCode).toBe(401);
});

test('last_sync_at in the future → no server changes returned', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  await createItem(app, user.token, { title: 'Recent' });

  const res = await sync(user.token, [], '2030-01-01T00:00:00.000Z');
  expect(res.statusCode).toBe(200);
  expect(res.json<{ updated_items: unknown[] }>().updated_items).toEqual([]);
});

// --- Streak via sync (регрессия: серия не росла, т.к. /sync не вызывал движок) ---

const STREAK_DAY = '2026-07-20T10:00:00.000Z';

test('main item marked done via sync → streak increments to 1', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, {
    title: 'Finish thesis',
    priority: 'main',
    scheduled_at: STREAK_DAY,
  });

  const res = await sync(
    user.token,
    [
      {
        id: item.id,
        priority: 'main',
        status: 'done',
        scheduled_at: STREAK_DAY,
        updated_at: '2030-01-01T00:00:00.000Z',
      },
    ],
    EPOCH
  );
  expect(res.statusCode).toBe(200);

  const streak = await getStreak(user.token);
  expect(streak.current).toBe(1);
  expect(streak.last_completed_date).toBe('2026-07-20');
});

test('non-main item done via sync → streak NOT incremented', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, {
    title: 'Low prio chore',
    priority: 'low',
    scheduled_at: STREAK_DAY,
  });

  await sync(
    user.token,
    [
      {
        id: item.id,
        priority: 'low',
        status: 'done',
        scheduled_at: STREAK_DAY,
        updated_at: '2030-01-01T00:00:00.000Z',
      },
    ],
    EPOCH
  );

  const streak = await getStreak(user.token);
  expect(streak.current).toBe(0);
});

// --- Water log sync (append-only) ---

const WATER_DAY = '2026-07-21T09:00:00.000Z';

test('water log synced → created and returned in updated_water_logs', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const id = randomUUID();

  const res = await sync(user.token, [], EPOCH, [
    { id, amount_ml: 250, logged_at: WATER_DAY },
  ]);
  expect(res.statusCode).toBe(200);

  const water = res.json<{
    updated_water_logs: Array<{ id: string; user_id: string; amount_ml: number }>;
  }>().updated_water_logs;
  const found = water.find((w) => w.id === id);
  expect(found).toBeDefined();
  expect(found?.amount_ml).toBe(250);
  expect(found?.user_id).toBe(user.userId); // привязка к токену
});

test('water log sync is idempotent — no duplicate on second sync', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const id = randomUUID();
  const payload = [{ id, amount_ml: 500, logged_at: WATER_DAY }];

  await sync(user.token, [], EPOCH, payload);
  const res = await sync(user.token, [], EPOCH, payload);

  const water = res.json<{ updated_water_logs: Array<{ id: string }> }>()
    .updated_water_logs;
  expect(water.filter((w) => w.id === id)).toHaveLength(1);
});

test('one of two main items done via sync → streak NOT incremented', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const a = await createItem(app, user.token, {
    title: 'Main A',
    priority: 'main',
    scheduled_at: STREAK_DAY,
  });
  await createItem(app, user.token, {
    title: 'Main B (stays pending)',
    priority: 'main',
    scheduled_at: STREAK_DAY,
  });

  await sync(
    user.token,
    [
      {
        id: a.id,
        priority: 'main',
        status: 'done',
        scheduled_at: STREAK_DAY,
        updated_at: '2030-01-01T00:00:00.000Z',
      },
    ],
    EPOCH
  );

  const streak = await getStreak(user.token);
  expect(streak.current).toBe(0);
});

// --- Delete sync (tombstones) ---

async function syncWithDeletes(token: string, deletedItemIds: string[]) {
  return app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    headers: { Authorization: `Bearer ${token}` },
    payload: { items: [], deleted_item_ids: deletedItemIds, last_sync_at: EPOCH },
  });
}

test('deleted_item_ids removes the item server-side (no reappearance)', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, { title: 'To delete' });

  const res = await syncWithDeletes(user.token, [item.id]);
  expect(res.statusCode).toBe(200);

  const get = await app.inject({
    method: 'GET',
    url: '/api/v1/items',
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect(get.json<Array<{ id: string }>>().some((i) => i.id === item.id)).toBe(false);
});

test("deleted_item_ids cannot delete another user's item", async () => {
  const owner = await registerUser(app);
  userIds.push(owner.userId);
  const attacker = await registerUser(app);
  userIds.push(attacker.userId);
  const item = await createItem(app, owner.token, { title: 'Owned' });

  const res = await syncWithDeletes(attacker.token, [item.id]);
  expect(res.statusCode).toBe(200);

  const get = await app.inject({
    method: 'GET',
    url: '/api/v1/items',
    headers: { Authorization: `Bearer ${owner.token}` },
  });
  expect(get.json<Array<{ id: string }>>().some((i) => i.id === item.id)).toBe(true);
});

// --- DayLog sync (upsert by user+date, last-write-wins) ---

const DAY_LOG_DATE = '2026-07-26';

function postDayLog(
  token: string,
  log: { date: string; mood?: number | null; note?: string | null; updated_at: string }
) {
  return app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    headers: { Authorization: `Bearer ${token}` },
    payload: { items: [], day_logs: [log], last_sync_at: EPOCH },
  });
}

test('day log synced → upserted by date and returned in updated_day_logs', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await postDayLog(user.token, {
    date: DAY_LOG_DATE,
    mood: 4,
    note: 'good day',
    updated_at: '2026-07-26T20:00:00.000Z',
  });
  expect(res.statusCode).toBe(200);

  const logs = res.json<{
    updated_day_logs: Array<{ date: string; mood: number; note: string; user_id: string }>;
  }>().updated_day_logs;
  const found = logs.find((l) => l.date === DAY_LOG_DATE);
  expect(found).toBeDefined();
  expect(found?.mood).toBe(4);
  expect(found?.note).toBe('good day');
  expect(found?.user_id).toBe(user.userId);
});

test('day log LWW: stale update ignored, newer update applied', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const dateObj = new Date(`${DAY_LOG_DATE}T00:00:00.000Z`);

  // Создаём (mood=3). После create серверный updatedAt = реальное "сейчас".
  await postDayLog(user.token, {
    date: DAY_LOG_DATE,
    mood: 3,
    note: 'first',
    updated_at: '2026-07-26T10:00:00.000Z',
  });

  // Устаревшее обновление (2000 < серверного now) — игнорируется.
  await postDayLog(user.token, {
    date: DAY_LOG_DATE,
    mood: 1,
    note: 'stale',
    updated_at: '2000-01-01T00:00:00.000Z',
  });
  let dl = await prisma.dayLog.findUnique({
    where: { userId_date: { userId: user.userId, date: dateObj } },
  });
  expect(dl?.mood).toBe(3);

  // Более новое (2030 > серверного now) — применяется.
  await postDayLog(user.token, {
    date: DAY_LOG_DATE,
    mood: 5,
    note: 'final',
    updated_at: '2030-01-01T00:00:00.000Z',
  });
  dl = await prisma.dayLog.findUnique({
    where: { userId_date: { userId: user.userId, date: dateObj } },
  });
  expect(dl?.mood).toBe(5);
  expect(dl?.note).toBe('final');
});

// --- Combined: all sections in one /sync request coexist ---

test('combined sync: item-done + water + day_log + delete + streak together', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const toDelete = await createItem(app, user.token, { title: 'Delete me' });
  const mainItem = await createItem(app, user.token, {
    title: 'Main',
    priority: 'main',
    scheduled_at: '2026-08-01T09:00:00.000Z',
  });
  const waterId = randomUUID();

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: {
      items: [
        {
          id: mainItem.id,
          priority: 'main',
          status: 'done',
          scheduled_at: '2026-08-01T09:00:00.000Z',
          updated_at: '2030-01-01T00:00:00.000Z',
        },
      ],
      water_logs: [
        { id: waterId, amount_ml: 300, logged_at: '2026-08-01T10:00:00.000Z' },
      ],
      day_logs: [
        { date: '2026-08-01', mood: 5, note: 'great', updated_at: '2026-08-01T20:00:00.000Z' },
      ],
      deleted_item_ids: [toDelete.id],
      last_sync_at: EPOCH,
    },
  });
  expect(res.statusCode).toBe(200);

  const body = res.json<{
    updated_items: Array<{ id: string; status: string }>;
    updated_water_logs: Array<{ id: string }>;
    updated_day_logs: Array<{ date: string; mood: number }>;
  }>();

  expect(body.updated_items.find((i) => i.id === mainItem.id)?.status).toBe('done');
  expect(body.updated_items.some((i) => i.id === toDelete.id)).toBe(false); // удалён
  expect(body.updated_water_logs.some((w) => w.id === waterId)).toBe(true);
  expect(body.updated_day_logs.find((d) => d.date === '2026-08-01')?.mood).toBe(5);

  const streak = await getStreak(user.token);
  expect(streak.current).toBe(1);
});

// --- Cross-device delete propagation (tombstones) ---

test('deletion propagates to another device via deleted_item_ids', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, { title: 'Cross-device delete' });

  // Device A deletes via sync — its own delete is NOT echoed back to itself.
  const aRes = await syncWithDeletes(user.token, [item.id]);
  expect(aRes.json<{ deleted_item_ids: string[] }>().deleted_item_ids).not.toContain(item.id);

  // Device B (still at EPOCH) syncs → learns about the deletion.
  const bRes = await app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: { items: [], last_sync_at: EPOCH },
  });
  expect(bRes.json<{ deleted_item_ids: string[] }>().deleted_item_ids).toContain(item.id);
});

test('DELETE /items/:id creates a tombstone returned by sync', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const item = await createItem(app, user.token, { title: 'REST delete' });

  const del = await app.inject({
    method: 'DELETE',
    url: `/api/v1/items/${item.id}`,
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect(del.statusCode).toBe(204);

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/sync',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: { items: [], last_sync_at: EPOCH },
  });
  expect(res.json<{ deleted_item_ids: string[] }>().deleted_item_ids).toContain(item.id);
});
