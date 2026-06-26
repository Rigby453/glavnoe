// Виджет-тест: на экране «Мои данные» норма КБЖУ (калории/макросы) обновляется
// ВЖИВУЮ при изменении антропометрии — без нажатия «Сохранить» — в режиме
// авто-расчёта (override макросов выключен). Регрессионный тест бага, когда
// live пересчитывалась только норма воды, а КБЖУ показывало старые значения.

import 'package:app/core/settings/macro_override_provider.dart';
import 'package:app/core/settings/nutrition_targets.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/profile/my_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ThemeData _testTheme() {
  return ThemeData.dark().copyWith(
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: _testTheme(),
          home: const MyDataScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'КБЖУ-превью обновляется вживую при изменении веса (авто-расчёт)',
    (tester) async {
      // Полная антропометрия, override макросов выключен → авто-расчёт.
      SharedPreferences.setMockInitialValues({
        'user_weight_kg': 70.0,
        'user_height_cm': 175,
        'user_age': 25,
        'user_sex': 'male',
        'user_activity': 'medium',
        'food_goal': 'maintain',
        kMacroOverrideEnabledKey: false,
      });
      prefs = await SharedPreferences.getInstance();

      final before = computeNutritionTargets(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        sex: 'male',
        activity: 'medium',
        goal: 'maintain',
      );
      final after = computeNutritionTargets(
        weightKg: 90,
        heightCm: 175,
        age: 25,
        sex: 'male',
        activity: 'medium',
        goal: 'maintain',
      );
      // Санити: значения kcal действительно различаются (иначе тест бессмысленен).
      expect(before.kcal, isNot(after.kcal));

      await pumpScreen(tester);

      // Изначально показана норма для 70 кг.
      expect(find.textContaining('${before.kcal}'), findsWidgets);

      // Меняем вес 70 → 90 БЕЗ нажатия «Сохранить».
      final weightField = find.widgetWithText(TextField, '70');
      expect(weightField, findsOneWidget);
      await tester.enterText(weightField, '90');
      await tester.pump();

      // Норма пересчиталась вживую: новое значение видно, старое исчезло.
      expect(find.textContaining('${after.kcal}'), findsWidgets);
      expect(find.textContaining('${before.kcal}'), findsNothing);
    },
  );

  testWidgets(
    'Режим override: КБЖУ НЕ меняется от антропометрии',
    (tester) async {
      // override включён (ручной режим) → калории = пользовательские цели,
      // изменение веса не должно их трогать.
      SharedPreferences.setMockInitialValues({
        'user_weight_kg': 70.0,
        'user_height_cm': 175,
        'user_age': 25,
        'user_sex': 'male',
        'user_activity': 'medium',
        'food_goal': 'maintain',
        kMacroOverrideEnabledKey: true,
        kMacroAutoBalanceKey: false,
        kMacroProteinGKey: 150,
        kMacroFatGKey: 60,
        kMacroCarbsGKey: 200,
      });
      prefs = await SharedPreferences.getInstance();

      // derivedKcal = 150*4 + 60*9 + 200*4 = 1940
      const overrideKcal = 1940;

      await pumpScreen(tester);
      expect(find.textContaining('$overrideKcal'), findsWidgets);

      // Меняем вес — override-калории остаются прежними.
      final weightField = find.widgetWithText(TextField, '70');
      await tester.enterText(weightField, '90');
      await tester.pump();

      expect(find.textContaining('$overrideKcal'), findsWidgets);
    },
  );
}
