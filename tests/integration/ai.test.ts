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
      {
        label: 'Front-load priorities',
        reason: 'Math exam prep (2h) → 09:00 [main priority, peak focus]; Essay draft (1h) → 12:00.',
        items: [
          { id: 'task-uuid-1', scheduledAt: '2026-06-10T09:00:00.000Z', title: 'Math exam prep', priority: 'main' },
          { id: 'task-uuid-2', scheduledAt: '2026-06-10T12:00:00.000Z', title: 'Essay draft', priority: 'high' },
        ],
      },
    ],
  }),
}));
jest.mock('../../backend/src/ai/onboardingPlan', () => ({
  generateOnboardingPlan: jest.fn().mockResolvedValue({
    goals: [{ title: 'Pass the algebra exam', horizon: 'month' }],
    tasks: [
      {
        title: 'Algebra exam',
        type: 'exam',
        priority: 'main',
        scheduledAt: '2026-07-10T09:00:00.000Z',
        durationMinutes: 90,
      },
      {
        title: 'Review notes',
        type: 'task',
        priority: 'medium',
        note: 'chapters 3-5',
      },
    ],
    foodPrefs: { tracksFood: true, tracksWater: false, tracksSleep: false },
  }),
}));
jest.mock('../../backend/src/ai/quickAdd', () => ({
  generateQuickAddTask: jest.fn().mockResolvedValue({
    task: {
      title: 'Work',
      type: 'event',
      priority: 'high',
      scheduledAt: '2026-07-02T15:00:00.000Z',
      note: 'Butovo',
    },
  }),
}));
jest.mock('../../backend/src/ai/diaryInsight', () => ({
  generateDiaryInsight: jest.fn().mockResolvedValue({
    insight: 'You journal most on Sundays.',
    coveredFrom: '2026-06-04',
    coveredTo: '2026-06-10',
  }),
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
    totals: { calories: 2000, protein: 75, fat: 65, carbs: 250, sugar: 30, fiber: 28 },
    offTarget: false,
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

test('ai redistribute: 403 free / 200 premium with plans; items carry title + priority', async () => {
  await expectGated(
    '/api/v1/ai/redistribute',
    { target_date: '2026-06-10' },
    (b) => {
      const plans = b['plans'] as Array<Record<string, unknown>>;
      expect(Array.isArray(plans)).toBe(true);
      const items = (plans[0]!['items'] as Array<Record<string, unknown>>);
      // Новые поля — title и priority — пробрасываются из SmartPlan в ответ (ADR-057).
      expect(items[0]!['title']).toBe('Math exam prep');
      expect(items[0]!['priority']).toBe('main');
      expect(items[1]!['title']).toBe('Essay draft');
      expect(items[1]!['priority']).toBe('high');
      // Оригинальные поля на месте.
      expect(typeof items[0]!['id']).toBe('string');
      expect(typeof items[0]!['scheduled_at']).toBe('string');
    }
  );
});

test('diary-insight: 403 free / 200 premium with insight + covered date range', async () => {
  await expectGated(
    '/api/v1/ai/diary-insight',
    { tone: 'harsh' },
    (b) => {
      expect(typeof b['insight']).toBe('string');
      // Новые поля — covered_from/covered_to — диапазон анализируемых дат (ADR-057).
      expect(b['covered_from']).toBe('2026-06-04');
      expect(b['covered_to']).toBe('2026-06-10');
    }
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
      // ADR-046: ответ несёт машинно-читаемый флаг и посчитанные КОДОМ итоги.
      expect(typeof b['off_target']).toBe('boolean');
      const totals = b['totals'] as Record<string, unknown>;
      expect(typeof totals?.['calories']).toBe('number');
    }
  );
});

test('menu-build: full macro targets are accepted and forwarded to buildMenu', async () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { buildMenu } = require('../../backend/src/ai/menuBuild') as {
    buildMenu: jest.Mock;
  };
  buildMenu.mockClear();

  const prem = await registerUser(app);
  userIds.push(prem.userId);
  await makePremium(prem.userId);

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/menu-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: {
      candidates: _menuCandidates,
      calorie_goal: 2000,
      protein_goal_g: 75,
      fat_goal_g: 65,
      carbs_goal_g: 250,
      sugar_max_g: 40,
      fiber_min_g: 25,
      meals: ['breakfast', 'lunch', 'dinner'],
      tone: 'gentle',
    },
  });
  expect(res.statusCode).toBe(200);
  expect(buildMenu).toHaveBeenCalledTimes(1);
  const arg = buildMenu.mock.calls[0]![0] as Record<string, unknown>;
  expect(arg['fatGoalG']).toBe(65);
  expect(arg['carbsGoalG']).toBe(250);
  expect(arg['sugarMaxG']).toBe(40);
  expect(arg['fiberMinG']).toBe(25);
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

// DB-backed counter: AiUsage таблица хранит счётчик между запросами (ADR-034).
// Три успешных вызова → одна строка с count ≥ 3; четвёртый → 429.
test('food-recognize: AiUsage row persisted in DB with count >= 3 after 3 calls', async () => {
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

  // Три вызова — все должны вернуть 200
  for (let i = 0; i < 3; i++) {
    expect((await call()).statusCode).toBe(200);
  }

  // Четвёртый вызов — превышение лимита
  const fourth = await call();
  expect(fourth.statusCode).toBe(429);

  // Проверяем DB: ровно одна запись на сегодня для этого пользователя/фичи
  const today = new Date().toISOString().slice(0, 10);
  const rows = await prisma.aiUsage.findMany({
    where: { userId: prem.userId, feature: 'food_photo' },
  });
  expect(rows).toHaveLength(1);
  // Счётчик может быть 4 — четвёртый вызов тоже инкрементирует (per ADR-034)
  expect(rows[0]!.count).toBeGreaterThanOrEqual(3);
  expect(rows[0]!.day).toBe(today);
});

test('onboarding-plan: 403 free / 200 premium with goals + tasks (snake_case)', async () => {
  await expectGated(
    '/api/v1/ai/onboarding-plan',
    { answers: 'I have an algebra exam next week, need to review notes.', date: '2026-07-02', timezone: 'Europe/Moscow' },
    (b) => {
      const goals = b['goals'] as Array<Record<string, unknown>>;
      expect(goals[0]!['title']).toBe('Pass the algebra exam');
      expect(goals[0]!['horizon']).toBe('month');
      const tasks = b['tasks'] as Array<Record<string, unknown>>;
      expect(tasks).toHaveLength(2);
      expect(tasks[0]!['title']).toBe('Algebra exam');
      expect(tasks[0]!['type']).toBe('exam');
      expect(tasks[0]!['priority']).toBe('main');
      expect(tasks[0]!['scheduled_at']).toBe('2026-07-10T09:00:00.000Z');
      expect(tasks[0]!['duration_minutes']).toBe(90);
      expect(tasks[1]!['note']).toBe('chapters 3-5');
      const foodPrefs = b['food_prefs'] as Record<string, unknown>;
      expect(foodPrefs['tracks_food']).toBe(true);
      expect(foodPrefs['tracks_water']).toBe(false);
    }
  );
});

test('onboarding-plan: invalid body (missing timezone) → 400', async () => {
  const prem = await registerUser(app);
  userIds.push(prem.userId);
  await makePremium(prem.userId);

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/onboarding-plan',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: { answers: 'text', date: '2026-07-02' },
  });
  expect(res.statusCode).toBe(400);
});

test('quick-add: 403 free / 200 premium with task (snake_case)', async () => {
  await expectGated(
    '/api/v1/ai/quick-add',
    { text: 'work in an hour in Butovo', date: '2026-07-02', timezone: 'Europe/Moscow' },
    (b) => {
      const task = b['task'] as Record<string, unknown>;
      expect(task['title']).toBe('Work');
      expect(task['type']).toBe('event');
      expect(task['priority']).toBe('high');
      expect(task['scheduled_at']).toBe('2026-07-02T15:00:00.000Z');
      expect(task['note']).toBe('Butovo');
    }
  );
});

test('quick-add: empty text → 400', async () => {
  const prem = await registerUser(app);
  userIds.push(prem.userId);
  await makePremium(prem.userId);

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/quick-add',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: { text: '', date: '2026-07-02', timezone: 'Europe/Moscow' },
  });
  expect(res.statusCode).toBe(400);
});

test('morning-message without auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/morning-message',
    payload: { pending_count: 1, tone: 'gentle' },
  });
  expect(res.statusCode).toBe(401);
});
