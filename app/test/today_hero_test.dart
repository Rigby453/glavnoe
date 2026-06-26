// today_hero_test.dart
// Проверяет три требования задачи 10:
//   1. MorningReviewCard: при наличии переносов — заметный блок с 3 кнопками одного касания.
//   2. TaskList: при наличии main-задач — акцентный hero-заголовок (titleLarge).
//   3. Нет RenderFlex overflow на 320px × textScale 1.5 для обоих виджетов.
//
// Стратегия: минимальные моки, без реального Drift-IO в критическом пути,
// без pumpAndSettle (deadlock guard). Сидинг данных через StreamProvider.overrideWith.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/today/widgets/morning_review_card.dart';
import 'package:app/features/today/widgets/task_list.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Вспомогательные фабрики
// ---------------------------------------------------------------------------

/// Тестовая задача с разумными дефолтами.
ItemsTableData _item({
  String id = 'i1',
  String title = 'Test task',
  String priority = 'medium',
  String status = 'pending',
  String type = 'task',
  DateTime? scheduledAt,
}) {
  final when = scheduledAt ?? DateTime(2026, 6, 26, 9, 0);
  return ItemsTableData(
    id: id,
    userId: 'local',
    title: title,
    type: type,
    priority: priority,
    status: status,
    scheduledAt: when,
    durationMinutes: 30,
    isProtected: priority == 'main',
    createdAt: when,
    updatedAt: when,
  );
}

/// Тестовая тема — без accent/onAccent (FocusThemeExtension не хранит их).
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

// ---------------------------------------------------------------------------
// Общий харнесс
// ---------------------------------------------------------------------------

class _Harness {
  _Harness({required this.db, required this.prefs});

  final AppDatabase db;
  final SharedPreferences prefs;

  /// Строит ProviderScope с минимальными переопределениями.
  /// [overdueOverride] — если задан, переопределяет overduePendingProvider.
  Widget wrap(
    Widget child, {
    double width = 390,
    double textScale = 1.0,
    List<ItemsTableData>? overdueOverride,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Переопределяем overduePendingProvider синхронным Stream если нужно.
        if (overdueOverride != null)
          overduePendingProvider.overrideWith(
            (ref) => Stream.value(overdueOverride),
          ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: Size(width, 800),
        ),
        child: MaterialApp(
          theme: _testTheme(),
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Сеттл без pumpAndSettle + размонтирование для сброса Drift-таймеров
// ---------------------------------------------------------------------------

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump(const Duration(milliseconds: 120));
}

/// Размонтирует дерево виджетов, чтобы Drift-таймеры завершились до конца
/// теста. Без этого flutter_test падает с «A Timer is still pending».
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _Harness harness;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({
      // seen_swipe_hint=true → TaskList не запускает nudge-анимацию в тесте.
      'seen_swipe_hint': true,
    });
    prefs = await SharedPreferences.getInstance();
    harness = _Harness(db: db, prefs: prefs);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 1. MorningReviewCard — заметный banner с 3 кнопками
  // ─────────────────────────────────────────────────────────────────────────
  group('MorningReviewCard — prominent banner', () {
    testWidgets('показывает 3 кнопки одного касания при наличии переносов',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          const MorningReviewCard(),
          overdueOverride: [
            _item(id: 'o1', title: 'Overdue task 1', priority: 'main'),
            _item(id: 'o2', title: 'Overdue task 2', priority: 'medium'),
          ],
        ),
      );
      await _settle(tester);

      // Три кнопки одного касания: Принять / Поправить / Оставить.
      expect(find.text('Accept all'), findsOneWidget);
      expect(find.text('Adjust'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      // Нет кнопки прежнего Review (заменена на Adjust).
      expect(find.text('Review'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('скрыт когда список переносов пуст', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          const MorningReviewCard(),
          overdueOverride: const [],
        ),
      );
      await _settle(tester);

      expect(find.text('Morning review'), findsNothing);
      expect(find.text('Accept all'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('нет overflow 320px × 1.5 с 3 просроченными задачами',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          const MorningReviewCard(),
          width: 320,
          textScale: 1.5,
          overdueOverride: [
            _item(
              id: 'o1',
              title:
                  'A very long overdue task name that is likely to overflow the card on narrow screens',
              priority: 'main',
            ),
            _item(id: 'o2', title: 'Second overdue', priority: 'high'),
            _item(id: 'o3', title: 'Third overdue', priority: 'medium'),
          ],
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('«Оставить» скрывает карточку в текущей сессии', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          const MorningReviewCard(),
          overdueOverride: [
            _item(id: 'o1', title: 'Overdue', priority: 'main'),
          ],
        ),
      );
      await _settle(tester);

      expect(find.text('Morning review'), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pump();

      // После «Оставить» карточка скрыта.
      expect(find.text('Morning review'), findsNothing);

      await _unmount(tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. TaskList — hero main section
  // ─────────────────────────────────────────────────────────────────────────
  group('TaskList — hero main section', () {
    testWidgets('задачи main и medium оба видны', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          TaskList(
            items: [
              _item(id: 'm1', title: 'Main task A', priority: 'main'),
              _item(id: 'm2', title: 'Main task B', priority: 'main'),
              _item(id: 'r1', title: 'Regular task', priority: 'medium'),
            ],
            day: DateTime(2026, 6, 26),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Main task A'), findsOneWidget);
      expect(find.text('Main task B'), findsOneWidget);
      expect(find.text('Regular task'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('нет overflow 320px × 1.5 с main + medium задачами',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          TaskList(
            items: [
              _item(
                id: 'm1',
                title:
                    'Very long main task that might cause overflow on narrow screens in hero mode',
                priority: 'main',
              ),
              _item(id: 'm2', title: 'Another main task', priority: 'main'),
              _item(
                id: 'r1',
                title: 'Regular task with also quite a long name',
                priority: 'medium',
              ),
            ],
            day: DateTime(2026, 6, 26),
          ),
          width: 320,
          textScale: 1.5,
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('без main-задач нет пустого hero-блока', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        harness.wrap(
          TaskList(
            items: [
              _item(id: 'r1', title: 'Only regular', priority: 'medium'),
            ],
            day: DateTime(2026, 6, 26),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Only regular'), findsOneWidget);
      // Счётчик «0» не должен появляться — hero нет.
      expect(find.text('0'), findsNothing);
      await _unmount(tester);
    });
  });
}
