/**
 * Integration: восстановление пароля (ADR-047) — коды в БД, не в памяти.
 *
 * Покрывает:
 *  - forgot-password создаёт запись и (в dev/test) возвращает dev_code
 *  - reset с неверным кодом → 400
 *  - reset с истёкшим кодом → 400
 *  - reset с верным кодом → 200, пароль меняется, код становится использованным
 *    (повторный reset тем же кодом → 400)
 *
 * ВНИМАНИЕ: эти тесты ходят в реальную БД (нет DATABASE_URL_TEST). Пока SQL-миграция
 * для таблицы PasswordResetCode не применена, они упадут с Prisma P2021
 * «table does not exist» — это ожидаемо до миграции (см. отчёт/ADR-047).
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { randomEmail, cleanupUser } from '../helpers';

// Реальный Resend никогда не вызываем из тестов — мокаем модуль доставки.
// sendPasswordResetEmail по умолчанию резолвится в "успех", чтобы не трогать
// поведение forgot-password при тестах без RESEND_API_KEY (где она не вызывается).
const sendPasswordResetEmailMock = jest.fn().mockResolvedValue({ sent: true });
jest.mock('../../backend/src/lib/email', () => ({
  isEmailDeliveryConfigured: () => Boolean(process.env['RESEND_API_KEY']),
  sendPasswordResetEmail: (...args: unknown[]) => sendPasswordResetEmailMock(...args),
}));

let app: FastifyInstance;
const userIdsToCleanup: string[] = [];

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  for (const userId of userIdsToCleanup) {
    await cleanupUser(userId);
  }
  await app.close();
});

// Регистрирует пользователя и возвращает email + userId
async function register(): Promise<{ email: string; userId: string }> {
  const email = randomEmail();
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: { email, password: 'OldPass123!', name: 'Reset User' },
  });
  const body = res.json<{ user: { id: string } }>();
  userIdsToCleanup.push(body.user.id);
  return { email, userId: body.user.id };
}

// Запрашивает код восстановления и возвращает dev_code из ответа
async function requestCode(email: string): Promise<string> {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/forgot-password',
    payload: { email },
  });
  expect(res.statusCode).toBe(200);
  const body = res.json<{ dev_code?: string }>();
  expect(typeof body.dev_code).toBe('string');
  return body.dev_code as string;
}

describe('POST /api/v1/auth/forgot-password', () => {
  test('создаёт запись PasswordResetCode и возвращает dev_code (test-режим)', async () => {
    const { email, userId } = await register();
    const code = await requestCode(email);
    expect(code).toMatch(/^\d{6}$/);

    // В БД появилась активная (неиспользованная) запись для пользователя
    const active = await prisma.passwordResetCode.findFirst({
      where: { userId, usedAt: null },
    });
    expect(active).not.toBeNull();
  });

  test('несуществующий email → 200 без dev_code (не раскрываем отсутствие)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/forgot-password',
      payload: { email: 'nobody@yandex.ru' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ dev_code?: string }>();
    expect(body.dev_code).toBeUndefined();
  });

  test('запрос нового кода инвалидирует прошлый (одноразовость окна)', async () => {
    const { email } = await register();
    const firstCode = await requestCode(email);
    const secondCode = await requestCode(email);
    expect(secondCode).toMatch(/^\d{6}$/);

    // Старый код больше не работает
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/reset-password',
      payload: { email, code: firstCode, newPassword: 'BrandNew123!' },
    });
    expect(res.statusCode).toBe(400);
  });
});

describe('POST /api/v1/auth/forgot-password — email delivery (Resend, ADR-059)', () => {
  const ORIGINAL_RESEND_API_KEY = process.env['RESEND_API_KEY'];

  afterEach(() => {
    sendPasswordResetEmailMock.mockClear();
    sendPasswordResetEmailMock.mockResolvedValue({ sent: true });
    if (ORIGINAL_RESEND_API_KEY === undefined) {
      delete process.env['RESEND_API_KEY'];
    } else {
      process.env['RESEND_API_KEY'] = ORIGINAL_RESEND_API_KEY;
    }
  });

  test('RESEND_API_KEY задан → письмо отправляется, dev_code НЕ возвращается', async () => {
    process.env['RESEND_API_KEY'] = 'test_resend_key';
    const { email } = await register();

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/forgot-password',
      payload: { email },
    });

    expect(res.statusCode).toBe(200);
    const body = res.json<{ message: string; dev_code?: string }>();
    expect(body.dev_code).toBeUndefined();
    expect(body.message).toBe('If this email is registered, a reset code was sent.');

    expect(sendPasswordResetEmailMock).toHaveBeenCalledTimes(1);
    const [sentToEmail, sentCode] = sendPasswordResetEmailMock.mock.calls[0] as [string, string];
    expect(sentToEmail).toBe(email);
    expect(sentCode).toMatch(/^\d{6}$/);
  });

  test('RESEND_API_KEY задан, но отправка падает → всё равно 200 без dev_code (не палим аккаунт)', async () => {
    process.env['RESEND_API_KEY'] = 'test_resend_key';
    sendPasswordResetEmailMock.mockResolvedValueOnce({ sent: false, error: 'Resend API 500' });
    const { email } = await register();

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/forgot-password',
      payload: { email },
    });

    expect(res.statusCode).toBe(200);
    const body = res.json<{ dev_code?: string }>();
    expect(body.dev_code).toBeUndefined();
  });

  test('RESEND_API_KEY не задан → старое dev-поведение, email не отправляется', async () => {
    delete process.env['RESEND_API_KEY'];
    const { email } = await register();

    const code = await requestCode(email);
    expect(code).toMatch(/^\d{6}$/);
    expect(sendPasswordResetEmailMock).not.toHaveBeenCalled();
  });
});

describe('POST /api/v1/auth/reset-password', () => {
  test('неверный код → 400', async () => {
    const { email } = await register();
    await requestCode(email);
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/reset-password',
      payload: { email, code: '000000', newPassword: 'BrandNew123!' },
    });
    expect(res.statusCode).toBe(400);
  });

  test('истёкший код → 400', async () => {
    const { email, userId } = await register();
    const code = await requestCode(email);

    // Принудительно состариваем код в БД
    await prisma.passwordResetCode.updateMany({
      where: { userId, usedAt: null },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/reset-password',
      payload: { email, code, newPassword: 'BrandNew123!' },
    });
    expect(res.statusCode).toBe(400);
  });

  test('верный код → 200, пароль меняется; повторный reset тем же кодом → 400', async () => {
    const { email } = await register();
    const code = await requestCode(email);
    const newPassword = 'BrandNew123!';

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/reset-password',
      payload: { email, code, newPassword },
    });
    expect(res.statusCode).toBe(200);

    // Новый пароль работает на логине
    const login = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email, password: newPassword },
    });
    expect(login.statusCode).toBe(200);

    // Старый пароль больше не подходит
    const oldLogin = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email, password: 'OldPass123!' },
    });
    expect(oldLogin.statusCode).toBe(401);

    // Повторное использование того же кода → 400 (одноразовость)
    const replay = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/reset-password',
      payload: { email, code, newPassword: 'AnotherPass123!' },
    });
    expect(replay.statusCode).toBe(400);
  });
});
