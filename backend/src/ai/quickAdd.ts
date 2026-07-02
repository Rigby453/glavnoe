/**
 * Волна 6 / Этап 1: ИИ быстрое добавление — свободная фраза → одна задача
 * (premium). Например «на работу через час в Бутово» → type=event,
 * scheduled_at=now+1h, note содержит место. Сервер ничего не сохраняет —
 * клиент показывает превью/подтверждение (решение B).
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";
import { withAiRetry } from "./retry.js";
import { languageDirectiveForFields } from "./langDirective.js";

export interface QuickAddTask {
  title: string;
  type: "task" | "event" | "exam" | "deadline";
  priority: "low" | "medium" | "high" | "main";
  scheduledAt?: string;
  deadline?: string;
  durationMinutes?: number;
  note?: string;
}

const RawTaskSchema = z.object({
  title: z.string().min(1),
  type: z.enum(["task", "event", "exam", "deadline"]),
  priority: z.enum(["low", "medium", "high", "main"]),
  scheduled_at: z.string().optional(),
  deadline: z.string().optional(),
  duration_minutes: z.number().int().positive().optional(),
  note: z.string().optional(),
});

/**
 * Разбирает свободную фразу («на работу через час в Бутово», «сдать эссе
 * в пятницу») в одну структурированную задачу. Тип/важность — на усмотрение
 * модели; относительные даты («через час», «завтра») считаются от date+timezone.
 * @param text - свободная фраза пользователя (голос/текст)
 * @param date - 'YYYY-MM-DD', точка отсчёта для относительных дат
 * @param timezone - IANA-таймзона пользователя
 * @param language - язык текстовых полей (title/note), по умолчанию "English"
 * @param languageCode - ISO-код языка, усиливает языковую инструкцию
 */
export async function generateQuickAddTask(params: {
  text: string;
  date: string;
  timezone: string;
  language?: string;
  languageCode?: string;
}): Promise<{ task: QuickAddTask }> {
  const { text, date, timezone, language = "English", languageCode } = params;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new Error(`date must be YYYY-MM-DD, got "${date}"`);
  }

  const langLine = languageDirectiveForFields("the title and note fields", language, languageCode);

  const system =
    `${langLine}\n\n` +
    "You are a study planner assistant. The user typed (or spoke) a short " +
    "free-form phrase describing ONE thing they need to do. Turn it into a " +
    "single structured task.\n\n" +
    "Rules:\n" +
    "1. Pick type: 'task' (generic to-do), 'event' (has a fixed time/place), " +
    "'exam', or 'deadline' (a due date, not a scheduled time). You are the " +
    "authority on type and priority — infer them from context.\n" +
    "2. Resolve relative dates/times (e.g. 'in an hour', 'tomorrow', 'next " +
    `Friday') against today = ${date} in timezone ${timezone}. If the phrase ` +
    "gives no date/time at all, omit scheduled_at and deadline — do not guess.\n" +
    "3. scheduled_at and deadline, when present, must be full ISO 8601 " +
    "date-time strings (e.g. \"2026-07-05T09:00:00.000Z\").\n" +
    "4. If the phrase mentions a place or extra detail (e.g. a location), put " +
    "it in the note field.\n" +
    "5. priority: pick 'main' only if the phrase clearly signals top " +
    "importance/urgency; otherwise 'high'/'medium'/'low'.\n\n" +
    "Return STRICT JSON only — no prose, no markdown fences:\n" +
    '{"title": "string", "type": "task|event|exam|deadline", ' +
    '"priority": "low|medium|high|main", "scheduled_at": "ISO string", ' +
    '"deadline": "ISO string", "duration_minutes": number, "note": "string"}\n\n' +
    `IMPORTANT: ${langLine}`;

  const user = JSON.stringify({ text, today: date, timezone });

  const raw = await withAiRetry(() => callAndParse({ system, user }));

  const task: QuickAddTask = {
    title: raw.title,
    type: raw.type,
    priority: raw.priority,
  };
  if (raw.scheduled_at !== undefined) task.scheduledAt = raw.scheduled_at;
  if (raw.deadline !== undefined) task.deadline = raw.deadline;
  if (raw.duration_minutes !== undefined) task.durationMinutes = raw.duration_minutes;
  if (raw.note !== undefined) task.note = raw.note;

  return { task };
}

async function callAndParse(args: {
  system: string;
  user: string;
}): Promise<z.infer<typeof RawTaskSchema>> {
  const text = await generateText({
    system: args.system,
    user: args.user,
    maxTokens: 500,
    tier: "smart",
    json: true,
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned unparseable JSON for quick-add.");
  }
  const result = RawTaskSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected quick-add shape.");
  }
  return result.data;
}
