/**
 * AI-06: Импорт расписания из фото (мультимодаль).
 * Распознаёт расписание с изображения через провайдер (Gemini/Claude).
 * Дата-арифметика — в коде (детерминированно); модель только извлекает title+time.
 * Вызов модели — только через provider.ts.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";

export interface ScheduleImportItem {
  title: string;
  /** ISO 8601, UTC — например "2025-09-01T09:00:00.000Z" */
  scheduledAt: string;
}

export interface ScheduleImportResult {
  items: ScheduleImportItem[];
}

const RawEntrySchema = z.object({
  title: z.string().min(1),
  /** 24-часовой формат "HH:MM" */
  time: z.string().regex(/^\d{2}:\d{2}$/, "Expected HH:MM (24-hour format)"),
});
const RawScheduleSchema = z.array(RawEntrySchema);

/**
 * Отправляет изображение расписания в модель и возвращает список занятий.
 *
 * @param params.imageBase64  - base64-строка (без data URI prefix)
 * @param params.mediaType    - MIME-тип изображения
 * @param params.targetDate   - дата 'YYYY-MM-DD' для построения ISO-меток
 */
export async function importScheduleFromPhoto(params: {
  imageBase64: string;
  mediaType: "image/jpeg" | "image/png";
  targetDate: string;
}): Promise<ScheduleImportResult> {
  const { imageBase64, mediaType, targetDate } = params;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
    throw new Error(`targetDate must be in YYYY-MM-DD format, got: "${targetDate}"`);
  }

  const system =
    "You are a timetable extraction assistant. " +
    "Read the schedule or timetable shown in the image. " +
    "Return ONLY a JSON array — no prose, no markdown fences, no extra keys. " +
    "Each element must be an object with exactly two fields: " +
    '"title" (string, the class or event name) and ' +
    '"time" (string, 24-hour format "HH:MM"). ' +
    "If a time cannot be determined for an entry, omit that entry entirely. " +
    "If the image contains no schedule, return an empty array [].";

  const user =
    "Extract all schedule items from this timetable image. " +
    'Return a JSON array of { "title": string, "time": "HH:MM" } objects only.';

  const text = await generateText({
    system,
    user,
    maxTokens: 500,
    tier: "fast",
    json: true,
    image: { base64: imageBase64, mediaType },
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned an unparseable response for schedule import.");
  }
  const result = RawScheduleSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected schedule-import shape.");
  }

  // Строим ScheduleImportItem[], комбинируя targetDate + HH:MM (детерминированно).
  const items: ScheduleImportItem[] = [];
  for (const entry of result.data) {
    const [hhStr, mmStr] = entry.time.split(":");
    const hh = parseInt(hhStr ?? "", 10);
    const mm = parseInt(mmStr ?? "", 10);
    if (isNaN(hh) || isNaN(mm) || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
      continue;
    }
    const scheduledAt = `${targetDate}T${String(hh).padStart(2, "0")}:${String(
      mm
    ).padStart(2, "0")}:00.000Z`;
    items.push({ title: entry.title, scheduledAt });
  }

  return { items };
}
