// Фокус-тест на баг с устройства: минимум приёмов пищи в день был 3,
// пользователь хочет минимум 1 (интервальное голодание/OMAD).
//
// Покрывает:
//  1. MealsPerDayPicker (UI) — минимальный пресет = 1, не 3; выбор "1" реально
//     вызывает onChanged(1) и делает чип выбранным.
//  2. FoodPreferences — 1 является валидным сохранённым значением (round-trip
//     через toApiMap/copyWith), никакого зажима на 3.
//  3. mealsForCount(1) — деление целей КБЖУ по приёмам корректно для 1 приёма
//     (без деления на константу 3, без падений).

import 'package:app/core/settings/food_preferences_provider.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/food/meal_slots.dart';
import 'package:app/features/profile/widgets/food_preferences_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _testTheme() => ThemeData.dark().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF9E9070),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFF3A3020),
          surfaceElevated: Color(0xFF2E2618),
          textFaint: Color(0xFF736850),
          accentMuted: Color(0xFF26290F),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFF524630),
        ),
      ],
    );

void main() {
  group('MealsPerDayPicker — минимум 1 (не 3)', () {
    testWidgets('пресеты начинаются с 1, чип "1" присутствует и выбираем',
        (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: _testTheme(),
          home: Scaffold(
            body: MealsPerDayPicker(
              value: 3,
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );
      await tester.pump();

      // Пресет "1" должен существовать как отдельный выбираемый чип —
      // это и есть регрессия бага (раньше минимум был 3).
      final chip1 = find.widgetWithText(ChoiceChip, '1');
      expect(chip1, findsOneWidget);

      await tester.tap(chip1);
      await tester.pump();

      expect(selected, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('value=1 отображается выбранным (не проваливается в "custom")',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: _testTheme(),
          home: Scaffold(
            body: MealsPerDayPicker(value: 1, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pump();

      final chip1 = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '1'),
      );
      expect(chip1.selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('пресеты 1..6 присутствуют (никакого нижнего зажима на 3)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: _testTheme(),
          home: Scaffold(
            body: MealsPerDayPicker(value: 3, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pump();

      for (final n in [1, 2, 3, 4, 5, 6]) {
        expect(find.widgetWithText(ChoiceChip, '$n'), findsOneWidget,
            reason: 'preset $n should exist');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('FoodPreferences — 1 приём — валидное значение без зажима', () {
    test('copyWith(mealsPerDay: 1) сохраняет 1, не откатывается на 3', () {
      const base = FoodPreferences();
      final withOne = base.copyWith(mealsPerDay: 1);
      expect(withOne.mealsPerDay, 1);
      // 1 != дефолт(3) → не isEmpty по этому полю.
      expect(withOne.isEmpty, isFalse);
    });

    test('toApiMap() отправляет meals_per_day=1 (отличается от дефолта 3)', () {
      const prefs = FoodPreferences(mealsPerDay: 1);
      final map = prefs.toApiMap();
      expect(map['meals_per_day'], 1);
    });
  });

  group('mealsForCount(1) — деление целей КБЖУ на 1 приём не падает', () {
    test('возвращает ровно 1 слот, без деления на константу 3', () {
      final slots = mealsForCount(1);
      expect(slots, ['breakfast']);
      expect(slots.length, 1);
    });

    test('распределение дневных целей по слотам работает при n=1', () {
      // Симулируем то, что делает вызывающий код: делит дневные цели по
      // числу слотов. При n=1 весь день должен уйти в единственный слот,
      // без ArithmeticException и без деления на захардкоженную 3.
      const dailyKcal = 2400;
      const dailyProteinG = 150;
      final slots = mealsForCount(1);

      final perSlotKcal = dailyKcal ~/ slots.length;
      final perSlotProtein = dailyProteinG ~/ slots.length;

      expect(slots.length, greaterThan(0)); // защита от деления на 0
      expect(perSlotKcal, dailyKcal); // весь день = один приём (OMAD)
      expect(perSlotProtein, dailyProteinG);
    });
  });
}
