// Чистая логика рецептов: итоги КБЖУ по ингредиентам и пересчёт «на 100 г».
// Числа берутся из снапшотов ингредиентов (на 100 г), масштабируются кодом —
// модель/сеть здесь не участвуют. Без I/O — легко тестируется.

import '../../core/database/database.dart';
import 'food_nutrition.dart';

/// Итог рецепта: суммарное КБЖУ и общий вес в граммах.
typedef RecipeTotals = ({Nutrition total, double totalGrams});

/// Суммирует ингредиенты рецепта: каждое значение «на 100 г» масштабируется
/// под граммы ингредиента, затем складывается (null трактуется как 0).
RecipeTotals recipeTotals(List<RecipeIngredientsTableData> ingredients) {
  final scaled = ingredients.map(
    (i) => scaleNutrition(
      Nutrition(
        calories: i.calories,
        protein: i.protein,
        fat: i.fat,
        carbs: i.carbs,
        sugar: i.sugar,
        fiber: i.fiber,
      ),
      i.grams,
    ),
  );
  final totalGrams =
      ingredients.fold<double>(0, (sum, i) => sum + i.grams);
  return (total: sumNutrition(scaled), totalGrams: totalGrams);
}

/// Пересчитывает итог рецепта в значения «на 100 г» готового блюда.
/// null, если общий вес нулевой (нечего пересчитывать).
Nutrition? recipePer100g(Nutrition total, double totalGrams) {
  if (totalGrams <= 0) return null;
  final k = 100.0 / totalGrams;
  double? mul(double? v) => v == null ? null : v * k;
  return Nutrition(
    calories: mul(total.calories),
    protein: mul(total.protein),
    fat: mul(total.fat),
    carbs: mul(total.carbs),
    sugar: mul(total.sugar),
    fiber: mul(total.fiber),
  );
}
