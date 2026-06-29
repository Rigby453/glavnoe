// Блок 6: виджет-тесты Today / Plan / Diary с мок-БД (in-memory Drift).
// Без сети: sharedPreferencesProvider замокан, БД — NativeDatabase.memory().
// Цель — экраны рендерятся без ошибок и реагируют на данные из Drift.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/mascot/kai_mascot.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/core/utils/id.dart';
import 'package:app/features/diary/diary_screen.dart';
import 'package:app/features/food/shopping_list_screen.dart';
import 'package:app/features/health/meditation_screen.dart';
import 'package:app/features/plan/plan_screen.dart';
import 'package:app/features/today/today_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Лёгкая тестовая тема: системный шрифт + FocusThemeExtension с палитрой Focus.
/// Избегает GoogleFonts (в тестах шрифты не доступны через сеть/ассеты),
/// но предоставляет `extension<FocusThemeExtension>()!`, который нужен экранам.
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

  Widget harness(Widget screen) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      // Scaffold — потому что в приложении экраны живут внутри
      // ScaffoldWithNavBar; без него TextField в Diary не находит Material.
      // _testTheme() содержит FocusThemeExtension — экраны вызывают extension<FocusThemeExtension>()!
      // Используем системный шрифт вместо GoogleFonts (шрифты недоступны в тест-окружении).
      child: MaterialApp(theme: _testTheme(), home: Scaffold(body: screen)),
    );
  }

  // Drift при отписке стримов создаёт zero-duration таймер (markAsClosed).
  // flutter_test падает, если таймер остаётся после теста. Поэтому в конце
  // каждого теста размонтируем дерево (dispose ProviderScope) и прокачиваем
  // кадр, чтобы таймер успел сработать ВНУТРИ тела теста.
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> insertTask(
    String title, {
    String priority = 'medium',
    String status = 'pending',
    DateTime? scheduledAt,
  }) async {
    final now = DateTime.now();
    await db.into(db.itemsTable).insert(
          ItemsTableCompanion(
            id: Value(uuidV4()),
            userId: const Value('local'),
            title: Value(title),
            type: const Value('task'),
            priority: Value(priority),
            status: Value(status),
            // Полдень текущего дня, а не «сейчас»: иначе в ранние часы (когда
            // локальное «сейчас» по UTC ещё вчера) UTC-границы watchTodayItems
            // исключают задачу и тест становится зависимым от времени суток.
            scheduledAt:
                Value(scheduledAt ?? DateTime(now.year, now.month, now.day, 12)),
            durationMinutes: const Value(30),
            isProtected: Value(priority == 'main'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('TodayScreen', () {
    testWidgets('renders greeting, ring and main task from DB',
        (tester) async {
      // Реальный async Drift внутри fakeAsync-зоны теста дедлочится —
      // прямые обращения к БД выполняем через tester.runAsync (реальный IO).
      await tester.runAsync(() => insertTask('Write essay', priority: 'main'));

      await tester.pumpWidget(harness(const TodayScreen()));
      // Дать стримам Drift доставить данные (runAsync — реальные микротаски)
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Good '), findsOneWidget); // приветствие
      // Редизайн: ring/секцию «Focus» заменил счётчик «Main · X/Y» (EN label='Main').
      expect(find.text('Main · 0/1'), findsOneWidget);
      expect(find.text('Write essay'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await unmountAndFlush(tester);
    });

    testWidgets('empty DB → empty-state hint', (tester) async {
      await tester.pumpWidget(harness(const TodayScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));

      // 'Nothing planned yet' встречается в двух виджетах: TaskList и Kai-пузырь.
      expect(find.textContaining('Nothing planned yet'), findsWidgets);

      await unmountAndFlush(tester);
    });
  });

  group('PlanScreen', () {
    testWidgets('renders view switcher, FAB and a scheduled task',
        (tester) async {
      await tester.runAsync(() => insertTask('Lecture: Algebra'));

      await tester.pumpWidget(harness(const PlanScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));

      // Переключатель День/Неделя/Месяц
      expect(find.byType(SegmentedButton<dynamic>), findsNothing);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // Задача на сегодня видна в таймлайне дня
      expect(find.text('Lecture: Algebra'), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('ShoppingListScreen', () {
    testWidgets('empty state renders shopping cart icon', (tester) async {
      await tester.pumpWidget(harness(const ShoppingListScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      // Empty-state теперь Kai (§4.2), а не Material shopping_cart.
      expect(find.byType(KaiMascot), findsOneWidget);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);

      await unmountAndFlush(tester);
    });

    testWidgets('adding an item via TextField shows it in the list',
        (tester) async {
      await tester.pumpWidget(harness(const ShoppingListScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      // Вводим название и нажимаем кнопку добавления
      await tester.enterText(find.byType(TextField), 'Apples');
      // Экран использует Phosphor plusCircle (раньше Icons.add_circle_outline)
      await tester.tap(find.byIcon(PhosphorIcons.plusCircle()));
      // Ждём записи в Drift и обновления стрима
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apples'), findsOneWidget);
      // Поле ввода очищается после добавления
      expect(find.widgetWithText(TextField, 'Apples'), findsNothing);

      await unmountAndFlush(tester);
    });
  });

  group('MeditationScreen', () {
    testWidgets('session list renders all sessions', (tester) async {
      await tester.pumpWidget(harness(const MeditationScreen()));
      await tester.pump();

      // Список из 5 текстовых сессий — проверяем по названиям.
      expect(find.text('Body Scan'), findsOneWidget);
      expect(find.text('Focus Reset'), findsOneWidget);
      expect(find.text('Sleep Prep'), findsOneWidget);

      await unmountAndFlush(tester);
    });

    testWidgets('tapping a session opens the player without crashing',
        (tester) async {
      await tester.pumpWidget(harness(const MeditationScreen()));
      await tester.pump();

      // Открываем превью позы первой сессии (ADR-054: перед плеером показывается
      // поза), затем сам плеер — здесь жил red-screen краш
      // (MediaQuery.disableAnimationsOf в initState → старт Timer/анимации).
      await tester.tap(find.text('Body Scan'));
      await tester.pump(); // навигация на превью позы
      await tester.pump(const Duration(milliseconds: 350)); // переход доехал

      // Превью позы → плеер по кнопке «Start».
      await tester.tap(find.text('Start'));
      await tester.pump(); // навигация
      await tester.pump(const Duration(milliseconds: 100)); // первый кадр плеера

      // Прогресс шага виден → плеер отрисовался без эксепшена.
      expect(find.textContaining('1 / 6'), findsOneWidget);

      // Останавливаем периодический Timer плеера: возвращаемся назад.
      await unmountAndFlush(tester);
    });
  });

  group('DiaryScreen', () {
    testWidgets('mood + save writes a DayLog row to Drift', (tester) async {
      await tester.pumpWidget(harness(const DiaryScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      // Выбираем настроение 🙂 (4/5) и сохраняем
      await tester.tap(find.text('🙂'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save Day'));
      await tester.tap(find.text('Save Day'));
      // Запись в Drift — реальный IO; даём ему завершиться в runAsync
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      final rows =
          await tester.runAsync(() => db.select(db.dayLogsTable).get());
      expect(rows, isNotNull);
      expect(rows!, hasLength(1));
      expect(rows.first.mood, 4);

      await unmountAndFlush(tester);
    });
  });
}
