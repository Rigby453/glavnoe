// Юнит-тесты для computeNutritionTargets и NutritionTargets.fallback.
// Чистая логика без I/O; Riverpod-провайдер тестируется отдельно
// (требует SharedPreferences-моков, пока не нужно).

import 'package:app/core/settings/nutrition_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // --- Тест 1: мужчина 70 кг / 175 см / 25 лет / medium-активность ---
  // BMR = 10*70 + 6.25*175 - 5*25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
  // TDEE = 1673.75 * 1.55 ≈ 2594.3 → round → 2594, clamp(1200,4000) → 2594
  // protein = round(1.6 * 70) = 112 г
  // fat = round(2594 * 0.25 / 9) = round(72.06) = 72 г
  // carbs = round((2594 - 112*4 - 72*9) / 4) = round((2594 - 448 - 648) / 4)
  //       = round(1498 / 4) = round(374.5) = 375 (или близко)
  // fiber = round(14 * 2594 / 1000) = round(36.3) = 36 г
  // sugarMax = round(2594 * 0.10 / 4) = round(64.85) = 65 г
  group('male 70kg/175cm/25/medium', () {
    late NutritionTargets t;

    setUpAll(() {
      t = computeNutritionTargets(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        sex: 'male',
        activity: 'medium',
      );
    });

    test('kcal в ожидаемом диапазоне', () {
      expect(t.kcal, inInclusiveRange(2500, 2700));
    });

    test('protein ≈ 1.6 × 70 = 112 г', () {
      expect(t.proteinG, 112);
    });

    test('fat > 0 и в разумном диапазоне', () {
      expect(t.fatG, greaterThan(50));
      expect(t.fatG, lessThan(100));
    });

    test('carbs > 0', () {
      expect(t.carbsG, greaterThan(0));
    });

    test('fiber ≈ 14 г/1000 ккал', () {
      final expected = (14.0 * t.kcal / 1000).round();
      expect(t.fiberG, expected);
    });

    test('sugarMax ≈ 10% ккал / 4', () {
      final expected = (t.kcal * 0.10 / 4).round();
      expect(t.sugarMaxG, expected);
    });
  });

  // --- Тест 2: женщина 60 кг / 165 см / 30 лет / high-активность ---
  // BMR = 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
  // TDEE = 1320.25 * 1.725 ≈ 2277.4 → 2277
  group('female 60kg/165cm/30/high', () {
    late NutritionTargets t;

    setUpAll(() {
      t = computeNutritionTargets(
        weightKg: 60,
        heightCm: 165,
        age: 30,
        sex: 'female',
        activity: 'high',
      );
    });

    test('kcal в ожидаемом диапазоне', () {
      expect(t.kcal, inInclusiveRange(2100, 2400));
    });

    test('protein = round(1.6 * 60) = 96 г', () {
      expect(t.proteinG, 96);
    });

    test('carbs > 0', () {
      expect(t.carbsG, greaterThan(0));
    });
  });

  // --- Тест 3: пол 'other' --- среднее смещение -78 ---
  test('sex=other использует смещение -78', () {
    final other = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'other',
      activity: 'medium',
    );
    final male = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'medium',
    );
    final female = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'female',
      activity: 'medium',
    );
    // other ккал должны быть между female и male
    expect(other.kcal, lessThan(male.kcal));
    expect(other.kcal, greaterThan(female.kcal));
  });

  // --- Тест 4: clamp снизу (очень низкий BMR → min 1200) ---
  test('clamp kcal снизу: минимум 1200', () {
    final t = computeNutritionTargets(
      weightKg: 40,
      heightCm: 145,
      age: 80,
      sex: 'female',
      activity: 'low',
    );
    expect(t.kcal, greaterThanOrEqualTo(1200));
  });

  // --- Тест 5: clamp сверху (очень высокий BMR → max 4000) ---
  test('clamp kcal сверху: максимум 4000', () {
    final t = computeNutritionTargets(
      weightKg: 150,
      heightCm: 210,
      age: 20,
      sex: 'male',
      activity: 'high',
    );
    expect(t.kcal, lessThanOrEqualTo(4000));
  });

  // --- Тест 6: fallback имеет разумные значения ---
  test('NutritionTargets.fallback содержит ожидаемые дефолты', () {
    const f = NutritionTargets.fallback;
    expect(f.kcal, kDefaultNutritionKcal);
    expect(f.proteinG, kDefaultNutritionProteinG);
    expect(f.fatG, kDefaultNutritionFatG);
    expect(f.carbsG, kDefaultNutritionCarbsG);
    expect(f.fiberG, kDefaultNutritionFiberG);
    expect(f.sugarMaxG, kDefaultNutritionSugarMaxG);
  });

  // --- Тест 7: активность low / medium / high дают разные ккал ---
  test('activity влияет на kcal (low < medium < high)', () {
    NutritionTargets build(String act) => computeNutritionTargets(
          weightKg: 70,
          heightCm: 175,
          age: 25,
          sex: 'male',
          activity: act,
        );
    final low = build('low');
    final medium = build('medium');
    final high = build('high');
    expect(low.kcal, lessThan(medium.kcal));
    expect(medium.kcal, lessThan(high.kcal));
  });

  // --- Тест 8: неизвестная активность трактуется как medium ---
  test('неизвестная activity трактуется как medium', () {
    final unknown = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'extreme',
    );
    final medium = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'medium',
    );
    expect(unknown.kcal, medium.kcal);
  });
}
