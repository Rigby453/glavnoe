// DAO для таблицы items
// Предоставляет стримы и методы CRUD для задач/событий/дедлайнов
// Используется в Today/Plan экранах через Riverpod-провайдеры

import 'package:drift/drift.dart';

import '../database.dart';

part 'items_dao.g.dart';

@DriftAccessor(tables: [ItemsTable])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  // ---------------------------------------------------------------------------
  // Стримы (реактивные запросы)
  // ---------------------------------------------------------------------------

  /// Все задачи на конкретный календарный день, отсортированные по scheduledAt.
  /// "День" = [date 00:00:00 UTC, date+1 00:00:00 UTC)
  Stream<List<ItemsTableData>> watchTodayItems(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// Только MAIN-задачи на день — используются для кольца прогресса
  Stream<List<ItemsTableData>> watchMainItems(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                t.priority.equals('main'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// Просроченные невыполненные задачи: status=pending и scheduledAt раньше
  /// начала сегодняшнего дня. Используется карточкой утреннего разбора
  /// (перенос несделанного с подтверждением). Сортировка по времени.
  Stream<List<ItemsTableData>> watchOverduePending(DateTime now) {
    final todayStart = DateTime.utc(now.year, now.month, now.day);

    return (select(itemsTable)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.scheduledAt.isSmallerThanValue(todayStart),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// Все задачи в диапазоне [from, to) — для weekly wrapped.
  Future<List<ItemsTableData>> itemsInRange(DateTime from, DateTime to) {
    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(from) &
                t.scheduledAt.isSmallerThanValue(to),
          ))
        .get();
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Вставить задачу; возвращает UUID (id), переданный в companion
  Future<String> insertItem(ItemsTableCompanion companion) async {
    await into(itemsTable).insert(companion);
    return companion.id.value;
  }

  /// Обновить запись по UUID; возвращает true, если строка была найдена и обновлена
  Future<bool> updateItem(String id, ItemsTableCompanion companion) async {
    final rowsAffected = await (update(itemsTable)
          ..where((t) => t.id.equals(id)))
        .write(companion);
    return rowsAffected > 0;
  }

  /// Пометить задачу как выполненную
  Future<bool> markDone(String id) => updateItem(
        id,
        ItemsTableCompanion(
          status: const Value('done'),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Пометить задачу как пропущенную
  Future<bool> markSkipped(String id) => updateItem(
        id,
        ItemsTableCompanion(
          status: const Value('skipped'),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Удалить задачу по UUID; возвращает true, если строка была найдена
  Future<bool> deleteItem(String id) async {
    final rowsAffected = await (delete(itemsTable)
          ..where((t) => t.id.equals(id)))
        .go();
    return rowsAffected > 0;
  }

  /// Количество MAIN-задач на конкретный день (для проверки лимита 3).
  /// Получаем список и считаем длину — простой и надёжный подход.
  Future<int> countMainItems(DateTime date) async {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final rows = await (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                t.priority.equals('main'),
          ))
        .get();
    return rows.length;
  }
}
