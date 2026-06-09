/**
 * AI-04: Инсайт по дневнику (premium).
 * По последним записям (настроение/заметки) даёт 2-3 предложения инсайта
 * через провайдер (Gemini/Claude). Вызов модели — только через provider.ts.
 */

import { generateText } from "./provider.js";

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
 */
export async function generateDiaryInsight(params: {
  logs: DiaryLogInput[];
  tone: Tone;
}): Promise<{ insight: string }> {
  const { logs, tone } = params;

  const toneHint =
    tone === "harsh"
      ? "Be blunt and direct, point out patterns honestly, but never insulting."
      : "Be warm, supportive and constructive.";

  const system =
    "You analyse a student's recent diary entries (mood 1-5 and short notes) " +
    "and surface ONE useful pattern or suggestion in 2-3 short sentences. " +
    "Plain text, no emoji, no quotes. " +
    toneHint;

  const user =
    logs.length === 0
      ? "There are no diary entries yet. Gently encourage the user to start journaling."
      : `Recent entries (JSON): ${JSON.stringify(logs)}. Write the insight.`;

  const insight = await generateText({
    system,
    user,
    maxTokens: 200,
    tier: "smart",
  });
  if (!insight) throw new Error("AI returned an empty diary insight.");
  return { insight };
}
