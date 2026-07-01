import type { User } from "@prisma/client";
import { resolveEntitlement } from "./entitlement.js";

// Тип ответа для пользователя — строго по api-spec.yaml (snake_case, без passwordHash).
// email и phone теперь nullable (406-ФЗ).
// ADR-041: добавлены is_premium, premium_until, premium_source.
// ADR-062: добавлены антропометрия + цели питания/воды (синк профиля между устройствами).
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
  onboarding_done: boolean;
  weight_kg: number | null;
  height_cm: number | null;
  age_years: number | null;
  sex: string | null;
  activity_level: string | null;
  food_goal: string | null;
  calorie_goal: number | null;
  macro_override_enabled: boolean;
  macro_kcal_target: number | null;
  macro_protein_g: number | null;
  macro_fat_g: number | null;
  macro_carbs_g: number | null;
  water_goal_ml: number | null;
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
    onboarding_done: user.onboardingDone,
    weight_kg: user.weightKg ?? null,
    height_cm: user.heightCm ?? null,
    age_years: user.ageYears ?? null,
    sex: user.sex ?? null,
    activity_level: user.activityLevel ?? null,
    food_goal: user.foodGoal ?? null,
    calorie_goal: user.calorieGoal ?? null,
    macro_override_enabled: user.macroOverrideEnabled,
    macro_kcal_target: user.macroKcalTarget ?? null,
    macro_protein_g: user.macroProteinG ?? null,
    macro_fat_g: user.macroFatG ?? null,
    macro_carbs_g: user.macroCarbsG ?? null,
    water_goal_ml: user.waterGoalMl ?? null,
    created_at: user.createdAt.toISOString(),
    updated_at: user.updatedAt.toISOString(),
  };
}
