/**
 * ADR-067: YooKassa live integration — create-payment + real webhook.
 *
 * create-payment: mocks backend/src/billing/yookassaClient (no real HTTP calls
 * to api.yookassa.ru in tests — QA rule: no external network calls).
 * webhook: exercises the REAL verifyYookassaWebhook / validateYookassaPayment /
 * idempotency store — only YOOKASSA_WEBHOOK_SECRET env + prisma are touched
 * directly, matching how a real notification would be authenticated.
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, cleanupUser } from '../helpers';
import { computeYookassaSignature } from '../../backend/src/billing/yookassaWebhook';
import { resetProcessedPayments } from '../../backend/src/billing/yookassaPayment';

// Мокаем только createPayment (реальный сетевой вызов к api.yookassa.ru);
// kPremiumMonthlyRub/BillingNotConfiguredError остаются настоящими — роут
// (billing.ts) делает `instanceof BillingNotConfiguredError`, и это должен
// быть ТОТ ЖЕ класс, что импортирован там же (jest.mock подменяет модуль
// целиком для всех импортёров, поэтому instanceof продолжает работать).
jest.mock('../../backend/src/billing/yookassaClient', () => {
  const actual = jest.requireActual('../../backend/src/billing/yookassaClient');
  return {
    ...actual,
    createPayment: jest.fn(),
  };
});
import {
  createPayment,
  BillingNotConfiguredError,
} from '../../backend/src/billing/yookassaClient';

const mockCreatePayment = createPayment as jest.Mock;

const TEST_SECRET = 'test-integration-yookassa-secret';

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

beforeEach(() => {
  mockCreatePayment.mockReset();
  resetProcessedPayments();
});

// ────────────────────────────────────────────────────────────────
// POST /api/v1/billing/yookassa/create-payment
// ────────────────────────────────────────────────────────────────

async function callCreatePayment(token?: string) {
  return app.inject({
    method: 'POST',
    url: '/api/v1/billing/yookassa/create-payment',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
}

test('create-payment without token → 401', async () => {
  const res = await callCreatePayment();
  expect(res.statusCode).toBe(401);
});

test('create-payment → 503 when billing is not configured', async () => {
  mockCreatePayment.mockRejectedValueOnce(
    new BillingNotConfiguredError('YOOKASSA_SHOP_ID')
  );
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await callCreatePayment(user.token);
  expect(res.statusCode).toBe(503);
  expect(res.json<{ error: string }>().error).toBe('Billing is not configured');
});

test('create-payment → 502 when the YooKassa API call fails unexpectedly', async () => {
  mockCreatePayment.mockRejectedValueOnce(new Error('YooKassa createPayment failed: HTTP 500'));
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await callCreatePayment(user.token);
  expect(res.statusCode).toBe(502);
});

test('create-payment → 200 with mocked client returns payment_id + confirmation_url', async () => {
  mockCreatePayment.mockResolvedValueOnce({
    id: 'pay-mock-001',
    confirmationUrl: 'https://yookassa.ru/checkout/pay-mock-001',
    status: 'pending',
  });
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await callCreatePayment(user.token);
  expect(res.statusCode).toBe(200);
  const body = res.json<{ payment_id: string; confirmation_url: string }>();
  expect(body.payment_id).toBe('pay-mock-001');
  expect(body.confirmation_url).toBe('https://yookassa.ru/checkout/pay-mock-001');

  expect(mockCreatePayment).toHaveBeenCalledWith(
    expect.objectContaining({ userId: user.userId })
  );
});

// ────────────────────────────────────────────────────────────────
// POST /api/v1/billing/webhook/yookassa — real signature + payload
// ────────────────────────────────────────────────────────────────

interface NotificationOverrides {
  event?: string;
  status?: string;
  userId?: string;
  paymentId?: string;
}

function buildNotification(overrides: NotificationOverrides = {}): string {
  const paymentId = overrides.paymentId ?? `pay-int-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return JSON.stringify({
    type: 'notification',
    event: overrides.event ?? 'payment.succeeded',
    object: {
      id: paymentId,
      status: overrides.status ?? 'succeeded',
      amount: { value: '399.00', currency: 'RUB' },
      metadata: overrides.userId ? { user_id: overrides.userId, plan: 'premium_monthly' } : undefined,
    },
  });
}

async function postWebhook(rawBody: string, signature?: string) {
  return app.inject({
    method: 'POST',
    url: '/api/v1/billing/webhook/yookassa',
    headers: {
      'content-type': 'application/json',
      ...(signature ? { 'x-yookassa-signature': signature } : {}),
    },
    payload: rawBody,
  });
}

describe('webhook — signature enforced (YOOKASSA_WEBHOOK_SECRET set)', () => {
  let savedSecret: string | undefined;

  beforeAll(() => {
    savedSecret = process.env['YOOKASSA_WEBHOOK_SECRET'];
    process.env['YOOKASSA_WEBHOOK_SECRET'] = TEST_SECRET;
  });

  afterAll(() => {
    if (savedSecret === undefined) delete process.env['YOOKASSA_WEBHOOK_SECRET'];
    else process.env['YOOKASSA_WEBHOOK_SECRET'] = savedSecret;
  });

  test('valid signature + payment.succeeded → premiumUntil set in the future, source=yookassa', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const rawBody = buildNotification({ userId: user.userId });
    const sig = computeYookassaSignature(rawBody, TEST_SECRET);

    const res = await postWebhook(rawBody, sig);
    expect(res.statusCode).toBe(200);
    expect(res.json<{ ok: boolean }>().ok).toBe(true);

    const updated = await prisma.user.findUnique({ where: { id: user.userId } });
    expect(updated?.premiumSource).toBe('yookassa');
    expect(updated?.premiumUntil).not.toBeNull();
    expect(updated!.premiumUntil!.getTime()).toBeGreaterThan(Date.now());
  });

  test('same payment_id processed twice → idempotent, premiumUntil not extended again', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const paymentId = `pay-int-idem-${user.userId.slice(0, 8)}`;
    const rawBody = buildNotification({ userId: user.userId, paymentId });
    const sig = computeYookassaSignature(rawBody, TEST_SECRET);

    const first = await postWebhook(rawBody, sig);
    expect(first.statusCode).toBe(200);
    const afterFirst = await prisma.user.findUnique({ where: { id: user.userId } });
    const premiumUntilAfterFirst = afterFirst!.premiumUntil!.getTime();

    const second = await postWebhook(rawBody, sig);
    expect(second.statusCode).toBe(200);
    expect(second.json<{ ok: boolean; idempotent?: boolean }>().idempotent).toBe(true);

    const afterSecond = await prisma.user.findUnique({ where: { id: user.userId } });
    expect(afterSecond!.premiumUntil!.getTime()).toBe(premiumUntilAfterFirst);
  });

  test('invalid signature → 401, premium untouched', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const rawBody = buildNotification({ userId: user.userId });
    const res = await postWebhook(rawBody, 'totally-wrong-signature');
    expect(res.statusCode).toBe(401);

    const untouched = await prisma.user.findUnique({ where: { id: user.userId } });
    expect(untouched?.premiumUntil).toBeNull();
  });

  test('missing signature header → 401', async () => {
    const rawBody = buildNotification({ userId: '00000000-0000-0000-0000-000000000000' });
    const res = await postWebhook(rawBody);
    expect(res.statusCode).toBe(401);
  });

  test('valid signature but unsupported event (payment.canceled) → 200, ignored', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const rawBody = buildNotification({
      userId: user.userId,
      event: 'payment.canceled',
      status: 'canceled',
    });
    const sig = computeYookassaSignature(rawBody, TEST_SECRET);

    const res = await postWebhook(rawBody, sig);
    expect(res.statusCode).toBe(200);
    expect(res.json<{ ok: boolean; ignored?: boolean }>().ignored).toBe(true);

    const untouched = await prisma.user.findUnique({ where: { id: user.userId } });
    expect(untouched?.premiumUntil).toBeNull();
  });

  test('valid signature, unknown user_id → 200, ignored (no crash)', async () => {
    const rawBody = buildNotification({ userId: '00000000-0000-0000-0000-000000000000' });
    const sig = computeYookassaSignature(rawBody, TEST_SECRET);

    const res = await postWebhook(rawBody, sig);
    expect(res.statusCode).toBe(200);
  });

  test('garbage (non-JSON) body → 400, no crash', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/billing/webhook/yookassa',
      headers: { 'content-type': 'application/json' },
      payload: '{not valid json!!',
    });
    expect([400, 200]).toContain(res.statusCode);
  });
});

describe('webhook — dev mode (no YOOKASSA_WEBHOOK_SECRET)', () => {
  let savedSecret: string | undefined;

  beforeAll(() => {
    savedSecret = process.env['YOOKASSA_WEBHOOK_SECRET'];
    delete process.env['YOOKASSA_WEBHOOK_SECRET'];
  });

  afterAll(() => {
    if (savedSecret !== undefined) process.env['YOOKASSA_WEBHOOK_SECRET'] = savedSecret;
  });

  test('no secret configured → signature check skipped, valid notification still grants premium', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const rawBody = buildNotification({ userId: user.userId });
    // Никакой подписи не передаём — dev-режим пропускает проверку.
    const res = await postWebhook(rawBody);
    expect(res.statusCode).toBe(200);

    const updated = await prisma.user.findUnique({ where: { id: user.userId } });
    expect(updated?.premiumSource).toBe('yookassa');
  });
});
