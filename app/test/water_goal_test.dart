// Юнит-тесты для recommendedWaterMl (water_goal_provider.dart).
// Формула: weightKg × 30 × multiplier, округление до 100, clamp(1500, 3000).

import 'package:app/core/settings/water_goal_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recommendedWaterMl', () {
    // Базовый кейс: средний вес, medium активность
    // 70 × 30 × 1.0 = 2100 → округление до 100 → 2100
    test('medium activity: 70 kg → 2100 ml', () {
      expect(
        recommendedWaterMl(weightKg: 70, activity: 'medium'),
        2100,
      );
    });

    // Low активность: множитель 0.9
    // 60 × 30 × 0.9 = 1620 → округление до 100 → 1600
    test('low activity: 60 kg → 1600 ml', () {
      expect(
        recommendedWaterMl(weightKg: 60, activity: 'low'),
        1600,
      );
    });

    // High активность: множитель 1.15
    // 80 × 30 × 1.15 = 2760 → округление до 100 → 2800
    test('high activity: 80 kg → 2800 ml', () {
      expect(
        recommendedWaterMl(weightKg: 80, activity: 'high'),
        2800,
      );
    });

    // Clamp снизу: очень маленький вес → не меньше 1500
    // 20 × 30 × 0.9 = 540 → округление до 100 → 500 → clamp → 1500
    test('clamp minimum: very low weight → 1500 ml', () {
      expect(
        recommendedWaterMl(weightKg: 20, activity: 'low'),
        1500,
      );
    });

    // Clamp сверху: очень большой вес → не больше 3000
    // 150 × 30 × 1.15 = 5175 → округление → 5200 → clamp → 3000
    test('clamp maximum: very high weight → 3000 ml', () {
      expect(
        recommendedWaterMl(weightKg: 150, activity: 'high'),
        3000,
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
