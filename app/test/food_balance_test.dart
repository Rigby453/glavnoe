// Юнит-тесты правил «Баланса рациона» (SPEC C5) — чистая логика, без I/O.

import 'package:app/features/food/food_balance.dart';
import 'package:app/features/food/food_nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Цели: 2000 ккал, 60 г белка → клетчатка ≥ 28 г (14 г/1000 ккал),
  // сахар < 50 г (10% от 2000 ккал / 4).
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

  test('недобор калорий → мягкая подсказка про приём пищи', () {
    final b = eval(const Nutrition(
      calories: 1200, protein: 80, sugar: 10, fiber: 30,
    ));
    expect(b.balanced, isFalse);
    expect(b.hints.single, 'food.hint_cal_low');
  });

  test('перебор калорий → подсказка без шейминга', () {
    final b = eval(const Nutrition(
      calories: 2500, protein: 80, sugar: 10, fiber: 30,
    ));
    expect(b.hints.single, 'food.hint_cal_high');
  });

  test('мало белка → подсказка про белок', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 30, sugar: 10, fiber: 30,
    ));
    expect(b.hints.single, 'food.hint_protein_low');
  });

  test('мало клетчатки → подсказка про овощи/злаки', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, sugar: 10, fiber: 5,
    ));
    expect(b.hints.single, 'food.hint_fiber_low');
  });

  test('сахар выше потолка → подсказка про сладкое', () {
    final b = eval(const Nutrition(
      calories: 2000, protein: 80, sugar: 80, fiber: 30,
    ));
    expect(b.hints.single, 'food.hint_sugar_high');
  });

  test('несколько проблем → несколько подсказок', () {
    final b = eval(const Nutrition(
      calories: 900, protein: 20, sugar: 90, fiber: 3,
    ));
    expect(b.hints, hasLength(4));
  });
}
