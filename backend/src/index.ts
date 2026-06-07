import { buildServer } from "./app.js";

const PORT = parseInt(process.env["PORT"] ?? "3000", 10);

// Точка входа: собираем приложение и начинаем слушать порт.
async function start(): Promise<void> {
  const fastify = await buildServer();
  try {
    await fastify.listen({ port: PORT, host: "0.0.0.0" });
    console.log(`Kaizen backend started on port ${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

start().catch((err: unknown) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});
