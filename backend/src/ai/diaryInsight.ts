/**
 * AI-04: Инсайт по дневнику (premium, Sonnet).
 * Claude по последним записям (настроение/заметки) даёт 2-3 предложения инсайта.
 * Claude вызывается ТОЛЬКО здесь. Ключ — из env.
 */

import Anthropic from "@anthropic-ai/sdk";

let _client: Anthropic | null = null;
function getClient(): Anthropic {
  if (_client) return _client;
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY is not set.");
  _client = new Anthropic({ apiKey });
  return _client;
}

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
  const client = getClient();

  const toneHint =
    tone === "harsh"
      ? "Be blunt and direct, point out patterns honestly, but never insulting."
      : "Be warm, supportive and constructive.";

  const system =
    "You analyse a student's recent diary entries (mood 1-5 and short notes) " +
    "and surface ONE useful pattern or suggestion in 2-3 short sentences. " +
    "Plain text, no emoji, no quotes. " +
    toneHint;

  const userText =
    logs.length === 0
      ? "There are no diary entries yet. Gently encourage the user to start journaling."
      : `Recent entries (JSON): ${JSON.stringify(logs)}. Write the insight.`;

  const msg = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 200,
    system: [
      { type: "text", text: system, cache_control: { type: "ephemeral" } },
    ],
    messages: [{ role: "user", content: userText }],
  });

  const block = msg.content[0];
  const insight = block && block.type === "text" ? block.text.trim() : "";
  if (!insight) throw new Error("Claude returned an empty diary insight.");
  return { insight };
}
