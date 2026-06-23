// Провайдеры экрана Plan: режим вида (День/Неделя/Месяц), раскладка
// (список/сетка) и реактивный диапазон задач для месячного календаря.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../../core/utils/day_window.dart';
import 'recurrence_providers.dart';
import 'week_strip.dart' show selectedDayProvider;

/// Режим отображения плана. Порядок видов: День, 3 дня, Неделя, Месяц.
enum PlanView { day, threeDay, week, month }

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

/// Видимость строки поиска на экране Plan.
final planSearchVisibleProvider = StateProvider<bool>((ref) => false);

/// Текущий поисковый запрос на экране Plan.
final planSearchQueryProvider = StateProvider<String>((ref) => '');

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
