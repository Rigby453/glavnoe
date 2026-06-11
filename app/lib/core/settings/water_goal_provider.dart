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

/// Рассчитывает рекомендуемую норму воды по весу и уровню активности.
///
/// Формула: weightKg × 33 мл × множитель активности.
/// Множители: low=0.9, medium=1.0, high=1.15.
/// Результат округляется до 100 мл, зажимается в диапазон [1500, 4000].
///
/// Рост [heightCm] собирается для будущей аналитики (индексы, нормы ВОЗ),
/// но в текущей формуле расчёта воды НЕ участвует.
int recommendedWaterMl({
  required double weightKg,
  required String activity, // 'low' | 'medium' | 'high'
}) {
  final multiplier = switch (activity) {
    'low' => 0.9,
    'high' => 1.15,
    _ => 1.0, // 'medium' и любое неизвестное значение
  };
  // Базовый расчёт: 33 мл на кг веса
  final raw = weightKg * 33.0 * multiplier;
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
