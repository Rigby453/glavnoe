/**
 * In-memory rate limiter с фиксированным окном (fixed window) — ADR-058.
 *
 * Предназначен для защиты публичных и вебхук-эндпоинтов от флуда.
 * Ключ — обычно IP-адрес запроса или комбинация IP + endpoint.
 *
 * Ограничения стаба:
 *   - хранилище пропадает при рестарте процесса
 *   - не работает при нескольких инстансах (горизонтальное масштабирование)
 *
 * В production рассмотреть:
 *   @fastify/rate-limit (встраивается в Fastify, поддерживает Redis-бэкенд)
 *   или Redis + sliding window для распределённого деплоя.
 *
 * Env-переменные:
 *   RATE_LIMIT_WEBHOOK_MAX_PER_MINUTE  — макс. запросов к вебхук-эндпоинтам (default: 60)
 *   RATE_LIMIT_PUBLIC_MAX_PER_MINUTE   — макс. запросов к публичным эндпоинтам (default: 20)
 */

export interface RateLimitOptions {
  /** Длина окна в миллисекундах (например 60 * 1000 = 1 минута). */
  windowMs: number;
  /** Максимум запросов, допустимых за одно окно. */
  maxRequests: number;
}

export interface RateLimitResult {
  /** true — запрос разрешён; false — лимит превышен. */
  allowed: boolean;
  /** Оставшихся запросов в текущем окне (0 при allowed=false). */
  remaining: number;
  /** timestamp (Date.now() мс), когда текущее окно сбросится. */
  resetAt: number;
}

interface WindowEntry {
  count: number;
  resetAt: number;
}

/**
 * In-memory rate limiter с фиксированным окном.
 * Безопасен в однопоточной среде Node.js (Event Loop).
 */
export class InMemoryRateLimiter {
  private readonly windowMs: number;
  private readonly maxRequests: number;
  private readonly store = new Map<string, WindowEntry>();

  constructor(options: RateLimitOptions) {
    this.windowMs = options.windowMs;
    this.maxRequests = options.maxRequests;
  }

  /**
   * Проверяет и фиксирует запрос от ключа.
   * Каждый вызов увеличивает счётчик при allowed=true.
   *
   * @param key — идентификатор (IP, userId, "ip:endpoint" и т.п.)
   * @returns { allowed, remaining, resetAt }
   */
  check(key: string): RateLimitResult {
    const now = Date.now();
    const entry = this.store.get(key);

    if (!entry || now >= entry.resetAt) {
      // Первый запрос или окно истекло — начинаем новое окно
      const resetAt = now + this.windowMs;
      this.store.set(key, { count: 1, resetAt });
      return { allowed: true, remaining: this.maxRequests - 1, resetAt };
    }

    if (entry.count >= this.maxRequests) {
      // Лимит исчерпан
      return { allowed: false, remaining: 0, resetAt: entry.resetAt };
    }

    // Разрешаем и увеличиваем счётчик
    entry.count += 1;
    return {
      allowed: true,
      remaining: this.maxRequests - entry.count,
      resetAt: entry.resetAt,
    };
  }

  /**
   * Сбрасывает счётчик для конкретного ключа.
   * Полезно после успешного прохождения challenge или в тестах.
   */
  reset(key: string): void {
    this.store.delete(key);
  }

  /**
   * Очищает всё хранилище.
   * Использовать ТОЛЬКО в тестах (NODE_ENV=test).
   */
  clear(): void {
    this.store.clear();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Готовые синглтон-экземпляры для использования в маршрутах
// ────────────────────────────────────────────────────────────────────────────

function parseEnvInt(key: string, defaultValue: number): number {
  const val = parseInt(process.env[key] ?? "", 10);
  return isNaN(val) || val <= 0 ? defaultValue : val;
}

/**
 * Лимитер для вебхук-эндпоинтов биллинга.
 * Default: 60 запросов/минуту на ключ.
 * Ключ: обычно IP-адрес запроса.
 */
export const webhookRateLimiter = new InMemoryRateLimiter({
  windowMs: 60 * 1000,
  maxRequests: parseEnvInt("RATE_LIMIT_WEBHOOK_MAX_PER_MINUTE", 60),
});

/**
 * Лимитер для публичных эндпоинтов (auth/register, auth/login).
 * Default: 20 запросов/минуту на ключ.
 * Ключ: обычно IP-адрес запроса.
 */
export const publicRateLimiter = new InMemoryRateLimiter({
  windowMs: 60 * 1000,
  maxRequests: parseEnvInt("RATE_LIMIT_PUBLIC_MAX_PER_MINUTE", 20),
});
