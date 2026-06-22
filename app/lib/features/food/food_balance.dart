// Баланс рациона — правила из SPEC C5 (rule-based, без AI):
// день сбалансирован, если калории в коридоре цели; белок не ниже нормы;
// клетчатка ≥ цели (≥25 г или 14 г на 1000 ккал цели); сахар ниже потолка
// (ориентир ВОЗ: свободные сахара <10% калорий цели); жиры не выше ~35%
// калорий цели (1 г жира = 9 ккал).
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

  /// Короткие id категорий по непройденным проверкам (пусто, если balanced).
  /// Возможные значения: 'cal_low', 'cal_high', 'protein_low', 'fiber_low',
  /// 'sugar_high', 'fat_high'. Конкретный текст подсказки выбирается в UI.
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
  final fat = totals.fat ?? 0;
  final fiber = totals.fiber ?? 0;
  final sugar = totals.sugar ?? 0;

  // Клетчатка: ≥25 г/день или 14 г на 1000 ккал цели — берём большее.
  final fiberGoal = math.max(25.0, 14.0 * calorieGoal / 1000.0);
  // Сахар: свободные сахара <10% калорий цели; 1 г сахара = 4 ккал.
  final sugarCap = 0.10 * calorieGoal / 4.0;
  // Жиры: не выше ~35% калорий цели; 1 г жира = 9 ккал. Консервативно.
  final fatCap = 0.35 * calorieGoal / 9.0;

  final hints = <String>[];

  if (calories < calorieGoal * _calLow) {
    hints.add('cal_low');
  } else if (calories > calorieGoal * _calHigh) {
    hints.add('cal_high');
  }

  if (protein < proteinGoalG) {
    hints.add('protein_low');
  }

  if (fiber < fiberGoal) {
    hints.add('fiber_low');
  }

  if (sugar > sugarCap) {
    hints.add('sugar_high');
  }

  if (fat > fatCap) {
    hints.add('fat_high');
  }

  return DayBalance(
    balanced: hints.isEmpty,
    hints: hints,
    fiberGoalG: fiberGoal,
    sugarCapG: sugarCap,
  );
}

/// Реестр вариантов подсказок: id категории → список l10n-ключей (по 4 на
/// категорию). Разные формулировки одной и той же мысли, чтобы карточка не
/// выглядела шаблонной. Конкретный вариант выбирает [resolveHintKey].
const Map<String, List<String>> kHintVariants = {
  'cal_low': [
    'food.hint_cal_low_1',
    'food.hint_cal_low_2',
    'food.hint_cal_low_3',
    'food.hint_cal_low_4',
  ],
  'cal_high': [
    'food.hint_cal_high_1',
    'food.hint_cal_high_2',
    'food.hint_cal_high_3',
    'food.hint_cal_high_4',
  ],
  'protein_low': [
    'food.hint_protein_low_1',
    'food.hint_protein_low_2',
    'food.hint_protein_low_3',
    'food.hint_protein_low_4',
  ],
  'fiber_low': [
    'food.hint_fiber_low_1',
    'food.hint_fiber_low_2',
    'food.hint_fiber_low_3',
    'food.hint_fiber_low_4',
  ],
  'sugar_high': [
    'food.hint_sugar_high_1',
    'food.hint_sugar_high_2',
    'food.hint_sugar_high_3',
    'food.hint_sugar_high_4',
  ],
  'fat_high': [
    'food.hint_fat_high_1',
    'food.hint_fat_high_2',
    'food.hint_fat_high_3',
    'food.hint_fat_high_4',
  ],
};

/// Варианты позитивного сообщения «всё в норме» (3 формулировки).
const List<String> kBalanceOkVariants = [
  'food.balance_ok_1',
  'food.balance_ok_2',
  'food.balance_ok_3',
];

/// Детерминированно выбирает l10n-ключ подсказки для [category] по [daySeed].
/// Стабилен для одного сида (не «прыгает» при ребилде), меняется между днями.
String resolveHintKey(String category, int daySeed) {
  final list = kHintVariants[category]!;
  // Берём модуль положительного индекса: daySeed может быть любым int.
  final i = daySeed % list.length;
  return list[i < 0 ? i + list.length : i];
}

/// Детерминированно выбирает l10n-ключ позитивного сообщения по [daySeed].
String resolveBalanceOkKey(int daySeed) {
  final list = kBalanceOkVariants;
  final i = daySeed % list.length;
  return list[i < 0 ? i + list.length : i];
}
