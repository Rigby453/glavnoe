/**
 * ADR-041: тесты серверного entitlement + вебхуки биллинга + AI-гейт.
 *
 * Сценарии:
 * 1. Вебхук выставляет premiumUntil → GET /subscription/status возвращает is_premium=true
 * 2. expires_at в прошлом → is_premium=false
 * 3. dev-upgrade по-прежнему даёт premium (legacy subscriptionTier)
 * 4. AI-гейт пускает юзера с активным premiumUntil
 * 5. AI-гейт блокирует free-юзера
 *
 * AI-модули полностью замоканы — реальных вызовов нет (правило QA).
 */

import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, cleanupUser } from '../helpers';

// Мокируем все AI-модули (обязательно — иначе нужен ключ)
jest.mock('../../backend/src/ai/scheduleImport', () => ({
  importScheduleFromPhoto: jest.fn().mockResolvedValue({ items: [] }),
}));
jest.mock('../../backend/src/ai/morningMessage', () => ({
  generateMorningMessage: jest.fn().mockResolvedValue({ message: 'mock' }),
}));
jest.mock('../../backend/src/ai/smartRedistribute', () => ({
  generateSmartPlans: jest.fn().mockResolvedValue({ plans: [] }),
}));
jest.mock('../../backend/src/ai/diaryInsight', () => ({
  generateDiaryInsight: jest.fn().mockResolvedValue({ insight: 'mock' }),
}));
jest.mock('../../backend/src/ai/wrappedSummary', () => ({
  generateWrappedSummary: jest.fn().mockResolvedValue({ summary: 'mock' }),
}));
jest.mock('../../backend/src/ai/menuBuild', () => ({
  buildMenu: jest.fn().mockResolvedValue({ meals: [], note: 'mock' }),
}));
jest.mock('../../backend/src/ai/foodRecognize', () => ({
  recognizeFood: jest.fn().mockResolvedValue({
    dish: 'salad',
    portionDescription: 'small',
    confidence: 0.9,
  }),
}));
jest.mock('../../backend/src/food/openFoodFacts', () => ({
  searchProducts: jest.fn().mockResolvedValue([]),
  lookupBarcode: jest.fn().mockResolvedValue(null),
}));

let app: FastifyInstance;
const userIds: string[] = [];

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  for (const id of userIds) await cleanupUser(id);
  await app.close();
});

// Хелпер: вызов вебхука биллинга (заглушечный каркас — ADR-041).
// YooKassa не входит: с ADR-067 у неё реальная нотификация/подпись, см.
// billing-yookassa.test.ts.
async function callWebhook(
  channel: 'apple' | 'google' | 'rustore' | 'stripe',
  userId: string,
  expiresAt: string
) {
  return app.inject({
    method: 'POST',
    url: `/api/v1/billing/webhook/${channel}`,
    payload: { user_id: userId, product_id: 'kaizen_premium_1m', expires_at: expiresAt },
  });
}

// Хелпер: GET /subscription/status
async function getStatus(token: string) {
  return app.inject({
    method: 'GET',
    url: '/api/v1/subscription/status',
    headers: { Authorization: `Bearer ${token}` },
  });
}

// ────────────────────────────────────────────────────────────────
// 1. Вебхук выставляет premiumUntil → is_premium=true + правильный source/until
// ────────────────────────────────────────────────────────────────
// ADR-067: YooKassa вышла из этого общего каркаса-заглушки — у неё теперь
// реальная нотификация ЮKassa (type/event/object.metadata.user_id) и своя
// подпись/идемпотентность, покрытые отдельно в billing-yookassa.test.ts.
test('webhook sets premiumUntil → status returns is_premium=true with correct source/until', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const futureDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  for (const channel of ['apple', 'google', 'rustore', 'stripe'] as const) {
    // Проверяем каждый канал
    const wh = await callWebhook(channel, user.userId, futureDate);
    expect(wh.statusCode).toBe(200);
    expect(wh.json<{ ok: boolean }>().ok).toBe(true);

    const res = await getStatus(user.token);
    expect(res.statusCode).toBe(200);
    const body = res.json<{ is_premium: boolean; premium_until: string | null; source: string | null }>();
    expect(body.is_premium).toBe(true);
    expect(body.source).toBe(channel);
    expect(body.premium_until).not.toBeNull();
    // premium_until должен быть близок к futureDate
    const diff = Math.abs(new Date(body.premium_until!).getTime() - new Date(futureDate).getTime());
    expect(diff).toBeLessThan(2000); // допуск 2 сек
  }
});

// ────────────────────────────────────────────────────────────────
// 2. expires_at в прошлом → is_premium=false
// ────────────────────────────────────────────────────────────────
test('expired premiumUntil → is_premium=false', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  // Устанавливаем premiumUntil в прошлом напрямую через Prisma (чтобы обойти Zod datetime)
  const pastDate = new Date(Date.now() - 60 * 1000); // 1 минута назад
  await prisma.user.update({
    where: { id: user.userId },
    data: { premiumUntil: pastDate, premiumSource: 'stripe' },
  });

  const res = await getStatus(user.token);
  expect(res.statusCode).toBe(200);
  const body = res.json<{ is_premium: boolean }>();
  expect(body.is_premium).toBe(false);
});

// ────────────────────────────────────────────────────────────────
// 3. dev-upgrade (legacy subscriptionTier) по-прежнему даёт premium
// ────────────────────────────────────────────────────────────────
test('dev-upgrade still gives is_premium=true via legacy subscriptionTier', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const upgrade = await app.inject({
    method: 'POST',
    url: '/api/v1/subscription/dev-upgrade',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: { tier: 'premium' },
  });
  expect(upgrade.statusCode).toBe(200);
  // serializeUser должен включать is_premium=true
  const upgradeBody = upgrade.json<{ is_premium: boolean; subscription_tier: string }>();
  expect(upgradeBody.subscription_tier).toBe('premium');
  expect(upgradeBody.is_premium).toBe(true);

  // GET /status тоже должен отдавать true
  const res = await getStatus(user.token);
  expect(res.json<{ is_premium: boolean }>().is_premium).toBe(true);
});

// ────────────────────────────────────────────────────────────────
// 4. AI-гейт пускает юзера с активным premiumUntil
// ────────────────────────────────────────────────────────────────
test('AI gate allows user with active premiumUntil', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  // Устанавливаем срочный premium через вебхук
  const futureDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const wh = await callWebhook('stripe', user.userId, futureDate);
  expect(wh.statusCode).toBe(200);

  // Должен пройти AI-гейт (вернуть 200)
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/morning-message',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: { pending_count: 3, tone: 'gentle' },
  });
  expect(res.statusCode).toBe(200);
});

// ────────────────────────────────────────────────────────────────
// 5. AI-гейт блокирует free-юзера
// ────────────────────────────────────────────────────────────────
test('AI gate blocks free user (403)', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/morning-message',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: { pending_count: 0, tone: 'gentle' },
  });
  expect(res.statusCode).toBe(403);
});

// ────────────────────────────────────────────────────────────────
// 6. Вебхук — невалидное тело → 400
// ────────────────────────────────────────────────────────────────
test('webhook with invalid body returns 400', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/billing/webhook/stripe',
    payload: { user_id: '' }, // пустой user_id + нет expires_at
  });
  expect(res.statusCode).toBe(400);
});

// ────────────────────────────────────────────────────────────────
// 7. Вебхук — несуществующий user_id → 404
// ────────────────────────────────────────────────────────────────
test('webhook with unknown user_id returns 404', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/billing/webhook/apple',
    payload: {
      user_id: '00000000-0000-0000-0000-000000000000',
      expires_at: new Date(Date.now() + 86400000).toISOString(),
    },
  });
  expect(res.statusCode).toBe(404);
});

// ────────────────────────────────────────────────────────────────
// 8. GET /subscription/status без auth → 401
// ────────────────────────────────────────────────────────────────
test('GET /subscription/status without auth returns 401', async () => {
  const res = await app.inject({
    method: 'GET',
    url: '/api/v1/subscription/status',
  });
  expect(res.statusCode).toBe(401);
});

// ────────────────────────────────────────────────────────────────
// 9. serializeUser включает is_premium в /auth/me и /auth/register
// ────────────────────────────────────────────────────────────────
test('GET /auth/me returns is_premium field', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const me = await app.inject({
    method: 'GET',
    url: '/api/v1/auth/me',
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect(me.statusCode).toBe(200);
  const body = me.json<{ is_premium: boolean; premium_until: unknown; premium_source: unknown }>();
  expect(typeof body.is_premium).toBe('boolean');
  expect(body.is_premium).toBe(false); // новый юзер — free
  expect(body.premium_until).toBeNull();
  expect(body.premium_source).toBeNull();
});
