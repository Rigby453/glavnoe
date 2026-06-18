// Баланс рациона — правила из SPEC C5 (rule-based, без AI):
// день сбалансирован, если калории в коридоре цели; белок не ниже нормы;
// клетчатка ≥ цели (≥25 г или 14 г на 1000 ккал цели); сахар ниже потолка
// (ориентир ВОЗ: свободные сахара <10% калорий цели).
// Подсказки мягкие и конкретные, БЕЗ шейминга еды/тела (правило SPEC B6).
// Точные пороги финализирует нутрициолог — пока разумные дефолты.
// Чистая логика без I/O — юнит-тестируется.

import 'dart:math' as math;

import 'food_nutrition.dart';

/// Итог проверки дня.
class DayBalance {
  const DayBalance({
    required this.balanced,
    required this.hints,
    required this.fiberGoalG,
    required this.sugarCapG,
  });

  /// Все проверки пройдены.
  final bool balanced;

  /// Мягкие подсказки по непройденным проверкам (пусто, если balanced).
  final List<String> hints;

  /// Расчётная цель клетчатки (г) — для отображения.
  final double fiberGoalG;

  /// Расчётный потолок сахара (г) — для отображения.
  final double sugarCapG;
}

/// Коридор калорий: [нижняя, верхняя] доля от цели.
const _calLow = 0.85;
const _calHigh = 1.10;

/// Оценивает съеденное за день против целей пользователя.
///
/// [totals] — сумма за день (sumNutrition: null уже сведены к 0).
/// [calorieGoal] — дневная цель калорий; [proteinGoalG] — цель белка, г.
DayBalance evaluateDayBalance(
  Nutrition totals, {
  required int calorieGoal,
  required int proteinGoalG,
}) {
  final calories = totals.calories ?? 0;
  final protein = totals.protein ?? 0;
  final fiber = totals.fiber ?? 0;
  final sugar = totals.sugar ?? 0;

  // Клетчатка: ≥25 г/день или 14 г на 1000 ккал цели — берём большее.
  final fiberGoal = math.max(25.0, 14.0 * calorieGoal / 1000.0);
  // Сахар: свободные сахара <10% калорий цели; 1 г сахара = 4 ккал.
  final sugarCap = 0.10 * calorieGoal / 4.0;

  final hints = <String>[];

  if (calories < calorieGoal * _calLow) {
    hints.add('food.hint_cal_low');
  } else if (calories > calorieGoal * _calHigh) {
    hints.add('food.hint_cal_high');
  }

  if (protein < proteinGoalG) {
    hints.add('food.hint_protein_low');
  }

  if (fiber < fiberGoal) {
    hints.add('food.hint_fiber_low');
  }

  if (sugar > sugarCap) {
    hints.add('food.hint_sugar_high');
  }

  return DayBalance(
    balanced: hints.isEmpty,
    hints: hints,
    fiberGoalG: fiberGoal,
    sugarCapG: sugarCap,
  );
}
