// Юнит-тесты чистой логики рецептов (recipe_nutrition.dart).

import 'package:app/core/database/database.dart';
import 'package:app/features/food/recipe_nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeIngredientsTableData _ing({
  required String id,
  required double grams,
  double? calories,
  double? protein,
  double? fat,
  double? carbs,
  double? sugar,
  double? fiber,
  int sortOrder = 0,
}) {
  return RecipeIngredientsTableData(
    id: id,
    recipeId: 'r1',
    name: 'ing-$id',
    grams: grams,
    calories: calories,
    protein: protein,
    fat: fat,
    carbs: carbs,
    sugar: sugar,
    fiber: fiber,
    sortOrder: sortOrder,
  );
}

void main() {
  test('recipeTotals суммирует масштабированные ингредиенты', () {
    // 200 г риса (130 ккал/100г) + 100 г курицы (165 ккал/100г, 31 белка)
    final totals = recipeTotals([
      _ing(id: 'a', grams: 200, calories: 130, protein: 2.7),
      _ing(id: 'b', grams: 100, calories: 165, protein: 31),
    ]);

    expect(totals.totalGrams, 300);
    expect(totals.total.calories, closeTo(130 * 2 + 165, 0.001)); // 425
    expect(totals.total.protein, closeTo(2.7 * 2 + 31, 0.001)); // 36.4
  });

  test('recipeTotals: null-поля трактуются как 0 в сумме', () {
    final totals = recipeTotals([
      _ing(id: 'a', grams: 100, calories: 100), // protein = null
      _ing(id: 'b', grams: 100, protein: 10), // calories = null
    ]);
    expect(totals.total.calories, 100);
    expect(totals.total.protein, 10);
  });

  test('recipeTotals пустого списка — нули', () {
    final totals = recipeTotals(const []);
    expect(totals.totalGrams, 0);
    expect(totals.total.calories, 0);
  });

  test('recipePer100g пересчитывает итог на 100 г готового блюда', () {
    // 425 ккал на 300 г → 141.67 на 100 г
    final per100 = recipePer100g(
      recipeTotals([
        _ing(id: 'a', grams: 200, calories: 130),
        _ing(id: 'b', grams: 100, calories: 165),
      ]).total,
      300,
    );
    expect(per100, isNotNull);
    expect(per100!.calories, closeTo(425 / 3, 0.01));
  });

  test('recipePer100g при нулевом весе — null', () {
    final totals = recipeTotals(const []);
    expect(recipePer100g(totals.total, totals.totalGrams), isNull);
  });
}
