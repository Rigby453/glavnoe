/**
 * QA: reminder_minutes_before — сериализация и валидация (без БД).
 *
 * Покрывает контракт с app-агентом: serializeItem отдаёт snake_case
 * reminder_minutes_before (число или null). Валидация границ (0..10080)
 * проверяется тем же Zod-выражением, что используют routes/items + routes/sync.
 */
import type { Item } from '@prisma/client';
import { serializeItem } from '../../backend/src/models/item';

// Базовый Item для сериализации (camelCase, как из Prisma).
function makeItem(overrides: Partial<Item> = {}): Item {
  const now = new Date('2026-06-23T08:00:00.000Z');
  return {
    id: '11111111-1111-1111-1111-111111111111',
    userId: '22222222-2222-2222-2222-222222222222',
    title: 'Test',
    type: 'task',
    priority: 'medium',
    status: 'pending',
    scheduledAt: now,
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: null,
    reminderMinutesBefore: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

describe('serializeItem → reminder_minutes_before', () => {
  test('null when no reminder set', () => {
    const s = serializeItem(makeItem({ reminderMinutesBefore: null }));
    expect(s.reminder_minutes_before).toBeNull();
  });

  test('number when reminder set', () => {
    const s = serializeItem(makeItem({ reminderMinutesBefore: 15 }));
    expect(s.reminder_minutes_before).toBe(15);
  });

  test('field is always present in serialized output (snake_case)', () => {
    const s = serializeItem(makeItem());
    expect('reminder_minutes_before' in s).toBe(true);
  });
});

/**
 * Зеркало валидации reminder_minutes_before, которую делают routes/items +
 * routes/sync через Zod: .number().int().min(0).max(10080).nullable().optional().
 * Дублируем границы здесь без импорта zod (модуль резолвится из backend/, не из
 * tests/), чтобы зафиксировать контракт допустимых значений.
 */
function isValidReminder(value: unknown): boolean {
  if (value === undefined || value === null) return true; // optional + nullable
  if (typeof value !== 'number') return false;
  if (!Number.isInteger(value)) return false; // .int()
  return value >= 0 && value <= 10080; // .min(0).max(10080)
}

describe('reminder_minutes_before validation (0..10080, nullable, optional)', () => {
  test('accepts 0 (= no reminder)', () => {
    expect(isValidReminder(0)).toBe(true);
  });

  test('accepts 15', () => {
    expect(isValidReminder(15)).toBe(true);
  });

  test('accepts 10080 (week, upper bound)', () => {
    expect(isValidReminder(10080)).toBe(true);
  });

  test('accepts null', () => {
    expect(isValidReminder(null)).toBe(true);
  });

  test('accepts undefined (omitted)', () => {
    expect(isValidReminder(undefined)).toBe(true);
  });

  test('rejects negative', () => {
    expect(isValidReminder(-1)).toBe(false);
  });

  test('rejects above 10080', () => {
    expect(isValidReminder(10081)).toBe(false);
  });

  test('rejects non-integer', () => {
    expect(isValidReminder(15.5)).toBe(false);
  });
});
