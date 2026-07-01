// Тест: Health screen корректно отображает тематические группы
// (Nutrition / Sleep / Mind / Movement) без overflow, и корректно скрывает
// отключённые опциональные модули (#17 — disabled modules must not appear as
// a toggle-card in Health; they're hidden entirely and switch ONLY in
// Profile → Behavior).
//
// Проверяем:
//   1. Default (все флаги=false): только Sleep всегда виден (Water — теперь
//      опциональный модуль, как Food/Workouts/Meditation/Breathing, решение
//      владельца); Nutrition/Mind/Movement ПОЛНОСТЬЮ скрыты (все их модули
//      выключены); нет ни одной карточки/Switch для Water/Food/Meditation/
//      Breathing/Workouts.
//   2. Все флаги=true (включая Water): все 4 секции видны, опциональные
//      модули — nav-карточки (caretRight) БЕЗ инлайн-Switch (тумблер живёт
//      только в Profile → Behavior); карточка воды — не nav-tile, у неё
//      остаётся собственный инлайн-Switch (напоминания).
//   3. Нет RenderFlex overflow ни на 320x2500px, ни при textScale 1.5 на 360x2500px
//      (в обоих состояниях флагов).
//
// Примечание о высоте: ListView lazy-строит только видимые элементы.
// Используем высоту 2500px, чтобы все элементы были в дереве. Ширина 320px
// тестирует горизонтальный overflow (основной риск) — вертикальный scroll не ошибка.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/settings/feature_modes_provider.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/health/health_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — минимальная, содержит FocusThemeExtension
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Вспомогательные константы
// ---------------------------------------------------------------------------

/// 320px ширина (узкий телефон) + большая высота, чтобы все ListView-элементы
/// попали в дерево (ListView lazy-билдит только видимые). Overflow-тест — по ширине.
const Size _narrowTallSize = Size(320, 2500);

/// Обычная ширина + большая высота + крупный текст (1.5x а11y).
const Size _normalTallSize = Size(360, 2500);

const double _largeTextScale = 1.5;

// ---------------------------------------------------------------------------
// Вспомогательный harness
// ---------------------------------------------------------------------------

Widget _buildHarness(
  AppDatabase db,
  SharedPreferences prefs,
  Widget screen, {
  double textScale = 1.0,
  Size size = _narrowTallSize,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        size: size,
      ),
      child: MaterialApp(
        theme: _testTheme(),
        // Без GoRouter — навигация не тестируется, только рендер
        home: Scaffold(body: screen),
      ),
    ),
  );
}

/// Прокачивает виджет и ждёт Drift-стримы.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  group('HealthScreen — taxonomy grouping', () {
    testWidgets(
        '320px width, default (все модули выключены): только Sleep виден, '
        'Nutrition/Mind/Movement скрыты целиком, нет overflow', (tester) async {
      // Высота 2500px чтобы все lazy-ListView элементы попали в дерево;
      // ширина 320px для проверки горизонтального overflow.
      await _setSize(tester, _narrowTallSize);
      await tester.pumpWidget(
        _buildHarness(db, prefs, const HealthScreen()),
      );
      await _settle(tester);

      // Sleep — единственный всегда видимый модуль.
      expect(find.text('Sleep'), findsWidgets);
      // Nutrition держит ТОЛЬКО Water+Food — оба выключены (Water теперь
      // опциональна, решение владельца) → секция не рендерится вообще.
      expect(find.text('Nutrition'), findsNothing);
      // Mind/Movement держат ТОЛЬКО опциональные модули — оба выключены →
      // секции (и их заголовки) #17 не рендерятся вообще.
      expect(find.text('Mind'), findsNothing);
      expect(find.text('Movement'), findsNothing);

      // Нет исключений (overflow и др.)
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });

    testWidgets(
        'default (все модули выключены): нет ни одной карточки/Switch для '
        'Water/Food/Meditation/Breathing/Workouts (#17)', (tester) async {
      await _setSize(tester, _narrowTallSize);
      await tester.pumpWidget(
        _buildHarness(db, prefs, const HealthScreen()),
      );
      await _settle(tester);

      // Заголовки опциональных модулей не должны встречаться нигде на экране.
      expect(find.text('Food'), findsNothing);
      expect(find.text('Meditation'), findsNothing);
      expect(find.text('Breathing'), findsNothing);
      expect(find.text('Workouts'), findsNothing);

      // Water выключена по умолчанию — её карточка (и её инлайн-Switch
      // напоминаний) вообще не рендерится → на экране нет ни одного Switch.
      final switchWidgets =
          find.byWidgetPredicate((w) => w is Switch || w is CupertinoSwitch);
      expect(switchWidgets, findsNothing);

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets(
        'все модули включены (включая Water): все 4 секции видны, опциональные '
        'модули — nav-карточки БЕЗ инлайн-Switch (тумблер только в Profile → '
        'Behavior); у карточки воды остаётся свой Switch напоминаний',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        kWaterModeKey: true,
        kNutritionModeKey: true,
        kWorkoutModeKey: true,
        kMeditationLibraryModeKey: true,
        kBreathingEditorModeKey: true,
      });
      prefs = await SharedPreferences.getInstance();

      await _setSize(tester, _narrowTallSize);
      await tester.pumpWidget(
        _buildHarness(db, prefs, const HealthScreen()),
      );
      await _settle(tester);

      expect(find.text('Nutrition'), findsWidgets);
      expect(find.text('Sleep'), findsWidgets);
      expect(find.text('Mind'), findsWidgets);
      expect(find.text('Movement'), findsWidgets);

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Breathing'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);

      // Только water reminders Switch — модульные nav-карточки не имеют
      // инлайн-тумблера (#17): включаются только в Profile → Behavior.
      final switchWidgets =
          find.byWidgetPredicate((w) => w is Switch || w is CupertinoSwitch);
      expect(switchWidgets, findsOneWidget);

      // Вместо тумблера — caretRight (nav-карточка), по одной на модуль.
      final caretIcons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.caretRight(),
      );
      expect(caretIcons, findsAtLeast(4));

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets(
        'все модули включены (включая Water), textScale 1.5: все 4 секции '
        'видны, нет overflow',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        kWaterModeKey: true,
        kNutritionModeKey: true,
        kWorkoutModeKey: true,
        kMeditationLibraryModeKey: true,
        kBreathingEditorModeKey: true,
      });
      prefs = await SharedPreferences.getInstance();

      await _setSize(tester, _normalTallSize);
      await tester.pumpWidget(
        _buildHarness(
          db,
          prefs,
          const HealthScreen(),
          textScale: _largeTextScale,
          size: _normalTallSize,
        ),
      );
      await _settle(tester);

      expect(find.text('Nutrition'), findsWidgets);
      expect(find.text('Sleep'), findsWidgets);
      expect(find.text('Mind'), findsWidgets);
      expect(find.text('Movement'), findsWidgets);

      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });
  });
}
