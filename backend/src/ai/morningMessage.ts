/**
 * AI-02: Утреннее сообщение (tone-aware).
 * Генерирует 1-2 предложения под тон gentle/harsh через провайдер (Gemini/Claude).
 * Вызов модели — только через provider.ts.
 */

import { generateText } from "./provider.js";

export type Tone = "gentle" | "harsh";

/**
 * Возвращает короткое утреннее сообщение.
 * @param pendingCount - сколько незавершённых задач перенесено на сегодня
 * @param tone - gentle (мягкий) / harsh (жёсткий)
 * @param userName - имя пользователя (опционально)
 */
export async function generateMorningMessage(params: {
  pendingCount: number;
  tone: Tone;
  userName?: string;
}): Promise<{ message: string }> {
  const { pendingCount, tone, userName } = params;

  const toneHint =
    tone === "harsh"
      ? "Be blunt, no-nonsense and a little provocative, but never insulting."
      : "Be warm, supportive and encouraging.";

  const system =
    "You write the morning review line for a student planner called the app. " +
    "Output ONE or TWO short sentences, plain text, no emoji, no quotes. " +
    toneHint;

  const who = userName ? `The user's name is ${userName}. ` : "";
  const user =
    `${who}They have ${pendingCount} unfinished task(s) carried over to today. ` +
    "Write the morning message.";

  const message = await generateText({
    system,
    user,
    maxTokens: 120,
    tier: "fast",
  });
  if (!message) throw new Error("AI returned an empty morning message.");
  return { message };
}
