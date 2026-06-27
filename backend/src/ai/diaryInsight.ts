/**
 * AI-04: Инсайт по дневнику (premium).
 * По последним записям (настроение/заметки) даёт 2-3 предложения инсайта
 * через провайдер (Gemini/Claude). Вызов модели — только через provider.ts.
 */

import { generateText } from "./provider.js";
import { unwrapMaybeJson } from "./textResponse.js";

export type Tone = "gentle" | "harsh";

export interface DiaryLogInput {
  date: string; // 'YYYY-MM-DD'
  mood: number | null; // 1-5
  note: string | null;
}

/**
 * Возвращает короткий инсайт по последним записям дневника.
 * @param logs - последние записи (дата, настроение, заметка)
 * @param tone - gentle / harsh
 * @param language - язык инсайта (напр. "Russian"), по умолчанию "English"
 */
export async function generateDiaryInsight(params: {
  logs: DiaryLogInput[];
  tone: Tone;
  language?: string;
}): Promise<{ insight: string }> {
  const { logs, tone, language = "English" } = params;

  const toneHint =
    tone === "harsh"
      ? "Be blunt and direct, name patterns honestly, but never insulting."
      : "Be warm, supportive and constructive.";

  // Запрещаем пересказ данных; требуем вывод — тренд/корреляцию/совет.
  const system =
    "You are a thoughtful assistant analysing a student's diary (mood scores 1-5 and short notes). " +
    "Your task: identify a NON-OBVIOUS insight — a trend over time, a mood-note correlation, " +
    "or a pattern the student cannot simply read off the raw data. " +
    "DO NOT repeat or list the diary entries — the student already sees them. " +
    "DO NOT restate facts like 'your mood was 3 on Tuesday'. " +
    "Instead find WHAT IS CHANGING, WHAT IS CORRELATED, or WHAT MIGHT EXPLAIN the mood pattern. " +
    "End with ONE concrete, actionable suggestion. " +
    "2-3 sentences, plain text, no emoji, no quotes. " +
    "Complete every sentence fully — never stop mid-thought. " +
    toneHint +
    `\n\nIMPORTANT: Write all human-readable text in ${language}. Always finish every sentence completely.`;

  const user =
    logs.length === 0
      ? "No diary entries yet. Encourage the user to start journaling in 1-2 sentences."
      : `Student diary entries (${logs.length} day(s)): ${JSON.stringify(logs)}. ` +
        "Identify a trend, correlation or non-obvious pattern, then give one specific suggestion. " +
        "Do NOT summarise the raw numbers — state only your conclusion and the actionable tip.";

  const raw = await generateText({
    system,
    user,
    maxTokens: 450,
    tier: "smart",
  });
  // Защита: если модель всё же вернула JSON {"insight":"..."} — разворачиваем в текст.
  const insight = unwrapMaybeJson(raw, "insight");
  if (!insight) throw new Error("AI returned an empty diary insight.");
  return { insight };
}
