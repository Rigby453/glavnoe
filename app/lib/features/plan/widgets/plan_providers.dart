// Провайдеры экрана Plan: режим вида (День/Неделя/Месяц), раскладка
// (список/сетка) и реактивный диапазон задач для месячного календаря.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../../core/utils/day_window.dart';
import 'recurrence_providers.dart';

/// Режим отображения плана.
enum PlanView { day, week, month }

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

/// Ближайший будущий экзамен или дедлайн (закреплённая карточка Plan).
/// Реактивно смотрит задачи на [сегодня, сегодня + 365 дней).
/// Возвращает null, если нет ни одного предстоящего exam/deadline.
final nearestExamDeadlineProvider =
    StreamProvider.autoDispose<ItemsTableData?>((ref) {
  final now = DateTime.now();
  // Ищем от начала сегодняшнего дня (локальная полночь, как watchTodayItems),
  // чтобы «сегодня» тоже показывалось.
  final from = localDayStart(now);
  final to = from.add(const Duration(days: 365));
  return ref
      .watch(itemsDaoProvider)
      .watchItemsInRange(from, to)
      .map((items) {
    // Отбираем только exam/deadline, ближайший по scheduledAt.
    final urgent = items
        .where((i) => i.type == 'exam' || i.type == 'deadline')
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return urgent.isEmpty ? null : urgent.first;
  });
});
