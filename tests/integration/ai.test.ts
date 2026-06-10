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
jest.mock('../../backend/src/ai/wrappedSummary', () => ({
  generateWrappedSummary: jest
    .fn()
    .mockResolvedValue({ summary: 'A strong week: 12 of 15 tasks done.' }),
}));
jest.mock('../../backend/src/ai/menuBuild', () => ({
  buildMenu: jest.fn().mockResolvedValue({
    meals: [{ meal: 'breakfast', items: [{ name: 'Oatmeal', grams: 60 }] }],
    note: 'Solid day.',
  }),
}));
jest.mock('../../backend/src/ai/foodRecognize', () => ({
  recognizeFood: jest.fn().mockResolvedValue({
    dish: 'greek salad',
    portionDescription: 'a medium bowl',
    confidence: 0.86,
  }),
}));
// OFF тоже мокируем — никаких реальных HTTP-вызовов в тестах
jest.mock('../../backend/src/food/openFoodFacts', () => ({
  searchProducts: jest.fn().mockResolvedValue([
    {
      code: '123',
      name: 'Greek salad',
      brand: null,
      per100g: { calories: 101, protein: 2.3, fat: 7.4, carbs: 5.0, sugar: 3.1, fiber: 1.2 },
    },
  ]),
  lookupBarcode: jest.fn().mockResolvedValue(null),
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

test('food-recognize: 403 free / 200 premium with dish + products', async () => {
  await expectGated(
    '/api/v1/ai/food-recognize',
    { image_base64: 'ZmFrZQ==', media_type: 'image/jpeg' },
    (b) => {
      expect(b['dish']).toBe('greek salad');
      expect(typeof b['confidence']).toBe('number');
      const products = b['products'] as Array<Record<string, unknown>>;
      expect(products).toHaveLength(1);
      const per = products[0]?.['per_100g'] as Record<string, unknown>;
      expect(per['calories']).toBe(101); // числа из food DB, не из модели
    }
  );
});

test('wrapped-summary: 403 free / 200 premium with paragraph', async () => {
  await expectGated(
    '/api/v1/ai/wrapped-summary',
    {
      period_days: 7,
      tasks_done: 12,
      tasks_total: 15,
      main_done: 6,
      main_total: 7,
      avg_mood: 3.8,
      water_ml: 9000,
      top_issue: 'Social media',
      tone: 'gentle',
    },
    (b) => expect(typeof b['summary']).toBe('string')
  );
});

// 8 кандидатов для menu-build (минимум по схеме — 5)
const _menuCandidates = Array.from({ length: 8 }, (_, i) => ({
  name: i === 0 ? 'Oatmeal' : `Food ${i}`,
  per_100g: { calories: 100 + i, protein: 5, fat: 3, carbs: 12, sugar: 2, fiber: 1.5 },
}));

test('menu-build: 403 free / 200 premium with meals shape', async () => {
  await expectGated(
    '/api/v1/ai/menu-build',
    {
      candidates: _menuCandidates,
      calorie_goal: 2000,
      protein_goal_g: 60,
      meals: ['breakfast', 'lunch', 'dinner'],
      tone: 'gentle',
    },
    (b) => {
      const meals = b['meals'] as Array<Record<string, unknown>>;
      expect(meals).toHaveLength(1);
      expect(meals[0]?.['meal']).toBe('breakfast');
      const items = meals[0]?.['items'] as Array<Record<string, unknown>>;
      expect(typeof items[0]?.['grams']).toBe('number'); // только name+grams, числа КБЖУ считает клиент
      expect(typeof b['note']).toBe('string');
    }
  );
});

test('menu-build: fewer than 5 candidates → 400', async () => {
  const prem = await registerUser(app);
  userIds.push(prem.userId);
  await makePremium(prem.userId);

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/menu-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: {
      candidates: _menuCandidates.slice(0, 3),
      calorie_goal: 2000,
      protein_goal_g: 60,
    },
  });
  expect(res.statusCode).toBe(400);
});

test('food-recognize: 4th call same day → 429 (limit 3/day)', async () => {
  const prem = await registerUser(app);
  userIds.push(prem.userId);
  await makePremium(prem.userId);

  const call = () =>
    app.inject({
      method: 'POST',
      url: '/api/v1/ai/food-recognize',
      headers: { Authorization: `Bearer ${prem.token}` },
      payload: { image_base64: 'ZmFrZQ==', media_type: 'image/jpeg' },
    });

  for (let i = 0; i < 3; i++) {
    expect((await call()).statusCode).toBe(200);
  }
  const fourth = await call();
  expect(fourth.statusCode).toBe(429);
});

test('morning-message without auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/morning-message',
    payload: { pending_count: 1, tone: 'gentle' },
  });
  expect(res.statusCode).toBe(401);
});
