// Юнит-тесты правил «Баланса рациона» (SPEC C5) — чистая логика, без I/O.

import 'package:app/features/food/food_balance.dart';
import 'package:app/features/food/food_nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Цели: 2000 ккал, 60 г белка → клетчатка ≥ 28 г (14 г/1000 ккал),
  // сахар < 50 г (10% от 2000 ккал / 4), жиры ≤ ~77.8 г (35% от 2000 / 9).
  const goalKcal = 2000;
  const goalProtein = 60;

  DayBalance eval(Nutrition n) =>
      evaluateDayBalance(n, calorieGoal: goalKcal, proteinGoalG: goalProtein);

  test('сбалансированный день — balanced, подсказок нет', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, fat: 60, carbs: 220, sugar: 30, fiber: 30,
    ));
    expect(b.balanced, isTrue);
    expect(b.hints, isEmpty);
  });

  test('производные цели считаются от калорийности', () {
    final b = eval(const Nutrition(calories: 2000));
    expect(b.fiberGoalG, 28.0); // max(25, 14*2000/1000)
    expect(b.sugarCapG, 50.0); // 10% * 2000 / 4
  });

  test('клетчатка ≥ 25 г даже при низкой цели калорий', () {
    final b = evaluateDayBalance(
      const Nutrition(calories: 1200),
      calorieGoal: 1200,
      proteinGoalG: goalProtein,
    );
    expect(b.fiberGoalG, 25.0); // max(25, 16.8)
  });

  test('недобор калорий → категория cal_low', () {
    final b = eval(const Nutrition(
      calories: 1200, protein: 80, fat: 40, sugar: 10, fiber: 30,
    ));
    expect(b.balanced, isFalse);
    expect(b.hints.single, 'cal_low');
  });

  test('перебор калорий → категория cal_high', () {
    final b = eval(const Nutrition(
      calories: 2500, protein: 80, fat: 60, sugar: 10, fiber: 30,
    ));
    expect(b.hints.single, 'cal_high');
  });

  test('мало белка → категория protein_low', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 30, fat: 60, sugar: 10, fiber: 30,
    ));
    expect(b.hints.single, 'protein_low');
  });

  test('мало клетчатки → категория fiber_low', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, fat: 60, sugar: 10, fiber: 5,
    ));
    expect(b.hints.single, 'fiber_low');
  });

  test('сахар выше потолка → категория sugar_high', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, fat: 60, sugar: 80, fiber: 30,
    ));
    expect(b.hints.single, 'sugar_high');
  });

  test('жиры выше потолка → категория fat_high', () {
    // fatCap = 0.35 * 2000 / 9 ≈ 77.78 г; 90 г > потолка.
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, fat: 90, sugar: 10, fiber: 30,
    ));
    expect(b.hints.single, 'fat_high');
  });

  test('жиры на уровне потолка не дают подсказку (консервативно)', () {
    // fat == fatCap → не должно срабатывать (строгое >).
    const fatCap = 0.35 * 2000 / 9;
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, fat: fatCap, sugar: 10, fiber: 30,
    ));
    expect(b.hints, isEmpty);
  });

  test('несколько проблем → несколько подсказок', () {
    final b = eval(const Nutrition(
      calories: 900, protein: 20, fat: 100, sugar: 90, fiber: 3,
    ));
    // cal_low, protein_low, fiber_low, sugar_high, fat_high
    expect(b.hints, hasLength(5));
    expect(
      b.hints,
      containsAll(
        <String>['cal_low', 'protein_low', 'fiber_low', 'sugar_high', 'fat_high'],
      ),
    );
  });

  group('resolveHintKey', () {
    test('детерминирован для одного сида', () {
      expect(resolveHintKey('protein_low', 7), resolveHintKey('protein_low', 7));
    });

    test('всегда возвращает ключ из реестра категории', () {
      for (final entry in kHintVariants.entries) {
        for (var seed = 0; seed < 12; seed++) {
          expect(entry.value, contains(resolveHintKey(entry.key, seed)));
        }
      }
    });

    test('варьируется между днями', () {
      final keys = <String>{
        for (var seed = 0; seed < 4; seed++) resolveHintKey('protein_low', seed),
      };
      expect(keys.length, greaterThan(1));
    });

    test('корректен при отрицательном сиде', () {
      final key = resolveHintKey('cal_low', -3);
      expect(kHintVariants['cal_low'], contains(key));
    });
  });

  group('resolveBalanceOkKey', () {
    test('детерминирован для одного сида', () {
      expect(resolveBalanceOkKey(5), resolveBalanceOkKey(5));
    });

    test('всегда возвращает ключ из реестра', () {
      for (var seed = 0; seed < 12; seed++) {
        expect(kBalanceOkVariants, contains(resolveBalanceOkKey(seed)));
      }
    });

    test('варьируется между днями', () {
      final keys = <String>{
        for (var seed = 0; seed < 3; seed++) resolveBalanceOkKey(seed),
      };
      expect(keys.length, greaterThan(1));
    });
  });
}
