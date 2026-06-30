/**
 * withAiRetry — повтор AI-вызова при временных сбоях (квота-RPM/перегрузка/
 * сеть/битый JSON). Постоянные ошибки (гео-блок, ИСЧЕРПАННАЯ СУТОЧНАЯ квота,
 * 4xx бизнес-валидация) НЕ ретраятся — повтор внутри того же запроса либо
 * бесполезен (суточный лимит не сбросится за секунды), либо вреден (тратит
 * время пользователя и добивает уже исчерпанный лимит лишними вызовами).
 * Паузы детерминированы (без Math.random) для предсказуемости.
 * В тестовом окружении (NODE_ENV=test) задержки нулевые — скорость важнее.
 *
 * Классификация вынесена в aiErrors.ts (issue #18) — единая логика для
 * retry.ts И для будущего дифференцированного user-facing сообщения в routes.
 */

import { classifyAiError, RETRYABLE_AI_ERROR_KINDS } from "./aiErrors.js";

/** Задержки между попытками (ms), по индексу паузы (0 = перед 2-й попыткой). */
const RETRY_DELAYS_MS: ReadonlyArray<number> =
  process.env["NODE_ENV"] === "test" ? [0, 0] : [400, 900];

/**
 * Возвращает true для ошибок, при которых повтор запроса имеет смысл
 * (quota_rate / overloaded / invalid_response / network — см. aiErrors.ts).
 * Возвращает false для постоянных ошибок (region, quota_daily) и
 * неклассифицированных (unknown) — последнее консервативно: лучше не
 * ретраить незнакомую ошибку, чем зря тратить время на заведомо бесполезные
 * попытки.
 */
function isTransient(err: unknown): boolean {
  return RETRYABLE_AI_ERROR_KINDS.has(classifyAiError(err));
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
