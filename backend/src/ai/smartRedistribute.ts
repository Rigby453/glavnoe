/**
 * AI-01: Умное перераспределение (premium).
 * Предлагает 2-3 варианта плана дня для просроченных задач через провайдер
 * (Gemini/Claude). Дата собирается в коде (детерминированно). Модель только
 * раскладывает по времени. Вызов модели — только через provider.ts.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";

export interface PlanInputItem {
  id: string;
  title: string;
  priority: string;
  durationMinutes: number;
}

export interface SmartPlan {
  label: string;
  reason: string;
  items: { id: string; scheduledAt: string }[];
}

// Модель возвращает планы с временем "HH:MM"; id — только из переданного списка.
const RawPlanSchema = z.array(
  z.object({
    label: z.string().min(1),
    reason: z.string().min(1),
    items: z.array(
      z.object({
        id: z.string(),
        time: z.string().regex(/^\d{2}:\d{2}$/),
      })
    ),
  })
);

/**
 * Возвращает 2-3 варианта плана на targetDate для overdue-задач.
 * @param pendingItems - просроченные pending-задачи (движок их собирает)
 * @param occupiedTimes - занятые "HH:MM" слоты целевого дня
 * @param targetDate - 'YYYY-MM-DD'
 */
export async function generateSmartPlans(params: {
  pendingItems: PlanInputItem[];
  occupiedTimes: string[];
  targetDate: string;
}): Promise<{ plans: SmartPlan[] }> {
  const { pendingItems, occupiedTimes, targetDate } = params;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
    throw new Error(`targetDate must be YYYY-MM-DD, got "${targetDate}"`);
  }
  if (pendingItems.length === 0) return { plans: [] };

  const validIds = new Set(pendingItems.map((i) => i.id));

  const system =
    "You are a study-planner assistant. Given unfinished tasks, propose 2-3 " +
    "DISTINCT day plans (e.g. front-loaded mornings, balanced, light start). " +
    "Schedule between 08:00 and 22:00 in 30-minute granularity, avoid the " +
    "occupied times, do not double-book, keep higher-priority tasks earlier. " +
    "Use ONLY the provided task ids. " +
    'Return STRICT JSON only (no prose, no markdown fences): a JSON array of ' +
    'objects {"label": string, "reason": string, "items": [{"id": string, ' +
    '"time": "HH:MM"}]}.';

  const user = JSON.stringify({
    target_date: targetDate,
    occupied_times: occupiedTimes,
    tasks: pendingItems.map((i) => ({
      id: i.id,
      title: i.title,
      priority: i.priority,
      duration_minutes: i.durationMinutes,
    })),
  });

  const text = await generateText({
    system,
    user,
    maxTokens: 1500,
    tier: "smart",
    json: true,
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned unparseable JSON for smart-redistribute.");
  }
  const result = RawPlanSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected smart-redistribute shape.");
  }

  const plans: SmartPlan[] = result.data.slice(0, 3).map((plan) => ({
    label: plan.label,
    reason: plan.reason,
    items: plan.items
      // отбрасываем выдуманные id и битое время
      .filter((it) => validIds.has(it.id) && /^\d{2}:\d{2}$/.test(it.time))
      .map((it) => ({
        id: it.id,
        scheduledAt: `${targetDate}T${it.time}:00.000Z`,
      })),
  }));

  return { plans };
}
