/**
 * AI-01: Умное перераспределение (premium).
 * Предлагает 2-3 варианта плана дня для просроченных задач через провайдер
 * (Gemini/Claude). Дата собирается в коде (детерминированно). Модель только
 * раскладывает по времени. Вызов модели — только через provider.ts.
 *
 * Issue #18: обёрнут withAiRetry — раньше этот вызов не ретраился вовсе.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";
import { withAiRetry } from "./retry.js";

export interface PlanInputItem {
  id: string;
  title: string;
  priority: string;
  durationMinutes: number;
}

export interface SmartPlan {
  label: string;
  reason: string;
  /**
   * Каждый move содержит id + scheduledAt (для API-контракта) плюс title и
   * priority, которые Backend добавляет из входного списка — не из модели.
   * Поля title/priority не отражены в текущем api-spec.yaml (items имеют только
   * id + scheduled_at). Предлагаемое расширение контракта: добавить
   *   items[].title   { type: string }
   *   items[].priority { type: string, enum: [main,high,medium,low] }
   * чтобы клиент мог рендерить «переместить X → 10:00, подтвердить?» без
   * локального DB-лукапа. Требует одобрения оркестратора (правило api-spec).
   */
  items: { id: string; scheduledAt: string; title: string; priority: string }[];
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
 * @param language - язык текстовых полей (label, reason), по умолчанию "English"
 */
export async function generateSmartPlans(params: {
  pendingItems: PlanInputItem[];
  occupiedTimes: string[];
  targetDate: string;
  language?: string;
}): Promise<{ plans: SmartPlan[] }> {
  const { pendingItems, occupiedTimes, targetDate, language = "English" } = params;

  if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
    throw new Error(`targetDate must be YYYY-MM-DD, got "${targetDate}"`);
  }
  if (pendingItems.length === 0) return { plans: [] };

  const validIds = new Set(pendingItems.map((i) => i.id));

  // Промпт требует, чтобы reason был конкретным: называл задачи по title,
  // указывал предложенное время и кратко объяснял каждый ход — иначе модель
  // возвращала бесполезные общие фразы («balanced approach», «stay productive»).
  const system =
    "You are a study-planner assistant. Given a list of unfinished tasks " +
    "(with IDs, titles, priorities, durations), propose 2-3 DISTINCT redistribution plans.\n\n" +
    "Rules:\n" +
    "1. Schedule between 08:00 and 22:00 in 30-minute slots; avoid the occupied times; no double-booking.\n" +
    "2. Higher-priority tasks go earlier: main > high > medium > low.\n" +
    "3. Each plan MUST use a different strategy — for example:\n" +
    "   Plan A: 'Front-load priorities' — most important tasks first\n" +
    "   Plan B: 'Balanced pacing' — interleave heavy and light tasks\n" +
    "   Plan C: 'Quick wins first' — shortest tasks first to build momentum\n" +
    "4. Use ONLY the task IDs from the provided list — do NOT invent IDs.\n" +
    "5. CRITICAL — the 'reason' field MUST be a concrete, task-by-task breakdown:\n" +
    "   name every task by its actual TITLE, state its proposed time, and add a " +
    "   5-8 word rationale per task.\n" +
    "   Example: \"Math exam prep (2h) → 09:00 [main priority, peak focus window]; " +
    "Essay draft (1h) → 12:00 [medium load after break]; Quick reading (30min) → 14:00 [light close].\"\n\n" +
    "Return STRICT JSON only — no prose, no markdown fences:\n" +
    '[{"label": "strategy name", "reason": "task-by-task breakdown", "items": [{"id": "uuid", "time": "HH:MM"}]}]\n\n' +
    `IMPORTANT: Write all human-readable text (label and reason) in ${language}. ` +
    "JSON keys, task IDs, and time values must stay in English exactly as shown.";

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

  // withAiRetry повторяет вызов при временных сбоях (rate-limit/перегрузка/
  // битый JSON); постоянные сбои (гео-блок, суточная квота) идут наверх сразу.
  const rawPlans = await withAiRetry(() => callAndParse({ system, user }));

  // Индекс входных задач по id — для обогащения items title+priority без AI.
  const inputById = new Map(pendingItems.map((i) => [i.id, i]));

  const plans: SmartPlan[] = rawPlans.slice(0, 3).map((plan) => ({
    label: plan.label,
    reason: plan.reason,
    items: plan.items
      // отбрасываем выдуманные id и битое время
      .filter((it) => validIds.has(it.id) && /^\d{2}:\d{2}$/.test(it.time))
      .map((it) => {
        const input = inputById.get(it.id)!;
        return {
          id: it.id,
          scheduledAt: `${targetDate}T${it.time}:00.000Z`,
          // Добавляем title/priority из входных данных — не из модели.
          // Маршрут /routes/ai.ts пока сериализует только id+scheduled_at;
          // после расширения api-spec эти поля можно будет пробросить клиенту.
          title: input.title,
          priority: input.priority,
        };
      }),
  }));

  return { plans };
}

async function callAndParse(args: {
  system: string;
  user: string;
}): Promise<z.infer<typeof RawPlanSchema>> {
  const text = await generateText({
    system: args.system,
    user: args.user,
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
  return result.data;
}
