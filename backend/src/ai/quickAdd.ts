/**
 * Волна 6 / Этап 1: ИИ быстрое добавление — свободная фраза → одна задача
 * (premium). Например «на работу через час в Бутово» → type=event,
 * scheduled_at=now+1h, note содержит место. Сервер ничего не сохраняет —
 * клиент показывает превью/подтверждение (решение B).
 *
 * Волна 6 / Этап 4 (docs/WAVE6-REVIEW-FINDINGS.md, секция A):
 * - п.1: scheduled_at/deadline — naive-local ISO БЕЗ "Z" (модель работает в
 *   таймзоне пользователя и не конвертирует в UTC).
 * - п.2: user-payload несёт now (локальное «сейчас», см. localTime.ts) —
 *   без него «через час» неразрешимо (раньше был только today=date).
 * - п.4: ответ модели ограничен по размеру (title/note/duration/диапазон дат).
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";
import { withAiRetry } from "./retry.js";
import { languageDirectiveForFields } from "./langDirective.js";
import { localNowFor } from "./localTime.js";

// Naive-local ISO: "YYYY-MM-DDTHH:MM" или "YYYY-MM-DDTHH:MM:SS" — БЕЗ "Z"/
// смещения. Контракт: время уже в таймзоне пользователя (docs/WAVE6-REVIEW-FINDINGS.md п.1).
const NAIVE_LOCAL_DATETIME_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/;

// Постобработка (п.4): жёсткие потолки поверх Zod.
const kTitleMaxOut = 200;
const kNoteMaxOut = 500;
const kDurationMinOut = 5;
const kDurationMaxOut = 480;

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
  title: z.string().min(1).max(300),
  type: z.enum(["task", "event", "exam", "deadline"]),
  priority: z.enum(["low", "medium", "high", "main"]),
  scheduled_at: z.string().regex(NAIVE_LOCAL_DATETIME_RE).optional(),
  deadline: z.string().regex(NAIVE_LOCAL_DATETIME_RE).optional(),
  duration_minutes: z.number().int().positive().optional(),
  note: z.string().max(800).optional(),
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
 * [referenceDate-1год, referenceDate+2года] (п.4).
 */
function withinDateRange(naiveDateTime: string, referenceDate: string): boolean {
  const day = naiveDateTime.slice(0, 10);
  const lower = shiftYears(referenceDate, -1);
  const upper = shiftYears(referenceDate, 2);
  return day >= lower && day <= upper;
}

/**
 * Разбирает свободную фразу («на работу через час в Бутово», «сдать эссе
 * в пятницу») в одну структурированную задачу. Тип/важность — на усмотрение
 * модели; относительные даты («через час», «завтра») считаются от date+now+timezone.
 * @param text - свободная фраза пользователя (голос/текст)
 * @param date - 'YYYY-MM-DD', точка отсчёта для относительных дат
 * @param timezone - IANA-таймзона пользователя (или "UTC±HH:MM" от web)
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

  const now = localNowFor(timezone);

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
    `Friday') against today = ${date}, current local time now = ${now} — both ` +
    `are already in the user's local timezone (${timezone}). If the phrase ` +
    "gives no date/time at all, omit scheduled_at and deadline — do not guess.\n" +
    "3. scheduled_at and deadline, when present, are ALWAYS in the user's local " +
    "timezone. Do NOT convert to UTC, do NOT append 'Z' or any offset. Format " +
    'strictly as "YYYY-MM-DDTHH:MM:SS" (naive local time, no timezone suffix).\n' +
    "4. If the phrase mentions a place or extra detail (e.g. a location), put " +
    "it in the note field.\n" +
    "5. priority: pick 'main' only if the phrase clearly signals top " +
    "importance/urgency; otherwise 'high'/'medium'/'low'.\n\n" +
    "Return STRICT JSON only — no prose, no markdown fences:\n" +
    '{"title": "string", "type": "task|event|exam|deadline", ' +
    '"priority": "low|medium|high|main", "scheduled_at": "YYYY-MM-DDTHH:MM:SS", ' +
    '"deadline": "YYYY-MM-DDTHH:MM:SS", "duration_minutes": number, "note": "string"}\n\n' +
    `IMPORTANT: ${langLine}`;

  const user = JSON.stringify({ text, today: date, now, timezone });

  const raw = await withAiRetry(() => callAndParse({ system, user }));

  const task: QuickAddTask = {
    title: truncate(raw.title, kTitleMaxOut),
    type: raw.type,
    priority: raw.priority,
  };
  if (raw.scheduled_at !== undefined && withinDateRange(raw.scheduled_at, date)) {
    task.scheduledAt = raw.scheduled_at;
  }
  if (raw.deadline !== undefined && withinDateRange(raw.deadline, date)) {
    task.deadline = raw.deadline;
  }
  if (raw.duration_minutes !== undefined) task.durationMinutes = clampDuration(raw.duration_minutes);
  if (raw.note !== undefined) task.note = truncate(raw.note, kNoteMaxOut);

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
