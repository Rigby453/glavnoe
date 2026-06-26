// Тесты новых возможностей экрана Plan (ночной спринт):
//   (а) overflow-гейт переключателя видов: 320px (mobile _ViewDropdown) и
//       планшет (SegmentedButton) при textScale 1.5 — нет RenderFlex.
//   (б) поиск (planSearchQueryProvider) фильтрует список недели (WeekAgenda),
//       3-дневный список (ThreeDayAgenda) и месяц (MonthView).
//   (в) вид «3 дня» переключается список (ThreeDayAgenda) ↔ сетка
//       (ThreeDayTimeGrid) тумблером раскладки.
//
// Виджет-тесты фильтра пьют данные через overrides провайдеров
// (dayItemsProvider / rangeItemsProvider) — без Drift/стримов, чтобы быть
// детерминированными и быстрыми (как time_grid_overflow_test / year_view_test).
// Тесты PlanScreen используют in-memory Drift (overflow/toggle на реальном
// дереве экрана), settle через runAsync — паттерн из overflow_audit_test.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/plan/plan_screen.dart';
import 'package:app/features/plan/widgets/day_timeline.dart'
    show dayItemsProvider;
import 'package:app/features/plan/widgets/month_view.dart';
import 'package:app/features/plan/widgets/plan_providers.dart';
import 'package:app/features/plan/widgets/time_grid.dart' show ThreeDayTimeGrid;
import 'package:app/features/plan/widgets/week_agenda.dart'
    show WeekAgenda, ThreeDayAgenda;
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;
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

ItemsTableData _item({
  required String id,
  required String title,
  required DateTime at,
  String type = 'task',
}) {
  return ItemsTableData(
    id: id,
    userId: 'u1',
    title: title,
    type: type,
    priority: 'medium',
    status: 'pending',
    scheduledAt: at,
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: null,
    moduleLink: null,
    color: null,
    tags: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// Лёгкая обёртка для виджет-тестов (без Drift): фиксированный день + список
/// задач через override провайдеров данных и текущий поисковый запрос.
Widget _wrap(
  Widget child, {
  required DateTime day,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: [
      selectedDayProvider.overrideWith((ref) => day),
      ...overrides,
    ],
    child: MaterialApp(
      theme: _testTheme(),
      home: Scaffold(body: child),
    ),
  );
}

/// Тестовый нотифер раскладки: всегда стартует в grid (без SharedPreferences).
class _GridLayoutNotifier extends PlanLayoutNotifier {
  @override
  PlanLayout build() => PlanLayout.grid;
}

void main() {
  // -------------------------------------------------------------------------
  // (б) Поиск фильтрует списки недели и 3 дней (через dayItemsProvider).
  // -------------------------------------------------------------------------
  group('Поиск фильтрует агенда-списки (week / 3 days)', () {
    final day = DateTime(2026, 6, 15);
    final items = [
      _item(id: 'a', title: 'Algebra', at: DateTime(2026, 6, 15, 9)),
      _item(id: 'p', title: 'Physics', at: DateTime(2026, 6, 15, 11)),
    ];

    List<Override> overridesWithQuery(String query) => [
          dayItemsProvider.overrideWith((ref, date) => AsyncValue.data(items)),
          planSearchQueryProvider.overrideWith((ref) => query),
        ];

    testWidgets('WeekAgenda: пустой запрос показывает обе задачи',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const WeekAgenda(), day: day, overrides: overridesWithQuery('')),
      );
      await tester.pump();
      expect(find.text('Algebra'), findsWidgets);
      expect(find.text('Physics'), findsWidgets);
    });

    testWidgets('WeekAgenda: запрос «algebra» прячет Physics', (tester) async {
      await tester.pumpWidget(
        _wrap(const WeekAgenda(),
            day: day, overrides: overridesWithQuery('algebra')),
      );
      await tester.pump();
      expect(find.text('Algebra'), findsWidgets);
      expect(find.text('Physics'), findsNothing);
    });

    testWidgets('ThreeDayAgenda: запрос «algebra» прячет Physics',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ThreeDayAgenda(),
            day: day, overrides: overridesWithQuery('algebra')),
      );
      await tester.pump();
      expect(find.text('Algebra'), findsWidgets);
      expect(find.text('Physics'), findsNothing);
    });

    testWidgets('ThreeDayAgenda: пустой запрос показывает обе', (tester) async {
      await tester.pumpWidget(
        _wrap(const ThreeDayAgenda(),
            day: day, overrides: overridesWithQuery('')),
      );
      await tester.pump();
      expect(find.text('Algebra'), findsWidgets);
      expect(find.text('Physics'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // (б) Поиск фильтрует месяц (MonthView) — через rangeItemsProvider.
  // 4 задачи на 15-е: 3 «Algebra*» + 1 «Physics». Без запроса день >3 задач →
  // показывает «+2» (2 полоски + счётчик). С запросом «algebra» остаётся 3 →
  // ровно 3 полоски, «+2» исчезает. Так проверяем, что фильтр меняет счётчики.
  // -------------------------------------------------------------------------
  group('Поиск фильтрует месяц (MonthView)', () {
    final day = DateTime(2026, 6, 15);
    final monthStart = DateTime(2026, 6, 1);
    final monthEnd = DateTime(2026, 7, 1);
    final items = [
      _item(id: 'a1', title: 'Algebra1', at: DateTime(2026, 6, 15, 9)),
      _item(id: 'a2', title: 'Algebra2', at: DateTime(2026, 6, 15, 10)),
      _item(id: 'a3', title: 'Algebra3', at: DateTime(2026, 6, 15, 11)),
      _item(id: 'p', title: 'Physics', at: DateTime(2026, 6, 15, 12)),
    ];

    List<Override> overridesWithQuery(String query) => [
          rangeItemsProvider((monthStart, monthEnd))
              .overrideWith((ref) => AsyncValue.data(items)),
          planSearchQueryProvider.overrideWith((ref) => query),
        ];

    testWidgets('пустой запрос: день с 4 задачами показывает «+2»',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const MonthView(), day: day, overrides: overridesWithQuery('')),
      );
      await tester.pump();
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('запрос «algebra»: остаётся 3 задачи, «+2» исчезает',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const MonthView(),
            day: day, overrides: overridesWithQuery('algebra')),
      );
      await tester.pump();
      expect(find.text('+2'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // PlanScreen-тесты на реальном дереве экрана (in-memory Drift).
  // -------------------------------------------------------------------------
  group('PlanScreen (Drift)', () {
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

    Widget buildScreen({
      required Size size,
      double textScale = 1.0,
      List<Override> extra = const [],
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          ...extra,
        ],
        // size в MediaQueryData обязателен: PlanScreen выбирает tablet/mobile
        // по MediaQuery.sizeOf(context).width. Без него size == Size.zero и
        // экран всегда падал бы в mobile-ветку (SegmentedButton не строится).
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

    // -------- (а) overflow-гейт переключателя видов --------

    testWidgets('view switcher: mobile 320px + textScale 1.5 — нет overflow',
        (tester) async {
      const size = Size(320, 760);
      await setSize(tester, size);
      await tester.pumpWidget(buildScreen(size: size, textScale: 1.5));
      await settle(tester);
      // Успешный pump = RenderFlex overflow не возник (flutter_test бросил бы).
      await unmount(tester);
    });

    testWidgets(
        'view switcher: tablet (SegmentedButton) + textScale 1.5 — нет overflow',
        (tester) async {
      const size = Size(700, 900);
      await setSize(tester, size);
      await tester.pumpWidget(buildScreen(size: size, textScale: 1.5));
      await settle(tester);
      // Левая колонка с SegmentedButton из 5 видов не должна переполняться.
      expect(find.byType(SegmentedButton<PlanView>), findsOneWidget);
      await unmount(tester);
    });

    // -------- (в) вид «3 дня» переключается список ↔ сетка --------

    testWidgets('3 дня, list-раскладка → ThreeDayAgenda (не сетка)',
        (tester) async {
      const size = Size(400, 800);
      await setSize(tester, size);
      await tester.pumpWidget(buildScreen(size: size, extra: [
        planViewProvider.overrideWith((ref) => PlanView.threeDay),
      ]));
      await settle(tester);
      expect(find.byType(ThreeDayAgenda), findsOneWidget);
      expect(find.byType(ThreeDayTimeGrid), findsNothing);
      await unmount(tester);
    });

    testWidgets('3 дня, grid-раскладка → ThreeDayTimeGrid (не список)',
        (tester) async {
      const size = Size(400, 800);
      await setSize(tester, size);
      await tester.pumpWidget(buildScreen(size: size, extra: [
        planViewProvider.overrideWith((ref) => PlanView.threeDay),
        planLayoutProvider.overrideWith(() => _GridLayoutNotifier()),
      ]));
      await settle(tester);
      expect(find.byType(ThreeDayTimeGrid), findsOneWidget);
      expect(find.byType(ThreeDayAgenda), findsNothing);
      await unmount(tester);
    });
  });
}
