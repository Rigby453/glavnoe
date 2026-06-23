import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import bcrypt from "bcrypt";
import prisma from "../models/prisma.js";
import {
  RESET_CODE_TTL_MS,
  generateResetCode,
  hashResetCode,
} from "../models/passwordReset.js";

// Коды восстановления хранятся в таблице PasswordResetCode (ADR-047), а не в
// Map в памяти процесса: память не переживает рестарт/засыпание/масштабирование
// инстанса, из-за чего код терялся между запросом и вводом (тот же класс
// проблемы, что вынос AiUsage из памяти в БД — ADR-034).

// Раскрываем dev_code только в явно доверенных окружениях. Пустой/неизвестный
// NODE_ENV НЕ должен раскрывать код (иначе забытый NODE_ENV на проде = обход
// верификации). Allowlist, а не blacklist по 'production'.
function devCodeAllowed(): boolean {
  const env = process.env["NODE_ENV"];
  return env === "development" || env === "test";
}

const forgotSchema = z.object({ email: z.string().email() });
const resetSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6),
  newPassword: z.string().min(8),
});

const authResetRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/auth/forgot-password
  fastify.post("/api/v1/auth/forgot-password", async (request, reply) => {
    const parsed = forgotSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: "Valid email required" });
    }
    const { email } = parsed.data;

    // Проверяем существование пользователя (не раскрываем факт отсутствия — всегда 200)
    const user = await prisma.user.findUnique({ where: { email } });

    if (user) {
      const code = generateResetCode();
      const codeHash = hashResetCode(code);
      const expiresAt = new Date(Date.now() + RESET_CODE_TTL_MS);

      // Инвалидируем все прошлые неиспользованные коды пользователя, помечая их
      // использованными, и создаём новый — атомарно в одной транзакции, чтобы
      // сбой между двумя шагами не оставил пользователя без активного кода
      // (или с двумя активными). Активным остаётся только что выданный.
      await prisma.$transaction([
        prisma.passwordResetCode.updateMany({
          where: { userId: user.id, usedAt: null },
          data: { usedAt: new Date() },
        }),
        prisma.passwordResetCode.create({
          data: { userId: user.id, codeHash, expiresAt },
        }),
      ]);

      // TODO: в production отправить email через SMTP/SES (заблокировано отсутствием SMTP)
      fastify.log.info({ email }, "Password reset code generated");
      // В dev/test-режиме возвращаем код в ответе для тестирования
      if (devCodeAllowed()) {
        return reply.status(200).send({
          message: "If this email is registered, a reset code was sent.",
          dev_code: code,
        });
      }
    }

    return reply.status(200).send({
      message: "If this email is registered, a reset code was sent.",
    });
  });

  // POST /api/v1/auth/reset-password
  fastify.post("/api/v1/auth/reset-password", async (request, reply) => {
    const parsed = resetSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply
        .status(400)
        .send({ error: "email, code (6 digits), newPassword (min 8) required" });
    }
    const { email, code, newPassword } = parsed.data;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return reply.status(400).send({ error: "Invalid or expired code" });
    }

    // Ищем валидный код: совпадает хэш, не использован, ещё не истёк.
    const now = new Date();
    const record = await prisma.passwordResetCode.findFirst({
      where: {
        userId: user.id,
        codeHash: hashResetCode(code),
        usedAt: null,
        expiresAt: { gt: now },
      },
    });
    if (!record) {
      return reply.status(400).send({ error: "Invalid or expired code" });
    }

    const hash = await bcrypt.hash(newPassword, 12);
    // Помечаем код использованным и меняем пароль; одноразовость гарантируется
    // условием usedAt=null в updateMany — повторное использование не сработает.
    await prisma.$transaction([
      prisma.passwordResetCode.update({
        where: { id: record.id },
        data: { usedAt: now },
      }),
      prisma.user.update({
        where: { id: user.id },
        data: { passwordHash: hash },
      }),
    ]);

    // Лениво подчищаем истёкшие/использованные коды этого пользователя.
    await prisma.passwordResetCode.deleteMany({
      where: {
        userId: user.id,
        OR: [{ usedAt: { not: null } }, { expiresAt: { lte: now } }],
      },
    });

    return reply.status(200).send({ message: "Password updated successfully" });
  });
};

export default authResetRoutes;
