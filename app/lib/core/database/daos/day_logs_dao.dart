// DAO для таблицы day_logs
// Хранит ежедневные записи: настроение (1-5), заметки, инсайты (Phase 1).
// Один ряд на календарный день — upsert по дате.
// Офлайн-первый: все записи пишутся в Drift, синхронизация вторична.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'day_logs_dao.g.dart';

@DriftAccessor(tables: [DayLogsTable])
class DayLogsDao extends DatabaseAccessor<AppDatabase> with _$DayLogsDaoMixin {
  DayLogsDao(super.db);

  // ---------------------------------------------------------------------------
  // Чтение
  // ---------------------------------------------------------------------------

  /// Получить запись дневника за конкретный календарный день.
  /// Сравниваем по диапазону [dayStart, dayEnd), чтобы не зависеть от времени.
  Future<DayLogsTableData?> getForDate(DateTime date) async {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return (select(dayLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(dayEnd),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Записи начиная с даты [from] — для weekly wrapped.
  Future<List<DayLogsTableData>> since(DateTime from) {
    return (select(dayLogsTable)..where((t) => t.date.isBiggerOrEqualValue(from)))
        .get();
  }

  /// Записи за период [from, to) — для раскраски год-календаря (diary history).
  /// Полуоткрытый интервал, как в getForDate; границы нормализуются до
  /// 00:00 UTC по календарным компонентам (тот же приём, что в getForDate /
  /// saveForDate), чтобы не зависеть от времени суток внутри [from]/[to].
  Future<List<DayLogsTableData>> getBetween(DateTime from, DateTime to) {
    final normalizedFrom = DateTime.utc(from.year, from.month, from.day);
    final normalizedTo = DateTime.utc(to.year, to.month, to.day);
    return (select(dayLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(normalizedFrom) &
                t.date.isSmallerThanValue(normalizedTo),
          ))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Запись (upsert)
  // ---------------------------------------------------------------------------

  /// Upsert-сохранение записи за день.
  /// Если строка за этот день уже существует — обновляем mood и note,
  /// сохраняя исходный id и createdAt.
  /// Иначе — создаём новую строку с uuidV4() и датой, нормализованной до 00:00 UTC.
  ///
  /// Теги "What went wrong?" кодируются в поле note в виде суффикса
  /// "\n\nIssues: tag1, tag2" — отдельной колонки в схеме нет (FL-DIARY-01).
  Future<void> saveForDate({
    required DateTime date,
    int? mood,
    String? note,
  }) async {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    final existing = await getForDate(date);

    final now = DateTime.now();
    if (existing != null) {
      // Строка уже есть — обновляем mood, note и метку изменения
      await (update(dayLogsTable)..where((t) => t.id.equals(existing.id)))
          .write(
        DayLogsTableCompanion(
          mood: Value(mood),
          note: Value(note),
          updatedAt: Value(now),
        ),
      );
    } else {
      // Новая запись — генерируем UUID, фиксируем createdAt/updatedAt
      await into(dayLogsTable).insert(
        DayLogsTableCompanion(
          id: Value(uuidV4()),
          date: Value(normalizedDate),
          mood: Value(mood),
          note: Value(note),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Синхронизация
  // ---------------------------------------------------------------------------

  /// Записи, изменённые после [since] — исходящая дельта синка.
  Future<List<DayLogsTableData>> changedSince(DateTime since) {
    return (select(dayLogsTable)
          ..where((t) => t.updatedAt.isBiggerThanValue(since)))
        .get();
  }

  /// Слить запись дневника с сервера. Ключ — ДАТА (не id), т.к. на разных
  /// устройствах для одного дня свой uuid. Если запись за дату есть — обновляем
  /// поля; иначе создаём новую с локальным uuid.
  Future<void> upsertFromServerByDate({
    required DateTime date,
    int? mood,
    String? note,
    String? insight,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    final existing = await getForDate(normalizedDate);
    if (existing != null) {
      await (update(dayLogsTable)..where((t) => t.id.equals(existing.id)))
          .write(
        DayLogsTableCompanion(
          mood: Value(mood),
          note: Value(note),
          insight: Value(insight),
          updatedAt: Value(updatedAt),
        ),
      );
    } else {
      await into(dayLogsTable).insert(
        DayLogsTableCompanion(
          id: Value(uuidV4()),
          date: Value(normalizedDate),
          mood: Value(mood),
          note: Value(note),
          insight: Value(insight),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
