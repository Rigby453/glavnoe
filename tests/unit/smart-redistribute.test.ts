/**
 * Unit tests for generateSmartPlans (AI-01).
 * Provider полностью мокируется — реальных API-вызовов нет.
 * Проверяем: корректность структуры планов, фильтрацию галлюцинированных id,
 * обогащение items из входных данных, конкретность reason.
 */

import { generateSmartPlans } from "../../backend/src/ai/smartRedistribute";
import * as provider from "../../backend/src/ai/provider";

// Мокируем модуль провайдера целиком (ADR-022: вызов только из ai/).
jest.mock("../../backend/src/ai/provider", () => ({
  generateText: jest.fn(),
  // stripJsonFences нужен реальный — тестируем markdown-fence-очистку.
  stripJsonFences: (text: string): string => {
    const t = text.trim();
    if (t.startsWith("```")) {
      return t
        .replace(/^```(?:json)?\s*/i, "")
        .replace(/```$/, "")
        .trim();
    }
    return t;
  },
}));

const mockGenerate = provider.generateText as jest.MockedFunction<
  typeof provider.generateText
>;

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const TASKS = [
  { id: "task-1", title: "Math exam prep", priority: "main", durationMinutes: 120 },
  { id: "task-2", title: "Essay draft", priority: "high", durationMinutes: 60 },
  { id: "task-3", title: "Quick reading", priority: "low", durationMinutes: 30 },
];

/** Валидный ответ модели с конкретным reason (новое требование к промпту). */
const VALID_RESPONSE = JSON.stringify([
  {
    label: "Front-load priorities",
    reason:
      "Math exam prep (2h) → 09:00 [main priority, peak focus]; " +
      "Essay draft (1h) → 12:00 [high priority after break]; " +
      "Quick reading (30min) → 14:00 [light close].",
    items: [
      { id: "task-1", time: "09:00" },
      { id: "task-2", time: "12:00" },
      { id: "task-3", time: "14:00" },
    ],
  },
  {
    label: "Quick wins first",
    reason:
      "Quick reading (30min) → 09:00 [build momentum]; " +
      "Essay draft (1h) → 10:00 [medium load mid-morning]; " +
      "Math exam prep (2h) → 12:00 [main block after wins].",
    items: [
      { id: "task-3", time: "09:00" },
      { id: "task-2", time: "10:00" },
      { id: "task-1", time: "12:00" },
    ],
  },
]);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

beforeEach(() => {
  jest.clearAllMocks();
});

test("returns structured plans with correct fields from valid AI JSON", async () => {
  mockGenerate.mockResolvedValueOnce(VALID_RESPONSE);
  const { plans } = await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  expect(plans).toHaveLength(2);
  expect(plans[0]!.label).toBe("Front-load priorities");
  expect(typeof plans[0]!.reason).toBe("string");
  expect(plans[0]!.reason.length).toBeGreaterThan(0);
  expect(plans[0]!.items).toHaveLength(3);
  expect(plans[0]!.items[0]!.id).toBe("task-1");
  expect(plans[0]!.items[0]!.scheduledAt).toBe("2026-06-28T09:00:00.000Z");
});

test("enriches items with title and priority from input (not from model)", async () => {
  mockGenerate.mockResolvedValueOnce(VALID_RESPONSE);
  const { plans } = await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  // title и priority берутся из входного списка — модель их не выдаёт.
  expect(plans[0]!.items[0]!.title).toBe("Math exam prep");
  expect(plans[0]!.items[0]!.priority).toBe("main");
  expect(plans[0]!.items[1]!.title).toBe("Essay draft");
  expect(plans[0]!.items[1]!.priority).toBe("high");
  expect(plans[0]!.items[2]!.title).toBe("Quick reading");
  expect(plans[0]!.items[2]!.priority).toBe("low");
});

test("prompt user message includes task titles (enables concrete AI output)", async () => {
  mockGenerate.mockResolvedValueOnce(VALID_RESPONSE);
  await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  const callArg = mockGenerate.mock.calls[0]![0];
  // Задачи передаются с title → модель может называть их в reason.
  expect(callArg.user).toContain("Math exam prep");
  expect(callArg.user).toContain("Essay draft");
  expect(callArg.user).toContain("Quick reading");
});

test("prompt system message requires concrete task-by-task reason", async () => {
  mockGenerate.mockResolvedValueOnce(VALID_RESPONSE);
  await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  const { system } = mockGenerate.mock.calls[0]![0];
  // Промпт явно требует breakdown по задачам с title + time + rationale.
  expect(system).toContain("task-by-task breakdown");
  expect(system).toContain("TITLE");
  expect(system).toContain("rationale");
});

test("filters out hallucinated task IDs returned by model", async () => {
  const responseWithBadId = JSON.stringify([
    {
      label: "Test plan",
      reason: "Real task at 09:00; hallucinated task at 10:00.",
      items: [
        { id: "task-1", time: "09:00" }, // реальный
        { id: "hallucinated-uuid-9999", time: "10:00" }, // не в списке
      ],
    },
  ]);
  mockGenerate.mockResolvedValueOnce(responseWithBadId);
  const { plans } = await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  expect(plans[0]!.items).toHaveLength(1);
  expect(plans[0]!.items[0]!.id).toBe("task-1");
});

test("returns empty plans immediately when no pending items", async () => {
  const { plans } = await generateSmartPlans({
    pendingItems: [],
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  expect(plans).toHaveLength(0);
  // Нет смысла звать модель если задач нет.
  expect(mockGenerate).not.toHaveBeenCalled();
});

test("caps plans at 3 even if AI returns 4 or more", async () => {
  const times = ["09:00", "10:00", "11:00", "12:00"];
  const fourPlans = JSON.stringify(
    Array.from({ length: 4 }, (_, i) => ({
      label: `Plan ${i + 1}`,
      reason: `Math exam prep (2h) → ${times[i]} [strategy ${i + 1}].`,
      items: [{ id: "task-1", time: times[i] }],
    }))
  );
  mockGenerate.mockResolvedValueOnce(fourPlans);
  const { plans } = await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  expect(plans).toHaveLength(3);
});

test("throws with 'unparseable' on non-JSON response (retries 3x on this transient shape, still fails)", async () => {
  // Issue #18: generateSmartPlans теперь wrapped в withAiRetry — "unparseable"
  // классифицируется как transient (aiErrors.ts), поэтому use mockResolvedValue
  // (persists across all retries) so every attempt sees the same bad text and
  // the final rejected error keeps the expected message.
  mockGenerate.mockResolvedValue("Sorry, I cannot process that.");
  await expect(
    generateSmartPlans({ pendingItems: TASKS, occupiedTimes: [], targetDate: "2026-06-28" })
  ).rejects.toThrow(/unparseable/i);
  expect(mockGenerate).toHaveBeenCalledTimes(3); // 1 + 2 retries (NODE_ENV=test → no delay)
});

test("throws with 'unexpected' on wrong JSON shape (retries 3x, still fails)", async () => {
  mockGenerate.mockResolvedValue(JSON.stringify({ plans: "wrong" }));
  await expect(
    generateSmartPlans({ pendingItems: TASKS, occupiedTimes: [], targetDate: "2026-06-28" })
  ).rejects.toThrow(/unexpected/i);
  expect(mockGenerate).toHaveBeenCalledTimes(3);
});

test("retries once on transient unparseable JSON then succeeds", async () => {
  // Issue #18: a single flaky response should self-heal via withAiRetry
  // instead of surfacing as a user-facing error.
  mockGenerate
    .mockResolvedValueOnce("Sorry, I cannot process that.")
    .mockResolvedValueOnce(VALID_RESPONSE);

  const { plans } = await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  expect(plans).toHaveLength(2);
  expect(mockGenerate).toHaveBeenCalledTimes(2);
});

test("handles markdown-fenced JSON correctly (strips fences)", async () => {
  mockGenerate.mockResolvedValueOnce("```json\n" + VALID_RESPONSE + "\n```");
  const { plans } = await generateSmartPlans({
    pendingItems: TASKS,
    occupiedTimes: [],
    targetDate: "2026-06-28",
  });

  expect(plans).toHaveLength(2);
});

test("throws on invalid targetDate format", async () => {
  await expect(
    generateSmartPlans({
      pendingItems: TASKS,
      occupiedTimes: [],
      targetDate: "28-06-2026", // wrong format
    })
  ).rejects.toThrow(/YYYY-MM-DD/);
});
