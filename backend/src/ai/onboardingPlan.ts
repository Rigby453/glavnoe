/**
 * Волна 6 / Этап 1: ИИ-онбординг — «брейн-дамп» → черновой план (premium).
 * Пользователь свободным текстом описывает свои цели/задачи/расписание;
 * модель раскладывает это в структурированный план (цели + задачи).
 * Сервер НИЧЕГО не сохраняет — только возвращает превью (решение B,
 * AI-ONBOARDING-DESIGN.md). Даты — только явные/относительные из ответов,
 * относительные считаются от переданной date; модель не имеет права
 * выдумывать даты/дедлайны, которых нет в тексте пользователя.
 *
 * Волна 6 / Этап 4 (docs/WAVE6-REVIEW-FINDINGS.md, секция A):
 * - п.1: scheduled_at/deadline — naive-local ISO БЕЗ "Z" (модель работает в
 *   таймзоне пользователя и не конвертирует в UTC).
 * - п.2: user-payload несёт now (локальное «сейчас», см. localTime.ts) —
 *   без него относительные времена вроде «через час» неразрешимы.
 * - п.4: ответ модели ограничен по размеру (title/note/массивы/duration/
 *   диапазон дат) — защита от неограниченного/дефектного вывода.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";
import { withAiRetry } from "./retry.js";
import { languageDirectiveForFields } from "./langDirective.js";
import { localNowFor } from "./localTime.js";

const kMaxMainTasks = 3;

// Naive-local ISO: "YYYY-MM-DDTHH:MM" или "YYYY-MM-DDTHH:MM:SS" — БЕЗ "Z"/
// смещения. Контракт: время уже в таймзоне пользователя (docs/WAVE6-REVIEW-FINDINGS.md п.1).
const NAIVE_LOCAL_DATETIME_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/;

// Постобработка (п.4): жёсткие потолки поверх Zod — обрезаем, не отбрасываем
// задачу целиком (кроме дат вне диапазона — там отбрасывается только поле).
const kTitleMaxOut = 200;
const kNoteMaxOut = 500;
const kDurationMinOut = 5;
const kDurationMaxOut = 480;

export interface OnboardingGoal {
  title: string;
  horizon?: "week" | "month" | "quarter" | "year";
}

export interface OnboardingTask {
  title: string;
  type: "task" | "event" | "exam" | "deadline";
  priority: "low" | "medium" | "high" | "main";
  scheduledAt?: string;
  deadline?: string;
  durationMinutes?: number;
  note?: string;
}

export interface OnboardingPlan {
  goals: OnboardingGoal[];
  tasks: OnboardingTask[];
  foodPrefs?: {
    tracksFood: boolean;
    tracksWater: boolean;
    tracksSleep: boolean;
  };
}

const RawPlanSchema = z.object({
  goals: z
    .array(
      z.object({
        title: z.string().min(1).max(300),
        horizon: z.enum(["week", "month", "quarter", "year"]).optional(),
      })
    )
    .max(10)
    .default([]),
  tasks: z
    .array(
      z.object({
        title: z.string().min(1).max(300),
        type: z.enum(["task", "event", "exam", "deadline"]),
        priority: z.enum(["low", "medium", "high", "main"]),
        scheduled_at: z.string().regex(NAIVE_LOCAL_DATETIME_RE).optional(),
        deadline: z.string().regex(NAIVE_LOCAL_DATETIME_RE).optional(),
        duration_minutes: z.number().int().positive().optional(),
        note: z.string().max(800).optional(),
      })
    )
    .max(30)
    .default([]),
  food_prefs: z
    .object({
      tracks_food: z.boolean(),
      tracks_water: z.boolean(),
      tracks_sleep: z.boolean(),
    })
    .optional(),
});

/** Обрезает строку до max символов (постобработка сверх Zod-потолка). */
function truncate(s: string, max: number): string {
  return s.length > max ? s.slice(0, max) : s;
}

/** Клампит duration_minutes в разумный диапазон 5..480. */
function clampDuration(n: number): number {
  return Math.min(kDurationMaxOut, Math.max(kDurationMinOut, Math.round(n)));
}

/** referenceDate ± years, как 'YYYY-MM-DD' (для лексикографического сравнения). */
function shiftYears(referenceDate: string, years: number): string {
  const parts = referenceDate.split("-").map(Number);
  const y = parts[0] ?? 1970;
  const mo = parts[1] ?? 1;
  const d = parts[2] ?? 1;
  return new Date(Date.UTC(y + years, mo - 1, d)).toISOString().slice(0, 10);
}

/**
 * true, если naive-local datetime (YYYY-MM-DDTHH:MM...) попадает в
 * [referenceDate-1год, referenceDate+2года] (п.4). Сравнение по календарной
 * дате (первые 10 символов) — naive-local, часовой пояс тут не участвует.
 */
function withinDateRange(naiveDateTime: string, referenceDate: string): boolean {
  const day = naiveDateTime.slice(0, 10);
  const lower = shiftYears(referenceDate, -1);
  const upper = shiftYears(referenceDate, 2);
  return day >= lower && day <= upper;
}

/**
 * Строит черновой план (цели + задачи) из свободного текста онбординга.
 * @param answers - свободный текст пользователя (брейн-дамп/ответы на вопросы)
 * @param date - 'YYYY-MM-DD', точка отсчёта для относительных дат ("завтра", "через неделю")
 * @param timezone - IANA-таймзона пользователя (или "UTC±HH:MM" от web), для
 *   пересчёта относительных дат и вычисления localNowFor()
 * @param language - язык текстовых полей (title/note/goals.title), по умолчанию "English"
 * @param languageCode - ISO-код языка, усиливает языковую инструкцию
 */
export async function generateOnboardingPlan(params: {
  answers: string;
  date: string;
  timezone: string;
  language?: string;
  languageCode?: string;
}): Promise<OnboardingPlan> {
  const { answers, date, timezone, language = "English", languageCode } = params;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new Error(`date must be YYYY-MM-DD, got "${date}"`);
  }
  if (!answers.trim()) {
    return { goals: [], tasks: [] };
  }

  const now = localNowFor(timezone);

  const langLine = languageDirectiveForFields(
    "the title, note, and goals.title fields",
    language,
    languageCode
  );

  const system =
    `${langLine}\n\n` +
    "You are a study planner assistant. A student just wrote a free-form " +
    "brain-dump describing their goals, upcoming tasks, deadlines, exams, and " +
    "daily habits. Turn it into a structured draft plan.\n\n" +
    "Rules:\n" +
    "1. Extract GOALS (longer-term aspirations, e.g. 'pass the algebra exam', " +
    "'get fit') separately from TASKS (concrete actionable items).\n" +
    "2. For each task, pick type: 'task' (generic to-do), 'event' (has a fixed " +
    "time/place), 'exam', or 'deadline' (a due date, not a scheduled time).\n" +
    "3. DO NOT invent dates or times. Only set scheduled_at/deadline when the " +
    `user's text gives an explicit or relative date/time (e.g. "tomorrow at 9am", ` +
    '"next Friday", "in two weeks"). Resolve relative dates against ' +
    `today = ${date}, current local time now = ${now} — both are already in the ` +
    `user's local timezone (${timezone}). If no date is mentioned for a task, ` +
    "omit scheduled_at and deadline entirely — do not guess.\n" +
    "4. scheduled_at and deadline, when present, are ALWAYS in the user's local " +
    "timezone. Do NOT convert to UTC, do NOT append 'Z' or any offset. Format " +
    'strictly as "YYYY-MM-DDTHH:MM:SS" (naive local time, no timezone suffix).\n' +
    "5. Mark priority='main' SPARINGLY — at most 3 tasks total, only the truly " +
    "most important ones. Use 'high'/'medium'/'low' for the rest.\n" +
    "6. If the user's text is short or vague, return FEW tasks — do not " +
    "fabricate tasks or goals that aren't grounded in the text.\n" +
    "7. Optionally infer food_prefs (tracks_food/tracks_water/tracks_sleep as " +
    "booleans) ONLY if the text clearly mentions wanting to track nutrition, " +
    "water, or sleep — otherwise omit the food_prefs field entirely.\n\n" +
    "Return STRICT JSON only — no prose, no markdown fences:\n" +
    '{"goals": [{"title": "string", "horizon": "week|month|quarter|year"}], ' +
    '"tasks": [{"title": "string", "type": "task|event|exam|deadline", ' +
    '"priority": "low|medium|high|main", "scheduled_at": "YYYY-MM-DDTHH:MM:SS", ' +
    '"deadline": "YYYY-MM-DDTHH:MM:SS", "duration_minutes": number, "note": "string"}], ' +
    '"food_prefs": {"tracks_food": bool, "tracks_water": bool, "tracks_sleep": bool}}\n\n' +
    `IMPORTANT: ${langLine}`;

  const user = JSON.stringify({ answers, today: date, now, timezone });

  const raw = await withAiRetry(() => callAndParse({ system, user }));

  // Отфильтровываем задачи без title (страховка сверх Zod) и ограничиваем
  // priority='main' максимум kMaxMainTasks — лишние понижаем до 'high'.
  let mainCount = 0;
  const tasks: OnboardingTask[] = raw.tasks
    .filter((t) => t.title.trim().length > 0)
    .map((t) => {
      let priority = t.priority;
      if (priority === "main") {
        mainCount += 1;
        if (mainCount > kMaxMainTasks) priority = "high";
      }
      const task: OnboardingTask = {
        title: truncate(t.title, kTitleMaxOut),
        type: t.type,
        priority,
      };
      if (t.scheduled_at !== undefined && withinDateRange(t.scheduled_at, date)) {
        task.scheduledAt = t.scheduled_at;
      }
      if (t.deadline !== undefined && withinDateRange(t.deadline, date)) {
        task.deadline = t.deadline;
      }
      if (t.duration_minutes !== undefined) task.durationMinutes = clampDuration(t.duration_minutes);
      if (t.note !== undefined) task.note = truncate(t.note, kNoteMaxOut);
      return task;
    });

  const goals: OnboardingGoal[] = raw.goals
    .filter((g) => g.title.trim().length > 0)
    .map((g) =>
      g.horizon !== undefined
        ? { title: truncate(g.title, kTitleMaxOut), horizon: g.horizon }
        : { title: truncate(g.title, kTitleMaxOut) }
    );

  const result: OnboardingPlan = { goals, tasks };
  if (raw.food_prefs !== undefined) {
    result.foodPrefs = {
      tracksFood: raw.food_prefs.tracks_food,
      tracksWater: raw.food_prefs.tracks_water,
      tracksSleep: raw.food_prefs.tracks_sleep,
    };
  }
  return result;
}

async function callAndParse(args: {
  system: string;
  user: string;
}): Promise<z.infer<typeof RawPlanSchema>> {
  const text = await generateText({
    system: args.system,
    user: args.user,
    maxTokens: 2000,
    tier: "smart",
    json: true,
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned unparseable JSON for onboarding-plan.");
  }
  const result = RawPlanSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected onboarding-plan shape.");
  }
  return result.data;
}
