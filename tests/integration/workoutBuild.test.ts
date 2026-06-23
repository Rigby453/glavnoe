/**
 * Feature A: AI workout-build — route (premium gate, validation, mapped
 * snake_case response, days clamp, 503 geo/quota path) + real buildWorkoutProgram.
 *
 * Мокаем ТОЛЬКО provider.generateText — реальных вызовов модели нет (правило QA).
 * Это прогоняет НАСТОЯЩУЮ логику buildWorkoutProgram (парсинг, клемп дней, ретрай)
 * через реальный маршрут.
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, cleanupUser } from '../helpers';

// generateText замокан — его же зовёт buildWorkoutProgram через callAndClean.
jest.mock('../../backend/src/ai/provider', () => {
  const actual = jest.requireActual('../../backend/src/ai/provider');
  return {
    ...actual,
    generateText: jest.fn(),
  };
});

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { generateText } = require('../../backend/src/ai/provider') as {
  generateText: jest.Mock;
};

let app: FastifyInstance;
const userIds: string[] = [];

async function makePremium(userId: string): Promise<void> {
  await prisma.user.update({
    where: { id: userId },
    data: { subscriptionTier: 'premium' },
  });
}

async function premiumUser() {
  const u = await registerUser(app);
  userIds.push(u.userId);
  await makePremium(u.userId);
  return u;
}

// Канонная валидная программа на 3 дня (как «вернула бы модель»).
function programJson(dayCount: number): string {
  const days = Array.from({ length: dayCount }, (_, i) => ({
    title: `Day ${i + 1} — Full Body`,
    exercises: [
      { name: 'Squat', sets: 3, reps: '8-12', rest_seconds: 120, note: 'brace hard' },
      { name: 'Bench Press', sets: 3, reps: '8-12', rest_seconds: 120 },
    ],
  }));
  return JSON.stringify({
    program_name: 'Starter Strength',
    days,
    note: 'Show up and progress slowly.',
  });
}

const validBody = {
  goal: 'strength',
  experience: 'beginner',
  equipment: ['barbell', 'dumbbells'],
  days_per_week: 3,
  minutes_per_session: 60,
  tone: 'gentle',
};

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});
afterAll(async () => {
  for (const id of userIds) await cleanupUser(id);
  await app.close();
});
beforeEach(() => {
  generateText.mockReset();
});

test('workout-build without auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    payload: validBody,
  });
  expect(res.statusCode).toBe(401);
});

test('workout-build: free user → 403 (premium gate)', async () => {
  const free = await registerUser(app);
  userIds.push(free.userId);
  generateText.mockResolvedValue(programJson(3));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${free.token}` },
    payload: validBody,
  });
  expect(res.statusCode).toBe(403);
});

test('workout-build: premium → 200 with mapped snake_case response', async () => {
  const prem = await premiumUser();
  generateText.mockResolvedValue(programJson(3));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: validBody,
  });
  expect(res.statusCode).toBe(200);
  const b = res.json<Record<string, unknown>>();
  expect(typeof b['program_name']).toBe('string');
  expect(typeof b['note']).toBe('string');
  const days = b['days'] as Array<Record<string, unknown>>;
  expect(Array.isArray(days)).toBe(true);
  expect(typeof days[0]?.['title']).toBe('string');
  const exercises = days[0]?.['exercises'] as Array<Record<string, unknown>>;
  const ex = exercises[0]!;
  expect(typeof ex['name']).toBe('string');
  expect(typeof ex['sets']).toBe('number');
  expect(typeof ex['reps']).toBe('string'); // строка — допускает "8-12"/"AMRAP"
  // snake_case mapping: restSeconds → rest_seconds; camelCase не протекает
  expect(typeof ex['rest_seconds']).toBe('number');
  expect(ex['restSeconds']).toBeUndefined();
  expect(ex['note']).toBe('brace hard');
});

test('workout-build: days are clamped to days_per_week', async () => {
  const prem = await premiumUser();
  // Модель «вернула» 5 дней, а запрошено 2 → ответ должен содержать ровно 2.
  generateText.mockResolvedValue(programJson(5));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: { ...validBody, days_per_week: 2 },
  });
  expect(res.statusCode).toBe(200);
  const days = res.json<Record<string, unknown>>()['days'] as unknown[];
  expect(days).toHaveLength(2);
});

test('workout-build: bad body (missing equipment) → 400', async () => {
  const prem = await premiumUser();
  generateText.mockResolvedValue(programJson(3));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: {
      goal: 'strength',
      experience: 'beginner',
      // equipment отсутствует
      days_per_week: 3,
      minutes_per_session: 60,
    },
  });
  expect(res.statusCode).toBe(400);
});

test('workout-build: invalid enum / out-of-range → 400', async () => {
  const prem = await premiumUser();
  generateText.mockResolvedValue(programJson(3));

  const badGoal = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: { ...validBody, goal: 'bulk_forever' },
  });
  expect(badGoal.statusCode).toBe(400);

  const badDays = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: { ...validBody, days_per_week: 9 },
  });
  expect(badDays.statusCode).toBe(400);
});

test('workout-build: provider geo/quota error → 503', async () => {
  const prem = await premiumUser();
  // Имитируем гео-блок провайдера (та же фраза, что ловит aiError → 503).
  generateText.mockRejectedValue(new Error('User location is not supported for the API use.'));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: validBody,
  });
  expect(res.statusCode).toBe(503);
});

test('workout-build: quota (429) provider error → 503', async () => {
  const prem = await premiumUser();
  generateText.mockRejectedValue(new Error('Gemini API error 429: quota exceeded'));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: validBody,
  });
  expect(res.statusCode).toBe(503);
});

test('workout-build: retries once on unparseable JSON then succeeds', async () => {
  const prem = await premiumUser();
  generateText
    .mockResolvedValueOnce('Sorry, here is no JSON.')
    .mockResolvedValueOnce(programJson(3));

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: validBody,
  });
  expect(res.statusCode).toBe(200);
  expect(generateText).toHaveBeenCalledTimes(2); // ровно один ретрай
});

test('workout-build: prompt respects equipment + days, weight not prescribed', async () => {
  const prem = await premiumUser();
  generateText.mockResolvedValue(programJson(4));

  await app.inject({
    method: 'POST',
    url: '/api/v1/ai/workout-build',
    headers: { Authorization: `Bearer ${prem.token}` },
    payload: {
      ...validBody,
      equipment: ['pullup_bar', 'bodyweight'],
      days_per_week: 4,
      focus: 'back',
      limitations: 'left knee pain',
    },
  });

  const system = generateText.mock.calls[0]![0].system as string;
  expect(system).toContain('pullup_bar, bodyweight');
  expect(system).toContain('EXACTLY 4 day');
  expect(system).toMatch(/do not prescribe weights/i);
  expect(system).toContain('back'); // focus
  expect(system).toContain('left knee pain'); // limitations
});
