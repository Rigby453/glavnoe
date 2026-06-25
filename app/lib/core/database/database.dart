// Drift-схема базы данных Kaizen
// Офлайн-первый подход: все данные сначала пишутся сюда, синхронизация вторична
// Версия схемы: 1
// Источник правды по колонкам: /docs/data-model.md

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/habits_dao.dart';

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

  // Напоминание перед задачей: за сколько минут до scheduledAt уведомить.
  // null или 0 = нет напоминания; >0 = за N минут. Синхронизируется
  // (snake_case reminder_minutes_before). Добавлено в schemaVersion 15.
  IntColumn get reminderMinutesBefore => integer().nullable()();

  // Ссылка на модуль: null | 'workout' | 'meal:breakfast' | 'meal:lunch' |
  // 'meal:dinner' | 'sleep'. Локальное поле — НЕ синхронизируется с сервером.
  TextColumn get moduleLink => text().nullable()();

  // Пользовательский цвет-метка задачи: ключ палитры из task_colors.dart
  // (например 'tomato') или null = нет цвета. Локальная колонка
  // (не синхронизируется), добавлено в schemaVersion 13. Аналогично moduleLink.
  TextColumn get color => text().nullable()();

  // Место/локация задачи (как в Google Calendar): свободный текст —
  // «Аудитория 305», «Зал» и т.п., или null = не указано. Локальная колонка
  // (НЕ синхронизируется с сервером, нет в sync-payload), добавлено в
  // schemaVersion 17. По образцу color/moduleLink.
  TextColumn get location => text().nullable()();

  // Теги задачи: comma-joined строка («shopping,urgent»), или null = нет тегов.
  // Теги извлекаются парсером из заголовка при сохранении и хранятся отдельно
  // для быстрого поиска. Локальная колонка (НЕ синхронизируется с сервером,
  // нет в sync-payload), добавлено в schemaVersion 18. По образцу moduleLink.
  TextColumn get tags => text().nullable()();

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

  // Время последнего изменения — для синхронизации (last-write-wins).
  // Добавлено в schemaVersion 2 (миграция addColumn).
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Записи о съеденном (Food). Локально; числа КБЖУ уже посчитаны на грамм порции.
/// Добавлено в schemaVersion 3.
class FoodLogsTable extends Table {
  @override
  String get tableName => 'food_logs';

  TextColumn get id => text()();

  // День (UTC-полночь), как у других дневных сущностей
  DateTimeColumn get date => dateTime()();

  // Приём пищи: breakfast / lunch / dinner / snack
  TextColumn get meal => text().withDefault(const Constant('snack'))();

  TextColumn get name => text()();

  // Сколько грамм съедено
  RealColumn get grams => real().withDefault(const Constant(100))();

  // Абсолютные значения для этой порции (per100g * grams/100); null если неизвестно
  RealColumn get calories => real().nullable()();
  RealColumn get protein => real().nullable()();
  RealColumn get fat => real().nullable()();
  RealColumn get carbs => real().nullable()();
  RealColumn get sugar => real().nullable()();
  RealColumn get fiber => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Записи сна (Sleep tracker, Phase 2). Локальный, offline-first.
/// startAt — время отхода ко сну; endAt — null пока ночь не завершена.
/// Добавлено в schemaVersion 6.
class SleepLogsTable extends Table {
  @override
  String get tableName => 'sleep_logs';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Время начала (лёг спать)
  DateTimeColumn get startAt => dateTime()();

  // Время конца (проснулся); null = ночь ещё идёт
  DateTimeColumn get endAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Список покупок (SPEC C5, Phase 1). Локальный, без синхронизации (Ф3).
/// id — UUID, генерируется клиентом. Добавлено в schemaVersion 4.
class ShoppingItemsTable extends Table {
  @override
  String get tableName => 'shopping_items';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Название продукта/позиции
  TextColumn get name => text()();

  // Количество в свободной форме: «2 шт», «500 г», null = не указано
  TextColumn get quantity => text().nullable()();

  // Отмечен как купленный
  BoolColumn get checked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  // Время изменения (для сортировки и будущей синхронизации)
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Пользовательские рецепты (SPEC C5, Phase 1). Локальные, без синхронизации.
/// Добавлено в schemaVersion 5.
class RecipesTable extends Table {
  @override
  String get tableName => 'recipes';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Название рецепта
  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Время последнего изменения (для сортировки)
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ингредиенты рецепта. Числа КБЖУ — «на 100 г», копируются из продукта при добавлении.
/// Добавлено в schemaVersion 5.
class RecipeIngredientsTable extends Table {
  @override
  String get tableName => 'recipe_ingredients';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на рецепт (родительский)
  TextColumn get recipeId => text()();

  // Название ингредиента (свободная строка)
  TextColumn get name => text()();

  // Граммы этого ингредиента в рецепте
  RealColumn get grams => real().withDefault(const Constant(100))();

  // Значения питательности «на 100 г» (null если неизвестно)
  RealColumn get calories => real().nullable()();
  RealColumn get protein => real().nullable()();
  RealColumn get fat => real().nullable()();
  RealColumn get carbs => real().nullable()();
  RealColumn get sugar => real().nullable()();
  RealColumn get fiber => real().nullable()();

  // Порядок отображения в редакторе
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Шаблоны тренировок (Phase 2). Локальные, без синхронизации.
/// Добавлено в schemaVersion 7.
class WorkoutsTable extends Table {
  @override
  String get tableName => 'workouts';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Название шаблона тренировки
  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Время последнего изменения (для сортировки)
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Долгосрочные цели пользователя (SPEC C4). Горизонт: month / year / five_years / ten_years.
/// Локальные, без синхронизации (ADR-027). Добавлено в schemaVersion 9.
class GoalsTable extends Table {
  @override
  String get tableName => 'goals';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Название цели
  TextColumn get title => text()();

  // Горизонт: month | year | five_years | ten_years
  TextColumn get horizon => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Привычки пользователя (трекер). Добавлено в schemaVersion 10.
/// type: 'good' (нужно делать) | 'bad' (нужно избегать).
class HabitsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('good'))(); // 'good' | 'bad'
  TextColumn get emoji => text().withDefault(const Constant('✅'))();
  IntColumn get targetPerDay => integer().withDefault(const Constant(1))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  // Частота привычки (ADR-053). Добавлено в schemaVersion 19.
  // frequencyType: 'daily' | 'weekly_days' | 'weekly_count'.
  TextColumn get frequencyType =>
      text().withDefault(const Constant('daily'))();
  // Битовая маска дней недели Пн..Вс = биты 1..64; 127 = все дни (для 'weekly_days').
  IntColumn get weekdayMask => integer().withDefault(const Constant(127))();
  // Цель выполнений в неделю (для 'weekly_count', напр. 3 раза/нед).
  IntColumn get weeklyTarget => integer().withDefault(const Constant(0))();
  // Минуты от полуночи для напоминания; null = напоминания нет.
  IntColumn get reminderMinutes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Логи выполнения привычек по дням. Добавлено в schemaVersion 10.
class HabitLogsTable extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(HabitsTable, #id)();
  DateTimeColumn get date => dateTime()(); // нормализована до 00:00 UTC
  IntColumn get count => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Шаги (подзадачи) долгосрочной цели. Добавлено в schemaVersion 9.
class GoalStepsTable extends Table {
  @override
  String get tableName => 'goal_steps';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на цель
  TextColumn get goalId => text()();

  // Название шага
  TextColumn get title => text()();

  // Выполнен ли шаг
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  // Порядок отображения
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Сессии тренировок (фактические выполнения шаблона). Добавлено в schemaVersion 8.
/// finishedAt = null означает незавершённую сессию (тренировка прервана или в процессе).
class WorkoutSessionsTable extends Table {
  @override
  String get tableName => 'workout_sessions';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на шаблон тренировки (может быть удалён — снапшот имени хранится отдельно)
  TextColumn get workoutId => text()();

  // Снапшот имени тренировки на момент старта (шаблон может быть удалён позже)
  TextColumn get workoutName => text()();

  // Время начала сессии
  DateTimeColumn get startedAt => dateTime()();

  // Время завершения; null = сессия ещё идёт или прервана
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Упражнения в шаблоне тренировки. Добавлено в schemaVersion 7.
class WorkoutExercisesTable extends Table {
  @override
  String get tableName => 'workout_exercises';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на шаблон тренировки
  TextColumn get workoutId => text()();

  // Название упражнения
  TextColumn get name => text()();

  // Количество подходов
  IntColumn get sets => integer().withDefault(const Constant(3))();

  // Количество повторений
  IntColumn get reps => integer().withDefault(const Constant(10))();

  // Вес в кг (опционально)
  RealColumn get weightKg => real().nullable()();

  // Отдых между подходами в секундах
  IntColumn get restSeconds => integer().withDefault(const Constant(60))();

  // Короткая текстовая подсказка по технике (опционально)
  TextColumn get technique => text().nullable()();

  // Порядок отображения в редакторе
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Факты выполненных подходов (set-by-set дневник тренировки).
/// Одна строка = один фактически выполненный подход (reps × weight).
/// Локальные, без синхронизации. Добавлено в schemaVersion 16.
class WorkoutSetLogsTable extends Table {
  @override
  String get tableName => 'workout_set_logs';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на сессию тренировки (workout_sessions.id)
  TextColumn get sessionId => text()();

  // Ссылка на упражнение-шаблон (workout_exercises.id) — для группировки истории
  TextColumn get exerciseId => text()();

  // Индекс подхода внутри упражнения (0-based)
  IntColumn get setIndex => integer()();

  // Фактически выполненные повторения
  IntColumn get reps => integer()();

  // Использованный вес в кг; null = собственный вес (bodyweight)
  RealColumn get weightKg => real().nullable()();

  // Время фиксации подхода
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Вложения к задачам (фото/видео). Локальные, без синхронизации.
/// Добавлено в schemaVersion 11.
class ItemAttachmentsTable extends Table {
  @override
  String get tableName => 'item_attachments';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на задачу
  TextColumn get itemId => text()();

  // Абсолютный путь к файлу на устройстве
  TextColumn get localPath => text()();

  // Тип: 'photo' | 'video'
  TextColumn get type => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Подзадачи (чеклист) обычной задачи. Добавлено в schemaVersion 14.
/// На ЯКОРЕ серии (recurrenceRule != null) подзадачи играют роль ШАБЛОНА —
/// при материализации дня (materializeOccurrence) они копируются в новую
/// concrete-строку (новые uuid, itemId = новой строки), чтобы каждый
/// материализованный день можно было переопределить независимо от серии.
/// Едут в sync-пейлоаде задачи вложенным массивом `subtasks` (snake_case).
class SubtasksTable extends Table {
  @override
  String get tableName => 'subtasks';

  // UUID, генерируется клиентом
  TextColumn get id => text()();

  // Ссылка на задачу (items.id)
  TextColumn get itemId => text()();

  // Текст подзадачи
  TextColumn get title => text()();

  // Выполнена ли подзадача
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  // Порядок отображения в чеклисте
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

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
    FoodLogsTable,
    SyncQueueTable,
    ShoppingItemsTable,
    RecipesTable,
    RecipeIngredientsTable,
    SleepLogsTable,
    WorkoutsTable,
    WorkoutExercisesTable,
    WorkoutSessionsTable,
    GoalsTable,
    GoalStepsTable,
    HabitsTable,
    HabitLogsTable,
    ItemAttachmentsTable,
    SubtasksTable,
    WorkoutSetLogsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Для тестов: in-memory исполнитель (NativeDatabase.memory()).
  AppDatabase.forTesting(super.e);

  /// DAO для трекера привычек (schemaVersion 10).
  HabitsDao get habitsDao => HabitsDao(this);

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: добавлен day_logs.updated_at (для синхронизации дневника).
          if (from < 2) {
            await m.addColumn(dayLogsTable, dayLogsTable.updatedAt);
          }
          // v3: добавлена таблица food_logs (модуль «Еда»).
          if (from < 3) {
            await m.createTable(foodLogsTable);
          }
          // v4: добавлена таблица shopping_items (список покупок, SPEC C5).
          if (from < 4) {
            await m.createTable(shoppingItemsTable);
          }
          // v5: добавлены таблицы recipes и recipe_ingredients (рецепты, SPEC C5).
          if (from < 5) {
            await m.createTable(recipesTable);
            await m.createTable(recipeIngredientsTable);
          }
          // v6: добавлена таблица sleep_logs (трекер сна, Phase 2).
          if (from < 6) {
            await m.createTable(sleepLogsTable);
          }
          // v7: добавлены таблицы workouts и workout_exercises (тренировки, Phase 2).
          if (from < 7) {
            await m.createTable(workoutsTable);
            await m.createTable(workoutExercisesTable);
          }
          // v8: добавлена таблица workout_sessions (сессии тренировок, Phase 2).
          if (from < 8) {
            await m.createTable(workoutSessionsTable);
          }
          // v9: добавлены таблицы goals и goal_steps (долгосрочные цели, SPEC C4).
          if (from < 9) {
            await m.createTable(goalsTable);
            await m.createTable(goalStepsTable);
          }
          // v10: добавлены таблицы habits и habit_logs (трекер привычек).
          if (from < 10) {
            await m.createTable(habitsTable);
            await m.createTable(habitLogsTable);
          }
          // v11: добавлена таблица item_attachments (фото/видео к задачам, локально).
          if (from < 11) {
            await m.createTable(itemAttachmentsTable);
          }
          // v12: добавлена колонка module_link в items (локальная ссылка на модуль).
          if (from < 12) {
            await m.addColumn(itemsTable, itemsTable.moduleLink);
          }
          // v13: добавлена колонка color в items (локальный цвет-метка задачи).
          if (from < 13) {
            await m.addColumn(itemsTable, itemsTable.color);
          }
          // v14: добавлена таблица subtasks (чеклист подзадач у задач).
          if (from < 14) {
            await m.createTable(subtasksTable);
          }
          // v15: добавлена колонка reminder_minutes_before в items
          // (напоминание за N минут до scheduledAt).
          if (from < 15) {
            await m.addColumn(itemsTable, itemsTable.reminderMinutesBefore);
          }
          // v16: добавлена таблица workout_set_logs (дневник подходов).
          if (from < 16) {
            await m.createTable(workoutSetLogsTable);
          }
          // v17: добавлена колонка location в items (локальное место/локация
          // задачи, как в Google Calendar). НЕ синхронизируется — по образцу
          // color/moduleLink.
          if (from < 17) {
            await m.addColumn(itemsTable, itemsTable.location);
          }
          // v18: добавлена колонка tags в items (comma-joined теги из заголовка,
          // извлекаются тег-парсером при сохранении). Локальная колонка —
          // НЕ синхронизируется — по образцу moduleLink/color/location.
          if (from < 18) {
            await m.addColumn(itemsTable, itemsTable.tags);
          }
          // v19: добавлены колонки частоты привычек (ADR-053) — frequencyType,
          // weekdayMask, weeklyTarget, reminderMinutes. Существующие привычки
          // мигрируют как daily/127/0/null (дефолты колонок).
          if (from < 19) {
            await m.addColumn(habitsTable, habitsTable.frequencyType);
            await m.addColumn(habitsTable, habitsTable.weekdayMask);
            await m.addColumn(habitsTable, habitsTable.weeklyTarget);
            await m.addColumn(habitsTable, habitsTable.reminderMinutes);
          }
        },
      );
}

/// Открывает соединение с БД через drift_flutter.
/// Работает на всех платформах: iOS, Android, Web.
/// На вебе нужны ассеты в app/web/ (sqlite3.wasm + drift_worker.js) и явные
/// web-опции — иначе drift_flutter бросает «the `web` parameter needs to be set».
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return driftDatabase(
      name: 'kaizen',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  });
}
