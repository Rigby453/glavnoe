// Недельный вид Plan: повестка из 7 дней недели, содержащей выбранный день.
// Каждый день — заголовок + его задачи. Использует тот же dayItemsProvider
// (watchTodayItems), что и дневной вид и экран Today — единая логика «дня».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../today/widgets/add_task_sheet.dart';
import 'day_timeline.dart' show dayItemsProvider;
import 'week_strip.dart' show selectedDayProvider;

class WeekAgenda extends ConsumerWidget {
  const WeekAgenda({super.key});

  /// Понедельник недели, содержащей [date].
  DateTime _weekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  /// Клонировать события недели на следующую (с подтверждением).
  Future<void> _cloneWeek(
    BuildContext context,
    WidgetRef ref,
    DateTime weekStart,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('plan.clone_week_title')),
        content: Text(ctx.s('plan.clone_week_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.s('plan.clone_week_copy')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final weekStartUtc =
        DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final count =
        await ref.read(itemsDaoProvider).cloneWeekEvents(weekStartUtc);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? context.s('plan.clone_week_nothing')
              : '${context.s('plan.clone_week_done_prefix')}$count${context.s('plan.clone_week_done_suffix')}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final weekStart = _weekStart(selectedDay);
    final days = List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: Text(context.s('plan.clone_week_button')),
            onPressed: () => _cloneWeek(context, ref, weekStart),
          ),
        ),
        for (final day in days) _DaySection(day: day),
      ],
    );
  }
}

class _DaySection extends ConsumerWidget {
  const _DaySection({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final items = ref.watch(dayItemsProvider(day)).valueOrNull ??
        const <ItemsTableData>[];

    final today = DateTime.now();
    final isToday =
        day == DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Text(
                DateFormat('EEE, MMM d').format(day),
                style: textTheme.titleSmall?.copyWith(
                  color: isToday ? colorScheme.primary : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Text(context.s('plan.week_today_label'),
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary)),
              ],
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('—', style: textTheme.bodySmall),
          )
        else
          ...items.map((i) => _AgendaRow(item: i, day: day)),
        const Divider(height: 16),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.item, required this.day});

  final ItemsTableData item;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final done = item.status == 'done';

    return InkWell(
      onTap: () => showAddTaskSheet(context, day: day, existing: item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                DateFormat.Hm().format(item.scheduledAt),
                style: textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            if (item.priority == 'main')
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.shield_outlined,
                    size: 14, color: colorScheme.primary),
              ),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done
                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
