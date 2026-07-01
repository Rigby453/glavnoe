// Адопция профиля пользователя (антропометрия/цели питания/вода) с сервера
// в локальные SharedPreferences-ключи (ADR-062).
//
// Диагностика бага: вес/рост/возраст/пол/активность/цель питания/override
// макросов/норма воды раньше хранились ТОЛЬКО локально (SharedPreferences) —
// на сервер уходил только флаг онбординга. Каждое устройство одного аккаунта
// считало КБЖУ по своей ЛОКАЛЬНОЙ антропометрии → расхождение норм между
// устройствами (например, 3000 ккал на телефоне против 2000 на web).
//
// Решение: бэкенд теперь хранит эти поля на пользователе (PATCH/GET
// /api/v1/auth/me, snake_case — см. /docs/api-spec.yaml). [applyServerProfile]
// читает объект `user` (из ответа /auth/login, /auth/register или GET /auth/me —
// все три возвращают один и тот же контракт `User`) и для КАЖДОГО заданного
// (не-null) поля перезаписывает соответствующий локальный ключ — сервер
// выступает источником истины для вернувшегося пользователя на новом
// устройстве. Поля, которые сервер не прислал (null/отсутствуют в теле),
// НЕ трогают локальное значение — так локально введённые (и ещё не
// отправленные на сервер, например гостевые) данные не затираются нулями.
//
// Чистая функция (без Riverpod/Dio) — легко тестируется с мок-SharedPreferences
// (SharedPreferences.setMockInitialValues), по образцу onboarding_sync_test.dart.
// Вызывающий код (AuthController) отвечает за ref.invalidate(...) провайдеров,
// которые кэшируют значения, посчитанные из этих ключей (nutritionTargetsProvider,
// macroOverrideProvider, waterGoalProvider, foodPreferencesProvider).

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/food_preferences_provider.dart' show kFoodGoalKey;
import '../../core/settings/macro_override_provider.dart';
import '../../core/settings/water_goal_provider.dart';

/// Применяет профиль [user] (снапшот с сервера) к [prefs].
///
/// `calorie_goal`, присланный сервером, здесь НЕ пишется отдельно: локально
/// он не отдельный ключ — клиент всегда пересчитывает ккал из антропометрии
/// (computeNutritionTargets) либо берёт из macro_kcal_target/macro_*_g при
/// включённом override. Адопция антропометрии + macro-полей ниже уже даёт
/// идентичный результат без риска разойтись с формулой на клиенте.
Future<void> applyServerProfile(
  Map<String, dynamic> user,
  SharedPreferences prefs,
) async {
  final weightKg = (user['weight_kg'] as num?)?.toDouble();
  if (weightKg != null) {
    await prefs.setDouble(kUserWeightKgKey, weightKg);
  }

  final heightCm = (user['height_cm'] as num?)?.toInt();
  if (heightCm != null) {
    await prefs.setInt(kUserHeightCmKey, heightCm);
  }

  final ageYears = (user['age_years'] as num?)?.toInt();
  if (ageYears != null) {
    await prefs.setInt(kUserAgeKey, ageYears);
  }

  final sex = user['sex'] as String?;
  if (sex != null) {
    await prefs.setString(kUserSexKey, sex);
  }

  final activityLevel = user['activity_level'] as String?;
  if (activityLevel != null) {
    await prefs.setString(kUserActivityKey, activityLevel);
  }

  final foodGoal = user['food_goal'] as String?;
  if (foodGoal != null) {
    await prefs.setString(kFoodGoalKey, foodGoal);
  }

  final macroOverrideEnabled = user['macro_override_enabled'] as bool?;
  if (macroOverrideEnabled != null) {
    await prefs.setBool(kMacroOverrideEnabledKey, macroOverrideEnabled);
  }

  final macroKcalTarget = (user['macro_kcal_target'] as num?)?.toInt();
  if (macroKcalTarget != null) {
    await prefs.setInt(kMacroKcalTargetKey, macroKcalTarget);
  }

  final macroProteinG = (user['macro_protein_g'] as num?)?.toInt();
  if (macroProteinG != null) {
    await prefs.setInt(kMacroProteinGKey, macroProteinG);
  }

  final macroFatG = (user['macro_fat_g'] as num?)?.toInt();
  if (macroFatG != null) {
    await prefs.setInt(kMacroFatGKey, macroFatG);
  }

  final macroCarbsG = (user['macro_carbs_g'] as num?)?.toInt();
  if (macroCarbsG != null) {
    await prefs.setInt(kMacroCarbsGKey, macroCarbsG);
  }

  final waterGoalMl = (user['water_goal_ml'] as num?)?.toInt();
  if (waterGoalMl != null) {
    await prefs.setInt(kWaterGoalMlKey, waterGoalMl);
  }
}
