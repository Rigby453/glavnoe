// Антирегрессионные тесты для двух layout-багов раздела Plan:
//
// (а) Переключатель промежутка (SegmentedButton / ViewDropdown) — не должен
//     давать overflow на ширине 320px + textScaleFactor 2.0.
//     На 320px используется мобильная раскладка (_ViewDropdown — выпадающий список),
//     которая должна без проблем влезать в один ряд на любом масштабе.
//
// (б) Пустой день при 6-рядном раскрытом месяце — не должен давать
//     «BOTTOM OVERFLOWED BY N PIXELS».
//     ExpandableWeekCalendar при 6 строках занимает ~410px; остаток для DayTimeline
//     может быть < 200px. _EmptyState.build теперь использует
//     LayoutBuilder + SingleChildScrollView + ConstrainedBox, поэтому прокручивается
//     вместо переполнения.
//
// Паттерн тестов: in-memory Drift + setSize + runAsync (как в plan_adaptive_views_test).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/plan/plan_screen.dart';
import 'package:app/features/plan/widgets/day_timeline.dart'
    show DayTimeline, dayItemsProvider;
import 'package:app/features/plan/widgets/plan_providers.dart' show PlanView;
import 'package:app/features/plan/widgets/week_strip.dart' show selectedDayProvider;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Тема, идентичная используемой в plan_adaptive_views_test.
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

/// Полный PlanScreen в тестовом окружении с in-memory Drift.
Widget _planScreenHarness({
  required Size size,
  required AppDatabase db,
  required SharedPreferences prefs,
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

/// Settle для полного PlanScreen с асинхронными Riverpod-провайдерами.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Размонтировать дерево без ошибок таймеров/анимаций.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

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
  // (а) Переключатель промежутка: 320px + textScale 2.0 — без overflow.
  // ---------------------------------------------------------------------------
  group('(а) Переключатель промежутка без overflow', () {
    testWidgets(
        '320px mobile + textScale 2.0: мобильная раскладка (_ViewDropdown) '
        'рендерится без RenderFlex overflow', (tester) async {
      const size = Size(320, 640);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _planScreenHarness(
          size: size,
          db: db,
          prefs: prefs,
          textScale: 2.0,
        ),
      );
      await _settle(tester);

      // На 320px isTablet=false → используется _ViewDropdown, не SegmentedButton.
      // Никакого RenderFlex overflow.
      expect(tester.takeException(), isNull);
      expect(find.byType(SegmentedButton<PlanView>), findsNothing);

      await _unmount(tester);
    });

    testWidgets(
        '320px mobile + textScale 1.5: та же проверка на textScale 1.5',
        (tester) async {
      const size = Size(320, 640);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _planScreenHarness(
          size: size,
          db: db,
          prefs: prefs,
          textScale: 1.5,
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // (б) 6-рядный месяц + пустой день: DayTimeline не переполняется.
  // ---------------------------------------------------------------------------
  group('(б) Пустой день при 6-рядном месяце — нет overflow', () {
    // Март 2026: 1 марта = воскресенье (leadingBlanks=6), 31 день.
    // rows = ceil((6+31)/7) = ceil(5.28) = 6. Это 6-рядный месяц.
    final sixRowDay = DateTime(2026, 3, 15);

    Widget emptyDayHarness({required Size size, double textScale = 1.0}) {
      return ProviderScope(
        overrides: [
          // Пустой день → DayTimeline показывает _EmptyState.
          dayItemsProvider.overrideWith(
              (ref, _) => const AsyncValue.data(<ItemsTableData>[])),
          selectedDayProvider.overrideWith((ref) => sixRowDay),
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
            home: Scaffold(
              body: Column(
                children: [
                  // Симуляция полностью раскрытого ExpandableWeekCalendar
                  // при 6 строках: header(32) + labels(18) + grid(336) + grabber(24) = 410px.
                  const SizedBox(height: 410),
                  // DayTimeline получает оставшиеся ~140-200px в зависимости от экрана.
                  const Expanded(child: DayTimeline()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
        'высота экрана 550px: DayTimeline _EmptyState прокручивается, '
        'не переполняется', (tester) async {
      // 550 - 410 = 140px для DayTimeline — тесное пространство.
      // Без SingleChildScrollView это давало overflow ~60px.
      const size = Size(360, 550);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(emptyDayHarness(size: size));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      // Никакого RenderFlex overflow.
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });

    testWidgets(
        'высота экрана 650px + textScale 2.0: крупный текст в _EmptyState '
        'не переполняется', (tester) async {
      // При textScale 2.0 контент _EmptyState вырастает примерно вдвое.
      // Должен прокручиваться, не переполняться.
      const size = Size(360, 650);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
          emptyDayHarness(size: size, textScale: 2.0));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });
  });
}
