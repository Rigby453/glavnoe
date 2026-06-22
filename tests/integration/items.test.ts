/**
 * QA-02: Items CRUD + ownership + date filters.
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, createItem, cleanupUser } from '../helpers';

interface SubtaskShape {
  id: string;
  title: string;
  done: boolean;
  sort_order: number;
}
interface ItemWithSubtasks {
  id: string;
  subtasks: SubtaskShape[];
}
interface CreatedItemReminder {
  reminder_minutes_before: number | null;
}

let app: FastifyInstance;
const userIds: string[] = [];

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

describe('POST /api/v1/items', () => {
  test('create task → 201 with id, is_protected=false by default', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Buy milk' });
    expect(item.id).toBeDefined();
    expect(item.title).toBe('Buy milk');
    expect(item.is_protected).toBe(false);
  });

  test('priority=main → is_protected forced true', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, {
      title: 'Final exam',
      priority: 'main',
    });
    expect(item.priority).toBe('main');
    expect(item.is_protected).toBe(true);
  });

  test('reminder_minutes_before round-trips (create → response)', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, {
      title: 'Remind me',
      reminder_minutes_before: 15,
    });
    expect(item.reminder_minutes_before).toBe(15);
  });

  test('reminder_minutes_before defaults to null when omitted', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'No reminder' });
    expect(item.reminder_minutes_before).toBeNull();
  });

  test('reminder_minutes_before out of range (>10080) → 400', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'Bad reminder',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        reminder_minutes_before: 10081,
      },
    });
    expect(res.statusCode).toBe(400);
  });

  test('missing title → 400', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { type: 'task', scheduled_at: new Date().toISOString() },
    });
    expect(res.statusCode).toBe(400);
  });
});

describe('GET /api/v1/items', () => {
  test('date range returns only items inside the range', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const inRange = await createItem(app, user.token, {
      title: 'In range',
      scheduled_at: '2026-06-15T10:00:00.000Z',
    });
    await createItem(app, user.token, {
      title: 'Out of range',
      scheduled_at: '2026-06-20T10:00:00.000Z',
    });

    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/items?from=2026-06-15T00:00:00.000Z&to=2026-06-15T23:59:59.000Z',
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(res.statusCode).toBe(200);
    const items = res.json<Array<{ id: string }>>();
    const ids = items.map((i) => i.id);
    expect(ids).toContain(inRange.id);
    expect(ids).toHaveLength(1);
  });

  test("another user's token sees none of the first user's items", async () => {
    const owner = await registerUser(app);
    userIds.push(owner.userId);
    await createItem(app, owner.token, { title: 'Private' });

    const other = await registerUser(app);
    userIds.push(other.userId);
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${other.token}` },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<unknown[]>()).toEqual([]);
  });
});

describe('PATCH /api/v1/items/:id', () => {
  test('update title → reflected in response', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Old' });
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { title: 'New' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<{ title: string }>().title).toBe('New');
  });

  test('status=done → updated', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Do it' });
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { status: 'done' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<{ status: string }>().status).toBe('done');
  });

  test('reminder_minutes_before set then cleared via null', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, {
      title: 'Reminder edit',
      reminder_minutes_before: 30,
    });
    expect(item.reminder_minutes_before).toBe(30);

    // Set to a new value
    const set = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { reminder_minutes_before: 60 },
    });
    expect(set.statusCode).toBe(200);
    expect(set.json<CreatedItemReminder>().reminder_minutes_before).toBe(60);

    // Clear with explicit null
    const cleared = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { reminder_minutes_before: null },
    });
    expect(cleared.statusCode).toBe(200);
    expect(cleared.json<CreatedItemReminder>().reminder_minutes_before).toBeNull();
  });

  test("another user's item → 404", async () => {
    const owner = await registerUser(app);
    userIds.push(owner.userId);
    const item = await createItem(app, owner.token, { title: 'Owned' });

    const other = await registerUser(app);
    userIds.push(other.userId);
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${other.token}` },
      payload: { title: 'hacked' },
    });
    expect(res.statusCode).toBe(404);
  });
});

describe('Subtasks (Items)', () => {
  test('POST with subtasks → 201, returned sorted by sort_order (snake_case)', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'Project',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        subtasks: [
          { title: 'Second', done: false, sort_order: 1 },
          { title: 'First', done: true, sort_order: 0 },
        ],
      },
    });
    expect(res.statusCode).toBe(201);
    const item = res.json<ItemWithSubtasks>();
    expect(item.subtasks).toHaveLength(2);
    // Отсортированы по sort_order
    expect(item.subtasks[0].title).toBe('First');
    expect(item.subtasks[0].done).toBe(true);
    expect(item.subtasks[0].sort_order).toBe(0);
    expect(item.subtasks[1].title).toBe('Second');
    expect(item.subtasks[1].sort_order).toBe(1);
    // Каждая подзадача получила id
    expect(item.subtasks[0].id).toBeDefined();
  });

  test('POST without subtasks → subtasks is empty array', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = (await createItem(app, user.token, {
      title: 'No subs',
    })) as unknown as ItemWithSubtasks;
    expect(item.subtasks).toEqual([]);
  });

  test('GET /items includes subtasks', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'With subs',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        subtasks: [{ title: 'A', sort_order: 0 }],
      },
    });
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(res.statusCode).toBe(200);
    const items = res.json<ItemWithSubtasks[]>();
    const withSubs = items.find((i) => i.subtasks.length > 0);
    expect(withSubs).toBeDefined();
    expect(withSubs!.subtasks[0].title).toBe('A');
  });

  test('PATCH upserts: updates existing, adds new, deletes missing', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'Checklist',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        subtasks: [
          { title: 'Keep', done: false, sort_order: 0 },
          { title: 'Remove', done: false, sort_order: 1 },
        ],
      },
    });
    const item = created.json<ItemWithSubtasks>();
    const keepId = item.subtasks.find((s) => s.title === 'Keep')!.id;

    // Обновляем 'Keep' (done=true), удаляем 'Remove' (не присылаем), добавляем новую
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        subtasks: [
          { id: keepId, title: 'Keep', done: true, sort_order: 0 },
          { title: 'Added', done: false, sort_order: 1 },
        ],
      },
    });
    expect(res.statusCode).toBe(200);
    const updated = res.json<ItemWithSubtasks>();
    expect(updated.subtasks).toHaveLength(2);
    const keep = updated.subtasks.find((s) => s.id === keepId);
    expect(keep).toBeDefined();
    expect(keep!.done).toBe(true); // обновилось
    expect(updated.subtasks.some((s) => s.title === 'Added')).toBe(true);
    expect(updated.subtasks.some((s) => s.title === 'Remove')).toBe(false); // удалено
  });

  test('PATCH with empty subtasks array → removes all subtasks', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'Clearable',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        subtasks: [{ title: 'X', sort_order: 0 }],
      },
    });
    const item = created.json<ItemWithSubtasks>();
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { subtasks: [] },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<ItemWithSubtasks>().subtasks).toEqual([]);
  });

  test('PATCH without subtasks key → subtasks untouched', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'Untouched',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        subtasks: [{ title: 'Stays', sort_order: 0 }],
      },
    });
    const item = created.json<ItemWithSubtasks>();
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { title: 'Renamed' },
    });
    expect(res.statusCode).toBe(200);
    const updated = res.json<ItemWithSubtasks>();
    expect(updated.subtasks).toHaveLength(1);
    expect(updated.subtasks[0].title).toBe('Stays');
  });

  test('deleting item cascades subtasks (no orphan rows)', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        title: 'Cascade',
        type: 'task',
        scheduled_at: new Date().toISOString(),
        subtasks: [
          { title: 'one', sort_order: 0 },
          { title: 'two', sort_order: 1 },
        ],
      },
    });
    const item = created.json<ItemWithSubtasks>();
    const before = await prisma.subtask.count({ where: { itemId: item.id } });
    expect(before).toBe(2);

    const del = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(del.statusCode).toBe(204);

    const after = await prisma.subtask.count({ where: { itemId: item.id } });
    expect(after).toBe(0); // каскадно удалены
  });
});

describe('DELETE /api/v1/items/:id', () => {
  test('delete → 204, then second delete → 404', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Temp' });

    const first = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(first.statusCode).toBe(204);

    const second = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(second.statusCode).toBe(404);
  });

  test("another user's item → 404", async () => {
    const owner = await registerUser(app);
    userIds.push(owner.userId);
    const item = await createItem(app, owner.token, { title: 'Owned' });

    const other = await registerUser(app);
    userIds.push(other.userId);
    const res = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${other.token}` },
    });
    expect(res.statusCode).toBe(404);
  });
});
