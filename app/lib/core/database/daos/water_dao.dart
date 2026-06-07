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
    final last = await (select(waterLogsTable)
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
}
