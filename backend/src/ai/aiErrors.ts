/**
 * Issue #18: классификация ошибок AI-провайдера для дифференцированной обработки.
 *
 * Раньше ЛЮБОЙ сбой апстрима (429 квота, 503 перегрузка, гео-блок, битый JSON)
 * сваливался в одно сообщение "AI is temporarily unavailable (quota/region)"
 * (см. backend/src/routes/ai.ts → aiError()). Это мешает понять РЕАЛЬНУЮ причину
 * и не даёт пользователю/логам сигнала, есть ли смысл повторить запрос прямо
 * сейчас (rate-limit/перегрузка — да) или только через сутки (дневная квота —
 * нет) или вообще никогда (регион).
 *
 * AiError — типизированная ошибка с полем `kind`. retry.ts использует её, чтобы
 * решать, повторять ли вызов модели. classifyAiError() работает и с обычными
 * Error (обратная совместимость со старым кодом / Anthropic SDK), и с AiError.
 *
 * userMessageFor() даёт раздельные пользовательские формулировки по `kind` —
 * готова к использованию маршрутом backend/src/routes/ai.ts (ВНЕ зоны
 * ответственности backend/src/ai/, правка туда не входит в этот коммит,
 * см. отчёт по задаче #18: рекомендованный one-line diff для aiError()).
 */

/** Тонкая классификация сбоя AI-провайдера. */
export type AiErrorKind =
  | "quota_daily" // суточный лимит провайдера исчерпан — повтор сейчас бесполезен, ждать сброс
  | "quota_rate" // лимит запросов в минуту (RPM) — кратковременно, повтор обычно помогает
  | "region" // провайдер недоступен из текущего региона — постоянная ошибка
  | "overloaded" // 5xx / "overloaded" / "high demand" — временная перегрузка апстрима
  | "invalid_response" // битый/неожиданный JSON или пустой ответ модели — повтор обычно помогает
  | "network" // таймаут/обрыв соединения — повтор обычно помогает
  | "unknown"; // не классифицировано — консервативно: НЕ ретраим

/** Виды ошибок, для которых withAiRetry имеет смысл повторить вызов. */
export const RETRYABLE_AI_ERROR_KINDS: ReadonlySet<AiErrorKind> = new Set([
  "quota_rate",
  "overloaded",
  "invalid_response",
  "network",
]);

/** Типизированная ошибка AI-провайдера/фичи с классификацией для retry и UX. */
export class AiError extends Error {
  readonly kind: AiErrorKind;
  readonly retryable: boolean;

  constructor(kind: AiErrorKind, message: string) {
    super(message);
    this.name = "AiError";
    this.kind = kind;
    this.retryable = RETRYABLE_AI_ERROR_KINDS.has(kind);
  }
}

/**
 * Классифицирует ЛЮБУЮ ошибку (AiError напрямую; обычный Error/string — по
 * эвристикам в тексте сообщения, для обратной совместимости со старым кодом
 * фич AI и с ошибками Anthropic SDK).
 */
export function classifyAiError(err: unknown): AiErrorKind {
  if (err instanceof AiError) return err.kind;
  const msg = (err instanceof Error ? err.message : String(err)).toLowerCase();

  // Гео-блок — постоянный, ретраить бесполезно (provider.ts уже пытается
  // fallback на Anthropic при наличии ключа, прежде чем это всплывёт сюда).
  if (msg.includes("user location is not supported")) return "region";

  const quotaSignal =
    msg.includes("resource_exhausted") ||
    msg.includes("quota") ||
    msg.includes("429") ||
    msg.includes("rate_limit");
  if (quotaSignal) {
    // Суточный лимит (RPD) — отдельный маркер из тела ошибки Gemini
    // (quotaId вида "...PerDayPerProjectPerModel...", см. provider.ts).
    // Без явного маркера считаем это поминутным (RPM) лимитом — кратковременным.
    const dailySignal =
      msg.includes("perday") || msg.includes("per_day") || msg.includes("requestsperday");
    return dailySignal ? "quota_daily" : "quota_rate";
  }

  if (
    msg.includes("503") ||
    msg.includes("529") ||
    msg.includes("overloaded") ||
    msg.includes("high demand")
  ) {
    return "overloaded";
  }

  if (
    msg.includes("unparseable") ||
    msg.includes("no usable") ||
    (msg.includes("unexpected") && msg.includes("shape"))
  ) {
    return "invalid_response";
  }

  if (
    msg.includes("timeout") ||
    msg.includes("etimedout") || // Node connect-timeout error code (doesn't contain "timeout" literally)
    msg.includes("econnreset") ||
    msg.includes("fetch failed")
  ) {
    return "network";
  }

  return "unknown";
}

/**
 * Раздельные пользовательские сообщения по виду ошибки — вместо одного общего
 * "AI is temporarily unavailable (quota/region)". НЕ дублирует HTTP-статусы —
 * это забота вызывающего слоя (routes), который сегодня этот хелпер не зовёт
 * (см. JSDoc файла).
 */
export function userMessageFor(kind: AiErrorKind): string {
  switch (kind) {
    case "quota_daily":
      return "Daily AI usage limit reached — please try again later (resets within 24h).";
    case "quota_rate":
      return "AI is getting a lot of requests right now — please try again in a minute.";
    case "region":
      return "AI provider is temporarily unavailable from this region.";
    case "overloaded":
      return "AI service is busy right now — please try again shortly.";
    case "invalid_response":
      return "AI couldn't build this right now — please try again.";
    case "network":
      return "Network hiccup talking to AI — please try again.";
    case "unknown":
    default:
      return "AI service is unavailable. Please try again later.";
  }
}
