/**
 * ADR-041: серверный entitlement — единый источник правды о premium-статусе.
 *
 * isPremium = subscriptionTier === "premium" (legacy/пожизненный)
 *             ИЛИ (premiumUntil != null && premiumUntil > now)
 *
 * Все AI-гейты и billing-эндпоинты должны вызывать этот хелпер,
 * а не читать subscriptionTier напрямую.
 */

// Минимальный тип пользователя, нужный для расчёта entitlement.
// Совместим с Prisma User (полным или частичным select).
export interface EntitlementUser {
  subscriptionTier: string;
  premiumUntil: Date | null;
  premiumSource: string | null;
}

export interface EntitlementResult {
  isPremium: boolean;
  premiumUntil: Date | null;
  source: string | null;
}

/**
 * Возвращает текущий entitlement пользователя.
 * Безопасно вызывать в любом контексте — только вычисления, нет IO.
 */
export function resolveEntitlement(user: EntitlementUser): EntitlementResult {
  const now = new Date();

  // Legacy/пожизненный premium по subscriptionTier
  const legacyPremium = user.subscriptionTier === "premium";

  // Срочная подписка: premiumUntil установлен и ещё не истёк
  const timedPremium =
    user.premiumUntil !== null && user.premiumUntil > now;

  const isPremium = legacyPremium || timedPremium;

  return {
    isPremium,
    premiumUntil: user.premiumUntil,
    source: user.premiumSource,
  };
}
