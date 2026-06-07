// Drift-схема базы данных Kaizen
// Офлайн-первый подход: все данные сначала пишутся сюда, синхронизация вторична
// Версия схемы: 1
// Источник правды по колонкам: /docs/data-model.md

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Импорт сгенерированного файла (создаётся build_runner)
part 'database.g.dart';

// ---------------------------------------------------------------------------
// Таблицы
// ---------------------------------------------------------------------------

/// Задачи/события/экзамены/дедлайны пользователя
/// id — UUID, генерируется клиентом (не autoincrement, т.к. синхронизируется с сервером)
class ItemsTable extends Table {
  @override
  String get tableName => 'items';

  // UUID, генерируется клиентом через uuid-пакет
  TextColumn get id => text()();

  // userId = 'local' до реализации авторизации (шаг 8)
  TextColumn get userId => text()();

  TextColumn get title => text()();

  // Тип: task / event / exam / deadline
  TextColumn get type => text()();

  // Приоритет: low / medium / high / main
  TextColumn get priority => text().withDefault(const Constant('medium'))();

  // Статус: pending / done / skipped
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get scheduledAt => dateTime()();

  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();

  // Защищён от автоматического переноса (true для main-задач)
  BoolColumn get isProtected => boolean().withDefault(const Constant(false))();

  // iCal RRULE, null = не повторяется
  TextColumn get recurrenceRule => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Серия дней (streak) пользователя
/// Одна строка на пользователя; для MVP используем userId = 'local'
class StreakTable extends Table {
  @override
  String get tableName => 'streaks';

  // Текущая серия (кол-во дней подряд)
  IntColumn get current => integer().withDefault(const Constant(0))();

  // Рекорд
  IntColumn get longest => integer().withDefault(const Constant(0))();

  // Дата последнего завершённого дня (null = нет данных)
  DateTimeColumn get lastCompletedDate => dateTime().nullable()();

  // Количество использованных заморозок
  IntColumn get freezeCount => integer().withDefault(const Constant(0))();
}

/// Записи потребления воды
class WaterLogsTable extends Table {
  @override
  String get tableName => 'water_logs';

  TextColumn get id => text()();

  IntColumn get amountMl => integer()();

  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Дневные записи (настроение, заметки, инсайты от AI)
class DayLogsTable extends Table {
  @override
  String get tableName => 'day_logs';

  TextColumn get id => text()();

  // Дата дня (хранится как DateTime, время = 00:00 UTC)
  DateTimeColumn get date => dateTime()();

  // Настроение: 1-5, может быть null
  IntColumn get mood => integer().nullable()();

  TextColumn get note => text().nullable()();

  // Инсайт от AI (Phase 1, пока null)
  TextColumn get insight => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Очередь синхронизации: записи, ожидающие отправки на сервер
/// id — autoincrement int (локальный, не синхронизируется)
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get id => integer().autoIncrement()();

  // Имя таблицы: 'items', 'water_logs', 'day_logs'
  TextColumn get tableName_ => text().named('table_name')();

  // UUID записи в исходной таблице
  TextColumn get recordId => text()();

  // Тип операции: create / update / delete
  TextColumn get operation => text()();

  // Данные записи в формате JSON
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();
}

// ---------------------------------------------------------------------------
// База данных
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    ItemsTable,
    StreakTable,
    WaterLogsTable,
    DayLogsTable,
    SyncQueueTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

/// Открывает соединение с БД через drift_flutter
/// Работает на всех платформах: iOS, Android, Web (IndexedDB)
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return driftDatabase(name: 'kaizen');
  });
}
