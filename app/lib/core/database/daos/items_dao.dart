// DAO для таблицы items
// Предоставляет стримы и методы CRUD для задач/событий/дедлайнов
// Используется в Today/Plan экранах через Riverpod-провайдеры

import 'dart:async';

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/day_window.dart';
import '../../utils/id.dart';
import '../../../features/plan/recurrence.dart';
import '../../../services/sound/completion_sound_service.dart';

part 'items_dao.g.dart';

@DriftAccessor(tables: [ItemsTable, SubtasksTable])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  // ---------------------------------------------------------------------------
  // Стримы (реактивные запросы)
  // ---------------------------------------------------------------------------

  /// Все задачи на конкретный календарный день, отсортированные по scheduledAt.
  /// "День" = [локальная полночь date, локальная полночь date+1)
  Stream<List<ItemsTableData>> watchTodayItems(DateTime date) {
    final dayStart = localDayStart(date);
    final dayEnd = localDayEnd(date);

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                // Якорные строки серий (recurrenceRule != null) — это шаблоны,
                // их не показываем как обычные задачи; повторы порождает
                // recurrence_providers через раскрытие (expansion).
                t.recurrenceRule.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// Только MAIN-задачи на день — используются для кольца прогресса
  Stream<List<ItemsTableData>> watchMainItems(DateTime date) {
    final dayStart = localDayStart(date);
    final dayEnd = localDayEnd(date);

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                t.priority.equals('main') &
                t.recurrenceRule.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// Просроченные невыполненные задачи: status=pending и scheduledAt раньше
  /// начала сегодняшнего дня. Используется карточкой утреннего разбора
  /// (перенос несделанного с подтверждением). Сортировка по времени.
  Stream<List<ItemsTableData>> watchOverduePending(DateTime now) {
    final todayStart = localDayStart(now);

    return (select(itemsTable)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.scheduledAt.isSmallerThanValue(todayStart) &
                t.recurrenceRule.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// MAIN-задачи на день (Future-вариант watchMainItems).
  /// Используется StreakService для пересчёта серии после завершения задач.
  Future<List<ItemsTableData>> mainItemsForDay(DateTime date) {
    final dayStart = localDayStart(date);
    final dayEnd = localDayEnd(date);

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                t.priority.equals('main') &
                t.recurrenceRule.isNull(),
          ))
        .get();
  }

  /// Задачи в диапазоне [from, to) реактивно — для месячного вида Plan.
  /// Границы передаёт вызывающий (обычно локальная полночь, как в watchTodayItems).
  Stream<List<ItemsTableData>> watchItemsInRange(DateTime from, DateTime to) {
    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(from) &
                t.scheduledAt.isSmallerThanValue(to) &
                t.recurrenceRule.isNull(),
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
                t.scheduledAt.isSmallerThanValue(to) &
                t.recurrenceRule.isNull(),
          ))
        .get();
  }

  /// Все якорные строки серий (recurrenceRule != null) — шаблоны повторов.
  /// Раскрываются в виртуальные повторы слоем recurrence_providers.
  Stream<List<ItemsTableData>> watchSeriesAnchors() {
    return (select(itemsTable)
          ..where((t) => t.recurrenceRule.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }

  /// Якорь серии по id (или null). Используется для серийных действий
  /// (stop repeating / delete series) над виртуальным повтором.
  Future<ItemsTableData?> getItemById(String id) {
    return (select(itemsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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

  /// Пометить задачу как выполненную.
  /// Побочный эффект: проигрывает короткий звук завершения, если включена
  /// настройка 'completion_sound_enabled' (сервис читает её сам из
  /// SharedPreferences). Срабатывает на всех путях done через DAO — и при
  /// свайпе вправо, и при тапе-чекбоксе. Звук — fire-and-forget, чтобы не
  /// задерживать запись в БД и не ронять завершение при ошибке плеера.
  Future<bool> markDone(String id) async {
    final ok = await updateItem(
      id,
      ItemsTableCompanion(
        status: const Value('done'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (ok) {
      unawaited(CompletionSoundService.instance.playIfEnabled());
    }
    return ok;
  }

  /// Пометить задачу как пропущенную
  Future<bool> markSkipped(String id) => updateItem(
        id,
        ItemsTableCompanion(
          status: const Value('skipped'),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Клонирует ВСЁ запланированное в неделе [weekStart, +7d) на следующую
  /// неделю (scheduledAt + 7 дней), сбрасывая статус в pending. Возвращает
  /// число скопированных. Используется «Clone week» (импорт расписания, C4).
  /// Ревью 2026-06-11: раньше фильтровали по type='event' — пользователь
  /// ожидает копию всей недели, обычные задачи пропускались (баг).
  /// Границы — локальная полночь, согласованы с watchTodayItems/watchMainItems.
  Future<int> cloneWeekEvents(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final events = await (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(weekStart) &
                t.scheduledAt.isSmallerThanValue(weekEnd) &
                // Исключаем якоря серий (recurrenceRule != null): клонировать их
                // строкой создало бы вторую активную серию-дубль. Конкретные
                // (материализованные) дни серий клонируются как обычные строки.
                t.recurrenceRule.isNull(),
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
    // Каскад: удаляем подзадачи задачи (schemaVersion 14). Делаем до удаления
    // строки, чтобы не оставить «осиротевшие» подзадачи в чеклисте.
    await (delete(subtasksTable)..where((t) => t.itemId.equals(id))).go();
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

  /// Ближайшие предстоящие пункты на СЕГОДНЯ от текущего момента.
  /// scheduledAt >= now и в пределах сегодняшнего (локального) дня, статус
  /// pending, сортировка по времени, лимит 4. Используется data-bridge виджета
  /// (§8 WIDGET.md).
  Future<List<ItemsTableData>> upcomingTodayItems(DateTime now) {
    final dayEnd = localDayEnd(now);

    return (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isBiggerOrEqualValue(now) &
                t.scheduledAt.isSmallerThanValue(dayEnd) &
                t.status.equals('pending'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)])
          ..limit(4))
        .get();
  }

  /// Есть ли просроченные (незавершённые) пункты на СЕГОДНЯ до текущего момента
  /// или из прошлых дней со статусом pending. Используется для вычисления
  /// эмоции Kai в виджете (anxious при наличии просрочки).
  Future<bool> hasOverdueItems(DateTime now) async {
    final rows = await (select(itemsTable)
          ..where(
            (t) =>
                t.scheduledAt.isSmallerThanValue(now) &
                t.status.equals('pending'),
          )
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  /// Количество MAIN-задач на конкретный день (для проверки лимита 3).
  /// Получаем список и считаем длину — простой и надёжный подход.
  Future<int> countMainItems(DateTime date) async {
    final dayStart = localDayStart(date);
    final dayEnd = localDayEnd(date);

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

  // ---------------------------------------------------------------------------
  // Повторяющиеся задачи (серии) — материализация одного дня
  // ---------------------------------------------------------------------------

  /// Материализует один день серии [anchorId] на дату [date].
  ///
  /// Это превращает виртуальный повтор в РЕАЛЬНУЮ строку, чтобы зафиксировать
  /// действие пользователя (done/skip/edit/drag) на конкретный день:
  ///   1. читает якорь (шаблон серии) по [anchorId];
  ///   2. вставляет новую concrete-строку (новый uuid, recurrenceRule=null,
  ///      scheduledAt = date + время-суток якоря, поля скопированы из шаблона
  ///      с применёнными [overrides]/[status]);
  ///   3. добавляет [date] в EXDATE правила якоря — раскрытие больше не
  ///      порождает виртуальный повтор на этот день (его представляет concrete).
  ///
  /// Возвращает id новой concrete-строки, либо null если якорь не найден или
  /// не является серией. Идемпотентность по EXDATE обеспечивает addExDateToRule;
  /// при повторном вызове создастся ещё одна concrete-строка — вызывающий код
  /// должен материализовать день не более одного раза (виртуал исчезает после
  /// первой материализации, т.к. дата попадает в EXDATE).
  Future<String?> materializeOccurrence(
    String anchorId,
    DateTime date, {
    String? status,
    String? title,
    String? type,
    String? priority,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? isProtected,
    String? color,
  }) async {
    final anchor = await getItemById(anchorId);
    if (anchor == null) return null;
    final rule = RecurrenceRule.parse(anchor.recurrenceRule);
    if (rule == null) return null; // не серия — нечего материализовать

    // Время-суток повтора берём из якоря; дату — из [date].
    final anchorTime = anchor.scheduledAt;
    final occurrenceAt = scheduledAt ??
        DateTime(
          date.year,
          date.month,
          date.day,
          anchorTime.hour,
          anchorTime.minute,
        );

    // Идемпотентность по (anchorId, date): если день УЖЕ материализован (дата в
    // EXDATE якоря), значит concrete-строка для него создана ранее. Быстрый
    // повторный свайп виртуала (done/skip/snooze возвращают confirmDismiss=false,
    // карточка живёт до ребилда стрима) мог бы вызвать materializeOccurrence
    // второй раз → дубль concrete-строки. Вместо вставки находим существующую
    // строку и применяем к ней статус/правки, возвращая её id.
    if (rule.exDates.contains(_dateOnly(date))) {
      final existing = await _findMaterializedOccurrence(anchor, date);
      if (existing != null) {
        final companion = ItemsTableCompanion(
          title: title != null ? Value(title) : const Value.absent(),
          type: type != null ? Value(type) : const Value.absent(),
          priority: priority != null ? Value(priority) : const Value.absent(),
          status: status != null ? Value(status) : const Value.absent(),
          scheduledAt:
              scheduledAt != null ? Value(scheduledAt) : const Value.absent(),
          durationMinutes: durationMinutes != null
              ? Value(durationMinutes)
              : const Value.absent(),
          isProtected:
              isProtected != null ? Value(isProtected) : const Value.absent(),
          color: color != null ? Value(color) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        );
        await updateItem(existing.id, companion);
        if (status == 'done') {
          unawaited(CompletionSoundService.instance.playIfEnabled());
        }
        return existing.id;
      }
      // EXDATE есть, но concrete-строку не нашли (её могли удалить) — не плодим
      // новую материализацию: день осознанно исключён из серии.
      return null;
    }

    final newId = uuidV4();
    final now = DateTime.now();
    await into(itemsTable).insert(
      ItemsTableCompanion(
        id: Value(newId),
        userId: Value(anchor.userId),
        title: Value(title ?? anchor.title),
        type: Value(type ?? anchor.type),
        priority: Value(priority ?? anchor.priority),
        status: Value(status ?? 'pending'),
        scheduledAt: Value(occurrenceAt),
        durationMinutes: Value(durationMinutes ?? anchor.durationMinutes),
        isProtected: Value(isProtected ?? anchor.isProtected),
        // concrete-строка — НЕ серия.
        recurrenceRule: const Value(null),
        moduleLink: Value(anchor.moduleLink),
        // Цвет: явный аргумент (правка) перекрывает значение якоря.
        color: Value(color ?? anchor.color),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Копируем подзадачи-ШАБЛОН с якоря в новую concrete-строку (schemaVersion 14).
    // Каждая получает НОВЫЙ uuid и itemId = newId, поэтому материализованный день
    // имеет собственную копию чеклиста и может быть переопределён независимо от
    // серии (отметка done / удаление / добавление не влияют на якорь и другие дни).
    final templateSubtasks = await (select(subtasksTable)
          ..where((t) => t.itemId.equals(anchorId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    for (final st in templateSubtasks) {
      await into(subtasksTable).insert(
        SubtasksTableCompanion(
          id: Value(uuidV4()),
          itemId: Value(newId),
          title: Value(st.title),
          // Сохраняем done из шаблона (баг 7): превью прогресса дня (бейдж N/M)
          // читает подзадачи якоря; если на шаблоне подзадача отмечена done,
          // материализация со сбросом в false показала бы расхождение «превью
          // врёт». Обычно шаблон весь не-done, так что поведение не меняется.
          done: Value(st.done),
          sortOrder: Value(st.sortOrder),
        ),
      );
    }

    // Исключаем этот день из генерации виртуальных повторов.
    final updatedRule = addExDateToRule(anchor.recurrenceRule, date);
    await updateItem(
      anchorId,
      ItemsTableCompanion(
        recurrenceRule: Value(updatedRule),
        updatedAt: Value(now),
      ),
    );

    // Материализация повтора со статусом 'done' = завершение задачи →
    // тот же звук, что и markDone (например, свайп вправо по виртуальному
    // повтору серии). Прочие статусы (pending/skipped) звук не проигрывают.
    if (status == 'done') {
      unawaited(CompletionSoundService.instance.playIfEnabled());
    }

    return newId;
  }

  /// Нормализует дату к полуночи (для сравнения по Y/M/D, как EXDATE в правиле).
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Ищет уже материализованную concrete-строку серии [anchor] для дня [date]
  /// (для идемпотентности materializeOccurrence). Concrete-строки не хранят
  /// ссылку на якорь, поэтому матчим по: НЕ-серия (recurrenceRule=null), тот же
  /// userId, и scheduledAt попадает в календарный день [date] (канонический слот
  /// материализации done/skip-правок). Берём самую раннюю при коллизии.
  Future<ItemsTableData?> _findMaterializedOccurrence(
    ItemsTableData anchor,
    DateTime date,
  ) async {
    final dayStart = localDayStart(date);
    final dayEnd = localDayEnd(date);
    final rows = await (select(itemsTable)
          ..where(
            (t) =>
                t.recurrenceRule.isNull() &
                t.userId.equals(anchor.userId) &
                t.scheduledAt.isBiggerOrEqualValue(dayStart) &
                t.scheduledAt.isSmallerThanValue(dayEnd),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .get();
    if (rows.isEmpty) return null;
    // Предпочитаем строку с тем же заголовком, что и якорь (правки могли его
    // изменить — тогда берём первую попавшуюся строку дня как лучший кандидат).
    for (final r in rows) {
      if (r.title == anchor.title) return r;
    }
    return rows.first;
  }

  /// Останавливает серию [anchorId]: ставит UNTIL = день ПЕРЕД [day]
  /// (сегодня и будущее перестают порождать повторы; история/материализованное
  /// прошлое остаются). Возвращает true, если якорь найден и обновлён.
  Future<bool> stopSeries(String anchorId, DateTime day) async {
    final anchor = await getItemById(anchorId);
    if (anchor == null) return false;
    final rule = RecurrenceRule.parse(anchor.recurrenceRule);
    if (rule == null) return false;
    final dayBefore =
        DateTime(day.year, day.month, day.day).subtract(const Duration(days: 1));
    final updatedRule = setUntilOnRule(anchor.recurrenceRule, dayBefore);
    return updateItem(
      anchorId,
      ItemsTableCompanion(
        recurrenceRule: Value(updatedRule),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
