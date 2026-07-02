import type { FastifyInstance, FastifyPluginAsync, FastifyReply, FastifyRequest } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { requireAuth } from "./middleware/auth.js";
import { importScheduleFromPhoto } from "../ai/scheduleImport.js";
import { generateMorningMessage } from "../ai/morningMessage.js";
import { generateSmartPlans } from "../ai/smartRedistribute.js";
import { generateOnboardingPlan } from "../ai/onboardingPlan.js";
import { generateQuickAddTask } from "../ai/quickAdd.js";
import { generateDiaryInsight } from "../ai/diaryInsight.js";
import { recognizeFood } from "../ai/foodRecognize.js";
import { generateWrappedSummary } from "../ai/wrappedSummary.js";
import { buildMenu } from "../ai/menuBuild.js";
import { buildWorkoutProgram } from "../ai/workoutBuild.js";
import { searchProducts } from "../food/openFoodFacts.js";
import type { FoodProduct } from "../food/openFoodFacts.js";
import { parseLangCode } from "../lib/lang.js";
import { resolveEntitlement } from "../models/entitlement.js";

/**
 * Маппинг Accept-Language заголовка (двухбуквенный тег) в имя языка для промптов.
 * Всё, что не совпадает — возвращает "English" (безопасный дефолт).
 */
function langName(header: string | string[] | undefined): string {
  const tag = (Array.isArray(header) ? header[0] : header ?? "en")
    .toString()
    .slice(0, 2)
    .toLowerCase();
  const map: Record<string, string> = {
    en: "English",
    ru: "Russian",
    de: "German",
    fr: "French",
    it: "Italian",
    pt: "Portuguese",
    id: "Indonesian",
    hi: "Hindi",
    ja: "Japanese",
    ko: "Korean",
    es: "Spanish",
  };
  return map[tag] ?? "English";
}

const dateOnly = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "must be YYYY-MM-DD");
const toneSchema = z.enum(["gentle", "harsh"]);

const scheduleImportSchema = z.object({
  image_base64: z.string().min(1),
  media_type: z.enum(["image/jpeg", "image/png"]),
  target_date: dateOnly,
});
const morningMessageSchema = z.object({
  pending_count: z.number().int().min(0),
  tone: toneSchema,
  user_name: z.string().optional(),
});
const redistributeSchema = z.object({ target_date: dateOnly });
const diaryInsightSchema = z.object({ tone: toneSchema });
// Волна 6 / Этап 1: ИИ-онбординг брейн-дамп + быстрое добавление (premium).
// locale — опциональный оверрайд языка ответа; по умолчанию берём Accept-Language
// (как во всех остальных AI-роутах), но клиент может передать явный locale.
const onboardingPlanSchema = z.object({
  answers: z.string().min(1).max(8000),
  date: dateOnly,
  timezone: z.string().min(1).max(64),
  locale: z.string().max(10).optional(),
});
const quickAddSchema = z.object({
  text: z.string().min(1).max(2000),
  date: dateOnly,
  timezone: z.string().min(1).max(64),
  locale: z.string().max(10).optional(),
});
const foodRecognizeSchema = z.object({
  image_base64: z.string().min(1),
  media_type: z.enum(["image/jpeg", "image/png"]),
});
// Числа на 100 г — от клиента (его food DB/рецепты); модель чисел не выдаёт.
const menuCandidateSchema = z.object({
  name: z.string().min(1),
  per_100g: z.object({
    calories: z.number().nullable(),
    protein: z.number().nullable(),
    fat: z.number().nullable(),
    carbs: z.number().nullable(),
    sugar: z.number().nullable(),
    fiber: z.number().nullable(),
  }),
});
// Необязательный профиль здоровья (свободный текст, ≤500 символов каждое поле).
// Backward-compatible: отсутствие поля не меняет поведение.
const healthProfileSchema = z
  .object({
    allergies: z.string().max(500).trim().optional(),
    healing: z.string().max(500).trim().optional(),
    deficiencies: z.string().max(500).trim().optional(),
  })
  .optional();

// Необязательные пищевые предпочтения пользователя (диета, цель, антипатии/симпатии).
// Backward-compatible: отсутствие поля не меняет поведение (ADR-038).
const foodPrefsSchema = z
  .object({
    diet: z.string().max(300).trim().optional(),
    goal: z.string().max(300).trim().optional(),
    dislikes: z.string().max(300).trim().optional(),
    likes: z.string().max(300).trim().optional(),
    meals_per_day: z.number().int().min(1).max(8).optional(),
  })
  .optional();

const menuBuildSchema = z.object({
  candidates: z.array(menuCandidateSchema).min(5).max(40),
  calorie_goal: z.number().min(800).max(6000),
  protein_goal_g: z.number().min(10).max(400),
  // Полный набор макро-целей (ADR-046). Опциональны для обратной совместимости:
  // если поле отсутствует — соответствующая цель просто не упоминается в промпте
  // и не проверяется валидационным циклом.
  fat_goal_g: z.number().min(0).max(400).optional(),
  carbs_goal_g: z.number().min(0).max(1000).optional(),
  sugar_max_g: z.number().min(0).max(500).optional(),
  fiber_min_g: z.number().min(0).max(200).optional(),
  meals: z
    .array(z.string().min(1))
    .min(1)
    .max(6)
    .default(["breakfast", "lunch", "dinner"]),
  tone: toneSchema.default("gentle"),
  health_profile: healthProfileSchema,
  food_prefs: foodPrefsSchema,
});
// Feature A: AI-программа тренировок (premium, Phase 2). Модель только
// компонует упражнения под цель/оборудование/время — вес не прописывает.
const workoutProfileSchema = z
  .object({
    sex: z.string().max(20).trim().optional(),
    age: z.number().int().min(5).max(120).optional(),
    weight_kg: z.number().min(20).max(400).optional(),
    height_cm: z.number().min(80).max(260).optional(),
  })
  .optional();

const workoutBuildSchema = z.object({
  goal: z.enum(["strength", "muscle", "fat_loss", "endurance", "general"]),
  experience: z.enum(["beginner", "intermediate", "advanced"]),
  equipment: z.array(z.string().min(1)).min(1).max(20),
  days_per_week: z.number().int().min(1).max(7),
  minutes_per_session: z.number().int().min(10).max(240),
  focus: z.string().max(200).trim().optional(),
  limitations: z.string().max(500).trim().optional(),
  tone: toneSchema.default("gentle"),
  profile: workoutProfileSchema,
});

const wrappedSummarySchema = z.object({
  period_days: z.number().int().min(1).max(366),
  tasks_done: z.number().int().min(0),
  tasks_total: z.number().int().min(0),
  main_done: z.number().int().min(0),
  main_total: z.number().int().min(0),
  avg_mood: z.number().min(1).max(5).nullable().optional(),
  water_ml: z.number().int().min(0),
  top_issue: z.string().nullable().optional(),
  tone: toneSchema,
});

// --- Лимит фото-распознаваний: 3 на пользователя в день (AI-03, ADR-034) ---
// Атомарный upsert в таблицу AiUsage: устойчив к рестарту и нескольким инстансам.
const kFoodPhotoDailyLimit = 3;

async function consumeFoodPhotoQuota(userId: string): Promise<boolean> {
  const day = new Date().toISOString().slice(0, 10);
  const rec = await prisma.aiUsage.upsert({
    where: { userId_day_feature: { userId, day, feature: "food_photo" } },
    create: { userId, day, feature: "food_photo", count: 1 },
    update: { count: { increment: 1 } },
  });
  // count 1-3 → разрешено; count 4+ → превышен лимит
  return rec.count <= kFoodPhotoDailyLimit;
}

// FoodProduct → snake_case (тот же формат, что /food/search)
function serializeProduct(p: FoodProduct) {
  return {
    code: p.code,
    name: p.name,
    brand: p.brand,
    per_100g: {
      calories: p.per100g.calories,
      protein: p.per100g.protein,
      fat: p.per100g.fat,
      carbs: p.per100g.carbs,
      sugar: p.per100g.sugar,
      fiber: p.per100g.fiber,
    },
  };
}

/**
 * Premium-гейт: AI — платные фичи. Возвращает true, если можно продолжать;
 * иначе сам отправляет 403/404 и возвращает false.
 * ADR-041: использует resolveEntitlement — учитывает и legacy subscriptionTier="premium",
 * и срочные подписки (premiumUntil > now) от любого billing-канала.
 */
async function ensurePremium(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: request.user.userId },
    select: { subscriptionTier: true, premiumUntil: true, premiumSource: true },
  });
  if (!user) {
    await reply.status(404).send({ error: "Not found" });
    return false;
  }
  const { isPremium } = resolveEntitlement(user);
  if (!isPremium) {
    await reply
      .status(403)
      .send({ error: "Premium feature — upgrade to use AI" });
    return false;
  }
  return true;
}

/** Ответ при сбое апстрима (нет ключа / ошибка провайдера). */
function aiError(fastify: FastifyInstance, reply: FastifyReply, err: unknown, ctx: string) {
  // Лог сохраняем всегда — даже при 503, чтобы не терять телеметрию.
  fastify.log.error({ err }, `${ctx} AI call failed`);
  const msg = (err instanceof Error ? err.message : String(err)).toLowerCase();

  // Ошибки парсинга/формата ответа модели после исчерпания ретраев (retry.ts).
  // Клиент понимает, что это временно, и предлагает повторить запрос.
  const parseOrShape =
    msg.includes("unparseable") ||
    msg.includes("no usable") ||
    (msg.includes("unexpected") && msg.includes("shape"));
  if (parseOrShape) {
    return reply.status(503).send({
      error: "AI couldn't build this right now — please tap retry.",
    });
  }

  // Временная недоступность апстрима (квота/перегрузка/регион).
  const temporarilyUnavailable =
    msg.includes("429") ||
    msg.includes("quota") ||
    msg.includes("503") ||
    msg.includes("high demand") ||
    msg.includes("overloaded") ||
    msg.includes("user location is not supported");
  if (temporarilyUnavailable) {
    return reply.status(503).send({
      error: "AI is temporarily unavailable (quota/region) — please try again later.",
    });
  }

  return reply
    .status(502)
    .send({ error: "AI service unavailable. Please try again later." });
}

function startOfDayUtc(d: string): Date {
  return new Date(`${d}T00:00:00.000Z`);
}

const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // AI-06: фото расписания → задачи (premium). Ничего не сохраняет.
  fastify.post(
    "/api/v1/ai/schedule-import",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = scheduleImportSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await importScheduleFromPhoto({
          imageBase64: parsed.data.image_base64,
          mediaType: parsed.data.media_type,
          targetDate: parsed.data.target_date,
        });
        return reply.status(200).send({
          items: result.items.map((i) => ({
            title: i.title,
            scheduled_at: i.scheduledAt,
          })),
        });
      } catch (err) {
        return aiError(fastify, reply, err, "schedule-import");
      }
    }
  );

  // AI-03: фото еды → блюдо + подбор продуктов из food DB (premium, 3/день).
  // Модель только называет блюдо; КБЖУ — из Open Food Facts, не из модели.
  fastify.post(
    "/api/v1/ai/food-recognize",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = foodRecognizeSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      if (!(await consumeFoodPhotoQuota(request.user.userId))) {
        return reply.status(429).send({
          error: `Daily limit reached — up to ${kFoodPhotoDailyLimit} food photos per day.`,
        });
      }

      try {
        const rec = await recognizeFood({
          imageBase64: parsed.data.image_base64,
          mediaType: parsed.data.media_type,
        });

        // Подбираем продукты с КБЖУ из food DB по названию блюда.
        // Сбой поиска не валит распознавание — вернём пустой список.
        let products: FoodProduct[] = [];
        try {
          const lang = parseLangCode(request.headers["accept-language"]);
          products = await searchProducts(rec.dish, 5, lang);
        } catch (err) {
          fastify.log.warn({ err }, "OFF lookup after food-recognize failed");
        }

        return reply.status(200).send({
          dish: rec.dish,
          portion_description: rec.portionDescription,
          confidence: rec.confidence,
          products: products.map(serializeProduct),
        });
      } catch (err) {
        return aiError(fastify, reply, err, "food-recognize");
      }
    }
  );

  // AI-05: wrapped-сводка одним абзацем (premium). Числа считает клиент
  // (код, не модель); on-demand вместо cron+Batch — ADR-026.
  fastify.post(
    "/api/v1/ai/wrapped-summary",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = wrappedSummarySchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const { summary } = await generateWrappedSummary({
          periodDays: parsed.data.period_days,
          tasksDone: parsed.data.tasks_done,
          tasksTotal: parsed.data.tasks_total,
          mainDone: parsed.data.main_done,
          mainTotal: parsed.data.main_total,
          avgMood: parsed.data.avg_mood ?? null,
          waterMl: parsed.data.water_ml,
          topIssue: parsed.data.top_issue ?? null,
          tone: parsed.data.tone,
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
        });
        return reply.status(200).send({ summary });
      } catch (err) {
        return aiError(fastify, reply, err, "wrapped-summary");
      }
    }
  );

  // AI-07: «Собрать ИИ» — дневное меню из продуктов/рецептов клиента (premium).
  // Модель выбирает позиции и граммы; КБЖУ пересчитает клиент (код). Ничего не сохраняет.
  fastify.post(
    "/api/v1/ai/menu-build",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = menuBuildSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await buildMenu({
          candidates: parsed.data.candidates.map((c) => ({
            name: c.name,
            per100g: c.per_100g,
          })),
          calorieGoal: parsed.data.calorie_goal,
          proteinGoalG: parsed.data.protein_goal_g,
          meals: parsed.data.meals,
          tone: parsed.data.tone,
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
          ...(parsed.data.fat_goal_g !== undefined ? { fatGoalG: parsed.data.fat_goal_g } : {}),
          ...(parsed.data.carbs_goal_g !== undefined ? { carbsGoalG: parsed.data.carbs_goal_g } : {}),
          ...(parsed.data.sugar_max_g !== undefined ? { sugarMaxG: parsed.data.sugar_max_g } : {}),
          ...(parsed.data.fiber_min_g !== undefined ? { fiberMinG: parsed.data.fiber_min_g } : {}),
          ...(parsed.data.health_profile !== undefined
            ? { healthProfile: parsed.data.health_profile }
            : {}),
          ...(parsed.data.food_prefs !== undefined
            ? {
                foodPrefs: {
                  diet: parsed.data.food_prefs.diet,
                  goal: parsed.data.food_prefs.goal,
                  dislikes: parsed.data.food_prefs.dislikes,
                  likes: parsed.data.food_prefs.likes,
                  mealsPerDay: parsed.data.food_prefs.meals_per_day,
                },
              }
            : {}),
        });
        return reply.status(200).send({
          // dish_name (snake_case, Bug fix 2026-07): composed meal name for
          // display, e.g. "Chicken breast with buckwheat and vegetables" —
          // NOT the raw item list. Numbers stay code-computed (below).
          meals: result.meals.map((m) => ({
            meal: m.meal,
            dish_name: m.dishName,
            items: m.items,
          })),
          note: result.note,
          off_target: result.offTarget,
          totals: result.totals,
        });
      } catch (err) {
        return aiError(fastify, reply, err, "menu-build");
      }
    }
  );

  // Feature A: «AI-программа тренировок» — недельная программа под цель/опыт/
  // оборудование/время (premium, Phase 2). Модель компонует упражнения и
  // подходы/повторы/отдых; вес НЕ прописывает. Ничего не сохраняет.
  fastify.post(
    "/api/v1/ai/workout-build",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = workoutBuildSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await buildWorkoutProgram({
          goal: parsed.data.goal,
          experience: parsed.data.experience,
          equipment: parsed.data.equipment,
          daysPerWeek: parsed.data.days_per_week,
          minutesPerSession: parsed.data.minutes_per_session,
          tone: parsed.data.tone,
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
          ...(parsed.data.focus !== undefined ? { focus: parsed.data.focus } : {}),
          ...(parsed.data.limitations !== undefined
            ? { limitations: parsed.data.limitations }
            : {}),
          ...(parsed.data.profile !== undefined
            ? {
                profile: {
                  ...(parsed.data.profile.sex !== undefined
                    ? { sex: parsed.data.profile.sex }
                    : {}),
                  ...(parsed.data.profile.age !== undefined
                    ? { age: parsed.data.profile.age }
                    : {}),
                  ...(parsed.data.profile.weight_kg !== undefined
                    ? { weightKg: parsed.data.profile.weight_kg }
                    : {}),
                  ...(parsed.data.profile.height_cm !== undefined
                    ? { heightCm: parsed.data.profile.height_cm }
                    : {}),
                },
              }
            : {}),
        });
        return reply.status(200).send({
          program_name: result.programName,
          days: result.days.map((d) => ({
            title: d.title,
            exercises: d.exercises.map((e) => ({
              name: e.name,
              sets: e.sets,
              reps: e.reps,
              rest_seconds: e.restSeconds,
              ...(e.note !== undefined ? { note: e.note } : {}),
            })),
          })),
          note: result.note,
        });
      } catch (err) {
        return aiError(fastify, reply, err, "workout-build");
      }
    }
  );

  // AI-02: tone-aware утреннее сообщение (premium).
  fastify.post(
    "/api/v1/ai/morning-message",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = morningMessageSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await generateMorningMessage({
          pendingCount: parsed.data.pending_count,
          tone: parsed.data.tone,
          ...(parsed.data.user_name !== undefined
            ? { userName: parsed.data.user_name }
            : {}),
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
        });
        return reply.status(200).send({ message: result.message });
      } catch (err) {
        return aiError(fastify, reply, err, "morning-message");
      }
    }
  );

  // AI-01: умное перераспределение — 2-3 варианта плана (premium). Ничего не сохраняет.
  fastify.post(
    "/api/v1/ai/redistribute",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = redistributeSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      const userId = request.user.userId;
      const start = startOfDayUtc(parsed.data.target_date);
      const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

      // Просроченные pending-задачи и занятые слоты целевого дня
      const pending = await prisma.item.findMany({
        where: { userId, status: "pending", scheduledAt: { lt: start } },
        select: { id: true, title: true, priority: true, durationMinutes: true },
      });
      const dayItems = await prisma.item.findMany({
        where: { userId, scheduledAt: { gte: start, lt: end } },
        select: { scheduledAt: true },
      });
      const occupiedTimes = dayItems.map((i) =>
        i.scheduledAt.toISOString().slice(11, 16)
      );

      try {
        const { plans } = await generateSmartPlans({
          pendingItems: pending,
          occupiedTimes,
          targetDate: parsed.data.target_date,
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
        });
        return reply.status(200).send({
          plans: plans.map((p) => ({
            label: p.label,
            reason: p.reason,
            items: p.items.map((it) => ({
              id: it.id,
              scheduled_at: it.scheduledAt,
              title: it.title,
              priority: it.priority,
            })),
          })),
        });
      } catch (err) {
        return aiError(fastify, reply, err, "ai-redistribute");
      }
    }
  );

  // AI-04: инсайт по дневнику за последние записи (premium).
  fastify.post(
    "/api/v1/ai/diary-insight",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = diaryInsightSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      const logs = await prisma.dayLog.findMany({
        where: { userId: request.user.userId },
        orderBy: { date: "desc" },
        take: 7,
        select: { date: true, mood: true, note: true },
      });

      try {
        const { insight, coveredFrom, coveredTo } = await generateDiaryInsight({
          tone: parsed.data.tone,
          logs: logs.map((l) => ({
            date: l.date.toISOString().slice(0, 10),
            mood: l.mood,
            note: l.note,
          })),
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
        });
        return reply.status(200).send({
          insight,
          covered_from: coveredFrom,
          covered_to: coveredTo,
        });
      } catch (err) {
        return aiError(fastify, reply, err, "diary-insight");
      }
    }
  );

  // Волна 6 / Этап 1: ИИ-онбординг — брейн-дамп текста → черновой план
  // (goals + tasks). Premium, ничего не сохраняет — превью на клиенте
  // (решение B, docs/AI-ONBOARDING-DESIGN.md). deadline→type='deadline'
  // маппинг делает клиент (решение C) — сервер только прокидывает deadline.
  fastify.post(
    "/api/v1/ai/onboarding-plan",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = onboardingPlanSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const result = await generateOnboardingPlan({
          answers: parsed.data.answers,
          date: parsed.data.date,
          timezone: parsed.data.timezone,
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
        });
        return reply.status(200).send({
          goals: result.goals.map((g) => ({
            title: g.title,
            ...(g.horizon !== undefined ? { horizon: g.horizon } : {}),
          })),
          tasks: result.tasks.map((t) => ({
            title: t.title,
            type: t.type,
            priority: t.priority,
            ...(t.scheduledAt !== undefined ? { scheduled_at: t.scheduledAt } : {}),
            ...(t.deadline !== undefined ? { deadline: t.deadline } : {}),
            ...(t.durationMinutes !== undefined
              ? { duration_minutes: t.durationMinutes }
              : {}),
            ...(t.note !== undefined ? { note: t.note } : {}),
          })),
          ...(result.foodPrefs !== undefined
            ? {
                food_prefs: {
                  tracks_food: result.foodPrefs.tracksFood,
                  tracks_water: result.foodPrefs.tracksWater,
                  tracks_sleep: result.foodPrefs.tracksSleep,
                },
              }
            : {}),
        });
      } catch (err) {
        return aiError(fastify, reply, err, "onboarding-plan");
      }
    }
  );

  // Волна 6 / Этап 1: ИИ быстрое добавление — свободная фраза → одна задача
  // (premium). Ничего не сохраняет — клиент показывает confirm-sheet.
  fastify.post(
    "/api/v1/ai/quick-add",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = quickAddSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }
      if (!(await ensurePremium(request, reply))) return reply;

      try {
        const { task } = await generateQuickAddTask({
          text: parsed.data.text,
          date: parsed.data.date,
          timezone: parsed.data.timezone,
          language: langName(request.headers["accept-language"]),
          languageCode: parseLangCode(request.headers["accept-language"]),
        });
        return reply.status(200).send({
          task: {
            title: task.title,
            type: task.type,
            priority: task.priority,
            ...(task.scheduledAt !== undefined ? { scheduled_at: task.scheduledAt } : {}),
            ...(task.deadline !== undefined ? { deadline: task.deadline } : {}),
            ...(task.durationMinutes !== undefined
              ? { duration_minutes: task.durationMinutes }
              : {}),
            ...(task.note !== undefined ? { note: task.note } : {}),
          },
        });
      } catch (err) {
        return aiError(fastify, reply, err, "quick-add");
      }
    }
  );
};

export default aiRoutes;
