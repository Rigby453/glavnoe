// Юнит-тесты для recommendedWaterMl (water_goal_provider.dart).
// Формула: weightKg × 33 × multiplier, округление до 100, clamp(1500, 4000).

import 'package:app/core/settings/water_goal_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recommendedWaterMl', () {
    // Базовый кейс: средний вес, medium активность
    // 70 × 33 × 1.0 = 2310 → округление до 100 → 2300
    test('medium activity: 70 kg → 2300 ml', () {
      expect(
        recommendedWaterMl(weightKg: 70, activity: 'medium'),
        2300,
      );
    });

    // Low активность: множитель 0.9
    // 60 × 33 × 0.9 = 1782 → округление до 100 → 1800
    test('low activity: 60 kg → 1800 ml', () {
      expect(
        recommendedWaterMl(weightKg: 60, activity: 'low'),
        1800,
      );
    });

    // High активность: множитель 1.15
    // 80 × 33 × 1.15 = 3036 → округление до 100 → 3000
    test('high activity: 80 kg → 3000 ml', () {
      expect(
        recommendedWaterMl(weightKg: 80, activity: 'high'),
        3000,
      );
    });

    // Clamp снизу: очень маленький вес → не меньше 1500
    // 20 × 33 × 0.9 = 594 → округление до 100 → 600 → clamp → 1500
    test('clamp minimum: very low weight → 1500 ml', () {
      expect(
        recommendedWaterMl(weightKg: 20, activity: 'low'),
        1500,
      );
    });

    // Clamp сверху: очень большой вес → не больше 4000
    // 150 × 33 × 1.15 = 5692.5 → округление → 5700 → clamp → 4000
    test('clamp maximum: very high weight → 4000 ml', () {
      expect(
        recommendedWaterMl(weightKg: 150, activity: 'high'),
        4000,
      );
    });

    // Неизвестное значение активности трактуется как medium (×1.0)
    test('unknown activity falls back to medium multiplier', () {
      expect(
        recommendedWaterMl(weightKg: 70, activity: 'extreme'),
        recommendedWaterMl(weightKg: 70, activity: 'medium'),
      );
    });
  });
}
