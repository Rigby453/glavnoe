# CODEMAP — карта кода «Главное» / Kaizen (Flutter, app/)

> ЗАДАЧА 0 (разведка). Документ зафиксирован по факту чтения кода (as-built),
> без изменения поведения. Все имена/пути/строки проверены в исходниках.
> Корень: `C:\Users\alune\glavnoe`, приложение: `app/`.
> Дата фиксации: 2026-06-26. Версия схемы Drift: **21** (подтверждено).

---

## 1. Модель задачи/события расписания

**Файл:** `app/lib/core/database/database.dart`
**Таблица:** `ItemsTable` (`tableName => 'items'`), строки 22–84.
DTO генерится Drift: `ItemsTableData`, companion `ItemsTableCompanion`.

Полный список колонок (тип Dart / SQL, дефолт, sync/local):

| Колонка | Тип | Дефолт | Примечание |
|---|---|---|---|
| `id` | Text (PK) | — | UUID, генерится клиентом (uuidV4) |
| `userId` | Text | — | 'local' до авторизации |
| `title` | Text | — | заголовок (хранит `чистый #tag1 #tag2`) |
| `type` | Text | — | task / event / exam / deadline |
| `priority` | Text | `'medium'` | low / medium / high / main |
| `status` | Text | `'pending'` | pending / done / skipped |
| `scheduledAt` | DateTime | — | время задачи |
| `durationMinutes` | Int | `30` | длительность |
| `isProtected` | Bool | `false` | защита от автопереноса (true у main) |
| `recurrenceRule` | Text? | null | iCal-RRULE-строка; null = не серия. **null = обычная строка; not-null = ЯКОРЬ серии** |
| `reminderMinutesBefore` | Int? | null | напоминание за N мин (sync, snake `reminder_minutes_before`), v15 |
| `moduleLink` | Text? | null | **ССЫЛКА НА МОДУЛЬ** — null/'workout'/'meal:breakfast'/'meal:lunch'/'meal:dinner'/'sleep'. ЛОКАЛЬНОЕ (не синкается), v12 |
| `color` | Text? | null | ключ палитры task_colors.dart. Локальное, v13 |
| `location` | Text? | null | свободный текст места. Локальное, v17 |
| `tags` | Text? | null | comma-joined теги. Локальное, v18 |
| `createdAt` | DateTime | — | |
| `updatedAt` | DateTime | — | last-write-wins |

### Есть ли уже поле «тип блока/модуля»?
**ДА — частично.** Поля `type` (task/event/exam/deadline) И `moduleLink`
('workout' | 'meal:breakfast'|'meal:lunch'|'meal:dinner' | 'sleep' | null) уже
существуют. **Отдельного enum-класса для type НЕТ** — это сырые строки.
Канонические списки строк-значений заданы в `add_task_sheet.dart`:
- `const List<String> _types = ['task', 'event', 'exam', 'deadline'];` (стр. 47)
- `const List<String> _priorities = ['low', 'medium', 'high', 'main'];` (стр. 48)
- Показываемые чипами: `_displayTypes = ['task','event','deadline']` (exam сворачивается в deadline, стр. 52), `_displayPriorities = ['main','high','medium']` (low→medium, стр. 55).

Полноценного enum «лекция/семинар/лаба/экзамен/дедлайн» НЕТ: `event` —
один общий тип «занятие/пара/лекция/семинар», `exam` — экзамен/зачёт,
`deadline` — сдать/срок/дедлайн. Различение на уровне ключевых слов (см. §2),
но в БД хранится один из 4 строковых типов.

### «Модуль определяется автоматически по названию» — как работает сейчас
Источник истины при сохранении — `inferModuleLink(title, {type})` из
`app/lib/core/utils/module_inference.dart` (стр. 146). Вызывается в
`add_task_sheet._save()` на всех путях вставки/обновления (стр. 1078, 1105, 1131)
и кладётся в колонку `moduleLink`. Возвращает 'workout' | 'meal:breakfast' |
'meal:lunch' | 'meal:dinner' | 'sleep' | null по ключевым словам (RU+EN).
Карта `_kInferenceKeywords` — `module_inference.dart` стр. 66–131.
**Дубль логики:** параллельно `_detectModuleLink` живёт в `nl_datetime.dart`
(стр. 324) с картой `_moduleKeywords` (стр. 235). Обе намеренно независимы;
`module_inference` — единственная точка истины для записи moduleLink, парсер
лишь подсказывает в UI.

---

## 2. Парсер естественного ввода

**Файл:** `app/lib/core/utils/nl_datetime.dart` (1556 строк).
**Точка входа:** `NlDateTimeResult parseNaturalDateTime(String text, DateTime now)` (стр. 94).

Возвращает `NlDateTimeResult` (стр. 27) с полями:
`when` (DateTime?), `cleanedTitle` (String), `durationMinutes` (int?),
`priority` ('main'|'medium'|'low'|null), `recurrenceRule` (String? RRULE),
`reminderMinutesBefore` (int?), `moduleLink` (String?), `type` (String?).

### Определение типа/модуля по названию
- `String? _detectModuleLink(String text)` — стр. 324. Карта `_moduleKeywords` (стр. 235).
- `String? _detectType(String text)` — стр. 337. Карта `_typeKeywords` (стр. 272).
- Сопоставление по ГРАНИЦАМ СЛОВА: `_Keyword{text, wholeWord}`; стем-префикс
  (`_findStem`) или целое слово (`_findWord`). RU+EN, базовый DE для дат.

### Таблицы соответствий ключевых слов
**moduleLink** (`_moduleKeywords`, nl_datetime.dart 235–266):
- `workout` ← тренировк*, трен(слово), качал*, спортзал*, workout*, gym(слово)
- `meal:breakfast` ← завтрак*, breakfast*
- `meal:lunch` ← пообед*, обед*, lunch*
- `meal:dinner` ← ужин*, dinner*, supper*
- `sleep` ← поспат*, выспат*, спать(слово), сон(слово), sleep*

**type** (`_typeKeywords`, nl_datetime.dart 272–299):
- `exam` ← экзамен*, зачёт/зачет(слово), exam*
- `deadline` ← сдать(слово), сдач*, дедлайн*, срок(слово), deadline*, due(слово)
- `event` ← пара(слово), лекци*, семинар*, занятие*, lecture*, class*

Парсер также извлекает дату/время (RU/EN/DE: «завтра 17:00», «через 2 часа»,
«в пятницу», «18 июня», «18.06», голое «1720»), длительность («1.5ч», «30 мин»,
диапазон «с 7 до 9»), приоритет («p1», «!важно»), повтор («каждый день», см. §8),
напоминание («напомни за 10 мин»). Ключевые слова модуля/типа НЕ вырезаются из
cleanedTitle (смысловое ядро названия).

> Отдельной карты «завтрак/тренировка/сон» как «модуль еды/тренировки» (для
> будущих nutritionMode и т.п.) кроме указанных выше двух карт — НЕ найдено.

---

## 3. Drift / БД

**Файл схемы:** `app/lib/core/database/database.dart`.
**Текущая версия:** `int get schemaVersion => 21;` (стр. 657). **Подтверждено: 21**
(не 18; 18 — это версия добавления колонки `items.tags`, 19 — частота привычек,
20 — custom_breathing, 21 — custom_meditation).
**Миграции:** `MigrationStrategy get migration` → `onUpgrade: (m, from, to)` —
стр. 660–760. Каскад `if (from < N) { ... }` от v2 до v21.

### Образец последней миграции (для новой v22)
```dart
// v21: добавлена таблица custom_meditation (пользовательские
// медитативные сессии, Phase 2). Локальная, без синхронизации.
if (from < 21) {
  await m.createTable(customMeditationTable);
}
```
Добавление колонки — образец v18:
```dart
if (from < 18) {
  await m.addColumn(itemsTable, itemsTable.tags);
}
```
> Для НОВОЙ версии: поднять `schemaVersion` до 22, дописать `if (from < 22)` в
> конце onUpgrade, зарегистрировать новую таблицу/колонку в `@DriftDatabase` и
> перегенерить `database.g.dart` через build_runner.

### Полный список таблиц (`@DriftDatabase`, стр. 615–640)
ItemsTable, StreakTable, WaterLogsTable, DayLogsTable, FoodLogsTable,
SyncQueueTable, ShoppingItemsTable, RecipesTable, RecipeIngredientsTable,
SleepLogsTable, WorkoutsTable, WorkoutExercisesTable, WorkoutSessionsTable,
GoalsTable, GoalStepsTable, HabitsTable, HabitLogsTable, ItemAttachmentsTable,
SubtasksTable, WorkoutSetLogsTable, CustomBreathingTable, CustomMeditationTable.

### DAO (каталог `app/lib/core/database/daos/`) и провайдеры
Провайдеры — `app/lib/core/database/database_providers.dart`.

| DAO (класс) | Файл | Таблицы | Провайдер |
|---|---|---|---|
| `ItemsDao` | daos/items_dao.dart | items, subtasks | `itemsDaoProvider` |
| `StreakDao` | daos/streak_dao.dart | streaks | `streakDaoProvider` |
| `DayLogsDao` | daos/day_logs_dao.dart | day_logs | `dayLogsDaoProvider` |
| `WaterDao` | daos/water_dao.dart | water_logs | `waterDaoProvider` |
| `FoodLogsDao` | daos/food_logs_dao.dart | food_logs | `foodLogsDaoProvider` |
| `ShoppingDao` | daos/shopping_dao.dart | shopping_items | `shoppingDaoProvider` |
| `RecipesDao` | daos/recipes_dao.dart | recipes, recipe_ingredients | `recipesDaoProvider` |
| `SleepDao` | daos/sleep_dao.dart | sleep_logs | `sleepDaoProvider` |
| `WorkoutsDao` | daos/workouts_dao.dart | workouts, workout_exercises, workout_sessions, workout_set_logs | `workoutsDaoProvider` |
| `GoalsDao` | daos/goals_dao.dart | goals, goal_steps | `goalsDaoProvider` |
| `HabitsDao` | daos/habits_dao.dart | habits, habit_logs | `habitsDaoProvider` (через `db.habitsDao`) |
| `ItemAttachmentsDao` | daos/item_attachments_dao.dart | item_attachments | `itemAttachmentsDaoProvider` |
| `SubtasksDao` | daos/subtasks_dao.dart | subtasks | `subtasksDaoProvider` |
| `CustomBreathingDao` | daos/custom_breathing_dao.dart | custom_breathing | `customBreathingDaoProvider` (через `db.customBreathingDao`) |
| `CustomMeditationDao` | daos/custom_meditation_dao.dart | custom_meditation | `customMeditationDaoProvider` (через `db.customMeditationDao`) |

Особо по запросу ТЗ:
- **Задачи:** `ItemsDao` / `ItemsTable` ('items').
- **Еда:** `FoodLogsDao` / `FoodLogsTable` ('food_logs'); + RecipesDao.
- **Привычки:** `HabitsDao` / `HabitsTable` (без явного tableName → 'habits_table'? — см. ниже*), `HabitLogsTable`.
- **Осанка:** отдельной таблицы/DAO НЕТ — `posture_screen` чисто статический контент (`posture_exercises.dart`).
- **Co-study:** отдельной таблицы/DAO НЕТ — `costudy_screen` (Ф3, локально/заглушка).
- **Тренировки:** `WorkoutsDao` (workouts/workout_exercises/workout_sessions/workout_set_logs). Подтверждено имя `WorkoutsDao`.
- **Кастомные дыхательные:** `CustomBreathingDao` / `CustomBreathingTable` ('custom_breathing'). Подтверждено.
- **Кастомные медитации:** `CustomMeditationDao` / `CustomMeditationTable` ('custom_meditation'). Подтверждено.

> *`HabitsTable` и `HabitLogsTable` НЕ переопределяют `tableName` → Drift возьмёт
> snake_case от имени класса: `habits_table` / `habit_logs_table`. (Расхождение —
> см. раздел в конце.) Доступ к DAO — геттер `AppDatabase.habitsDao` (стр. 648).

База открывается через drift_flutter, имя БД `'kaizen'`, web-ассеты sqlite3.wasm +
drift_worker.js (`_openConnection`, стр. 767). Единственный инстанс —
`appDatabaseProvider` (database_providers.dart, стр. 25).

---

## 4. Провайдеры настроек (ОБРАЗЕЦ для новых флагов)

Все настроечные провайдеры читают `sharedPreferencesProvider`
(объявлен в `app/lib/core/theme/theme_provider.dart`). Паттерн — Riverpod
`Notifier`/`NotifierProvider` (новый API) либо `StateNotifierProvider`.

### Образец A — enum-флаг с дефолтом (`fabPositionProvider`)
**Файл:** `app/lib/core/settings/fab_position_provider.dart`.
Тип: `NotifierProvider<FabPositionNotifier, FabPosition>`.
**Ключ SharedPreferences:** `'fab_position'` (const `_kFabPositionKey`, стр. 32).
ЦЕЛИКОМ (это шаблон для будущих nutritionMode/workoutMode):
```dart
enum FabPosition { left, center, right }

const _kFabPositionKey = 'fab_position';

class FabPositionNotifier extends Notifier<FabPosition> {
  @override
  FabPosition build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_kFabPositionKey);
    return FabPosition.values.firstWhere(
      (p) => p.name == saved,
      orElse: () => FabPosition.right, // дефолт
    );
  }

  Future<void> set(FabPosition position) async {
    await ref.read(sharedPreferencesProvider)
        .setString(_kFabPositionKey, position.name);
    state = position;
  }
}

final fabPositionProvider =
    NotifierProvider<FabPositionNotifier, FabPosition>(FabPositionNotifier.new);
```

### Образец B — двух-значный тон (`toneProvider`)
**Файл:** `app/lib/core/settings/tone_provider.dart`.
Тип: `NotifierProvider<ToneNotifier, AppTone>` (enum `AppTone { gentle, harsh }`).
**Ключ SharedPreferences:** `'tone_preference'` (const `_kToneKey`, стр. 64).
Read: `getString(_kToneKey) == 'harsh' ? harsh : gentle` (build, стр. 68).
Write: `setString(_kToneKey, harsh?'harsh':'gentle')` + `state=` (стр. 75–81).
Методы: `toggle()`, `set(AppTone)`. Влияет ТОЛЬКО на тексты (правило проекта).

### Образец C — enum-настройка интенсивности (`reactiveIntensityProvider`)
**Файл:** `app/lib/core/mood/reactive_intensity_provider.dart`.
Тип: `NotifierProvider<ReactiveIntensityNotifier, ReactiveIntensity>`,
enum `ReactiveIntensity { off, slight, full }` с дефолтом `off`.
**Ключ SharedPreferences:** `'reactive_intensity'` (const `_kReactiveIntensityKey`, стр. 16).
Read: switch по строке saved → off/slight/full (стр. 25). Write: `set(value)` пишет
`value.name`. Extension `.multiplier` (off=0.0/slight=0.5/full=1.0) — пример того,
как мапить enum-настройку в числовой коэффициент.

### Прочие настроечные провайдеры (тот же паттерн), каталог `core/settings/`
fab_position, tone, mascot (`mascot_provider.dart` → `showKaiProvider`), sound,
swipe_action, swipe_hint, text_scale, timezone, water_goal, rest_default,
reminder_default, task_presets (durationPresets/reminderPresets),
nutrition_goals, nutrition_targets, macro_override, food_preferences,
health_profile, recent_subjects. Также `core/health/screen_time_provider.dart`
и `features/health/screen_time_provider.dart` (см. §10).

---

## 5. Роутер (go_router)

**Файл:** `app/lib/core/router/app_router.dart`.
Провайдер: `final routerProvider = Provider<GoRouter>(...)` (стр. 64).
`initialLocation: '/today'`. Redirect-гейты (стр. 75–101):
1) онбординг (`onboardingDoneKey`) → `/onboarding`;
2) авторизация/офлайн (`authControllerProvider`) → `/auth`;
3) настройка (`setupDoneKey`) → `/setup`.

### Полный список маршрутов (path → экран)
**Вне оболочки (gate-экраны):**
- `/onboarding` → OnboardingScreen
- `/auth` → AuthScreen
- `/forgot-password` → ForgotPasswordScreen
- `/setup` → SetupFlowScreen (`features/onboarding/setup_flow.dart`)

**StatefulShellRoute (4 таба, оболочка ScaffoldWithNavBar):**
- `/today` → TodayScreen (ветка 0)
- `/plan` → PlanScreen (ветка 1)
- `/health` → HealthScreen (ветка 2)
- `/diary` → DiaryScreen (ветка 3)

**Push-маршруты вне оболочки:**
- `/profile` → ProfileScreen (НЕ таб, из AppBar leading)
- `/profile/custom-theme` → CustomThemeEditorScreen
- `/profile/my-data` → MyDataScreen
- `/focus` → FocusScreen
- `/food` → FoodScreen(targetMeal: `?meal=`)
- `/wrapped` → WrappedScreen
- `/sleep-report` → SleepReportScreen
- `/water` → WaterFullscreenScreen
- `/water-report` → WaterReportScreen
- `/paywall` → PaywallScreen
- `/shopping` → ShoppingListScreen
- `/recipes` → RecipesScreen; `/recipes/:id` → RecipeEditorScreen
- `/breathing` → BreathingScreen
- `/posture` → PostureScreen
- `/warmup` → WarmupScreen
- `/workouts` → WorkoutsScreen; `/workouts/:id` → WorkoutEditorScreen;
  `/workouts/:id/train` → WorkoutTrainerScreen;
  `/workouts/exercise/:id/history` → ExerciseHistoryScreen;
  `/workouts/session/:id` → SessionDetailScreen
- `/diary-history` → DiaryHistoryScreen
- `/goals` → GoalsScreen
- `/habits` → HabitsScreen; `/habits/archive` → HabitsArchiveScreen
- `/costudy` → CoStudyScreen
- `/meditation` → MeditationScreen
- `/screen-time` → ScreenTimeScreen
- `/terms` → TermsScreen

> Маршрутов `/water` и `/water-report` — два разных (полноэкранный трекер vs
> отчёт). Экрана `/sleep` НЕТ — сон открывается как `/sleep-report` (moduleLink
> 'sleep' → `/sleep-report`, см. task_list `_openModule`).

### Нижняя навигация (4 таба)
**Файл:** `app/lib/core/router/scaffold_with_nav_bar.dart`, класс `ScaffoldWithNavBar`.
Табы заданы НЕ списком-данными, а инлайн `destinations:` (mobile —
`NavigationBar`, стр. 194–221; wide ≥600px — `NavigationRail`, стр. 112–139):
1. Today — `Icons.wb_sunny(_outlined)`, `nav.today`
2. Plan — `Icons.calendar_today(_outlined)`, `nav.plan`
3. Health — `Icons.favorite(_border)`, `nav.health`
4. Diary — `Icons.menu_book(_outlined)`, `nav.diary`
Индекс ведёт `navigationShell.currentIndex`; `enum TabIndex` (today0/plan1/health2/diary3)
в app_router.dart стр. 52. Контекстные действия таба Plan (Цели/Импорт) — в
едином AppBar (`_planActions`, стр. 49). Profile — leading `ProfileAvatarButton`
(стр. 251) → `/profile`. Брейкпоинт: `Breakpoints.tablet` (`core/utils/breakpoints.dart`).

---

## 6. Today

**Файл:** `app/lib/features/today/today_screen.dart`, класс `TodayScreen` (ConsumerWidget, стр. 58).
Два макета: `_buildMobileLayout` (стр. 149) и `_buildTabletLayout` (стр. 246).

### Порядок секций мобильного `ListView` (`_buildMobileLayout`, стр. 199–235)
1. `_KaiHeaderSection` — Kai-шапка (маскот 104dp + речевой пузырь + приветствие + тумблер тона) — стр. 204
2. `SizedBox(32)` → `Center(ProgressRing(items: mainItems))` — кольцо прогресса (только main) — стр. 221
3. `SizedBox(32)` → `StreakRow()` — серия — стр. 224
4. `SizedBox(32)` → `MorningReviewCard()` — стр. 227
5. `EveningReviewCard()` — стр. 228
6. `SizedBox(32)` → `OverdueSection()` — секция «Просрочено» (ember) — стр. 231
7. `TaskList(items: items, day: now)` — основной список задач — стр. 232
8. `HabitsTodaySection()` — «Привычки сегодня» (ADR-053) — стр. 234

В планшетном макете (стр. 246): левая колонка — шапка/кольцо/серия/обзоры;
правая колонка — Overdue + TaskList + HabitsTodaySection (стр. 285–338).

### Ключевые провайдеры (today_screen.dart)
- `todayItemsProvider` (стр. 43) — реэкспорт `expandedDayItemsProvider(today)` (раскрытые задачи дня = конкретные + виртуальные повторы серий).
- `todayMainItemsProvider` (стр. 53) — `itemsDao.watchMainItems(now)` для кольца.
- `overduePendingProvider` — объявлен в `morning_review_card.dart` (стр. 35).
- Логика эмоции Kai (success/away/anxious/thinking/neutral) — стр. 113–131.
FAB: ряд `_UndoFab` (стр. 464, виден если есть `lastUndoableActionProvider`) + `FloatingActionButton(+)` → `showAddTaskSheet(context, day: now)`. Позиция FAB — `fabPositionProvider.fabLocation`.

---

## 7. Добавление задачи

**Файл:** `app/lib/features/today/widgets/add_task_sheet.dart` (2604 строки).
Вход: `Future<void> showAddTaskSheet(context, {required DateTime day, ItemsTableData? existing, DateTime? initialAt, int? initialDurationMinutes})` (стр. 97).
Виджет: `AddTaskSheet` (ConsumerStatefulWidget, стр. 142), state `_AddTaskSheetState`.

- **Тип/приоритет:** чипы из `_displayTypes`/`_displayPriorities`; поля `_type`,
  `_priority`. Тап приоритета → `_onPriorityTap` (стр. 659), который ЭНФОРСИТ
  лимит **max 3 main/день** (`_maxMainPerDay=3`, `dao.countMainItems`, стр. 668).
- **Парсер:** listener `_onTitleChanged` (стр. 361) зовёт
  `parseNaturalDateTime(text, DateTime.now())` и автоподставляет дату/время,
  длительность, приоритет, повтор, напоминание, тип — каждое поле до первого
  ручного выбора (флаги `_userPicked*`). Кэш разбора `_lastParseResult`.
- **moduleLink:** НЕ из парсера, а из `inferModuleLink(_cleanedTitle, type: _type)`
  при `_save` (стр. 1078/1105/1131) → колонка moduleLink.
- **Повтор (RRULE):** контролы `_repeatFreq`(RecurFreq?), `_repeatWeekdays`(Set<RecurWeekday>),
  `_repeatMonthDay`(int?), `_repeatUntil`(DateTime?). Сборка строки — `_buildRuleString()`
  (стр. 1212) через `dailyRule/weeklyRule/monthlyRule` + `.toRuleString()`.
- **Сохранение `_save()` (стр. 1013):** 3 ветки —
  1) `_isVirtualOccurrence` → `dao.materializeOccurrence(...)` (материализация дня серии);
  2) `_isEditing` → `dao.updateItem(...)` (включая возможное превращение задачи в серию);
  3) новая → `dao.insertItem(...)`. Заголовок собирается `buildStoredTitle(_cleanedTitle, _tags)`.
- Доп.: подзадачи (`_persistSubtasks`), вложения фото/видео (`_pendingAttachmentItemId='__pending__'`,
  перепривязка в _save), теги, локация, напоминание (`_applyReminder` → notificationService),
  голосовой ввод (speech_to_text), undo через `lastUndoableActionProvider`.

---

## 8. Повторяющиеся задачи (RRULE)

**Файл библиотеки правил:** `app/lib/features/plan/recurrence.dart` (чистый Dart, 439 строк).
- `enum RecurFreq { daily, weekly, monthly }` (стр. 30).
- `enum RecurWeekday { mo..su }` с `dartWeekday`(1..7) и iCal `token`(MO..SU) (стр. 34).
- `class RecurrenceRule { freq, until, exDates, byDays, byMonthDay }` (стр. 110).
- Формат хранения (строка в `items.recurrenceRule`): iCal-подобный,
  `FREQ=DAILY|WEEKLY|MONTHLY[;BYDAY=MO,WE][;BYMONTHDAY=15][;UNTIL=YYYY-MM-DD][;EXDATE=YYYYMMDD,...]`.
  Парс/сериализация: `RecurrenceRule.parse(raw)` (стр. 142) / `.toRuleString()` (стр. 202).
- Конструкторы: `dailyRule`, `weeklyRule(days)`, `monthlyRule(monthDay)` (стр. 427–438).
- Логика: `occursOn(rule, anchorStart, day)` (стр. 271), `occurrenceDatesInRange(...)` (стр. 295).
- Хелперы модификации: `addExDateToRule` (стр. 406), `setUntilOnRule` (стр. 415).

**Способы задать повтор:** ежедневно (DAILY), по дням недели (WEEKLY;BYDAY),
N-числа месяца (MONTHLY;BYMONTHDAY). «N раз в неделю» для ЗАДАЧ через RRULE
**НЕ** выражается (только конкретные дни недели). Для ПРИВЫЧЕК «N раз в неделю»
реализовано отдельно (см. §10, `HabitsTable.frequencyType='weekly_count'`).

**Разворачивание в ленту дня:** `app/lib/features/plan/widgets/recurrence_providers.dart`.
Якорь серии (`recurrenceRule != null`) ИСКЛЮЧАЕТСЯ из обычных запросов дня
(`ItemsDao.watchTodayItems` фильтрует `recurrenceRule.isNull()`), а виртуальные
повторы добавляются слоем раскрытия:
- `buildVirtualOccurrence(anchor, day)` → копия с синтетическим id `${anchorId}@yyyymmdd`, `recurrenceRule=null`, `status='pending'` (стр. 52).
- `mergeOccurrencesForDay/Range` — чистые функции слияния (стр. 75/95).
- Провайдеры: `seriesAnchorsProvider` (стр. 124), `expandedDayItemsProvider(date)` (стр. 131), `expandedRangeItemsProvider((from,to))` (стр. 144).
- Утилиты id: `isVirtualOccurrenceId`, `anchorIdFromVirtual`, `dateFromVirtual` (стр. 29–49).
Материализация дня (фиксация done/skip/правки) — `ItemsDao.materializeOccurrence(anchorId, date, ...)` (items_dao.dart стр. 381): создаёт concrete-строку + добавляет дату в EXDATE якоря + копирует подзадачи-шаблон.

### Может ли привычка быть выражена через RRULE-задачу?
**ЧАСТИЧНО, но в текущем коде — НЕТ, это разные подсистемы.** Привычки имеют
СВОЮ таблицу `habits`/`habit_logs` и свою модель частоты (`frequencyType` =
daily/weekly_days/weekly_count, `weekdayMask`, `weeklyTarget` — ADR-053, v19),
отдельную от RRULE задач. Технически daily/weekly_days привычки ≈ DAILY/WEEKLY
RRULE, НО «weekly_count» (N раз/нед без фикс. дней) RRURE-задачей не выражается,
и привычки трекаются счётчиком выполнений в день (`habit_logs.count`), а не
статусом задачи. Поэтому слияние «привычка как повторяющаяся задача» потребует
либо расширения RRULE (FREQ=WEEKLY;COUNT-семантика), либо моста habits→items.

---

## 9. Разбор дня (rule-based)

**Общая логика:** `app/lib/features/today/widgets/review_engine.dart`.
Чистые функции + запись в Drift:
- `class PlanVariant {label, reason, assign}` (стр. 13).
- `buildVariants(candidates, dayItems, day)` → 2–3 варианта раскладки (frontloaded/spread_out/afternoon_start) (стр. 63).
- `freeSlots(day, occupied)` — 30-мин слоты 08:00–22:00 (стр. 31).
- `distributeToDay(items, day, dayItems)` — раскладка пачки без коллизий (стр. 124).
- `moveToDay` / `moveAllToDay` / `applyVariant` — запись через itemsDao (стр. 89/242/263).
- `mapAiPlans(raw)` — маппинг ответа `/ai/redistribute` в PlanVariant (стр. 279).

**Утренний разбор:** `app/lib/features/today/widgets/morning_review_card.dart`,
класс `MorningReviewCard` (ConsumerStatefulWidget, стр. 46) + лист `_MorningReviewSheet`.
Триггер: `overduePendingProvider` (стр. 35) = `itemsDao.watchOverduePending(now)`
(просроченные `type='task'`, pending, не серия). AI: `/ai/morning-message` (tone-aware),
`/ai/redistribute` (premium-варианты). Кнопки: перенести на сегодня / move all / skip.

**Вечерний разбор:** `app/lib/features/today/widgets/evening_review_card.dart`,
класс `EveningReviewCard` (ConsumerWidget, стр. 56) + лист `_EveningReviewSheet`.
Показывается с 17:00 (`_eveningHour=17`, стр. 30). Провайдеры `_todayPendingProvider`
(сегодняшние pending task) и `_tomorrowItemsProvider`. Переносит несделанное на завтра.

### Куда встраивать сигнал «экранного времени» в вечерний разбор
В `EveningReviewCard.build` (evening_review_card.dart ~стр. 60–138) — между
tone-текстом (стр. 122) и кнопкой «План на завтра» (стр. 129), либо в
`_EveningReviewSheet.build`. Источник данных по экранному времени:
`features/health/screen_time_provider.dart` / `screen_time_usage_provider.dart`
и канон. категории `screen_time_categories.dart` + советы `screen_time_advice.dart`
(см. §10). Сейчас никакого экранного-времени-сигнала в разборе НЕТ — это
greenfield-вставка.

### Diary
**Файл:** `app/lib/features/diary/diary_screen.dart` (см. §10/раздел агента ниже).
DAO: `DayLogsDao` (day_logs). История — `/diary-history` (DiaryHistoryScreen),
wrapped — `/wrapped`.

---

## 10. Модули под растворение (для задач 6-9)

### health_screen.dart — список плиток-лаунчеров
**Файл:** `app/lib/features/health/health_screen.dart`, метод `_buildNavTileCards`
(стр. 361–468). Сверху экрана — карточки Воды и Сна (не плитки-лаунчеры).
Плитки (ListTile → `context.push`):
1. Еда — `restaurant_outlined` → `/food`
2. Фокус-сессии — `timer_outlined` → `/focus`
3. Тренировки — `fitness_center_outlined` → `/workouts`
4. Зарядка/растяжка — `accessibility_new_outlined` → `/warmup`
5. Дыхание — `air` → `/breathing`
6. Медитация — `spa_outlined` → `/meditation`
7. Осанка — `self_improvement` → `/posture`
8. Экранное время — `phone_android_outlined` → `/screen-time`
9. Трекер привычек — `track_changes_outlined` → `/habits`
10. Совместная учёба — `people_outline` → `/costudy`
(Вода → `/water` /`/water-report`, Сон → `/sleep-report` — отдельные карточки сверху.)

### Внутренняя структура модульных экранов

**habits_screen.dart** — `HabitsScreen` (ConsumerWidget, стр. 55), маршрут `/habits`.
Две секции: хорошие привычки (прогресс-бары, streak, кнопка лога) и плохие
(счётчик нарушений, дней «чисто»). Тап карточки → detail-sheet; свайп — удалить;
меню — архив/удалить. В AppBar — кнопка архива (`/habits/archive`).
Провайдеры: `_habitsProvider` (стр. 21), `_archivedHabitsProvider` (стр. 26),
`_habitTodayCountProvider` (family<int,String>, стр. 35),
`_habitStatsProvider` (family<HabitStats,HabitsTableData>, стр. 43),
`_habitDayCountsProvider` (FutureProvider family, стр. 50). DAO — `HabitsDao`.
Раздел «Привычки сегодня» на Today — `today/widgets/habits_today_section.dart`.

**posture_screen.dart** — `PostureScreen` (ConsumerWidget, стр. 61), маршрут `/posture`.
Карточка-тумблер напоминаний об осанке (запрос разрешения, расписание/отмена
уведомлений) + сворачиваемый список упражнений (контент из `posture_exercises.dart`).
Провайдер `postureRemindersProvider` (NotifierProvider<…,bool>, стр. 53),
ключ SharedPreferences `'posture_reminders_on'`. Своей Drift-таблицы НЕТ.

**costudy_screen.dart** — `CoStudyScreen` (ConsumerStatefulWidget, стр. 19), маршрут `/costudy`.
Карточка сессии (таймер, код сессии, старт/стоп) + группы + друзья + недельный
лидерборд. Провайдеры `_activeSessionProvider` (StateProvider<String?>, стр. 16),
`_sessionStartProvider` (StateProvider<DateTime?>, стр. 17). Своей Drift-таблицы НЕТ (Ф3/заглушка).

**screen_time_screen.dart** — `ScreenTimeScreen` (ConsumerStatefulWidget, стр. 35), маршрут `/screen-time`.
3 секции: (1) лимиты по категориям (social/video/games/browsing/messaging) —
тап открывает sheet со слайдером 15–720 мин / «без лимита»; (2) фактическое
использование (Android: PACKAGE_USAGE_STATS) — прогресс-бары, бейджи «over limit»,
контекстный совет; (3) 3 wellness-совета. Использует импортированные
`screenTimeLimitsProvider` и `screenTimeUsageProvider` (своих провайдеров не объявляет).

- **screen_time_provider.dart:** `screenTimeLimitsProvider`
  (StateNotifierProvider<…, Map<String,int>>, стр. 66), ключ SharedPreferences
  `'screen_time_limits'` (JSON-карта), метод `setLimit(category, minutes)`.
  Дисплей-имена — `screenTimeCategories` (const Map, стр. 16).
- **screen_time_advice.dart** (чистые функции): `enum ScreenTimeLevel {ok, much, tooMuch}`
  (стр. 14); `kScreenTimeDefaultThresholds` (social60/video90/games120/browsing60/
  messaging90/other720, стр. 19); `screenTimeLevel(used, limit, category)` (стр. 36);
  `screenTimeAdviceKey(category, level, tone)` → l10n-ключ
  `'screentime_advice_{category}_{level}_{gentle|harsh}'` (стр. 53).
- Также: `screen_time_usage_provider.dart` (факт по Android), `screen_time_categories.dart`.

**warmup_screen.dart** — `WarmupScreen` (StatelessWidget, стр. 24), маршрут `/warmup`.
Список гайдед-рутин (карточки с иконкой/именем/описанием/метаданными). Тап →
`_WarmupPlayerScreen`: пошаговый прогресс, круг-таймер (обратный отсчёт) ИЛИ
круг-счётчик повторов, инструкции, превью следующего, пауза/плей, «Далее», «Завершить».

**warmup_routines.dart** — данные готовых комплексов (без виджетов):
- `class WarmupStep` (стр. 18): `nameKey`, `descKey` (l10n), `seconds`(int?), `reps`(int?),
  `icon`; ровно одно из seconds/reps; геттеры `isReps`, `approxSeconds`.
- `class WarmupRoutine` (стр. 54): `id`(slug), `nameKey`, `descKey`, `icon`,
  `steps`(List<WarmupStep>); геттер `approxMinutes`.
- `const kWarmupRoutines` (стр. 87): **2 комплекса** —
  `'morning'` (7 шагов: neck rolls, shoulder circles, arm swings, torso twists,
  side bends, squats×12, jumping jacks) и `'stretch'` (7 шагов растяжки).
  Все строки — l10n-ключи (напр. `'warmup.morning.name'`), резолв через `context.s()`.

**diary_screen.dart** — `DiaryScreen` (ConsumerStatefulWidget, стр. 36), маршрут `/diary`.
DAO — `DayLogsDao`. Карточки/секции по порядку (mobile):
1. Mood-селектор (5 эмодзи 1–5);
2. Поле заметки (4 строки);
3. «Что пошло не так» — Wrap FilterChip-ов (social_media/went_out/was_tired/sick/other);
4. «Save Day» (upsert в Drift);
5. «Get AI Insight» (premium, API);
6. «This Week / Wrapped» → `/wrapped`;
7. Карточка «Plan vs Fact» (planned/done/skipped);
8. «Quick Insight» (rule-based недельные инсайты);
9. «Life Insights» (сон 7д + вода 7д).
Импортированные провайдеры: `todayPlanVsFactProvider`, `weeklyDiaryInsightProvider`,
`recentNightsProvider`, `weekWaterProvider`.

---

## Расхождения и заметки

Сюда вписывать, если реальное имя в коде отличается от ожидаемого в ТЗ.
Найденные на момент фиксации:

1. **Версия схемы Drift = 21, а НЕ 18** (ТЗ ожидало 18). 18 — это лишь версия,
   где добавили `items.tags`. Текущая: `schemaVersion => 21` (database.dart:657).
2. **Поля «тип блока/модуля» в задаче:** есть `type` (4 строки) и `moduleLink`
   (workout/meal:*/sleep). Отдельного enum-типа НЕТ — это сырые строки;
   канонические списки — в `add_task_sheet.dart` (`_types`, `_priorities`).
   Enum «лекция/семинар/лаба/экзамен/дедлайн» как отдельные значения НЕ
   существует: лекция/семинар/пара = один `event`; лабы отдельно НЕТ.
3. **Дублирование инференса модуля:** карта ключевых слов есть в ДВУХ местах —
   `core/utils/module_inference.dart` (`inferModuleLink`, источник истины для
   записи) и `core/utils/nl_datetime.dart` (`_detectModuleLink`, для подсказок UI).
   При рефакторинге свести к одной.
4. **`HabitsTable`/`HabitLogsTable` без явного `tableName`** → Drift сгенерит
   `habits_table` / `habit_logs_table` (а не 'habits'/'habit_logs', как у других
   таблиц с явным `tableName`). Проверять реальные имена в `database.g.dart`,
   если пишется сырой SQL.
5. **`/sleep` маршрута нет** — moduleLink 'sleep' ведёт на `/sleep-report`
   (task_list `_openModule`). Аналогично нет `/sleep` экрана отдельно от отчёта.
6. **Привычки НЕ выражены через RRURE задач** — отдельная подсистема
   (habits/habit_logs + frequencyType/weekdayMask/weeklyTarget, ADR-053). «N раз
   в неделю» в RRULE задач не выражается.
7. **Сигнала экранного времени в вечернем разборе пока НЕТ** — место вставки
   указано в §9; данные есть в `features/health/screen_time_*`.
