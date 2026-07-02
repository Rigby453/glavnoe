/**
 * Волна 6 / Этап 1: ИИ-онбординг — «брейн-дамп» → черновой план (premium).
 * Пользователь свободным текстом описывает свои цели/задачи/расписание;
 * модель раскладывает это в структурированный план (цели + задачи).
 * Сервер НИЧЕГО не сохраняет — только возвращает превью (решение B,
 * AI-ONBOARDING-DESIGN.md). Даты — только явные/относительные из ответов,
 * относительные считаются от переданной date; модель не имеет права
 * выдумывать даты/дедлайны, которых нет в тексте пользователя.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";
import { withAiRetry } from "./retry.js";
import { languageDirectiveForFields } from "./langDirective.js";

const kMaxMainTasks = 3;

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
        title: z.string().min(1),
        horizon: z.enum(["week", "month", "quarter", "year"]).optional(),
      })
    )
    .default([]),
  tasks: z
    .array(
      z.object({
        title: z.string().min(1),
        type: z.enum(["task", "event", "exam", "deadline"]),
        priority: z.enum(["low", "medium", "high", "main"]),
        scheduled_at: z.string().optional(),
        deadline: z.string().optional(),
        duration_minutes: z.number().int().positive().optional(),
        note: z.string().optional(),
      })
    )
    .default([]),
  food_prefs: z
    .object({
      tracks_food: z.boolean(),
      tracks_water: z.boolean(),
      tracks_sleep: z.boolean(),
    })
    .optional(),
});

/**
 * Строит черновой план (цели + задачи) из свободного текста онбординга.
 * @param answers - свободный текст пользователя (брейн-дамп/ответы на вопросы)
 * @param date - 'YYYY-MM-DD', точка отсчёта для относительных дат ("завтра", "через неделю")
 * @param timezone - IANA-таймзона пользователя, для корректного пересчёта относительных дат
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
    `today = ${date} in timezone ${timezone}. If no date is mentioned for a task, ` +
    "omit scheduled_at and deadline entirely — do not guess.\n" +
    "4. scheduled_at and deadline, when present, must be full ISO 8601 " +
    "date-time strings (e.g. \"2026-07-05T09:00:00.000Z\").\n" +
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
    '"priority": "low|medium|high|main", "scheduled_at": "ISO string", ' +
    '"deadline": "ISO string", "duration_minutes": number, "note": "string"}], ' +
    '"food_prefs": {"tracks_food": bool, "tracks_water": bool, "tracks_sleep": bool}}\n\n' +
    `IMPORTANT: ${langLine}`;

  const user = JSON.stringify({ answers, today: date, timezone });

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
        title: t.title,
        type: t.type,
        priority,
      };
      if (t.scheduled_at !== undefined) task.scheduledAt = t.scheduled_at;
      if (t.deadline !== undefined) task.deadline = t.deadline;
      if (t.duration_minutes !== undefined) task.durationMinutes = t.duration_minutes;
      if (t.note !== undefined) task.note = t.note;
      return task;
    });

  const goals: OnboardingGoal[] = raw.goals
    .filter((g) => g.title.trim().length > 0)
    .map((g) => (g.horizon !== undefined ? { title: g.title, horizon: g.horizon } : { title: g.title }));

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
