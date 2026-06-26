// Виджет-тест (правка 2): тумблер «Авто-баланс калорий» показывается ТОЛЬКО
// когда включены «свои цели» (macroOverrideProvider.enabled == true). В обычном
// режиме (override выключен — read-only расчётные нормы + кнопка «Задать свои
// цели») тумблера быть не должно.

import 'package:app/core/settings/macro_override_provider.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/profile/widgets/macro_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: _testTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: MacroEditor()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('override ВЫКЛ → тумблера авто-баланса нет', (tester) async {
    SharedPreferences.setMockInitialValues({
      kMacroOverrideEnabledKey: false,
      'user_weight_kg': 70.0,
      'user_height_cm': 175,
      'user_age': 25,
      'user_sex': 'male',
      'user_activity': 'medium',
      'food_goal': 'maintain',
    });
    prefs = await SharedPreferences.getInstance();

    await pump(tester);

    expect(find.text('Auto-balance calories'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    // Вместо тумблера — кнопка «Задать свои цели».
    expect(find.text('Set my own targets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('override ВКЛ → тумблер авто-баланса виден', (tester) async {
    SharedPreferences.setMockInitialValues({
      kMacroOverrideEnabledKey: true,
      kMacroAutoBalanceKey: true,
      kMacroKcalTargetKey: 2000,
      kMacroProteinGKey: 150,
      kMacroFatGKey: 60,
      kMacroCarbsGKey: 200,
    });
    prefs = await SharedPreferences.getInstance();

    await pump(tester);

    expect(find.text('Auto-balance calories'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
