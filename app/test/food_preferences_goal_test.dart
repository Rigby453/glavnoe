// Виджет-тест (правка 1): цель (lose/maintain/gain) НЕ редактируется в секции
// «Пищевые предпочтения». Дубль-UI убран — цель живёт только в «Параметрах тела»
// (my_data_screen). Здесь проверяем: ни в режиме редактирования, ни в просмотре
// нет элементов выбора/показа цели в food_preferences_section.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/profile/widgets/food_preferences_section.dart';
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
            body: SingleChildScrollView(child: FoodPreferencesSection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('режим редактирования: нет редактора цели', (tester) async {
    // Непустые предпочтения, чтобы был осмысленный просмотр + edit.
    SharedPreferences.setMockInitialValues({
      'food_diet': 'vegan',
      'food_goal': 'lose',
      'food_meals_per_day': 3,
    });
    prefs = await SharedPreferences.getInstance();

    await pump(tester);

    // Входим в режим редактирования.
    await tester.tap(find.text('Edit'));
    await tester.pump();

    // Никакого SegmentedButton (единственным был выбор цели).
    expect(find.byType(SegmentedButton<String>), findsNothing);
    // Метки вариантов цели не должны присутствовать как элементы выбора.
    expect(find.text('Lose weight'), findsNothing);
    expect(find.text('Maintain'), findsNothing);
    expect(find.text('Gain weight'), findsNothing);
    // При этом диета по-прежнему редактируется (sanity — секция жива).
    expect(find.text('Vegan'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('режим просмотра: строки «Цель» нет', (tester) async {
    SharedPreferences.setMockInitialValues({
      'food_diet': 'vegan',
      'food_goal': 'gain',
      'food_meals_per_day': 4,
    });
    prefs = await SharedPreferences.getInstance();

    await pump(tester);

    // Просмотр: строка-цель удалена (метка 'Goal' не выводится).
    expect(find.text('Goal'), findsNothing);
    expect(find.text('Gain weight'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
