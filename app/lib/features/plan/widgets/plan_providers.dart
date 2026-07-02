// Провайдеры экрана Plan: режим вида (День/Неделя/Месяц), раскладка
// (список/сетка) и реактивный диапазон задач для месячного календаря.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../../core/utils/day_window.dart';
import 'recurrence_providers.dart';
import 'week_strip.dart' show selectedDayProvider;

/// Режим отображения плана. Порядок видов: День, 3 дня, Неделя, Месяц, Год.
enum PlanView { day, threeDay, week, month, year }

/// Раскладка Day/Week: список (текущее поведение) или сетка времени
/// в стиле Google Calendar. Month всегда показывается как календарь.
enum PlanLayout { list, grid }

/// Текущий выбранный режим вида. По умолчанию — День (текущее поведение).
final planViewProvider = StateProvider<PlanView>((ref) => PlanView.day);

/// Ключ SharedPreferences для раскладки Day/Week.
const _kPlanLayoutPrefsKey = 'plan_layout';

/// Нотифер раскладки Day/Week: хранит выбор и персистирует его в
/// SharedPreferences (паттерн идентичен ThemeNotifier/SwipeHintNotifier).
class PlanLayoutNotifier extends Notifier<PlanLayout> {
  @override
  PlanLayout build() {
    final saved = ref.read(sharedPreferencesProvider).getString(
          _kPlanLayoutPrefsKey,
        );
    // По умолчанию — список (текущее поведение, не ломаем привычку).
    return saved == 'grid' ? PlanLayout.grid : PlanLayout.list;
  }

  /// Переключить и сохранить раскладку.
  Future<void> set(PlanLayout layout) async {
    await ref.read(sharedPreferencesProvider).setString(
          _kPlanLayoutPrefsKey,
          layout == PlanLayout.grid ? 'grid' : 'list',
        );
    state = layout;
  }

  /// Удобный тумблер list ↔ grid.
  Future<void> toggle() => set(
        state == PlanLayout.grid ? PlanLayout.list : PlanLayout.grid,
      );
}

/// Текущая раскладка Day/Week. По умолчанию — список; персистируется.
final planLayoutProvider =
    NotifierProvider<PlanLayoutNotifier, PlanLayout>(PlanLayoutNotifier.new);

/// Задачи в диапазоне [from, to) реактивно — раскрытые: конкретные строки +
/// виртуальные повторы серий. Ключ — запись (from, to) (value-equality в Dart 3).
/// Реэкспортирует expandedRangeItemsProvider — повторы видны в недельной сетке.
final rangeItemsProvider = Provider.autoDispose
    .family<AsyncValue<List<ItemsTableData>>, (DateTime, DateTime)>((ref, range) {
  return ref.watch(expandedRangeItemsProvider(range));
});

/// Счётчик задач по дням за весь [year] — для год-вида (как Google Calendar).
///
/// ЭФФЕКТИВНОСТЬ: один watch на диапазон [1 янв year, 1 янв year+1) через
/// expandedRangeItemsProvider (конкретные строки + раскрытые повторы серий),
/// затем группировка в Dart по ЛОКАЛЬНОМУ дню (localDayKey, не UTC-границы).
/// НЕ 365 отдельных watch — одна подписка на год.
///
/// Возвращает `Map<localDayKey, count>`. Ключ года — int (value-equality).
/// autoDispose: освобождается при уходе с год-вида/смене года.
final yearTaskCountsProvider =
    Provider.autoDispose.family<AsyncValue<Map<String, int>>, int>((ref, year) {
  final yearStart = DateTime(year, 1, 1);
  final yearEnd = DateTime(year + 1, 1, 1);
  final itemsAsync = ref.watch(expandedRangeItemsProvider((yearStart, yearEnd)));
  // Фильтр поиска: при активном запросе год-вид считает «занятость» только по
  // совпавшим задачам (точки-индикаторы остаются на днях с совпадениями).
  final query = ref.watch(planSearchQueryProvider);
  final filters = ref.watch(planFiltersProvider);
  return itemsAsync.whenData((items) {
    final filtered = (query.trim().isEmpty && filters.isEmpty)
        ? items
        : items.where((i) {
            final searchOk =
                query.trim().isEmpty || planSearchMatches(i, query);
            return searchOk && planFilterMatches(i, filters);
          });
    final counts = <String, int>{};
    for (final i in filtered) {
      // День задачи = ЛОКАЛЬНАЯ дата scheduledAt (согласовано с watchTodayItems
      // и месячным видом). localDayKey считает по локальным Y/M/D без toUtc.
      final key = localDayKey(i.scheduledAt);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  });
});

/// Текущий поисковый запрос на экране Plan.
final planSearchQueryProvider = StateProvider<String>((ref) => '');

/// Известные типы элементов (совпадают с ItemsTable.type в data-model).
/// Используются для распознавания токенов вида `exam` / `type:exam`.
const _kSearchTypeKeywords = {'task', 'event', 'exam', 'deadline'};

/// Проверяет, совпадает ли [item] с поисковым запросом [rawQuery].
///
/// Чистая функция (без I/O, без provider) — поэтому юнит-тестируемая.
/// Запрос разбивается по пробелам на токены (регистронезависимо), и
/// элемент проходит фильтр только если совпали ВСЕ токены (AND-семантика):
///   * `#tag` — ищем в поле [tags] (comma-joined строка в Drift, schemaVersion 18)
///     если оно заполнено; иначе — в заголовке целым словом (обратная совместимость
///     для задач, сохранённых до v18 и не прошедших re-save). Регистронезависимо.
///   * `type:VALUE` или голое слово-тип (`task`/`event`/`exam`/`deadline`) —
///     требует `item.type == value`;
///   * любой другой токен — подстрока в заголовке (прежнее поведение).
/// Пустой/пробельный запрос → совпадает со всем.
bool planSearchMatches(ItemsTableData item, String rawQuery) {
  final tokens = rawQuery.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((t) => t.isEmpty);
  if (tokens.isEmpty) return true;

  final title = item.title.toLowerCase();
  final type = item.type.toLowerCase();

  // Нормализованный список тегов из колонки tags (schemaVersion 18).
  // null/пустая → fallback на поиск в заголовке (обратная совместимость).
  final storedTagsRaw = item.tags;
  final storedTags = (storedTagsRaw != null && storedTagsRaw.isNotEmpty)
      ? storedTagsRaw.toLowerCase().split(',').map((t) => t.trim()).toSet()
      : null;

  for (final token in tokens) {
    if (token.startsWith('#')) {
      // Тег-запрос: имя тега = token без «#».
      final tagName = token.substring(1);
      if (storedTags != null) {
        // Ищем в выделенной колонке tags — точное совпадение (без truncation).
        if (!storedTags.contains(tagName)) return false;
      } else {
        // Fallback (задачи до v18 или не прошедшие re-save):
        // ищем #tag как целое слово в заголовке.
        final pattern = RegExp(
          r'(?<![\w#])' + RegExp.escape(token) + r'(?![\w#])',
        );
        if (!pattern.hasMatch(title)) return false;
      }
    } else if (token.startsWith('type:')) {
      // Явный фильтр по типу: type:exam.
      if (type != token.substring('type:'.length)) return false;
    } else if (_kSearchTypeKeywords.contains(token)) {
      // Голое слово-тип: exam / task / event / deadline.
      if (type != token) return false;
    } else {
      // Обычный токен — подстрока в заголовке.
      if (!title.contains(token)) return false;
    }
  }
  return true;
}

/// Ранг приоритета для сортировки: main > high > medium > low.
/// Больше — важнее (используется при равной дате дедлайнов).
int _priorityRank(String priority) {
  switch (priority) {
    case 'main':
      return 3;
    case 'high':
      return 2;
    case 'medium':
      return 1;
    default: // low и любые неизвестные
      return 0;
  }
}

/// Ближайший будущий экзамен или дедлайн (закреплённая карточка Plan).
/// Якорится на ВЫБРАННЫЙ день: смотрит задачи на
/// [начало(selectedDay), начало(selectedDay) + 365 дней). Так при открытии
/// 13-го числа показывается дедлайн после 13-го, а не «сегодня».
/// Сортировка: по дате (возрастание), при равной дате — по приоритету
/// (main > high > medium > low). Возвращает ближайший (один) или null.
final nearestExamDeadlineProvider =
    StreamProvider.autoDispose<ItemsTableData?>((ref) {
  final selectedDay = ref.watch(selectedDayProvider);
  // Ищем от начала выбранного дня (локальная полночь, как watchTodayItems),
  // чтобы дедлайн самого выбранного дня тоже показывался.
  final from = localDayStart(selectedDay);
  final to = from.add(const Duration(days: 365));
  return ref
      .watch(itemsDaoProvider)
      .watchItemsInRange(from, to)
      .map((items) {
    // Отбираем только exam/deadline; ближайший по дате, при равной — по приоритету.
    final urgent = items
        .where((i) => i.type == 'exam' || i.type == 'deadline')
        .toList()
      ..sort((a, b) {
        final byDate = a.scheduledAt.compareTo(b.scheduledAt);
        if (byDate != 0) return byDate;
        // При равной дате — выше приоритет идёт первым (по убыванию ранга).
        return _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
      });
    return urgent.isEmpty ? null : urgent.first;
  });
});

/// Ключ SharedPreferences для свёрнутого состояния дедлайн-карточки.
const _kPinnedDeadlineCollapsedKey = 'plan_deadline_collapsed';

/// Нотифер свёрнутого состояния закреплённой дедлайн-карточки. Хранит выбор
/// и персистирует его в SharedPreferences (паттерн идентичен PlanLayoutNotifier).
/// Сворачивание — НЕ удаление: вернуть полную карточку = тап (toggle).
class PinnedDeadlineCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .read(sharedPreferencesProvider)
            .getBool(_kPinnedDeadlineCollapsedKey) ??
        false; // по умолчанию развёрнуто
  }

  /// Установить и сохранить состояние.
  Future<void> set(bool collapsed) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kPinnedDeadlineCollapsedKey, collapsed);
    state = collapsed;
  }

  /// Переключить свёрнуто ↔ развёрнуто.
  Future<void> toggle() => set(!state);
}

/// Свёрнута ли закреплённая дедлайн-карточка. По умолчанию — нет; персистируется.
final pinnedDeadlineCollapsedProvider =
    NotifierProvider<PinnedDeadlineCollapsedNotifier, bool>(
  PinnedDeadlineCollapsedNotifier.new,
);

// ---------------------------------------------------------------------------
// B6 — Фильтры плана (priority / status / type)
// ---------------------------------------------------------------------------

/// Набор выбранных фильтров на экране Plan.
/// Пустые множества = «фильтр не активен» = показывать всё.
class PlanFilters {
  const PlanFilters({
    this.priorities = const <String>{},
    this.statuses = const <String>{},
    this.types = const <String>{},
  });

  /// Выбранные приоритеты: 'main', 'high', 'medium', 'low'.
  final Set<String> priorities;

  /// Выбранные статусы: 'pending', 'done', 'skipped'.
  final Set<String> statuses;

  /// Выбранные типы: 'task', 'event', 'exam', 'deadline'.
  final Set<String> types;

  /// Нет активных фильтров — показывать всё.
  bool get isEmpty =>
      priorities.isEmpty && statuses.isEmpty && types.isEmpty;

  /// Суммарное число активных фильтров (для бейджа-счётчика на иконке).
  int get activeCount =>
      priorities.length + statuses.length + types.length;

  /// Создать копию с заменёнными полями.
  PlanFilters copyWith({
    Set<String>? priorities,
    Set<String>? statuses,
    Set<String>? types,
  }) =>
      PlanFilters(
        priorities: priorities ?? this.priorities,
        statuses: statuses ?? this.statuses,
        types: types ?? this.types,
      );

  static bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanFilters &&
          _setsEqual(priorities, other.priorities) &&
          _setsEqual(statuses, other.statuses) &&
          _setsEqual(types, other.types);

  @override
  int get hashCode => Object.hash(
        priorities.fold<int>(0, (h, s) => h ^ s.hashCode),
        statuses.fold<int>(0, (h, s) => h ^ s.hashCode),
        types.fold<int>(0, (h, s) => h ^ s.hashCode),
      );
}

/// Активные фильтры экрана Plan. По умолчанию — без фильтров (всё видно).
final planFiltersProvider =
    StateProvider<PlanFilters>((ref) => const PlanFilters());

/// Проверяет, проходит ли [item] набор фильтров [filters].
///
/// Чистая функция (без I/O, без provider) — юнит-тестируемая.
/// Пустой набор фильтров → совпадает со всем.
/// AND-семантика: item должен пройти каждую непустую группу фильтров.
bool planFilterMatches(ItemsTableData item, PlanFilters filters) {
  if (filters.isEmpty) return true;
  if (filters.priorities.isNotEmpty &&
      !filters.priorities.contains(item.priority)) {
    return false;
  }
  if (filters.statuses.isNotEmpty &&
      !filters.statuses.contains(item.status)) {
    return false;
  }
  if (filters.types.isNotEmpty && !filters.types.contains(item.type)) {
    return false;
  }
  return true;
}
