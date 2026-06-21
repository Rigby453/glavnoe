// Юнит-тесты чистой логики AI-меню (ai_menu.dart): кандидаты, разбор ответа,
// пересчёт чисел кодом.

import 'package:app/core/database/database.dart';
import 'package:app/features/food/ai_menu.dart';
import 'package:app/features/food/ai_menu_sheet.dart';
import 'package:app/features/food/food_nutrition.dart';
import 'package:app/features/food/whole_food_staples.dart';
import 'package:flutter_test/flutter_test.dart';

FoodLogsTableData _log({
  required String id,
  required String name,
  required double grams,
  double? calories,
  double? protein,
}) {
  return FoodLogsTableData(
    id: id,
    date: DateTime.utc(2026, 6, 10),
    meal: 'lunch',
    name: name,
    grams: grams,
    calories: calories,
    protein: protein,
    fat: null,
    carbs: null,
    sugar: null,
    fiber: null,
    createdAt: DateTime(2026, 6, 10, 13),
  );
}

void main() {
  test('per100gFromLog выводит «на 100 г» из абсолютной порции', () {
    // 200 г → 300 ккал ⇒ 150 ккал / 100 г
    final per = per100gFromLog(
      _log(id: 'a', name: 'Rice', grams: 200, calories: 300, protein: 6),
    );
    expect(per, isNotNull);
    expect(per!.calories, closeTo(150, 0.001));
    expect(per.protein, closeTo(3, 0.001));
  });

  test('per100gFromLog без калорий или с нулевыми граммами — null', () {
    expect(per100gFromLog(_log(id: 'a', name: 'X', grams: 0, calories: 100)),
        isNull);
    expect(per100gFromLog(_log(id: 'b', name: 'Y', grams: 100)), isNull);
  });

  test('buildMenuCandidates: рецепты первыми, дедуп по имени без регистра', () {
    final candidates = buildMenuCandidates(
      recipes: [
        (name: 'Fried rice', per100g: const Nutrition(calories: 140)),
      ],
      recentLogs: [
        _log(id: '1', name: 'fried RICE', grams: 100, calories: 200),
        _log(id: '2', name: 'Greek salad', grams: 100, calories: 101),
      ],
    );
    // Первыми идут продукты пользователя (рецепт + лог), затем «основы».
    expect(candidates[0].name, 'Fried rice'); // рецепт, не лог
    expect(candidates[0].per100g.calories, 140);
    expect(candidates[1].name, 'Greek salad');
  });

  test('buildMenuCandidates: мерджит цельные продукты (основы) в кандидаты', () {
    final candidates = buildMenuCandidates(recipes: [], recentLogs: []);
    // Без продуктов пользователя список = только основы.
    expect(candidates, hasLength(kWholeFoodStaples.length));
    final names = candidates.map((c) => c.name).toList();
    expect(names, contains('Chicken breast'));
    expect(names, contains('Eggs'));
    expect(names, contains('Olive oil'));
  });

  test('buildMenuCandidates: продукт пользователя побеждает основу при совпадении имени', () {
    // У пользователя есть свой «Eggs» с другими числами — он должен победить.
    final candidates = buildMenuCandidates(
      recipes: [
        (name: 'eggs', per100g: const Nutrition(calories: 999, protein: 99)),
      ],
      recentLogs: [],
    );
    final eggs = candidates.where(
      (c) => c.name.toLowerCase() == 'eggs',
    );
    // Ровно один кандидат «eggs» (дедуп), и это запись пользователя.
    expect(eggs, hasLength(1));
    expect(eggs.single.per100g.calories, 999);
    // Длина: основы минус 1 (Eggs заменён) + 1 пользовательский = len основ.
    expect(candidates, hasLength(kWholeFoodStaples.length));
  });

  test('parseMenuResponse читает off_target и note', () {
    final candidates = [
      const MenuCandidate(
        name: 'Oatmeal',
        per100g: Nutrition(calories: 380, protein: 13),
      ),
    ];
    final response = {
      'meals': [
        {
          'meal': 'breakfast',
          'items': [
            {'name': 'Oatmeal', 'grams': 60},
          ],
        },
      ],
      'note': 'careful',
      'off_target': true,
      'totals': {'calories': 228, 'protein': 7.8},
    };
    final parsed = parseMenuResponse(response, candidates);
    expect(parsed.offTarget, isTrue);
    expect(parsed.note, 'careful');
    expect(parsed.meals, hasLength(1));
  });

  test('parseMenuResponse: off_target по умолчанию false когда поле отсутствует', () {
    final candidates = [
      const MenuCandidate(name: 'Oatmeal', per100g: Nutrition(calories: 380)),
    ];
    final parsed = parseMenuResponse({
      'meals': [
        {
          'meal': 'breakfast',
          'items': [
            {'name': 'Oatmeal', 'grams': 60},
          ],
        },
      ],
      'note': 'ok',
    }, candidates);
    expect(parsed.offTarget, isFalse);
  });

  test('mealsForCount строит массив приёмов нужной длины', () {
    expect(mealsForCount(3), ['breakfast', 'lunch', 'dinner']);
    expect(mealsForCount(1), ['breakfast']);
    expect(mealsForCount(4), ['breakfast', 'lunch', 'dinner', 'snack']);
    expect(mealsForCount(5),
        ['breakfast', 'lunch', 'dinner', 'snack', 'snack2']);
    // Уникальность ключей (важно для группировки по слотам в UI).
    final five = mealsForCount(5);
    expect(five.toSet(), hasLength(five.length));
    // Зажим в [1,6].
    expect(mealsForCount(0), ['breakfast']);
    expect(mealsForCount(99), hasLength(6));
  });

  test('parseProposedMenu отбрасывает чужие позиции и считает числа кодом', () {
    final candidates = [
      const MenuCandidate(
        name: 'Oatmeal',
        per100g: Nutrition(calories: 380, protein: 13),
      ),
    ];
    final meals = parseProposedMenu({
      'meals': [
        {
          'meal': 'breakfast',
          'items': [
            {'name': 'Oatmeal', 'grams': 60},
            {'name': 'Hallucinated cake', 'grams': 100}, // не из кандидатов
          ],
        },
        {
          'meal': 'lunch',
          'items': [
            {'name': 'Hallucinated cake', 'grams': 100},
          ],
        },
      ],
      'note': 'ok',
    }, candidates);

    expect(meals, hasLength(1)); // lunch выпал целиком
    expect(meals.single.meal, 'breakfast');
    final item = meals.single.items.single;
    expect(item.name, 'Oatmeal');
    expect(item.nutrition.calories, closeTo(380 * 0.6, 0.001));

    final total = proposedMenuTotal(meals);
    expect(total.calories, closeTo(228, 0.001));
    expect(total.protein, closeTo(7.8, 0.001));
  });
}
