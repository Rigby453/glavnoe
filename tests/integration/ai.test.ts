/**
 * Phase 1: AI routes — premium gating + response shape.
 * backend/src/ai/* полностью замокан — реальных вызовов Claude нет (правило QA).
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, cleanupUser } from '../helpers';

jest.mock('../../backend/src/ai/scheduleImport', () => ({
  importScheduleFromPhoto: jest.fn().mockResolvedValue({
    items: [
      { title: 'Math lecture', scheduledAt: '2026-06-10T09:00:00.000Z' },
      { title: 'Gym', scheduledAt: '2026-06-10T14:30:00.000Z' },
    ],
  }),
}));
jest.mock('../../backend/src/ai/morningMessage', () => ({
  generateMorningMessage: jest.fn().mockResolvedValue({ message: 'Good morning — 2 tasks carried over.' }),
}));
jest.mock('../../backend/src/ai/smartRedistribute', () => ({
  generateSmartPlans: jest.fn().mockResolvedValue({
    plans: [
      { label: 'Balanced day', reason: 'spreads tasks out', items: [{ id: 'x', scheduledAt: '2026-06-10T10:00:00.000Z' }] },
    ],
  }),
}));
jest.mock('../../backend/src/ai/diaryInsight', () => ({
  generateDiaryInsight: jest.fn().mockResolvedValue({ insight: 'You journal most on Sundays.' }),
}));

let app: FastifyInstance;
const userIds: string[] = [];

async function makePremium(userId: string): Promise<void> {
  await prisma.user.update({ where: { id: userId }, data: { subscriptionTier: 'premium' } });
}

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});
afterAll(async () => {
  for (const id of userIds) await cleanupUser(id);
  await app.close();
});

// Универсальная проверка гейтинга: free → 403, premium → 200.
async function expectGated(
  url: string,
  payload: Record<string, unknown>,
  assert200: (body: Record<string, unknown>) => void
) {
  const free = await registerUser(app);
  userIds.push(free.userId);
  const r403 = await app.inject({
    method: 'POST',
    url,
    headers: { Authorization: `Bearer ${free.token}` },
    payload,
  });
  expect(r403.statusCode).toBe(403);

  const prem = await registerUser(app);
  userIds.push(prem.userId);
  await makePremium(prem.userId);
  const r200 = await app.inject({
    method: 'POST',
    url,
    headers: { Authorization: `Bearer ${prem.token}` },
    payload,
  });
  expect(r200.statusCode).toBe(200);
  assert200(r200.json<Record<string, unknown>>());
}

test('schedule-import: 403 free / 200 premium with items', async () => {
  await expectGated(
    '/api/v1/ai/schedule-import',
    { image_base64: 'ZmFrZQ==', media_type: 'image/png', target_date: '2026-06-10' },
    (b) => expect((b['items'] as unknown[]).length).toBe(2)
  );
});

test('morning-message: 403 free / 200 premium with message', async () => {
  await expectGated(
    '/api/v1/ai/morning-message',
    { pending_count: 2, tone: 'gentle' },
    (b) => expect(typeof b['message']).toBe('string')
  );
});

test('ai redistribute: 403 free / 200 premium with plans', async () => {
  await expectGated(
    '/api/v1/ai/redistribute',
    { target_date: '2026-06-10' },
    (b) => expect(Array.isArray(b['plans'])).toBe(true)
  );
});

test('diary-insight: 403 free / 200 premium with insight', async () => {
  await expectGated(
    '/api/v1/ai/diary-insight',
    { tone: 'harsh' },
    (b) => expect(typeof b['insight']).toBe('string')
  );
});

test('morning-message without auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/morning-message',
    payload: { pending_count: 1, tone: 'gentle' },
  });
  expect(res.statusCode).toBe(401);
});
