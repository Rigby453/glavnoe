// DAO для таблицы items
// Предоставляет стримы и методы CRUD для задач/событий/дедлайнов
// Используется в Today/Plan экранах через Riverpod-провайдеры

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

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

  /// MAIN-задачи на день (Future-вариант watchMainItems).
  /// Используется StreakService для пересчёта серии после завершения задач.
  Future<List<ItemsTableData>> mainItemsForDay(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                t.priority.equals('main'),
          ))
        .get();
  }

  /// Задачи в диапазоне [from, to) реактивно — для месячного вида Plan.
  /// Границы передаёт вызывающий (обычно UTC-полночь, как в watchTodayItems).
  Stream<List<ItemsTableData>> watchItemsInRange(DateTime from, DateTime to) {
    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(from) &
                t.scheduledAt.isSmallerThanValue(to),
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

  /// Клонирует ВСЁ запланированное в неделе [weekStartUtc, +7d) на следующую
  /// неделю (scheduledAt + 7 дней), сбрасывая статус в pending. Возвращает
  /// число скопированных. Используется «Clone week» (импорт расписания, C4).
  /// Ревью 2026-06-11: раньше фильтровали по type='event' — пользователь
  /// ожидает копию всей недели, обычные задачи пропускались (баг).
  /// Границы — UTC-полночь, согласованы с watchTodayItems/watchMainItems.
  Future<int> cloneWeekEvents(DateTime weekStartUtc) async {
    final weekEnd = weekStartUtc.add(const Duration(days: 7));
    final events = await (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(weekStartUtc) &
                t.scheduledAt.isSmallerThanValue(weekEnd),
          ))
        .get();

    final now = DateTime.now();
    for (final e in events) {
      await into(itemsTable).insert(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: Value(e.userId),
          title: Value(e.title),
          type: Value(e.type),
          priority: Value(e.priority),
          status: const Value('pending'),
          scheduledAt: Value(e.scheduledAt.add(const Duration(days: 7))),
          durationMinutes: Value(e.durationMinutes),
          isProtected: Value(e.isProtected),
          recurrenceRule: Value(e.recurrenceRule),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    return events.length;
  }

  /// Удалить задачу по UUID; возвращает true, если строка была найдена.
  /// Кладёт «надгробие» (tombstone) в sync_queue, чтобы удаление доехало до
  /// сервера на следующей синхронизации (иначе удалённая задача вернулась бы
  /// обратно из ответа /sync). Запись в sync_queue идёт через attachedDatabase,
  /// поэтому таблица не нужна в @DriftAccessor этого DAO.
  Future<bool> deleteItem(String id) async {
    final rowsAffected = await (delete(itemsTable)
          ..where((t) => t.id.equals(id)))
        .go();
    if (rowsAffected > 0) {
      await attachedDatabase.into(attachedDatabase.syncQueueTable).insert(
            SyncQueueTableCompanion(
              tableName_: const Value('items'),
              recordId: Value(id),
              operation: const Value('delete'),
              payload: const Value(''),
              createdAt: Value(DateTime.now()),
            ),
          );
    }
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
