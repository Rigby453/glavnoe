/**
 * AI-01: Умное перераспределение (premium, Sonnet).
 * Claude предлагает 2-3 варианта плана дня для просроченных задач.
 * Claude вызывается ТОЛЬКО здесь. Дата собирается в коде (детерминировано).
 */

import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

let _client: Anthropic | null = null;
function getClient(): Anthropic {
  if (_client) return _client;
  const apiKey = process.env["ANTHROPIC_API_KEY"];
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY is not set.");
  _client = new Anthropic({ apiKey });
  return _client;
}

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
  const client = getClient();

  const system =
    "You are a study-planner assistant. Given unfinished tasks, propose 2-3 " +
    "DISTINCT day plans (e.g. front-loaded mornings, balanced, light start). " +
    "Schedule between 08:00 and 22:00 in 30-minute granularity, avoid the " +
    "occupied times, do not double-book, keep higher-priority tasks earlier. " +
    "Use ONLY the provided task ids. Return strict JSON.";

  const userText = JSON.stringify({
    target_date: targetDate,
    occupied_times: occupiedTimes,
    tasks: pendingItems.map((i) => ({
      id: i.id,
      title: i.title,
      priority: i.priority,
      duration_minutes: i.durationMinutes,
    })),
  });

  const message = await client.messages.parse({
    model: "claude-sonnet-4-6",
    max_tokens: 1500,
    system: [
      { type: "text", text: system, cache_control: { type: "ephemeral" } },
    ],
    messages: [{ role: "user", content: userText }],
    output_config: { format: zodOutputFormat(RawPlanSchema) },
  });

  const raw = message.parsed_output;
  if (!Array.isArray(raw)) {
    throw new Error("Claude returned an unparseable smart-redistribute response.");
  }

  const plans: SmartPlan[] = raw.slice(0, 3).map((plan) => ({
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
