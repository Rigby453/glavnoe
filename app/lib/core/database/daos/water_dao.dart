// DAO для таблицы water_logs — трекер воды (раздел Health).
// Офлайн-первый: пишем в Drift; синхронизация воды — позже.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'water_dao.g.dart';

@DriftAccessor(tables: [WaterLogsTable])
class WaterDao extends DatabaseAccessor<AppDatabase> with _$WaterDaoMixin {
  WaterDao(super.db);

  /// Сумма выпитого за календарный день (мл), реактивно.
  Stream<int> watchTodayTotalMl(DateTime day) {
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sumExpr = waterLogsTable.amountMl.sum();

    final query = selectOnly(waterLogsTable)
      ..addColumns([sumExpr])
      ..where(
        waterLogsTable.loggedAt.isBiggerOrEqualValue(start) &
            waterLogsTable.loggedAt.isSmallerThanValue(end),
      );

    return query.map((row) => row.read(sumExpr) ?? 0).watchSingle();
  }

  /// Сумма выпитого в диапазоне [from, to) — для weekly wrapped.
  Future<int> totalInRange(DateTime from, DateTime to) async {
    final sumExpr = waterLogsTable.amountMl.sum();
    final query = selectOnly(waterLogsTable)
      ..addColumns([sumExpr])
      ..where(
        waterLogsTable.loggedAt.isBiggerOrEqualValue(from) &
            waterLogsTable.loggedAt.isSmallerThanValue(to),
      );
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  /// Суммы по дням за последние [days] дней, включая [day].
  /// Индекс 0 — самый старый день, последний — сегодня. Реактивно.
  Stream<List<int>> watchDailyTotals(DateTime day, int days) {
    final todayStart = DateTime.utc(day.year, day.month, day.day);
    final start = todayStart.subtract(Duration(days: days - 1));
    final end = todayStart.add(const Duration(days: 1));
    return (select(waterLogsTable)..where(
          (t) =>
              t.loggedAt.isBiggerOrEqualValue(start) &
              t.loggedAt.isSmallerThanValue(end),
        ))
        .watch()
        .map((rows) {
          final totals = List<int>.filled(days, 0);
          for (final r in rows) {
            // Бакет дня — по тем же полям даты, что и в watchTodayTotalMl
            final bucket = DateTime.utc(
              r.loggedAt.year,
              r.loggedAt.month,
              r.loggedAt.day,
            );
            final idx = bucket.difference(start).inDays;
            if (idx >= 0 && idx < days) totals[idx] += r.amountMl;
          }
          return totals;
        });
  }

  /// Добавить порцию воды (мл).
  Future<void> addWater(int amountMl) {
    return into(waterLogsTable).insert(
      WaterLogsTableCompanion(
        id: Value(uuidV4()),
        amountMl: Value(amountMl),
        loggedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Отменить последнюю запись за день.
  Future<void> undoLast(DateTime day) async {
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final last =
        await (select(waterLogsTable)
              ..where(
                (t) =>
                    t.loggedAt.isBiggerOrEqualValue(start) &
                    t.loggedAt.isSmallerThanValue(end),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (last != null) {
      await (delete(waterLogsTable)..where((t) => t.id.equals(last.id))).go();
    }
  }

  /// Все записи воды за последние дни. Для полного отчёта.
  Stream<List<WaterLogsTableData>> watchAllWaterLogs(int days) {
    final todayStart = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final start = todayStart.subtract(Duration(days: days - 1));
    return (select(waterLogsTable)
          ..where((t) => t.loggedAt.isBiggerOrEqualValue(start))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .watch();
  }

  /// Все записи воды за конкретный календарный день.
  Stream<List<WaterLogsTableData>> watchWaterForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(waterLogsTable)
          ..where(
            (t) =>
                t.loggedAt.isBiggerOrEqualValue(start) &
                t.loggedAt.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .watch();
  }

  /// Сумма выпитого за конкретный календарный день (мл).
  Stream<int> watchTotalForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final sumExpr = waterLogsTable.amountMl.sum();
    final query = selectOnly(waterLogsTable)
      ..addColumns([sumExpr])
      ..where(
        waterLogsTable.loggedAt.isBiggerOrEqualValue(start) &
            waterLogsTable.loggedAt.isSmallerThanValue(end),
      );
    return query.map((row) => row.read(sumExpr) ?? 0).watchSingle();
  }
}
