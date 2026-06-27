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

  // Запрещаем перечисление входных чисел; требуем паттерн/сильную сторону/зону роста + совет.
  const system =
    (stats.tone === "harsh"
      ? "You write candid, sharp (not cruel) weekly recaps for a student planner. " +
        "Never shame food, body or weight. "
      : "You write warm, insightful weekly recaps for a student planner. ") +
    "DO NOT list or repeat the numbers the student already sees in their stats panel. " +
    "Instead: identify ONE strength visible in this period, ONE clear growth area, " +
    "and give ONE specific recommendation for the next week. " +
    "One paragraph, 3-4 sentences, plain text only, no emoji. " +
    "Complete every sentence fully — never stop mid-thought. " +
    `\n\nIMPORTANT: Write all human-readable text in ${language}. Always finish every sentence completely.`;

  // Данные передаём как контекст для вывода, а не как список для пересказа.
  const completionRate =
    stats.tasksTotal > 0
      ? Math.round((stats.tasksDone / stats.tasksTotal) * 100)
      : null;
  const mainRate =
    stats.mainTotal > 0
      ? Math.round((stats.mainDone / stats.mainTotal) * 100)
      : null;

  const user =
    `Student's ${periodLabel} context: ` +
    (completionRate !== null
      ? `overall task completion ${completionRate}%, `
      : "") +
    (mainRate !== null ? `priority-task completion ${mainRate}%, ` : "") +
    (stats.avgMood !== null
      ? `average mood ${stats.avgMood.toFixed(1)}/5, `
      : "") +
    (stats.waterMl > 0 ? `water ${stats.waterMl} ml logged, ` : "") +
    (stats.topIssue ? `main obstacle: "${stats.topIssue}". ` : ". ") +
    "Draw a conclusion about their performance pattern. " +
    "Name one strength, one growth area, and one concrete next-week recommendation. " +
    "Do not list these numbers back — give only your insight and advice.";

  const text = await generateText({
    system,
    user,
    maxTokens: 350,
    tier: "fast",
  });

  // Защита: если модель всё же вернула JSON {"summary":"..."} — разворачиваем в текст.
  return { summary: unwrapMaybeJson(text, "summary") };
}
