import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';

// Генерирует случайный email с российским доменом (mail.ru) для изоляции тестов
// (иностранные домены типа example.com/gmail.com отклоняются бэкендом — 406-ФЗ)
export function randomEmail(): string {
  return `test_${Date.now()}_${Math.random().toString(36).slice(2)}@mail.ru`;
}

// Генерирует уникальный российский номер телефона в формате +79XXXXXXXXX
// Использует Date.now() и случайный суффикс для уникальности между вызовами
export function randomPhone(): string {
  // Берём последние 9 цифр от Date.now() и дополняем случайными, чтобы всегда получить ровно 9 цифр
  const ts = Date.now() % 1_000_000_000; // 9 цифр максимум
  const padded = ts.toString().padStart(9, '0');
  // Итого: +7 9 XXXXXXXXX — 10 цифр после +7, первая всегда 9 (мобильный)
  return `+79${padded}`;
}

export interface RegisteredUser {
  token: string;
  userId: string;
  email: string;
}

export interface RegisteredUserByPhone {
  token: string;
  userId: string;
  phone: string;
}

/**
 * Регистрирует пользователя через API и возвращает токен, userId, email.
 * Использует случайный email с российским доменом для изоляции.
 */
export async function registerUser(app: FastifyInstance): Promise<RegisteredUser> {
  const email = randomEmail();
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      email,
      password: 'Test1234!',
      name: 'Test User',
    },
  });

  if (res.statusCode !== 201) {
    throw new Error(`registerUser failed: ${res.statusCode} ${res.body}`);
  }

  const body = res.json<{ access_token: string; user: { id: string } }>();
  return {
    token: body.access_token,
    userId: body.user.id,
    email,
  };
}

/**
 * Регистрирует пользователя по номеру телефона и возвращает токен, userId, phone.
 * Использует случайный российский номер телефона для изоляции.
 */
export async function registerUserByPhone(app: FastifyInstance): Promise<RegisteredUserByPhone> {
  const phone = randomPhone();
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      phone,
      password: 'Test1234!',
      name: 'Phone User',
    },
  });

  if (res.statusCode !== 201) {
    throw new Error(`registerUserByPhone failed: ${res.statusCode} ${res.body}`);
  }

  const body = res.json<{ access_token: string; user: { id: string } }>();
  return {
    token: body.access_token,
    userId: body.user.id,
    phone,
  };
}

export interface CreatedItem {
  id: string;
  user_id: string;
  title: string;
  type: string;
  priority: string;
  status: string;
  scheduled_at: string;
  duration_minutes: number;
  is_protected: boolean;
  recurrence_rule: string | null;
  reminder_minutes_before: number | null;
  created_at: string;
  updated_at: string;
}

/**
 * Создаёт задачу через API POST /api/v1/items.
 * overrides позволяет переопределить любые поля.
 */
export async function createItem(
  app: FastifyInstance,
  token: string,
  overrides: Record<string, unknown> = {}
): Promise<CreatedItem> {
  const defaults = {
    title: 'Test Item',
    type: 'task',
    scheduled_at: new Date().toISOString(),
    priority: 'medium',
    duration_minutes: 30,
  };

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/items',
    headers: { Authorization: `Bearer ${token}` },
    payload: { ...defaults, ...overrides },
  });

  if (res.statusCode !== 201) {
    throw new Error(`createItem failed: ${res.statusCode} ${res.body}`);
  }

  return res.json<CreatedItem>();
}

/**
 * Удаляет все данные, созданные тестом, для конкретного пользователя.
 * Порядок важен: сначала дочерние таблицы (items, streak, dayLogs, waterLogs), потом user.
 */
export async function cleanupUser(userId: string): Promise<void> {
  try {
    await prisma.item.deleteMany({ where: { userId } });
    await prisma.waterLog.deleteMany({ where: { userId } });
    await prisma.foodLog.deleteMany({ where: { userId } });
    await prisma.dayLog.deleteMany({ where: { userId } });
    await prisma.tombstone.deleteMany({ where: { userId } });
    await prisma.aiUsage.deleteMany({ where: { userId } });
    await prisma.streak.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  } catch {
    // Если пользователь уже удалён — игнорируем
  }
}
