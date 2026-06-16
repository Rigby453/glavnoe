import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();

// In-memory store: email → { code, expiresAt }
// Достаточно для MVP; в production заменить на Redis или DB-таблицу
const resetTokens = new Map<string, { code: string; expiresAt: number }>();

function generateCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
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
      const code = generateCode();
      resetTokens.set(email.toLowerCase(), {
        code,
        expiresAt: Date.now() + 15 * 60 * 1000,
      });
      // TODO: в production отправить email через SMTP/SES
      fastify.log.info({ email, code }, "Password reset code generated");
      // В dev-режиме возвращаем код в ответе для тестирования
      if (process.env["NODE_ENV"] !== "production") {
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

    const entry = resetTokens.get(email.toLowerCase());
    if (!entry || entry.code !== code || Date.now() > entry.expiresAt) {
      return reply.status(400).send({ error: "Invalid or expired code" });
    }

    const hash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({
      where: { email },
      data: { passwordHash: hash },
    });

    resetTokens.delete(email.toLowerCase());
    return reply.status(200).send({ message: "Password updated successfully" });
  });
};

export default authResetRoutes;
