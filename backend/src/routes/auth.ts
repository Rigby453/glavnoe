import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import bcrypt from "bcrypt";
import prisma from "../models/prisma.js";
import { serializeUser } from "../models/user.js";
import { requireAuth } from "./middleware/auth.js";
import {
  isAllowedEmailDomain,
  allowedDomainsHint,
} from "../lib/email-domains.js";

// ---------------------------------------------------------------------------
// Нормализация российского номера телефона в E.164: +7XXXXXXXXXX
// Принимает: +7XXXXXXXXXX | 7XXXXXXXXXX | 8XXXXXXXXXX
// Возвращает null, если формат не распознан
// ---------------------------------------------------------------------------
function normalizeRussianPhone(raw: string): string | null {
  // Убираем пробелы, дефисы, скобки
  const digits = raw.replace(/[\s\-().]/g, "");

  // Паттерн: опциональный + затем 11 цифр начинающихся на 7 или 8
  if (/^\+7\d{10}$/.test(digits)) {
    return digits; // уже +7XXXXXXXXXX
  }
  if (/^7\d{10}$/.test(digits)) {
    return "+" + digits; // 7XXXXXXXXXX → +7XXXXXXXXXX
  }
  if (/^8\d{10}$/.test(digits)) {
    return "+7" + digits.slice(1); // 8XXXXXXXXXX → +7XXXXXXXXXX
  }
  return null;
}

// ---------------------------------------------------------------------------
// Zod-схемы (api-spec.yaml: RegisterRequest, LoginRequest)
// Ровно один идентификатор: email ИЛИ phone
// ---------------------------------------------------------------------------

const registerSchema = z
  .object({
    email: z.string().email().optional(),
    phone: z.string().optional(),
    password: z.string().min(8),
    name: z.string().min(1),
  })
  .superRefine((data, ctx) => {
    const hasEmail = Boolean(data.email);
    const hasPhone = Boolean(data.phone);

    if (!hasEmail && !hasPhone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Provide either email or phone",
        path: ["email"],
      });
      return;
    }
    if (hasEmail && hasPhone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Provide either email or phone, not both",
        path: ["email"],
      });
    }
  });

const loginSchema = z
  .object({
    email: z.string().email().optional(),
    phone: z.string().optional(),
    password: z.string().min(1),
  })
  .superRefine((data, ctx) => {
    const hasEmail = Boolean(data.email);
    const hasPhone = Boolean(data.phone);

    if (!hasEmail && !hasPhone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Provide either email or phone",
        path: ["email"],
      });
      return;
    }
    if (hasEmail && hasPhone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Provide either email or phone, not both",
        path: ["email"],
      });
    }
  });

// Обновление флагов профиля (snake_case, все поля опциональны, лишние игнорируются)
const updateMeSchema = z.object({
  onboarding_done: z.boolean().optional(),
});

// ---------------------------------------------------------------------------
// Маршруты аутентификации
// ---------------------------------------------------------------------------

const authRoutes: FastifyPluginAsync = async (fastify) => {
  // AUTH-01: POST /api/v1/auth/register
  fastify.post("/api/v1/auth/register", async (request, reply) => {
    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: parsed.error.issues[0]?.message ?? "Validation error",
      });
    }

    const { email, phone: rawPhone, password, name } = parsed.data;

    // Нормализация и валидация телефона
    let phone: string | null = null;
    if (rawPhone !== undefined) {
      const normalized = normalizeRussianPhone(rawPhone);
      if (!normalized) {
        return reply.status(400).send({
          error:
            "Invalid phone number. Use Russian format: +7XXXXXXXXXX, 7XXXXXXXXXX, or 8XXXXXXXXXX",
        });
      }
      phone = normalized;
    }

    // Проверка домена email (только российские провайдеры, 406-ФЗ)
    if (email !== undefined) {
      if (!isAllowedEmailDomain(email)) {
        return reply.status(400).send({
          error: `Email provider not allowed. Use a Russian email (${allowedDomainsHint()}, …) or sign up by phone.`,
        });
      }
    }

    // Проверяем уникальность email и phone раздельно (409 при конфликте)
    if (email !== undefined) {
      const byEmail = await prisma.user.findUnique({ where: { email } });
      if (byEmail) {
        return reply.status(409).send({ error: "Email or phone already exists" });
      }
    }
    if (phone !== null) {
      const byPhone = await prisma.user.findUnique({ where: { phone } });
      if (byPhone) {
        return reply.status(409).send({ error: "Email or phone already exists" });
      }
    }

    // Хешируем пароль (saltRounds=12, согласно backend/CLAUDE.md)
    const passwordHash = await bcrypt.hash(password, 12);

    // Создаём пользователя и Streak одной транзакцией
    const user = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          email: email ?? null,
          phone: phone ?? null,
          passwordHash,
          name,
        },
      });
      await tx.streak.create({
        data: {
          userId: newUser.id,
          current: 0,
          longest: 0,
          freezeCount: 0,
        },
      });
      return newUser;
    });

    // Подписываем JWT — только userId (email теперь может быть null)
    const accessToken = await reply.jwtSign(
      { userId: user.id },
      { expiresIn: "30d" }
    );

    return reply.status(201).send({
      access_token: accessToken,
      user: serializeUser(user),
    });
  });

  // AUTH-02: POST /api/v1/auth/login
  fastify.post("/api/v1/auth/login", async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: parsed.error.issues[0]?.message ?? "Validation error",
      });
    }

    const { email, phone: rawPhone, password } = parsed.data;

    // Нормализация телефона (при входе по телефону)
    let phone: string | null = null;
    if (rawPhone !== undefined) {
      const normalized = normalizeRussianPhone(rawPhone);
      if (!normalized) {
        return reply.status(401).send({ error: "Invalid credentials" });
      }
      phone = normalized;
    }

    // Ищем пользователя по тому идентификатору, который передан
    let user: Awaited<ReturnType<typeof prisma.user.findUnique>>;
    if (email !== undefined) {
      user = await prisma.user.findUnique({ where: { email } });
    } else {
      // phone точно не null здесь (superRefine гарантирует наличие ровно одного)
      user = await prisma.user.findUnique({ where: { phone: phone! } });
    }

    if (!user) {
      return reply.status(401).send({ error: "Invalid credentials" });
    }

    // Сравниваем пароль
    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) {
      return reply.status(401).send({ error: "Invalid credentials" });
    }

    // JWT — только userId
    const accessToken = await reply.jwtSign(
      { userId: user.id },
      { expiresIn: "30d" }
    );

    return reply.status(200).send({
      access_token: accessToken,
      user: serializeUser(user),
    });
  });

  // AUTH-04: GET /api/v1/auth/me (защищённый маршрут)
  fastify.get(
    "/api/v1/auth/me",
    { preHandler: requireAuth },
    async (request, reply) => {
      const { userId } = request.user;

      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.status(404).send({ error: "Not found" });
      }

      return reply.status(200).send(serializeUser(user));
    }
  );

  // AUTH-05: PATCH /api/v1/auth/me (защищённый маршрут)
  // Обновление серверных флагов профиля. Сейчас — только onboarding_done
  // (ADR-055: синхронизация завершения онбординга между устройствами/вебом).
  fastify.patch(
    "/api/v1/auth/me",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = updateMeSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const { userId } = request.user;

      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.status(404).send({ error: "Not found" });
      }

      // Маппинг snake_case (API) → camelCase (Prisma); только переданные поля.
      const data: { onboardingDone?: boolean } = {};
      if (parsed.data.onboarding_done !== undefined) {
        data.onboardingDone = parsed.data.onboarding_done;
      }

      const updated = await prisma.user.update({
        where: { id: userId },
        data,
      });

      return reply.status(200).send(serializeUser(updated));
    }
  );
};

export default authRoutes;
