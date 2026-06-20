import type { Streak } from "@prisma/client";

// Тип ответа для Streak — строго по api-spec.yaml (snake_case)
export interface SerializedStreak {
  id: string;
  user_id: string;
  current: number;
  longest: number;
  last_completed_date: string | null; // формат YYYY-MM-DD или null
  freeze_count: number;
  last_freeze_accrual_at: string | null; // ISO datetime или null (ADR-044)
}

/**
 * Форматирует DateTime в строку вида "YYYY-MM-DD" (без времени).
 * Используем UTC-дату чтобы избежать смещения часового пояса.
 */
function toDateString(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/**
 * Преобразует Prisma Streak (camelCase) в snake_case ответ API.
 * last_completed_date — только дата "YYYY-MM-DD", не datetime.
 * last_freeze_accrual_at — ISO timestamp или null (LWW-курсор заморозок, ADR-044).
 */
export function serializeStreak(streak: Streak): SerializedStreak {
  return {
    id: streak.id,
    user_id: streak.userId,
    current: streak.current,
    longest: streak.longest,
    last_completed_date:
      streak.lastCompletedDate != null
        ? toDateString(streak.lastCompletedDate)
        : null,
    freeze_count: streak.freezeCount,
    last_freeze_accrual_at:
      streak.lastFreezeAccrualAt != null
        ? streak.lastFreezeAccrualAt.toISOString()
        : null,
  };
}
