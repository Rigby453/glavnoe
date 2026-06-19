import dotenv from "dotenv";
// Загружаем переменные окружения до всего остального
dotenv.config();

import Fastify, { type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import jwt from "@fastify/jwt";
import authRoutes from "./routes/auth.js";
import itemsRoutes from "./routes/items.js";
import streaksRoutes from "./routes/streaks.js";
import syncRoutes from "./routes/sync.js";
import redistributeRoutes from "./routes/redistribute.js";
import aiRoutes from "./routes/ai.js";
import subscriptionRoutes from "./routes/subscription.js";
import billingRoutes from "./routes/billing.js";
import foodRoutes from "./routes/food.js";
import shareRoutes from "./routes/share.js";
import authResetRoutes from "./routes/auth-reset.js";
import { coStudyRoutes } from "./routes/costudy.js";

/**
 * Собирает и конфигурирует экземпляр Fastify (без вызова listen).
 * Точка входа (index.ts) поднимает сервер, а тесты используют
 * этот же фабричный метод с fastify.inject()/supertest.
 */
export async function buildServer(): Promise<FastifyInstance> {
  const JWT_SECRET = process.env["JWT_SECRET"];
  if (!JWT_SECRET) {
    throw new Error("JWT_SECRET is not set in environment");
  }

  const fastify = Fastify({
    // В тестах логи отключаем, чтобы не зашумлять вывод
    logger: process.env["NODE_ENV"] !== "test",
    // /share/:token несёт JWT (~300 символов); дефолтный maxParamLength=100
    // не матчит такие URL (роутер отвечал 404 на валидные ссылки).
    maxParamLength: 1000,
  });

  // Регистрируем CORS — разрешаем localhost в dev
  await fastify.register(cors, {
    origin: (origin, cb) => {
      // Разрешаем запросы без origin (curl, мобильные) и localhost
      if (!origin || origin.startsWith("http://localhost")) {
        cb(null, true);
        return;
      }
      if (process.env["NODE_ENV"] !== "production") {
        cb(null, true);
        return;
      }
      cb(new Error("Not allowed by CORS"), false);
    },
  });

  // Регистрируем JWT с секретом из env
  await fastify.register(jwt, {
    secret: JWT_SECRET,
  });

  // GET /health — проверка работоспособности сервера (api-spec.yaml: returns { status: "ok" })
  fastify.get("/health", async (_request, _reply) => {
    return { status: "ok" };
  });

  // Регистрируем маршруты аутентификации (AUTH-01..04)
  await fastify.register(authRoutes);

  // Регистрируем маршруты Items (ITEMS-01..04)
  await fastify.register(itemsRoutes);

  // Регистрируем маршруты Streaks (STREAK-01)
  await fastify.register(streaksRoutes);

  // Регистрируем маршруты Sync (SYNC-01)
  await fastify.register(syncRoutes);

  // Регистрируем маршруты Engine (ENGINE-01)
  await fastify.register(redistributeRoutes);

  // Регистрируем AI-маршруты (Phase 1, premium): фото-импорт расписания
  await fastify.register(aiRoutes);

  // Регистрируем маршруты подписки (dev-upgrade + GET /status; реальные платежи — Phase 1)
  await fastify.register(subscriptionRoutes);

  // Регистрируем заглушки вебхуков биллинга (ADR-041; без проверки подписи — TODO при наличии ключей)
  await fastify.register(billingRoutes);

  // Регистрируем маршруты Food (Open Food Facts: barcode/search)
  await fastify.register(foodRoutes);

  // Регистрируем маршруты Share (Ф3: веб-шеринг плана, ADR-030)
  await fastify.register(shareRoutes);

  // Регистрируем маршруты сброса пароля (AUTH-05..06)
  await fastify.register(authResetRoutes);

  // Регистрируем маршруты Co-study (Ф3: друзья, учебные сессии, лидерборд)
  await fastify.register(coStudyRoutes);

  return fastify;
}
