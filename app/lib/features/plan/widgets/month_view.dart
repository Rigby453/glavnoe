// Месячный вид Plan: календарная сетка месяца выбранного дня.
// Точка под днём = в этот день есть задачи. Тап по дню → выбрать его и
// переключиться на дневной вид. Стрелки ‹ › листают месяцы.
//
// Бакетинг «дня» согласован с watchTodayItems: день задачи = UTC-дата
// scheduledAt (.toUtc()), границы месяца — UTC-полночь.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import 'plan_providers.dart';
import 'week_strip.dart' show selectedDayProvider;

const List<String> _weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  void _changeMonth(WidgetRef ref, int delta) {
    final sel = ref.read(selectedDayProvider);
    final target = DateTime(sel.year, sel.month + delta, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    final day = sel.day.clamp(1, lastDay);
    ref.read(selectedDayProvider.notifier).state =
        DateTime(target.year, target.month, day);
  }

  void _selectDay(WidgetRef ref, DateTime day) {
    ref.read(selectedDayProvider.notifier).state = day;
    ref.read(planViewProvider.notifier).state = PlanView.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final sel = ref.watch(selectedDayProvider);
    final year = sel.year;
    final month = sel.month;

    final monthStartUtc = DateTime.utc(year, month, 1);
    final monthEndUtc = DateTime.utc(year, month + 1, 1);
    final items = ref
            .watch(rangeItemsProvider((monthStartUtc, monthEndUtc)))
            .valueOrNull ??
        const <ItemsTableData>[];

    // Дни месяца, в которые есть задачи (по UTC-дате scheduledAt).
    final daysWithItems = <int>{};
    for (final i in items) {
      final u = i.scheduledAt.toUtc();
      if (u.year == year && u.month == month) daysWithItems.add(u.day);
    }

    final firstOfMonth = DateTime(year, month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // 0..6 (Mon=0)
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: d,
          hasItems: daysWithItems.contains(d),
          isToday: DateTime(year, month, d) == todayNorm,
          isSelected: DateTime(year, month, d) == sel,
          onTap: () => _selectDay(ref, DateTime(year, month, d)),
        ),
    ];

    return Column(
      children: [
        // Заголовок месяца со стрелками
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(ref, -1),
              ),
              Text(
                DateFormat('MMMM yyyy').format(firstOfMonth),
                style: textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(ref, 1),
              ),
            ],
          ),
        ),
        // Подписи дней недели
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Сетка дней
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
            children: cells,
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasItems,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final bool hasItems;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color textColor = isSelected
        ? colorScheme.onPrimary
        : isToday
            ? colorScheme.primary
            : colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: colorScheme.primary)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight:
                    isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            // Точка-индикатор наличия задач
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasItems
                    ? (isSelected ? colorScheme.onPrimary : colorScheme.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
