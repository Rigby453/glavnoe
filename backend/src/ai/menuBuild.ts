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
 * @param language - язык заметки (напр. "Russian"), по умолчанию "English"
 * @param healthProfile - необязательный профиль здоровья пользователя (свободный текст):
 *   allergies — аллергии/непереносимости; healing — скорость заживления ран;
 *   deficiencies — известные дефициты витаминов/минералов.
 *   Используется ТОЛЬКО для фильтрации и смещения выбора — числа КБЖУ считает код.
 * @param foodPrefs - необязательные пищевые предпочтения (ADR-038):
 *   diet — тип диеты (vegetarian, vegan, keto …); goal — цель по весу (lose/maintain/gain);
 *   dislikes — нежелательные продукты (свободный текст); likes — предпочтительные.
 *   mealsPerDay — целевое кол-во приёмов (справочно; состав meals[] — источник истины).
 *   Используется ТОЛЬКО для фильтрации/смещения выбора. Не медицинские рекомендации.
 */
export async function buildMenu(params: {
  candidates: MenuCandidate[];
  calorieGoal: number;
  proteinGoalG: number;
  meals: string[];
  tone: "gentle" | "harsh";
  language?: string;
  healthProfile?: {
    allergies?: string;
    healing?: string;
    deficiencies?: string;
  };
  foodPrefs?: {
    diet?: string;
    goal?: string;
    dislikes?: string;
    likes?: string;
    mealsPerDay?: number;
  };
}): Promise<{ meals: MenuMeal[]; note: string }> {
  const { candidates, calorieGoal, proteinGoalG, meals, tone, language = "English", healthProfile, foodPrefs } = params;

  const validNames = new Set(candidates.map((c) => c.name));

  // Базовый системный промпт — правила компоновки меню и формат вывода.
  let system =
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
    '"note": string}. The "meal" values must be exactly the requested meal names.' +
    `\n\nIMPORTANT: Write all human-readable text (the note field) in ${language}. Keep JSON keys, meal names, food item names, and grams values exactly as specified in English.`;

  // Если передан профиль здоровья — добавляем блок с инструкциями по фильтрации/смещению.
  // Это не медицинские рекомендации; числа КБЖУ по-прежнему считает код, не модель.
  if (healthProfile) {
    const hp = healthProfile;
    const hasAny = hp.allergies?.trim() || hp.healing?.trim() || hp.deficiencies?.trim();
    if (hasAny) {
      system +=
        "\n\nUSER HEALTH NOTES (free text from the user; treat as preferences, NOT medical advice):\n";
      if (hp.allergies?.trim()) {
        system += `- Allergies/intolerances to AVOID: ${hp.allergies.trim()}\n`;
      }
      if (hp.healing?.trim()) {
        system += `- Wound healing speed: ${hp.healing.trim()}\n`;
      }
      if (hp.deficiencies?.trim()) {
        system += `- Known deficiencies: ${hp.deficiencies.trim()}\n`;
      }
      system +=
        "Rules: NEVER include any candidate food that conflicts with the stated allergies/intolerances. " +
        "Bias selection toward foods rich in nutrients relevant to the notes " +
        "(e.g. slow wound healing → protein, vitamin C, zinc; stated deficiency → foods rich in it), " +
        "while still hitting the calorie/protein goals from the user's own candidate foods. " +
        "You still output ONLY name+grams and NEVER any nutrition numbers.";
    }
  }

  // Если переданы пищевые предпочтения — добавляем блок фильтрации/смещения (ADR-038).
  // Не медицинские рекомендации; числа КБЖУ считает код.
  if (foodPrefs) {
    const fp = foodPrefs;
    const effectiveDiet = fp.diet?.trim() && fp.diet.trim().toLowerCase() !== "none"
      ? fp.diet.trim()
      : undefined;
    const hasAny =
      effectiveDiet ||
      fp.goal?.trim() ||
      fp.dislikes?.trim() ||
      fp.likes?.trim() ||
      fp.mealsPerDay !== undefined;
    if (hasAny) {
      system += "\n\nUSER FOOD PREFERENCES (treat as preferences, NOT medical/nutritional prescription):\n";
      if (effectiveDiet) {
        system += `- Diet: Honor the diet: ${effectiveDiet}. EXCLUDE any candidate food that conflicts with it.\n`;
      }
      if (fp.dislikes?.trim()) {
        system += `- Avoid these disliked foods: ${fp.dislikes.trim()}\n`;
      }
      if (fp.likes?.trim()) {
        system += `- Prefer these when sensible: ${fp.likes.trim()}\n`;
      }
      if (fp.goal?.trim()) {
        system += `- The calorie goal already reflects the user's weight goal (${fp.goal.trim()}). No need to adjust numbers — just pick fitting foods.\n`;
      }
      if (fp.mealsPerDay !== undefined) {
        system += `- The user targets ${fp.mealsPerDay} meals per day. Use exactly the meal names provided in the request — do not invent new meal names.\n`;
      }
      system +=
        "You still output ONLY name+grams and NEVER any nutrition numbers.";
    }
  }

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
