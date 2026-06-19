import type { User } from "@prisma/client";
import { resolveEntitlement } from "./entitlement.js";

// Тип ответа для пользователя — строго по api-spec.yaml (snake_case, без passwordHash).
// email и phone теперь nullable (406-ФЗ).
// ADR-041: добавлены is_premium, premium_until, premium_source.
export interface SerializedUser {
  id: string;
  email: string | null;
  phone: string | null;
  name: string;
  subscription_tier: string;
  is_premium: boolean;
  premium_until: string | null;
  premium_source: string | null;
  theme: string;
  tone_preference: string;
  created_at: string;
  updated_at: string;
}

/**
 * Преобразует Prisma User (camelCase) в snake_case ответ API.
 * Гарантирует отсутствие passwordHash в ответе.
 * email и phone могут быть null (пользователь зарегистрирован по телефону или email).
 * ADR-041: включает entitlement (is_premium, premium_until, premium_source).
 */
export function serializeUser(user: User): SerializedUser {
  const entitlement = resolveEntitlement(user);
  return {
    id: user.id,
    email: user.email ?? null,
    phone: user.phone ?? null,
    name: user.name,
    subscription_tier: user.subscriptionTier,
    is_premium: entitlement.isPremium,
    premium_until: entitlement.premiumUntil
      ? entitlement.premiumUntil.toISOString()
      : null,
    premium_source: entitlement.source,
    theme: user.theme,
    tone_preference: user.tonePreference,
    created_at: user.createdAt.toISOString(),
    updated_at: user.updatedAt.toISOString(),
  };
}
