/**
 * AI-05: wrapped-сводка «период одним абзацем» (Phase 1, premium).
 * Все числа приходят от клиента (посчитаны кодом из локальной БД) — модель
 * только превращает их в короткий тёплый абзац. Вызов — через provider.ts.
 * On-demand вместо воскресного cron+Batch (ADR-026).
 */

import { generateText } from "./provider.js";
import { unwrapMaybeJson } from "./textResponse.js";

export interface WrappedStats {
  periodDays: number;
  tasksDone: number;
  tasksTotal: number;
  mainDone: number;
  mainTotal: number;
  avgMood: number | null;
  waterMl: number;
  topIssue: string | null;
  tone: "gentle" | "harsh";
  /** язык сводки (напр. "Russian"), по умолчанию "English" */
  language?: string;
}

export async function generateWrappedSummary(
  stats: WrappedStats
): Promise<{ summary: string }> {
  const periodLabel = stats.periodDays >= 28 ? "month" : "week";
  const language = stats.language ?? "English";

  const system =
    (stats.tone === "harsh"
      ? "You write blunt, funny (not mean) recaps for a student planner. " +
        "Never shame food, body or weight. Under 60 words, one paragraph, " +
        "plain text only."
      : "You write warm, upbeat recaps for a student planner. " +
        "Under 60 words, one paragraph, plain text only.") +
    `\n\nIMPORTANT: Write all human-readable text (the summary paragraph) in ${language}.`;

  const user =
    `Summarize the student's ${periodLabel}: ` +
    `${stats.tasksDone}/${stats.tasksTotal} tasks done, ` +
    `${stats.mainDone}/${stats.mainTotal} main (protected) tasks done, ` +
    `average mood ${stats.avgMood?.toFixed(1) ?? "unknown"}/5, ` +
    `${stats.waterMl} ml of water logged` +
    (stats.topIssue ? `, top setback reason: "${stats.topIssue}"` : "") +
    ". Mention the strongest point and one gentle suggestion.";

  const text = await generateText({
    system,
    user,
    maxTokens: 120,
    tier: "fast",
  });

  // Защита: если модель всё же вернула JSON {"summary":"..."} — разворачиваем в текст.
  return { summary: unwrapMaybeJson(text, "summary") };
}
