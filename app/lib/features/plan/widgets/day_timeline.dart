// FL-PLAN-02: Таймлайн задач выбранного дня.
// Реактивно читает задачи через watchTodayItems(selectedDay) из ItemsDao.
// Каждая карточка: время + заголовок + значок типа.
// Тап на карточку → showAddTaskSheet в режиме редактирования.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../today/widgets/add_task_sheet.dart';
import 'week_strip.dart';

/// StreamProvider с autoDispose + family: один провайдер на каждую дату.
/// Переиспользует watchTodayItems из ItemsDao — тот же метод, что и Today экран.
final dayItemsProvider = StreamProvider.autoDispose
    .family<List<ItemsTableData>, DateTime>((ref, date) {
  return ref.watch(itemsDaoProvider).watchTodayItems(date);
});

class DayTimeline extends ConsumerWidget {
  const DayTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final itemsAsync = ref.watch(dayItemsProvider(selectedDay));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Failed to load items: $err',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyState(day: selectedDay);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ItemCard(
              item: item,
              selectedDay: selectedDay,
            );
          },
        );
      },
    );
  }
}

/// Карточка одной задачи/события в таймлайне.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.selectedDay});

  final ItemsTableData item;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeExt = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;

    final borderColor = themeExt?.border ?? colorScheme.outline;

    return InkWell(
      onTap: () => showAddTaskSheet(
        context,
        day: selectedDay,
        existing: item,
      ),
      borderRadius: BorderRadius.circular(16), // radius.md
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Время
            SizedBox(
              width: 48,
              child: Text(
                DateFormat.Hm().format(item.scheduledAt),
                style: textTheme.bodySmall?.copyWith(
                  color: themeExt?.textMuted ?? colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Заголовок (растягивается)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: textTheme.bodyMedium?.copyWith(
                      decoration: item.status == 'done'
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.status == 'done'
                          ? (themeExt?.textMuted ?? colorScheme.onSurface)
                          : colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Обратный отсчёт для экзаменов/дедлайнов
                  if (item.type == 'exam' || item.type == 'deadline')
                    Text(
                      _countdownLabel(item.scheduledAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: themeExt?.ember ?? colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Значок типа
            _TypeBadge(type: item.type),
          ],
        ),
      ),
    );
  }
}

/// Текст обратного отсчёта до даты (для экзаменов/дедлайнов).
String _countdownLabel(DateTime at) {
  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  final d1 = DateTime(at.year, at.month, at.day);
  final days = d1.difference(d0).inDays;
  if (days < 0) return 'overdue';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

/// Маленький цветной значок типа задачи.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeExt = Theme.of(context).extension<FocusThemeExtension>();

    final (label, color) = switch (type) {
      'exam' => ('exam', themeExt?.ember ?? colorScheme.secondary),
      'deadline' => ('DL', themeExt?.ember ?? colorScheme.secondary),
      'event' => ('event', colorScheme.primary.withValues(alpha: 0.8)),
      _ => ('task', colorScheme.primary.withValues(alpha: 0.5)), // task
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999), // radius.pill
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
            ),
      ),
    );
  }
}

/// Пустое состояние — нет задач на выбранный день.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: themeExt?.textMuted ?? colorScheme.onSurface,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing planned for ${DateFormat.MMMd().format(day)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: themeExt?.textMuted ?? colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add something',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
