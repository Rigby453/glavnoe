// Общие провайдеры привычек, переиспользуемые экраном Today (ADR-053, slice 3).
//
// Раздел «Привычки сегодня» в today_screen показывает ХОРОШИЕ привычки, у
// которых СЕГОДНЯ запланированный день и цель ещё НЕ достигнута. Сюда вынесена:
//   • чистая функция [isHabitDueUnmet] — решает «надо ли показывать привычку
//     сегодня» (тестируется без БД и без виджетов);
//   • публичный провайдер [dueGoodHabitsProvider] — реактивный список таких
//     привычек, построенный поверх единственного habitsDaoProvider (один набор
//     стримов на всё приложение, без дублирования).
//
// Плохие привычки здесь НЕ участвуют — у них нет расписания/цели на день.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/daos/habits_dao.dart';

/// Запланирована ли [habit] на сегодня и НЕ выполнена ли ещё цель.
///
/// «Запланировано сегодня» зависит от частоты (ADR-053):
///   • daily        → всегда;
///   • weekly_days  → день недели входит в [HabitsTableData.weekdayMask];
///   • weekly_count → выполнений за текущую неделю меньше недельной цели.
/// «Не выполнено» (для всех режимов): за сегодня залогировано меньше, чем
/// [HabitsTableData.targetPerDay].
///
/// Плохие привычки (`type != 'good'`) — всегда false (в день не попадают).
///
/// Чистая функция: [todayCount] — сумма логов за сегодня, [weekCount] — сумма
/// логов за текущую ISO-неделю, [now] — «сейчас» (локальное). Не трогает БД,
/// поэтому юнит-тестируется напрямую.
bool isHabitDueUnmet({
  required HabitsTableData habit,
  required int todayCount,
  required int weekCount,
  required DateTime now,
}) {
  if (habit.type != 'good') return false;

  // Цель на день: минимум 1 (target<=1 → бинарная привычка).
  final target = habit.targetPerDay < 1 ? 1 : habit.targetPerDay;
  // Уже выполнено сегодня — не показываем.
  if (todayCount >= target) return false;

  // Запланировано ли сегодня по частоте.
  final today = DateTime.utc(now.year, now.month, now.day);
  switch (habit.frequencyType) {
    case 'weekly_days':
      return isScheduledDay(today, 'weekly_days', habit.weekdayMask);
    case 'weekly_count':
      final weeklyTarget = habit.weeklyTarget < 1 ? 1 : habit.weeklyTarget;
      return weekCount < weeklyTarget;
    case 'daily':
    default:
      return true;
  }
}

// ---------------------------------------------------------------------------
// Реактивные источники (приватные) — поверх единственного habitsDaoProvider.
// ---------------------------------------------------------------------------

/// Активные привычки (не заархивированные) — реэкспорт watchActive().
final _activeHabitsProvider =
    StreamProvider.autoDispose<List<HabitsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchActive();
});

/// Все логи привычек за сегодня (все привычки) — для подсчёта дневной цели.
final _todayHabitLogsProvider =
    StreamProvider.autoDispose<List<HabitLogsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchLogsForDate(DateTime.now());
});

/// Все логи привычек за текущую неделю — для режима weekly_count.
final _weekHabitLogsProvider =
    StreamProvider.autoDispose<List<HabitLogsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchLogsForWeek(DateTime.now());
});

/// Хорошие привычки, запланированные на сегодня и ещё не выполненные.
///
/// Реактивен: пересобирается при каждом logHabit (стримы логов эмитят новое
/// значение), поэтому строка в разделе Today сама обновляется/исчезает, когда
/// цель достигнута. Пока любой из стримов грузится — отдаёт пустой список
/// (раздел просто не показывается, без «пустой коробки»).
final dueGoodHabitsProvider =
    Provider.autoDispose<List<HabitsTableData>>((ref) {
  final habits = ref.watch(_activeHabitsProvider).valueOrNull;
  final todayLogs = ref.watch(_todayHabitLogsProvider).valueOrNull;
  final weekLogs = ref.watch(_weekHabitLogsProvider).valueOrNull;
  if (habits == null || todayLogs == null || weekLogs == null) {
    return const <HabitsTableData>[];
  }

  final todayByHabit = <String, int>{};
  for (final log in todayLogs) {
    todayByHabit[log.habitId] = (todayByHabit[log.habitId] ?? 0) + log.count;
  }
  final weekByHabit = <String, int>{};
  for (final log in weekLogs) {
    weekByHabit[log.habitId] = (weekByHabit[log.habitId] ?? 0) + log.count;
  }

  final now = DateTime.now();
  return habits
      .where(
        (h) => isHabitDueUnmet(
          habit: h,
          todayCount: todayByHabit[h.id] ?? 0,
          weekCount: weekByHabit[h.id] ?? 0,
          now: now,
        ),
      )
      .toList();
});
