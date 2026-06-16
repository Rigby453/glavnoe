// DAO для таблицы sleep_logs — трекер сна (раздел Health, Phase 2).
// Офлайн-первый: пишем в Drift; Health Connect и синхронизация — позже.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'sleep_dao.g.dart';

@DriftAccessor(tables: [SleepLogsTable])
class SleepDao extends DatabaseAccessor<AppDatabase> with _$SleepDaoMixin {
  SleepDao(super.db);

  /// Последняя незакрытая ночь (endAt == null). null если все ночи закрыты.
  Stream<SleepLogsTableData?> watchOpenNight() {
    return (select(sleepLogsTable)
          ..where((t) => t.endAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Начать ночь: вставить запись startAt = now.
  /// Если уже есть открытая ночь — ничего не делать (идемпотентно).
  Future<void> startNight() async {
    final open =
        await (select(sleepLogsTable)
              ..where((t) => t.endAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (open != null) return;

    await into(sleepLogsTable).insert(
      SleepLogsTableCompanion(
        id: Value(uuidV4()),
        startAt: Value(DateTime.now()),
      ),
    );
  }

  /// Завершить открытую ночь: записать endAt = now.
  Future<void> endNight() async {
    final open =
        await (select(sleepLogsTable)
              ..where((t) => t.endAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
              ..limit(1))
            .getSingleOrNull();
    if (open == null) return;

    await (update(sleepLogsTable)..where((t) => t.id.equals(open.id))).write(
      SleepLogsTableCompanion(endAt: Value(DateTime.now())),
    );
  }

  /// Завершённые ночи (endAt != null) за последние [days] дней, свежие первыми.
  /// Фильтрация — по дате endAt (день, когда проснулся).
  Stream<List<SleepLogsTableData>> watchRecentNights(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(sleepLogsTable)
          ..where(
            (t) => t.endAt.isNotNull() & t.endAt.isBiggerOrEqualValue(cutoff),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.endAt)]))
        .watch();
  }

  /// Все завершённые ночи (endAt != null), свежие первыми. Для полного отчёта.
  Stream<List<SleepLogsTableData>> watchAllNights() {
    return (select(sleepLogsTable)
          ..where((t) => t.endAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.endAt)]))
        .watch();
  }

  /// Ночи, где startAt или endAt попадают в диапазон [from, to)
  Stream<List<SleepLogsTableData>> watchNightsByDateRange(
    DateTime from,
    DateTime to,
  ) {
    return (select(sleepLogsTable)
          ..where(
            (t) =>
                (t.startAt.isBiggerOrEqualValue(from) &
                    t.startAt.isSmallerThanValue(to)) |
                (t.endAt.isNotNull() &
                    t.endAt.isBiggerOrEqualValue(from) &
                    t.endAt.isSmallerThanValue(to)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)]))
        .watch();
  }
}
