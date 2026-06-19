// Персональные нормы питания (ккал + БЖУ + клетчатка + сахар).
// Считаются из антропометрии пользователя (вес/рост/возраст/пол/активность)
// по формуле Миффлина–Сан-Жеора. Хранятся в SharedPreferences; Riverpod-провайдер
// читает их и возвращает типизированный объект NutritionTargets.
//
// Использование в UI: ref.watch(nutritionTargetsProvider).
// Чистая функция computeNutritionTargets тестируется отдельно.

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider
import 'water_goal_provider.dart'; // kUser*Key

// ---------------------------------------------------------------------------
// Дефолтные значения (fallback когда антропометрия не заполнена)
// ---------------------------------------------------------------------------
const kDefaultNutritionKcal = 2000;
const kDefaultNutritionProteinG = 75;
const kDefaultNutritionFatG = 65;
const kDefaultNutritionCarbsG = 250;
const kDefaultNutritionFiberG = 28;
const kDefaultNutritionSugarMaxG = 50;

/// Дневные нормы питания, персонализированные под пользователя.
class NutritionTargets {
  const NutritionTargets({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.fiberG,
    required this.sugarMaxG,
  });

  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbsG;
  final int fiberG;
  final int sugarMaxG;

  /// Дефолтные нормы для пользователя без антропометрии.
  static const fallback = NutritionTargets(
    kcal: kDefaultNutritionKcal,
    proteinG: kDefaultNutritionProteinG,
    fatG: kDefaultNutritionFatG,
    carbsG: kDefaultNutritionCarbsG,
    fiberG: kDefaultNutritionFiberG,
    sugarMaxG: kDefaultNutritionSugarMaxG,
  );
}

/// Считает персональные нормы питания по формуле Миффлина–Сан-Жеора.
///
/// BMR (ккал/сут):
///   мужчины:  10*weight + 6.25*height - 5*age + 5
///   женщины:  10*weight + 6.25*height - 5*age - 161
///   other:    10*weight + 6.25*height - 5*age - 78   (среднее ±)
///
/// Коэффициент активности:
///   low    → 1.375
///   medium → 1.55   (по умолчанию)
///   high   → 1.725
///
/// TDEE = BMR × фактор, kcal = round(TDEE), зажимаем в [1200, 4000].
///
/// Макросы:
///   protein = round(1.6 × weight) г
///   fat     = round(kcal × 0.25 / 9) г
///   carbs   = max(0, round((kcal - protein*4 - fat*9) / 4)) г
///   fiber   = round(14 × kcal / 1000) г
///   sugarMax= round(kcal × 0.10 / 4) г
NutritionTargets computeNutritionTargets({
  required double weightKg,
  required double heightCm,
  required int age,
  required String sex, // 'male' | 'female' | 'other'
  required String activity, // 'low' | 'medium' | 'high'
}) {
  // Константа Миффлина по полу
  final s = switch (sex) {
    'male' => 5.0,
    'female' => -161.0,
    _ => -78.0, // 'other' и любое неизвестное — среднее
  };

  final bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age + s;

  // Коэффициент активности
  final factor = switch (activity) {
    'low' => 1.375,
    'high' => 1.725,
    _ => 1.55, // 'medium' и неизвестное
  };

  final tdee = bmr * factor;
  // Зажимаем ккал в физиологически разумный диапазон [1200, 4000]
  final kcal = tdee.round().clamp(1200, 4000);

  // Белок: 1.6 г на кг веса (рекомендация для активного человека)
  final proteinG = (1.6 * weightKg).round();

  // Жир: 25% от ккал (1 г жира = 9 ккал)
  final fatG = (kcal * 0.25 / 9).round();

  // Углеводы: оставшиеся калории после белка и жира (1 г = 4 ккал)
  final carbsRaw = (kcal - proteinG * 4 - fatG * 9) / 4;
  final carbsG = math.max(0, carbsRaw.round());

  // Клетчатка: 14 г на 1000 ккал (рекомендация ВОЗ/ADA)
  final fiberG = (14.0 * kcal / 1000.0).round();

  // Сахар: не более 10% от ккал (ВОЗ), 1 г сахара = 4 ккал
  final sugarMaxG = (kcal * 0.10 / 4).round();

  return NutritionTargets(
    kcal: kcal,
    proteinG: proteinG,
    fatG: fatG,
    carbsG: carbsG,
    fiberG: fiberG,
    sugarMaxG: sugarMaxG,
  );
}

/// Riverpod-провайдер персональных норм питания.
/// Читает антропометрию из SharedPreferences (сохранённую на шаге онбординга).
/// Если данные отсутствуют или неполны — возвращает NutritionTargets.fallback.
final nutritionTargetsProvider = Provider<NutritionTargets>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  final weightKg = prefs.getDouble(kUserWeightKgKey);
  final heightCm = prefs.getInt(kUserHeightCmKey)?.toDouble();
  final age = prefs.getInt(kUserAgeKey);
  final sex = prefs.getString(kUserSexKey) ?? 'other';
  final activity = prefs.getString(kUserActivityKey) ?? 'medium';

  // Если ключевые поля не заполнены — возвращаем дефолт
  if (weightKg == null || weightKg <= 0 ||
      heightCm == null || heightCm <= 0 ||
      age == null || age <= 0) {
    return NutritionTargets.fallback;
  }

  return computeNutritionTargets(
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
    sex: sex,
    activity: activity,
  );
});
