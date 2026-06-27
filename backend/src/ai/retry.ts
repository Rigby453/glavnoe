/**
 * withAiRetry — повтор AI-вызова при временных сбоях (квота/сеть/битый JSON).
 * Постоянные ошибки (гео-блок, 4xx бизнес-валидация) НЕ ретраятся.
 * Паузы детерминированы (без Math.random) для предсказуемости.
 * В тестовом окружении (NODE_ENV=test) задержки нулевые — скорость важнее.
 */

/** Задержки между попытками (ms), по индексу паузы (0 = перед 2-й попыткой). */
const RETRY_DELAYS_MS: ReadonlyArray<number> =
  process.env["NODE_ENV"] === "test" ? [0, 0] : [400, 900];

/**
 * Возвращает true для ошибок, при которых повтор запроса имеет смысл:
 * квота/503/rate-limit/сетевые сбои/битый JSON ответа модели.
 * Возвращает false для постоянных ошибок (гео-блок) и бизнес-ошибок 4xx.
 */
function isTransient(err: unknown): boolean {
  const msg = (err instanceof Error ? err.message : String(err)).toLowerCase();
  // Гео-блок — постоянный, ретраить бесполезно
  if (msg.includes("user location is not supported")) return false;
  return (
    msg.includes("429") ||
    msg.includes("quota") ||
    msg.includes("503") ||
    msg.includes("overloaded") ||
    msg.includes("high demand") ||
    msg.includes("unparseable") ||
    msg.includes("no usable") ||
    (msg.includes("unexpected") && msg.includes("shape")) ||
    msg.includes("timeout") ||
    msg.includes("econnreset")
  );
}

/**
 * Оборачивает асинхронный AI-вызов с автоматическим ретраем при временных сбоях.
 * @param fn - функция, которую нужно выполнить (должна быть идемпотентна)
 * @param opts.attempts - максимальное число попыток включая первую (по умолчанию 3)
 */
export async function withAiRetry<T>(
  fn: () => Promise<T>,
  opts?: { attempts?: number }
): Promise<T> {
  const maxAttempts = opts?.attempts ?? 3;
  let lastErr: unknown;
  for (let i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (!isTransient(err)) throw err; // постоянный сбой — сразу наверх
      if (i < maxAttempts - 1) {
        await new Promise<void>((resolve) =>
          setTimeout(resolve, RETRY_DELAYS_MS[i] ?? 900)
        );
      }
    }
  }
  throw lastErr;
}
