// Augmentation модуля fastify — добавляем request.rawBody (ADR-067).
// Заполняется кастомным JSON content-type parser'ом в app.ts: нужен для
// HMAC-проверки подписи вебхука ЮKassa (HMAC считается по сырым байтам тела,
// а НЕ по повторной JSON.stringify() распарсенного объекта — порядок ключей/
// пробелы могут не совпасть с тем, что подписывал отправитель).
import "fastify";

declare module "fastify" {
  interface FastifyRequest {
    /** Raw UTF-8 тело запроса (только для application/json — см. app.ts). */
    rawBody?: string;
  }
}

export {};
