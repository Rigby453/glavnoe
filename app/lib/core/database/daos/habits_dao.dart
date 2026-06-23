import 'package:drift/drift.dart';
import '../database.dart';
import '../../utils/id.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [HabitsTable, HabitLogsTable])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  /// Все активные привычки (не заархивированные).
  Stream<List<HabitsTableData>> watchActive() {
    return (select(habitsTable)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Логи за конкретный день (нормализованная дата 00:00 UTC).
  Stream<List<HabitLogsTableData>> watchLogsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          ))
        .watch();
  }

  /// Количество выполнений привычки за день.
  Future<int> countForDate(String habitId, DateTime date) async {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (select(habitLogsTable)
          ..where(
            (t) =>
                t.habitId.equals(habitId) &
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          ))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.count);
  }

  /// Реактивное количество выполнений привычки за день.
  /// В отличие от [countForDate], эмитит новое значение при каждом logHabit —
  /// карточка обновляется сразу, без ухода/возврата на экран.
  Stream<int> watchCountForDate(String habitId, DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final countExpr = habitLogsTable.count.sum();
    final query = selectOnly(habitLogsTable)
      ..addColumns([countExpr])
      ..where(
        habitLogsTable.habitId.equals(habitId) &
            habitLogsTable.date.isBiggerOrEqualValue(start) &
            habitLogsTable.date.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  /// Добавить выполнение (+1 или +count).
  Future<void> logHabit(String habitId, {int count = 1}) {
    final date = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return into(habitLogsTable).insert(
      HabitLogsTableCompanion(
        id: Value(uuidV4()),
        habitId: Value(habitId),
        date: Value(date),
        count: Value(count),
      ),
    );
  }

  /// Создать новую привычку.
  Future<void> createHabit({
    required String name,
    required String type,
    String emoji = '✅',
    int targetPerDay = 1,
  }) {
    return into(habitsTable).insert(
      HabitsTableCompanion(
        id: Value(uuidV4()),
        name: Value(name),
        type: Value(type),
        emoji: Value(emoji),
        targetPerDay: Value(targetPerDay),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Архивировать привычку (скрыть без удаления).
  Future<void> archive(String id) {
    return (update(habitsTable)..where((t) => t.id.equals(id)))
        .write(const HabitsTableCompanion(archived: Value(true)));
  }

  /// Полностью удалить привычку по id.
  /// Логи выполнения (HabitLogsTable) при этом НЕ удаляются — они привязаны
  /// по habitId, но foreign key не каскадирует на delete в Drift (нет ON DELETE CASCADE).
  /// При восстановлении через [restoreHabit] привычка вернётся с тем же id,
  /// и существующие логи снова будут доступны.
  Future<void> deleteHabit(String id) {
    return (delete(habitsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Восстановить привычку из снапшота (после Undo).
  /// insertOnConflictUpdate перезапишет запись если она вдруг уже существует.
  /// Логи выполнения сохраняются в HabitLogsTable — прогресс не теряется.
  Future<void> restoreHabit(HabitsTableData snapshot) {
    return into(habitsTable).insertOnConflictUpdate(snapshot);
  }
}
