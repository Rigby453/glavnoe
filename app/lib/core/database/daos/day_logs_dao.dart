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

    if (existing != null) {
      // Строка уже есть — обновляем только mood и note
      await (update(dayLogsTable)..where((t) => t.id.equals(existing.id)))
          .write(
        DayLogsTableCompanion(
          mood: Value(mood),
          note: Value(note),
        ),
      );
    } else {
      // Новая запись — генерируем UUID, фиксируем createdAt
      await into(dayLogsTable).insert(
        DayLogsTableCompanion(
          id: Value(uuidV4()),
          date: Value(normalizedDate),
          mood: Value(mood),
          note: Value(note),
          createdAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
