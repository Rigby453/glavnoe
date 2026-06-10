import type { FoodLog } from "@prisma/client";

// Тип ответа для FoodLog — строго по api-spec.yaml (snake_case).
// Числа КБЖУ — абсолют на порцию, посчитаны клиентом из food DB (ADR-024).
export interface SerializedFoodLog {
  id: string;
  user_id: string;
  date: string; // YYYY-MM-DD
  meal: string;
  name: string;
  grams: number;
  calories: number | null;
  protein: number | null;
  fat: number | null;
  carbs: number | null;
  sugar: number | null;
  fiber: number | null;
  created_at: string;
}

/**
 * Преобразует Prisma FoodLog (camelCase) в snake_case ответ API.
 */
export function serializeFoodLog(log: FoodLog): SerializedFoodLog {
  return {
    id: log.id,
    user_id: log.userId,
    date: log.date.toISOString().slice(0, 10),
    meal: log.meal,
    name: log.name,
    grams: log.grams,
    calories: log.calories,
    protein: log.protein,
    fat: log.fat,
    carbs: log.carbs,
    sugar: log.sugar,
    fiber: log.fiber,
    created_at: log.createdAt.toISOString(),
  };
}
