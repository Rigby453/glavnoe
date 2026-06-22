/**
 * AI-07: «Собрать ИИ» — сборка дневного меню (premium, SPEC C5).
 * Модель компонует меню ТОЛЬКО из переданных клиентом позиций (продукты/рецепты
 * пользователя) и возвращает только name+grams. Все числа КБЖУ считает КОД —
 * модель чисел не выдаёт. Вызов модели — через provider.ts.
 *
 * ADR-046: smart-тир (gemini-2.5-flash), полный набор макро-целей,
 * предпочтение цельной еды, ограниченный валидационный цикл (1 ретрай),
 * приёмы пищи по количеству от клиента.
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

/** Посчитанные КОДОМ итоги по дню (из граммов × per-100g кандидатов). */
export interface MenuTotals {
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  sugar: number;
  fiber: number;
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

/** Цели по макросам (только переданные участвуют в промпте/валидации). */
interface MacroTargets {
  calorieGoal: number;
  proteinGoalG: number;
  fatGoalG?: number;
  carbsGoalG?: number;
  sugarMaxG?: number;
  fiberMinG?: number;
}

/**
 * Собирает дневное меню из кандидатов под полный набор макро-целей.
 * @param candidates - продукты/рецепты пользователя (имя + КБЖУ на 100 г)
 * @param calorieGoal - цель по калориям на день
 * @param proteinGoalG - цель по белку, г (минимум)
 * @param fatGoalG - цель по жирам, г (±15%), опционально
 * @param carbsGoalG - цель по углеводам, г (±15%), опционально
 * @param sugarMaxG - максимум сахара, г, опционально
 * @param fiberMinG - минимум клетчатки, г, опционально
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
 *
 * @returns meals — меню (name+grams), note — заметка, totals — посчитанные КОДОМ
 *   итоги по дню, offTarget — true если после ретрая всё ещё вне допусков.
 */
export async function buildMenu(params: {
  candidates: MenuCandidate[];
  calorieGoal: number;
  proteinGoalG: number;
  fatGoalG?: number;
  carbsGoalG?: number;
  sugarMaxG?: number;
  fiberMinG?: number;
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
}): Promise<{ meals: MenuMeal[]; note: string; totals: MenuTotals; offTarget: boolean }> {
  const {
    candidates,
    calorieGoal,
    proteinGoalG,
    fatGoalG,
    carbsGoalG,
    sugarMaxG,
    fiberMinG,
    meals,
    tone,
    language = "English",
    healthProfile,
    foodPrefs,
  } = params;

  const validNames = new Set(candidates.map((c) => c.name));
  const byName = new Map(candidates.map((c) => [c.name, c]));

  // Кол-во приёмов: явный mealsPerDay имеет приоритет, иначе длина meals[], иначе 3.
  // Если просят больше слотов, чем имён — добавляем безопасные имена snack 2..n.
  const desiredMealCount = foodPrefs?.mealsPerDay ?? (meals.length || 3);
  const mealNames = resolveMealNames(meals, desiredMealCount);

  const targets: MacroTargets = {
    calorieGoal,
    proteinGoalG,
    ...(fatGoalG !== undefined ? { fatGoalG } : {}),
    ...(carbsGoalG !== undefined ? { carbsGoalG } : {}),
    ...(sugarMaxG !== undefined ? { sugarMaxG } : {}),
    ...(fiberMinG !== undefined ? { fiberMinG } : {}),
  };

  const system = buildSystemPrompt({
    tone,
    language,
    targets,
    mealNames,
    healthProfile,
    foodPrefs,
  });

  const baseUser = JSON.stringify({
    calorie_goal: calorieGoal,
    protein_goal_g: proteinGoalG,
    ...(fatGoalG !== undefined ? { fat_goal_g: fatGoalG } : {}),
    ...(carbsGoalG !== undefined ? { carbs_goal_g: carbsGoalG } : {}),
    ...(sugarMaxG !== undefined ? { sugar_max_g: sugarMaxG } : {}),
    ...(fiberMinG !== undefined ? { fiber_min_g: fiberMinG } : {}),
    meals: mealNames,
    candidates: candidates.map((c) => ({ name: c.name, per_100g: c.per100g })),
  });

  // --- Ограниченный валидационный цикл: максимум 2 вызова модели (1 ретрай). ---
  // Чтобы не тормозить приложение, второй вызов делаем только если первый
  // результат вне «жёстких» допусков. Возвращаем лучшую попытку.
  const MAX_CALLS = 2;
  let best: { meals: MenuMeal[]; note: string; totals: MenuTotals } | null = null;
  let bestScore = Number.POSITIVE_INFINITY;
  let correction = "";

  for (let attempt = 0; attempt < MAX_CALLS; attempt++) {
    const user = correction ? `${baseUser}\n\n${correction}` : baseUser;
    const attemptResult = await callAndClean({ system, user, mealNames, validNames });
    const totals = computeTotals(attemptResult.meals, byName);
    const score = targetScore(totals, targets);

    if (score < bestScore) {
      bestScore = score;
      best = { ...attemptResult, totals };
    }

    // Внутри допусков → готово, ретрай не нужен.
    if (withinTolerance(totals, targets)) {
      return { ...attemptResult, totals, offTarget: false };
    }

    // Иначе — формируем подсказку для ретрая (если он ещё остался).
    if (attempt < MAX_CALLS - 1) {
      correction = buildCorrectionHint(totals, targets);
    }
  }

  // После ретрая всё ещё вне допусков → отдаём лучшую попытку с флагом.
  const result = best!;
  return {
    meals: result.meals,
    note: result.note,
    totals: result.totals,
    offTarget: true,
  };
}

// ---------------------------------------------------------------------------
// Промпт
// ---------------------------------------------------------------------------

function buildSystemPrompt(args: {
  tone: "gentle" | "harsh";
  language: string;
  targets: MacroTargets;
  mealNames: string[];
  healthProfile?: { allergies?: string; healing?: string; deficiencies?: string };
  foodPrefs?: {
    diet?: string;
    goal?: string;
    dislikes?: string;
    likes?: string;
    mealsPerDay?: number;
  };
}): string {
  const { tone, language, targets, mealNames, healthProfile, foodPrefs } = args;

  // Строки целей — только для переданных значений.
  const targetLines: string[] = [
    `- Calories: hit ${targets.calorieGoal} kcal within ±5%.`,
    `- Protein: at or ABOVE ${targets.proteinGoalG} g (never below).`,
  ];
  if (targets.fatGoalG !== undefined) {
    targetLines.push(`- Fat: ${targets.fatGoalG} g, within ±15%.`);
  }
  if (targets.carbsGoalG !== undefined) {
    targetLines.push(`- Carbs: ${targets.carbsGoalG} g, within ±15%.`);
  }
  if (targets.sugarMaxG !== undefined) {
    targetLines.push(`- Sugar: at or BELOW ${targets.sugarMaxG} g (a cap, not a target).`);
  }
  if (targets.fiberMinG !== undefined) {
    targetLines.push(`- Fiber: at or ABOVE ${targets.fiberMinG} g (a minimum).`);
  }

  let system =
    "You are a nutrition menu composer for a student planner. Compose a one-day " +
    "menu USING ONLY the provided candidate foods (names must match EXACTLY, " +
    "character for character). Do your own arithmetic from the provided per-100g " +
    "numbers to hit the targets, but NEVER output any nutrition numbers — output " +
    "only food names and grams.\n\n" +
    "TARGETS (hit ALL of them as closely as you can):\n" +
    targetLines.join("\n") +
    "\n\nFOOD QUALITY — IMPORTANT:\n" +
    "- PRIORITIZE whole, real foods: meat, poultry, fish, eggs, dairy, grains, " +
    "legumes, vegetables, fruit, nuts. These should form the BULK of the menu.\n" +
    "- Use processed convenience items (protein bars, protein shakes/powders, chips, " +
    "sweets) ONLY if strictly necessary to close a small remaining macro gap — " +
    "NEVER as the bulk of the day. A menu made mostly of bars/shakes is WRONG.\n\n" +
    "MEAL STRUCTURE:\n" +
    `- Split foods across EXACTLY these ${mealNames.length} meals: ${mealNames.join(", ")}.\n` +
    "- Each meal must be a sensible combination of foods — do NOT dump everything " +
    "into one meal. Use 2-4 items per meal, grams as multiples of 10 between 30 and 500.\n" +
    "- Each candidate may appear in at most two meals.\n\n" +
    "Also write 'note': ONE short sentence about the day's menu in a " +
    (tone === "harsh"
      ? "blunt, no-nonsense (but never insulting)"
      : "warm, encouraging") +
    " tone, no food shaming.\n\n" +
    'Return STRICT JSON only (no prose, no markdown fences): {"meals": ' +
    '[{"meal": string, "items": [{"name": string, "grams": number}]}], ' +
    '"note": string}. The "meal" values must be exactly the requested meal names.' +
    `\n\nIMPORTANT: Write all human-readable text (the note field) in ${language}. ` +
    "Keep JSON keys, meal names, food item names, and grams values exactly as specified in English.";

  // Профиль здоровья — фильтрация/смещение (не медицинские рекомендации).
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
        "while still hitting the macro targets from the user's own candidate foods. " +
        "You still output ONLY name+grams and NEVER any nutrition numbers.";
    }
  }

  // Пищевые предпочтения (ADR-038).
  if (foodPrefs) {
    const fp = foodPrefs;
    const effectiveDiet =
      fp.diet?.trim() && fp.diet.trim().toLowerCase() !== "none" ? fp.diet.trim() : undefined;
    const hasAny =
      effectiveDiet ||
      fp.goal?.trim() ||
      fp.dislikes?.trim() ||
      fp.likes?.trim() ||
      fp.mealsPerDay !== undefined;
    if (hasAny) {
      system +=
        "\n\nUSER FOOD PREFERENCES (treat as preferences, NOT medical/nutritional prescription):\n";
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
      system += "You still output ONLY name+grams and NEVER any nutrition numbers.";
    }
  }

  return system;
}

/** Подсказка для ретрая: текущие итоги vs цели и дельты к исправлению. */
function buildCorrectionHint(totals: MenuTotals, t: MacroTargets): string {
  const lines: string[] = [];
  lines.push(`- Calories: now ${Math.round(totals.calories)}, target ${t.calorieGoal} (${signed(totals.calories - t.calorieGoal)}).`);
  if (totals.protein < t.proteinGoalG) {
    lines.push(`- Protein: now ${Math.round(totals.protein)}, must be ≥ ${t.proteinGoalG} (add ${Math.ceil(t.proteinGoalG - totals.protein)}).`);
  }
  if (t.fatGoalG !== undefined) {
    lines.push(`- Fat: now ${Math.round(totals.fat)}, target ${t.fatGoalG} (${signed(totals.fat - t.fatGoalG)}).`);
  }
  if (t.carbsGoalG !== undefined) {
    lines.push(`- Carbs: now ${Math.round(totals.carbs)}, target ${t.carbsGoalG} (${signed(totals.carbs - t.carbsGoalG)}).`);
  }
  if (t.sugarMaxG !== undefined && totals.sugar > t.sugarMaxG) {
    lines.push(`- Sugar: now ${Math.round(totals.sugar)}, must be ≤ ${t.sugarMaxG} (cut ${Math.ceil(totals.sugar - t.sugarMaxG)}).`);
  }
  if (t.fiberMinG !== undefined && totals.fiber < t.fiberMinG) {
    lines.push(`- Fiber: now ${Math.round(totals.fiber)}, must be ≥ ${t.fiberMinG} (add ${Math.ceil(t.fiberMinG - totals.fiber)}).`);
  }
  return (
    "CORRECTION: your previous menu missed targets. Adjust grams (or swap candidate " +
    "foods) to fix these, keeping whole foods as the bulk:\n" +
    lines.join("\n") +
    "\nReturn the corrected STRICT JSON menu (same format). Numbers above are for your " +
    "reasoning only — still output ONLY name+grams."
  );
}

function signed(delta: number): string {
  const r = Math.round(delta);
  return r >= 0 ? `+${r}` : `${r}`;
}

// ---------------------------------------------------------------------------
// Один вызов модели + очистка результата
// ---------------------------------------------------------------------------

/**
 * Парсит JSON-ответ модели для menu-build с устойчивостью к мусору вокруг:
 * 1) пробуем JSON.parse после снятия markdown-ограждений;
 * 2) если не вышло — извлекаем первый сбалансированный объект {...}
 *    (от первой '{' до её парной '}') и парсим его;
 * 3) если и это не помогло — бросаем "unparseable JSON".
 */
function parseMenuJson(text: string): unknown {
  const stripped = stripJsonFences(text);
  try {
    return JSON.parse(stripped);
  } catch {
    // fall through to balanced-object extraction
  }
  const candidate = extractFirstJsonObject(stripped);
  if (candidate !== null) {
    try {
      return JSON.parse(candidate);
    } catch {
      // fall through to throw
    }
  }
  throw new Error("AI returned unparseable JSON for menu-build.");
}

/**
 * Возвращает подстроку первого сбалансированного top-level объекта `{ ... }`
 * (с учётом строк и экранирования), либо null, если такого нет.
 */
function extractFirstJsonObject(text: string): string | null {
  const start = text.indexOf("{");
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
    } else if (ch === "{") {
      depth++;
    } else if (ch === "}") {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}

async function callAndClean(args: {
  system: string;
  user: string;
  mealNames: string[];
  validNames: Set<string>;
}): Promise<{ meals: MenuMeal[]; note: string }> {
  const { system, user, mealNames, validNames } = args;

  const text = await generateText({
    system,
    user,
    // Полное меню (несколько приёмов × позиции + note) легко превышает 1500
    // токенов и обрезается → невалидный JSON. Поднимаем потолок (ADR-046).
    maxTokens: 4000,
    tier: "smart",
    json: true,
  });

  const parsed = parseMenuJson(text);
  const result = RawMenuSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected menu-build shape.");
  }

  // Страховка от галлюцинаций: выбрасываем позиции, которых нет среди кандидатов,
  // и приёмы, которых не просили; граммы округляем до кратных 10.
  const requested = new Set(mealNames);
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

// ---------------------------------------------------------------------------
// Серверный расчёт итогов и проверка допусков (числа считает КОД, не модель)
// ---------------------------------------------------------------------------

/** Считает дневные итоги из выбранных позиций: grams × per-100g кандидата. */
export function computeTotals(
  meals: MenuMeal[],
  byName: Map<string, MenuCandidate>
): MenuTotals {
  const totals: MenuTotals = { calories: 0, protein: 0, fat: 0, carbs: 0, sugar: 0, fiber: 0 };
  for (const meal of meals) {
    for (const item of meal.items) {
      const cand = byName.get(item.name);
      if (!cand) continue;
      const factor = item.grams / 100;
      totals.calories += (cand.per100g.calories ?? 0) * factor;
      totals.protein += (cand.per100g.protein ?? 0) * factor;
      totals.fat += (cand.per100g.fat ?? 0) * factor;
      totals.carbs += (cand.per100g.carbs ?? 0) * factor;
      totals.sugar += (cand.per100g.sugar ?? 0) * factor;
      totals.fiber += (cand.per100g.fiber ?? 0) * factor;
    }
  }
  // Округляем до 1 знака для стабильного вывода/сравнения.
  return {
    calories: round1(totals.calories),
    protein: round1(totals.protein),
    fat: round1(totals.fat),
    carbs: round1(totals.carbs),
    sugar: round1(totals.sugar),
    fiber: round1(totals.fiber),
  };
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

/**
 * «Жёсткие» допуски для решения о ретрае (вне этих границ → ретрай / off_target):
 *   kcal > ±10%, protein ниже цели более чем на 5%, fat/carbs > ±20%,
 *   sugar > cap, fiber < min.
 */
function withinTolerance(totals: MenuTotals, t: MacroTargets): boolean {
  if (Math.abs(totals.calories - t.calorieGoal) > t.calorieGoal * 0.1) return false;
  if (totals.protein < t.proteinGoalG * 0.95) return false;
  if (t.fatGoalG !== undefined && Math.abs(totals.fat - t.fatGoalG) > t.fatGoalG * 0.2) return false;
  if (t.carbsGoalG !== undefined && Math.abs(totals.carbs - t.carbsGoalG) > t.carbsGoalG * 0.2) return false;
  if (t.sugarMaxG !== undefined && totals.sugar > t.sugarMaxG) return false;
  if (t.fiberMinG !== undefined && totals.fiber < t.fiberMinG) return false;
  return true;
}

/** Нормированная «штрафная» метрика для выбора лучшей из двух попыток. */
function targetScore(totals: MenuTotals, t: MacroTargets): number {
  let score = Math.abs(totals.calories - t.calorieGoal) / t.calorieGoal;
  score += Math.max(0, t.proteinGoalG - totals.protein) / t.proteinGoalG;
  if (t.fatGoalG !== undefined && t.fatGoalG > 0) {
    score += Math.abs(totals.fat - t.fatGoalG) / t.fatGoalG;
  }
  if (t.carbsGoalG !== undefined && t.carbsGoalG > 0) {
    score += Math.abs(totals.carbs - t.carbsGoalG) / t.carbsGoalG;
  }
  if (t.sugarMaxG !== undefined && t.sugarMaxG > 0) {
    score += Math.max(0, totals.sugar - t.sugarMaxG) / t.sugarMaxG;
  }
  if (t.fiberMinG !== undefined && t.fiberMinG > 0) {
    score += Math.max(0, t.fiberMinG - totals.fiber) / t.fiberMinG;
  }
  return score;
}

// ---------------------------------------------------------------------------
// Приёмы пищи по количеству
// ---------------------------------------------------------------------------

/**
 * Возвращает ровно `count` имён приёмов. Если переданных имён хватает —
 * берём первые `count`. Если меньше — дополняем дефолтными именами,
 * не дублируя уже имеющиеся.
 */
function resolveMealNames(provided: string[], count: number): string[] {
  const n = Math.max(1, Math.min(8, Math.round(count)));
  if (provided.length >= n) return provided.slice(0, n);

  const result = [...provided];
  const defaults = ["breakfast", "lunch", "dinner", "snack", "snack 2", "snack 3", "snack 4", "snack 5"];
  for (const name of defaults) {
    if (result.length >= n) break;
    if (!result.includes(name)) result.push(name);
  }
  // На случай экзотики — добиваем нумерованными meal N.
  let i = result.length + 1;
  while (result.length < n) {
    const name = `meal ${i++}`;
    if (!result.includes(name)) result.push(name);
  }
  return result;
}
