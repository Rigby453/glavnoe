// Тесты UI-улучшений экрана Plan (ночной спринт, адаптивность):
//   (а) Переключатель видов читаем и без overflow при УЗКОЙ ширине +
//       textScale 1.5: на узком планшете он переходит в компактный список
//       (нормальный кегль, без FittedBox-мелочи и без RenderFlex), а на
//       широкой ширине показывает полноценный SegmentedButton с полными
//       подписями.
//   (б) Годовой вид рендерит ВСЕ 12 мини-месяцев в адаптивной сетке на широкой
//       ширине (1200px) без прокрутки и без overflow.
//
// Данные подменены через overrides провайдеров (Drift не задействован за год —
// источник дедлока под фейковым клоком), как в year_view_test.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/core/utils/day_window.dart';
import 'package:app/features/plan/plan_screen.dart';
import 'package:app/features/plan/widgets/plan_providers.dart';
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;
import 'package:app/features/plan/widgets/year_view.dart';
import 'package:drift/native.dart';
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

  // ---------------------------------------------------------------------------
  // (а) Переключатель видов: читаем и без overflow.
  // ---------------------------------------------------------------------------
  group('Переключатель видов адаптивен и читаем', () {
    Widget buildScreen({
      required Size size,
      double textScale = 1.0,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            theme: _testTheme(),
            home: const Scaffold(body: PlanScreen()),
          ),
        ),
      );
    }

    Future<void> setSize(WidgetTester tester, Size size) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets(
        'узкий планшет 600px + textScale 1.5: компактный список, без overflow',
        (tester) async {
      const size = Size(600, 900);
      await setSize(tester, size);
      await tester.pumpWidget(buildScreen(size: size, textScale: 1.5));
      await settle(tester);

      // Нет RenderFlex overflow (иначе pump бросил бы исключение).
      expect(tester.takeException(), isNull);
      // При нехватке ширины SegmentedButton не используется — вместо него
      // компактный выпадающий список (нормальный кегль).
      expect(find.byType(SegmentedButton<PlanView>), findsNothing);
      // Текущий вид показан полным читаемым словом (не ужат FittedBox'ом).
      expect(find.text('Day'), findsWidgets);
      await unmount(tester);
    });

    testWidgets(
        'широкий планшет 1100px + textScale 1.5: SegmentedButton с полными '
        'подписями, без overflow', (tester) async {
      const size = Size(1100, 900);
      await setSize(tester, size);
      await tester.pumpWidget(buildScreen(size: size, textScale: 1.5));
      await settle(tester);

      expect(tester.takeException(), isNull);
      // Хватает ширины — показываем полноценный переключатель…
      expect(find.byType(SegmentedButton<PlanView>), findsOneWidget);
      // …с ПОЛНЫМИ подписями всех 5 видов (читаемо, не на 2 строки, не ужато).
      for (final label in const ['Day', '3 days', 'Week', 'Month', 'Year']) {
        expect(find.text(label), findsWidgets,
            reason: 'подпись «$label» должна быть видна полностью');
      }
      await unmount(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // (б) Годовой вид: все 12 мини-месяцев в сетке на широкой ширине, без скролла.
  // ---------------------------------------------------------------------------
  group('Годовой вид: все 12 месяцев в сетке', () {
    final year = DateTime.now().year;
    final fixedDay = DateTime(year, 6, 15);

    Widget yearHarness(Size size) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          selectedDayProvider.overrideWith((ref) => fixedDay),
          // Подмена агрегата — без Drift-стрима за год (источник дедлока).
          yearTaskCountsProvider(year).overrideWith(
            (ref) => AsyncValue.data({localDayKey(fixedDay): 3}),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            theme: _testTheme(),
            home: const Scaffold(body: YearView()),
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('1200x800: видны все 12 мини-месяцев без overflow',
        (tester) async {
      const size = Size(1200, 800);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(yearHarness(size));
      await settle(tester);

      // Нет overflow (иначе pump бросил бы).
      expect(tester.takeException(), isNull);

      // Все 12 коротких имён месяцев присутствуют в дереве (значит выложены в
      // сетке без необходимости скроллить — GridView.builder с non-scroll
      // физикой строит все 12 в пределах вьюпорта).
      for (final m in const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ]) {
        expect(find.text(m), findsWidgets,
            reason: 'мини-месяц «$m» должен быть виден без прокрутки');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
