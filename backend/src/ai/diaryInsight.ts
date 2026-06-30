/**
 * AI-04: Инсайт по дневнику (premium).
 * По последним записям (настроение/заметки) даёт 2-3 предложения инсайта
 * через провайдер (Gemini/Claude). Вызов модели — только через provider.ts.
 *
 * Issue #18: обёрнут withAiRetry — раньше этот вызов не ретраился вовсе.
 */

import { generateText } from "./provider.js";
import { unwrapMaybeJson } from "./textResponse.js";
import { withAiRetry } from "./retry.js";

export type Tone = "gentle" | "harsh";

export interface DiaryLogInput {
  date: string; // 'YYYY-MM-DD'
  mood: number | null; // 1-5
  note: string | null;
}

/**
 * Результат инсайта: текст + охватываемый диапазон дат (для будущего отображения).
 * Текущий api-spec.yaml возвращает только { insight: string }; поля coveredFrom/
 * coveredTo пока не пробрасываются маршрутом. Предлагаемое расширение контракта:
 *   covered_from { type: string, format: date }
 *   covered_to   { type: string, format: date }
 * Требует одобрения оркестратора.
 */
export interface DiaryInsightResult {
  insight: string;
  coveredFrom: string | null;
  coveredTo: string | null;
}

/**
 * Возвращает инсайт по последним записям дневника + охватываемый диапазон дат.
 *
 * Причина увеличения maxTokens с 450 до 650:
 *   Gemini 2.5-flash оборачивает ответ в JSON {"insight":"..."} и добавляет
 *   рассуждения перед самим текстом. При 450 токенах JSON не успевал закрыться
 *   → unwrapMaybeJson падал на parse error → клиент видел сырую обрезанную строку
 *   вида {"insight":"текст без конца...
 *   650 токенов = безопасный запас для 2-3 полных предложений + JSON-обёртка.
 *
 * @param logs - последние записи (дата, настроение, заметка)
 * @param tone - gentle / harsh
 * @param language - язык инсайта (напр. "Russian"), по умолчанию "English"
 */
export async function generateDiaryInsight(params: {
  logs: DiaryLogInput[];
  tone: Tone;
  language?: string;
}): Promise<DiaryInsightResult> {
  const { logs, tone, language = "English" } = params;

  // Вычисляем диапазон охватываемых дат (min/max по полю date) — кодом, не моделью.
  const sortedDates = logs.map((l) => l.date).sort();
  const coveredFrom = sortedDates.length > 0 ? sortedDates[0]! : null;
  const coveredTo = sortedDates.length > 0 ? sortedDates[sortedDates.length - 1]! : null;

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

  // Передаём явный диапазон дат, чтобы модель могла на него ссылаться в инсайте.
  const dateRange =
    coveredFrom && coveredTo ? ` from ${coveredFrom} to ${coveredTo}` : "";

  const user =
    logs.length === 0
      ? "No diary entries yet. Encourage the user to start journaling in 1-2 sentences."
      : `Student diary entries${dateRange} (${logs.length} day(s)): ${JSON.stringify(logs)}. ` +
        "Identify a trend, correlation or non-obvious pattern, then give one specific suggestion. " +
        "Do NOT summarise the raw numbers — state only your conclusion and the actionable tip.";

  // maxTokens повышен до 650 (был 450) — исправляет обрезание инсайта.
  // Подробности в JSDoc выше.
  // withAiRetry повторяет вызов при временных сбоях (rate-limit/перегрузка);
  // постоянные сбои (гео-блок, суточная квота, пустой ответ модели) идут
  // наверх сразу — повтор внутри того же запроса им не поможет.
  const insight = await withAiRetry(() => callAndUnwrap({ system, user }));
  return { insight, coveredFrom, coveredTo };
}

async function callAndUnwrap(args: { system: string; user: string }): Promise<string> {
  const raw = await generateText({
    system: args.system,
    user: args.user,
    maxTokens: 650,
    tier: "smart",
  });
  // Защита: если модель всё же вернула JSON {"insight":"..."} — разворачиваем в текст.
  const insight = unwrapMaybeJson(raw, "insight");
  if (!insight) throw new Error("AI returned an empty diary insight.");
  return insight;
}
