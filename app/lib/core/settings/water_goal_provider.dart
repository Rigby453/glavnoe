// Дневная норма воды (мл). Настраивается в онбординге (шаг «нормы», SPEC C1)
// и в будущем в настройках профиля. Хранится в SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kWaterGoalKey = 'water_goal_ml';
const kDefaultWaterGoalMl = 2000;

// Ключи SharedPreferences для антропометрии — собираются в онбординге
// для будущей аналитики и возможного пересчёта нормы.
const kUserWeightKgKey = 'user_weight_kg';
const kUserHeightCmKey = 'user_height_cm';
const kUserActivityKey = 'user_activity'; // 'low' | 'medium' | 'high'
const kUserAgeKey = 'user_age'; // int (лет)
const kUserSexKey = 'user_sex'; // 'male' | 'female' | 'other'

/// Рассчитывает рекомендуемую норму воды по весу, активности, росту и возрасту.
///
/// Формула: weightKg × 33 мл × множитель активности × поправка на рост × поправка на возраст.
/// Множители активности: low=0.9, medium=1.0, high=1.15.
/// Поправка на рост [heightCm] — мягкая, относительно эталона 170 см:
/// ±0.2% на каждый см, зажата в [0.95, 1.08]. Основной фактор — вес;
/// рост влияет слабо (так и положено физиологически). Если рост не задан —
/// поправка нейтральная (1.0).
/// Поправка на возраст [age] — мягкое снижение у пожилых: clamp(1 - (age-30)*0.001, 0.95, 1.0).
/// Если возраст не задан — поправка нейтральная (1.0).
/// Результат округляется до 100 мл, зажимается в диапазон [1500, 4000].
/// После расчёта пользователь может поправить норму вручную (слайдер).
int recommendedWaterMl({
  required double weightKg,
  required String activity, // 'low' | 'medium' | 'high'
  double? heightCm,
  int? age,
}) {
  final multiplier = switch (activity) {
    'low' => 0.9,
    'high' => 1.15,
    _ => 1.0, // 'medium' и любое неизвестное значение
  };
  // Поправка на рост: эталон 170 см, ±0.2% на см, зажата в [0.95, 1.08].
  final heightFactor = (heightCm == null || heightCm <= 0)
      ? 1.0
      : (1 + (heightCm - 170) * 0.002).clamp(0.95, 1.08);
  // Поправка на возраст: мягкое снижение для возраста > 30 лет.
  final ageFactor = (age == null || age <= 0)
      ? 1.0
      : (1.0 - (age - 30) * 0.001).clamp(0.95, 1.0);
  // Базовый расчёт: 33 мл на кг веса
  final raw = weightKg * 33.0 * multiplier * heightFactor * ageFactor;
  // Округление до 100 мл
  final rounded = ((raw / 100).round() * 100).toInt();
  // Ограничиваем физиологически разумным диапазоном
  return rounded.clamp(1500, 4000);
}

class WaterGoalNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kWaterGoalKey) ??
      kDefaultWaterGoalMl;

  Future<void> set(int ml) async {
    await ref.read(sharedPreferencesProvider).setInt(_kWaterGoalKey, ml);
    state = ml;
  }
}

final waterGoalProvider =
    NotifierProvider<WaterGoalNotifier, int>(WaterGoalNotifier.new);
