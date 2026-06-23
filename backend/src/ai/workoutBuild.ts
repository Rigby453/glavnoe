/**
 * Feature A: AI workout program builder (premium, Phase 2).
 * Модель выступает в роли тренера по силовой и составляет недельную программу
 * ТОЛЬКО из доступного оборудования под цель/опыт/время пользователя. Вес НЕ
 * прописывается (первый проход — простая программа: подходы/повторы/отдых).
 * Вызов модели — ТОЛЬКО через provider.ts (ADR-022).
 *
 * ADR-051: smart-тир, generous maxTokens (4000, как menu-build по ADR-046,
 * чтобы JSON не обрезался), устойчивый парсинг + 1 ретрай, клемп числа дней к
 * days_per_week.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";

export type WorkoutGoal =
  | "strength"
  | "muscle"
  | "fat_loss"
  | "endurance"
  | "general";
export type WorkoutExperience = "beginner" | "intermediate" | "advanced";

export interface WorkoutExercise {
  name: string;
  sets: number;
  reps: string;
  restSeconds: number;
  note?: string;
}

export interface WorkoutDay {
  title: string;
  exercises: WorkoutExercise[];
}

// Модель возвращает программу: имя, дни (title + упражнения), coach-note.
// reps — строка (диапазоны "8-12" или "AMRAP"); вес не прописывается.
const RawExerciseSchema = z.object({
  name: z.string().min(1),
  sets: z.number().int().min(1).max(20),
  reps: z.string().min(1).max(40),
  rest_seconds: z.number().int().min(0).max(900),
  note: z.string().max(300).optional(),
});

const RawProgramSchema = z.object({
  program_name: z.string().min(1),
  days: z
    .array(
      z.object({
        title: z.string().min(1),
        exercises: z.array(RawExerciseSchema).min(1),
      })
    )
    .min(1),
  note: z.string(),
});

/**
 * Составляет недельную программу тренировок под цель/опыт/оборудование/время.
 * @param goal - цель (strength | muscle | fat_loss | endurance | general)
 * @param experience - уровень (beginner | intermediate | advanced)
 * @param equipment - доступное оборудование (напр. ["barbell","dumbbells"])
 * @param daysPerWeek - число тренировочных дней в неделю (1..7); число дней в
 *   ответе клемпится к этому значению
 * @param minutesPerSession - длительность одной тренировки, мин
 * @param focus - приоритетная часть тела / упражнение (опционально)
 * @param limitations - травмы/ограничения, которых надо избегать (опционально)
 * @param tone - тон coach-note (gentle/harsh), без оскорблений в обоих
 * @param language - язык человекочитаемого текста (по умолчанию "English")
 * @param profile - опциональный профиль (пол/возраст/вес/рост) для контекста
 *
 * @returns programName, days (title + упражнения), note (coach-note).
 */
export async function buildWorkoutProgram(params: {
  goal: WorkoutGoal;
  experience: WorkoutExperience;
  equipment: string[];
  daysPerWeek: number;
  minutesPerSession: number;
  focus?: string;
  limitations?: string;
  tone: "gentle" | "harsh";
  language?: string;
  profile?: {
    sex?: string;
    age?: number;
    weightKg?: number;
    heightCm?: number;
  };
}): Promise<{ programName: string; days: WorkoutDay[]; note: string }> {
  const {
    goal,
    experience,
    equipment,
    daysPerWeek,
    minutesPerSession,
    focus,
    limitations,
    tone,
    language = "English",
    profile,
  } = params;

  // Клемп числа дней к запрошенному диапазону (1..7).
  const targetDays = Math.max(1, Math.min(7, Math.round(daysPerWeek)));

  const system = buildSystemPrompt({
    goal,
    experience,
    equipment,
    daysPerWeek: targetDays,
    minutesPerSession,
    focus,
    limitations,
    tone,
    language,
    profile,
  });

  const baseUser = JSON.stringify({
    goal,
    experience,
    equipment,
    days_per_week: targetDays,
    minutes_per_session: minutesPerSession,
    ...(focus !== undefined ? { focus } : {}),
    ...(limitations !== undefined ? { limitations } : {}),
    ...(profile !== undefined
      ? {
          profile: {
            ...(profile.sex !== undefined ? { sex: profile.sex } : {}),
            ...(profile.age !== undefined ? { age: profile.age } : {}),
            ...(profile.weightKg !== undefined
              ? { weight_kg: profile.weightKg }
              : {}),
            ...(profile.heightCm !== undefined
              ? { height_cm: profile.heightCm }
              : {}),
          },
        }
      : {}),
  });

  // --- Ограниченный валидационный цикл: максимум 2 вызова модели (1 ретрай). ---
  // Если первый ответ не парсится / не проходит схему — один ретрай, затем
  // понятная ошибка. Мирроринг menuBuild.
  const MAX_CALLS = 2;
  let lastError: unknown = null;

  for (let attempt = 0; attempt < MAX_CALLS; attempt++) {
    try {
      const program = await callAndClean({
        system,
        user: baseUser,
        targetDays,
      });
      return program;
    } catch (err) {
      lastError = err;
      // ретрай только если он ещё остался
    }
  }

  throw lastError instanceof Error
    ? lastError
    : new Error("AI failed to build a workout program.");
}

// ---------------------------------------------------------------------------
// Промпт
// ---------------------------------------------------------------------------

function buildSystemPrompt(args: {
  goal: WorkoutGoal;
  experience: WorkoutExperience;
  equipment: string[];
  daysPerWeek: number;
  minutesPerSession: number;
  focus?: string;
  limitations?: string;
  tone: "gentle" | "harsh";
  language: string;
  profile?: { sex?: string; age?: number; weightKg?: number; heightCm?: number };
}): string {
  const {
    goal,
    experience,
    equipment,
    daysPerWeek,
    minutesPerSession,
    focus,
    limitations,
    tone,
    language,
    profile,
  } = args;

  const equipmentList =
    equipment.length > 0 ? equipment.join(", ") : "bodyweight only";

  let system =
    "You are a strength and conditioning coach for a student planner. Design a " +
    "weekly workout program tailored to the athlete's goal, experience, available " +
    "equipment, training days and time per session. Do NOT prescribe weights/loads — " +
    "only exercise name, sets, a reps string (ranges like \"8-12\" or \"AMRAP\" are " +
    "allowed), rest in seconds, and an optional short note.\n\n" +
    "CONSTRAINTS (respect ALL of them):\n" +
    `- Goal: ${goal}.\n` +
    `- Experience: ${experience} — match exercise complexity and volume to this level.\n` +
    `- Equipment available (use ONLY these): ${equipmentList}. NEVER program an exercise that needs equipment not listed.\n` +
    `- Training days: produce EXACTLY ${daysPerWeek} day(s), no more, no fewer.\n` +
    `- Time budget: each day must realistically fit in about ${minutesPerSession} minutes (sets × reps × rest).\n`;

  if (focus?.trim()) {
    system += `- Priority focus: emphasize ${focus.trim()} across the week (extra volume/frequency), without neglecting balance.\n`;
  }
  if (limitations?.trim()) {
    system +=
      `- Limitations/injuries to work AROUND: ${limitations.trim()}. NEVER include any exercise that aggravates this; pick safe alternatives.\n`;
  }
  if (profile) {
    const bits: string[] = [];
    if (profile.sex?.trim()) bits.push(`sex ${profile.sex.trim()}`);
    if (profile.age !== undefined) bits.push(`age ${profile.age}`);
    if (profile.weightKg !== undefined) bits.push(`weight ${profile.weightKg} kg`);
    if (profile.heightCm !== undefined) bits.push(`height ${profile.heightCm} cm`);
    if (bits.length > 0) {
      system += `- Athlete context (for sensible volume, NOT load): ${bits.join(", ")}.\n`;
    }
  }

  system +=
    "\nPROGRAM STRUCTURE:\n" +
    "- Give each day a short title that names the split or emphasis, e.g. \"Day 1 — Push\".\n" +
    "- Each day must have at least one exercise; use a sensible number for the time budget.\n" +
    "- sets is an integer; reps is a STRING (e.g. \"8-12\", \"5\", \"AMRAP\"); rest_seconds is an integer.\n\n" +
    "Also write 'note': a SHORT coach note for the whole program in a " +
    (tone === "harsh"
      ? "blunt, no-nonsense (but never insulting)"
      : "warm, encouraging") +
    " tone — no shaming.\n\n" +
    'Return STRICT JSON only (no prose, no markdown fences): {"program_name": string, ' +
    '"days": [{"title": string, "exercises": [{"name": string, "sets": number, ' +
    '"reps": string, "rest_seconds": number, "note": string}]}], "note": string}. ' +
    "The note field on an exercise is optional — omit it if there's nothing to add." +
    `\n\nIMPORTANT: Write all human-readable text (program_name, day titles, exercise ` +
    `names, notes) in ${language}. Keep JSON keys exactly as specified in English.`;

  return system;
}

// ---------------------------------------------------------------------------
// Один вызов модели + очистка результата
// ---------------------------------------------------------------------------

/**
 * Парсит JSON-ответ модели для workout-build с устойчивостью к мусору вокруг
 * (мирроринг menuBuild): JSON.parse после снятия fences → первый сбалансированный
 * объект → ошибка "unparseable JSON".
 */
function parseProgramJson(text: string): unknown {
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
  throw new Error("AI returned unparseable JSON for workout-build.");
}

/**
 * Возвращает подстроку первого сбалансированного top-level объекта `{ ... }`
 * (с учётом строк и экранирования), либо null.
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
  targetDays: number;
}): Promise<{ programName: string; days: WorkoutDay[]; note: string }> {
  const { system, user, targetDays } = args;

  const text = await generateText({
    system,
    user,
    // Несколько дней × упражнения + note легко превышают 1500 токенов и
    // обрезаются → невалидный JSON. Поднимаем потолок (мирроринг ADR-046).
    maxTokens: 4000,
    tier: "smart",
    json: true,
  });

  const parsed = parseProgramJson(text);
  const result = RawProgramSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected workout-build shape.");
  }

  // Клемп числа дней к запрошенному days_per_week (защита от лишних дней).
  const days: WorkoutDay[] = result.data.days
    .slice(0, targetDays)
    .map((d) => ({
      title: d.title,
      exercises: d.exercises.map((e) => ({
        name: e.name,
        sets: e.sets,
        reps: e.reps,
        restSeconds: e.rest_seconds,
        ...(e.note !== undefined && e.note.trim() !== ""
          ? { note: e.note }
          : {}),
      })),
    }));

  if (days.length === 0 || days.every((d) => d.exercises.length === 0)) {
    throw new Error("AI returned no usable workout program.");
  }

  return {
    programName: result.data.program_name,
    days,
    note: result.data.note,
  };
}
