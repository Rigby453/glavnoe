/**
 * AI-07: «Собрать ИИ» — сборка дневного меню (premium, SPEC C5).
 * Модель компонует меню ТОЛЬКО из переданных клиентом позиций (продукты/рецепты
 * пользователя) и возвращает только name+grams. Все числа КБЖУ считает КОД на
 * клиенте по своей базе — модель чисел не выдаёт. Вызов модели — через provider.ts.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";

export interface MenuCandidate {
  name: string;
  per100g: {
    calories: number | null;
    protein: number | null;
    fat: number | null;
    carbs: number | null;
    sugar: number | null;
    fiber: number | null;
  };
}

export interface MenuMeal {
  meal: string;
  items: { name: string; grams: number }[];
}

// Модель возвращает приёмы пищи с позициями name+grams; note — одно предложение.
const RawMenuSchema = z.object({
  meals: z.array(
    z.object({
      meal: z.string().min(1),
      items: z.array(
        z.object({
          name: z.string().min(1),
          grams: z.number().min(1).max(2000),
        })
      ),
    })
  ),
  note: z.string(),
});

/**
 * Собирает дневное меню из кандидатов под цели по калориям/белку.
 * @param candidates - продукты/рецепты пользователя (имя + КБЖУ на 100 г)
 * @param calorieGoal - цель по калориям на день
 * @param proteinGoalG - цель по белку, г
 * @param meals - приёмы пищи (напр. ["breakfast","lunch","dinner"])
 * @param tone - тон заметки (gentle/harsh), без шейминга в обоих
 */
export async function buildMenu(params: {
  candidates: MenuCandidate[];
  calorieGoal: number;
  proteinGoalG: number;
  meals: string[];
  tone: "gentle" | "harsh";
}): Promise<{ meals: MenuMeal[]; note: string }> {
  const { candidates, calorieGoal, proteinGoalG, meals, tone } = params;

  const validNames = new Set(candidates.map((c) => c.name));

  const system =
    "You are a nutrition menu composer for a student planner. Compose a one-day " +
    "menu USING ONLY the provided candidate foods (names must match EXACTLY, " +
    "character for character). Target the calorie goal within ±10% and protein " +
    "at or above the goal, using the provided per-100g numbers for your own " +
    "arithmetic — but NEVER output any nutrition numbers. Use 2-4 items per " +
    "meal, grams as multiples of 10 between 30 and 500. Each candidate may " +
    "appear in at most two meals. Also write 'note': ONE short sentence about " +
    `the day's menu in a ${tone === "harsh" ? "blunt, no-nonsense (but never insulting)" : "warm, encouraging"} ` +
    "tone, no food shaming. " +
    'Return STRICT JSON only (no prose, no markdown fences): {"meals": ' +
    '[{"meal": string, "items": [{"name": string, "grams": number}]}], ' +
    '"note": string}. The "meal" values must be exactly the requested meal names.';

  const user = JSON.stringify({
    calorie_goal: calorieGoal,
    protein_goal_g: proteinGoalG,
    meals,
    candidates: candidates.map((c) => ({
      name: c.name,
      per_100g: c.per100g,
    })),
  });

  const text = await generateText({
    system,
    user,
    maxTokens: 1500,
    tier: "smart",
    json: true,
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned unparseable JSON for menu-build.");
  }
  const result = RawMenuSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected menu-build shape.");
  }

  // Страховка от галлюцинаций: выбрасываем позиции, которых нет среди кандидатов,
  // и приёмы, которых не просили; граммы округляем до кратных 10.
  const requested = new Set(meals);
  const cleaned: MenuMeal[] = result.data.meals
    .filter((m) => requested.has(m.meal))
    .map((m) => ({
      meal: m.meal,
      items: m.items
        .filter((it) => validNames.has(it.name))
        .map((it) => ({
          name: it.name,
          grams: Math.min(500, Math.max(30, Math.round(it.grams / 10) * 10)),
        })),
    }));

  if (cleaned.every((m) => m.items.length === 0)) {
    throw new Error("AI returned no usable menu.");
  }

  return { meals: cleaned, note: result.data.note };
}
