// Тесты раздела «Привычки сегодня» в экране Today (ADR-053, slice 3).
//
// Стратегия (анти-флак): логика «надо ли показывать привычку сегодня»
// вынесена в чистую функцию isHabitDueUnmet — тестируется напрямую, без БД и
// без виджетов (детерминированно). Виджет HabitsTodaySection пумпится с
// переопределённым dueGoodHabitsProvider (готовые данные) и fake-DAO
// (фиксирует logHabit) — никакой реальной Drift-БД и fake-clock-дедлоков.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/habits_dao.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/habits_providers.dart';
import 'package:app/features/today/widgets/habits_today_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Фабрика тестовой привычки с разумными дефолтами.
HabitsTableData _habit({
  String id = 'h1',
  String name = 'Drink water',
  String type = 'good',
  String emoji = '💧',
  int targetPerDay = 1,
  String frequencyType = 'daily',
  int weekdayMask = 127,
  int weeklyTarget = 0,
}) {
  return HabitsTableData(
    id: id,
    name: name,
    type: type,
    emoji: emoji,
    targetPerDay: targetPerDay,
    archived: false,
    createdAt: DateTime(2026, 1, 1),
    frequencyType: frequencyType,
    weekdayMask: weekdayMask,
    weeklyTarget: weeklyTarget,
  );
}

/// DAO, который не трогает БД, а лишь фиксирует вызовы logHabit.
/// Наследует HabitsDao (тип провайдера), db не используется (стримы раздела
/// переопределены через dueGoodHabitsProvider).
class _RecordingDao extends HabitsDao {
  _RecordingDao(super.db);
  final List<String> logged = [];

  @override
  Future<void> logHabit(String habitId, {int count = 1}) async {
    logged.add(habitId);
  }
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<HabitsTableData> due,
  required HabitsDao dao,
  double width = 390,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dueGoodHabitsProvider.overrideWithValue(due),
        habitsDaoProvider.overrideWithValue(dao),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(children: const [HabitsTodaySection()]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Чистая логика «due + unmet» — isHabitDueUnmet.
  // ─────────────────────────────────────────────────────────────────────────
  group('isHabitDueUnmet', () {
    // Известный календарный день; вычисляем бит дня недели динамически,
    // чтобы тест не зависел от конкретного дня.
    final now = DateTime(2026, 6, 25);
    final todayBit =
        1 << (DateTime.utc(now.year, now.month, now.day).weekday - 1);

    test('daily, не выполнено сегодня → показывается', () {
      expect(
        isHabitDueUnmet(
            habit: _habit(frequencyType: 'daily'),
            todayCount: 0,
            weekCount: 0,
            now: now),
        isTrue,
      );
    });

    test('daily, цель достигнута сегодня → скрыто', () {
      expect(
        isHabitDueUnmet(
            habit: _habit(frequencyType: 'daily', targetPerDay: 2),
            todayCount: 2,
            weekCount: 2,
            now: now),
        isFalse,
      );
    });

    test('weekly_days, сегодня запланировано → показывается', () {
      expect(
        isHabitDueUnmet(
            habit:
                _habit(frequencyType: 'weekly_days', weekdayMask: todayBit),
            todayCount: 0,
            weekCount: 0,
            now: now),
        isTrue,
      );
    });

    test('weekly_days, сегодня НЕ запланировано → скрыто', () {
      final maskWithoutToday = 127 & ~todayBit;
      expect(
        isHabitDueUnmet(
            habit: _habit(
                frequencyType: 'weekly_days', weekdayMask: maskWithoutToday),
            todayCount: 0,
            weekCount: 0,
            now: now),
        isFalse,
      );
    });

    test('weekly_count, выполнений за неделю < цели → показывается', () {
      expect(
        isHabitDueUnmet(
            habit: _habit(frequencyType: 'weekly_count', weeklyTarget: 3),
            todayCount: 0,
            weekCount: 1,
            now: now),
        isTrue,
      );
    });

    test('weekly_count, выполнений за неделю >= цели → скрыто', () {
      expect(
        isHabitDueUnmet(
            habit: _habit(frequencyType: 'weekly_count', weeklyTarget: 3),
            todayCount: 0,
            weekCount: 3,
            now: now),
        isFalse,
      );
    });

    test('weekly_count, неделя не закрыта, но сегодня уже отмечено → скрыто',
        () {
      // targetPerDay=1 уже выполнен сегодня → не показываем, хотя неделя < цели.
      expect(
        isHabitDueUnmet(
            habit: _habit(frequencyType: 'weekly_count', weeklyTarget: 3),
            todayCount: 1,
            weekCount: 1,
            now: now),
        isFalse,
      );
    });

    test('плохая привычка → никогда не показывается', () {
      expect(
        isHabitDueUnmet(
            habit: _habit(type: 'bad', frequencyType: 'daily'),
            todayCount: 0,
            weekCount: 0,
            now: now),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Виджет HabitsTodaySection — рендер, тап, скрытие, overflow.
  // ─────────────────────────────────────────────────────────────────────────
  group('HabitsTodaySection widget', () {
    late AppDatabase db;
    late _RecordingDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = _RecordingDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('показывает строки для due-привычек', (tester) async {
      await _pumpSection(
        tester,
        due: [
          _habit(id: 'a', name: 'Drink water'),
          _habit(id: 'b', name: 'Read 10 pages', emoji: '📖'),
        ],
        dao: dao,
      );

      expect(find.text('Habits today'), findsOneWidget);
      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('Read 10 pages'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
    });

    testWidgets('тап по отметке вызывает logHabit с id привычки',
        (tester) async {
      await _pumpSection(
        tester,
        due: [_habit(id: 'water', name: 'Drink water')],
        dao: dao,
      );

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(dao.logged, ['water']);
    });

    testWidgets('пустой список → раздел не отрисован (нет заголовка)',
        (tester) async {
      await _pumpSection(tester, due: const [], dao: dao);

      // Раздел схлопнут в SizedBox.shrink → ни заголовка, ни строк, ни иконок.
      expect(find.text('Habits today'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('нет overflow на 320px + textScale 1.5', (tester) async {
      await _pumpSection(
        tester,
        due: [
          _habit(
              id: 'a',
              name: 'A very long habit name that could overflow the row easily',
              emoji: '🏃'),
          _habit(id: 'b', name: 'Meditate', emoji: '🧘'),
        ],
        dao: dao,
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
