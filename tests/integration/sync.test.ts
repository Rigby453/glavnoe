/**
 * QA-05: Sync conflict resolution (last-write-wins by updated_at).
 */
import { randomUUID } from 'crypto';
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
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
