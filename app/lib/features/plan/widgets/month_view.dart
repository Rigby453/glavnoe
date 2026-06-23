// Месячный вид Plan: календарная сетка месяца выбранного дня.
// Точка под днём = в этот день есть задачи. Тап по дню → выбрать его и
// переключиться на дневной вид. Стрелки ‹ › листают месяцы.
//
// Бакетинг «дня» согласован с watchTodayItems: день задачи = ЛОКАЛЬНАЯ дата
// scheduledAt, границы месяца — локальная полночь.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import 'plan_providers.dart';
import 'time_grid.dart' show taskStripeColor;
import 'week_strip.dart' show selectedDayProvider, dateOnly, isSameDate;

/// Максимум цветных полосок-задач, показываемых в одной ячейке дня.
/// Если задач больше — последняя строка заменяется на «+N».
const int _kMaxStripes = 3;

/// Ключи локализованных подписей дней недели (Пн..Вс).
const List<String> _weekdayKeys = [
  'plan.weekday_mon',
  'plan.weekday_tue',
  'plan.weekday_wed',
  'plan.weekday_thu',
  'plan.weekday_fri',
  'plan.weekday_sat',
  'plan.weekday_sun',
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
    ref.read(selectedDayProvider.notifier).state = dateOnly(day);
    ref.read(planViewProvider.notifier).state = PlanView.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;

    final sel = ref.watch(selectedDayProvider);
    final year = sel.year;
    final month = sel.month;

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1);
    final items = ref
            .watch(rangeItemsProvider((monthStart, monthEnd)))
            .valueOrNull ??
        const <ItemsTableData>[];

    // Группируем задачи по числу дня месяца (по локальной дате scheduledAt).
    // Сортировка устойчивая по времени старта — полоски идут хронологически.
    final itemsByDay = <int, List<ItemsTableData>>{};
    for (final i in items) {
      final s = i.scheduledAt;
      if (s.year == year && s.month == month) {
        (itemsByDay[s.day] ??= <ItemsTableData>[]).add(i);
      }
    }
    for (final list in itemsByDay.values) {
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
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
          dayItems: itemsByDay[d] ?? const <ItemsTableData>[],
          isToday: isSameDate(DateTime(year, month, d), todayNorm),
          isSelected: isSameDate(DateTime(year, month, d), sel),
          onTap: () => _selectDay(ref, DateTime(year, month, d)),
        ),
    ];

    return Column(
      children: [
        // Заголовок месяца со стрелками
        Padding(
          // 24dp горизонтальный отступ (02-type-space §4.1)
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Нейтральные иконки навигации (accent discipline)
              IconButton(
                icon: Icon(Icons.chevron_left, color: textMuted),
                onPressed: () => _changeMonth(ref, -1),
              ),
              // headlineSmall для заголовка месяца (display font, big headline serif)
              // Spec: month header = big headline serif (02-type-space §1 headlineSmall)
              Text(
                DateFormat('MMMM yyyy').format(firstOfMonth),
                style: textTheme.headlineSmall,
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: textMuted),
                onPressed: () => _changeMonth(ref, 1),
              ),
            ],
          ),
        ),
        // Подписи дней недели — labelSmall, textFaint (минимальный вес)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final key in _weekdayKeys)
                Expanded(
                  child: Center(
                    child: Text(
                      context.s(key),
                      style: textTheme.labelSmall?.copyWith(
                        // textFaint для неинтерактивных вспомогательных меток
                        color: textFaint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Сетка дней
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            // Ячейки чуть выше квадрата, чтобы цветные полоски-задачи влезали
            // под числом дня (число + до 3 полосок).
            childAspectRatio: 0.62,
            // 24dp горизонтальный отступ экрана (02-type-space §4.1)
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
    required this.dayItems,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final List<ItemsTableData> dayItems;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;

    // Accent discipline: только selected и today получают accent
    final Color textColor = isSelected
        ? colorScheme.onPrimary    // белый/тёмный поверх accent fill
        : isToday
            ? colorScheme.primary  // accent для маркера «сегодня»
            : colorScheme.onSurface;

    final total = dayItems.length;
    // Сколько полосок реально рисуем: если задач больше максимума, оставляем
    // место под строку «+N» (последний слот занимает счётчик).
    final stripeCount =
        total <= _kMaxStripes ? total : _kMaxStripes - 1;
    final overflow = total - stripeCount;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Число дня в компактном круге фиксированного размера: accent fill
            // для выбранного дня, тонкая рамка accent для «сегодня».
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: colorScheme.primary, width: 1.0)
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$day',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Цветные полоски-задачи (до ~3). Цвет = цвет-метка задачи или
            // правило по типу/приоритету (единое с сеткой времени).
            for (var i = 0; i < stripeCount; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Container(
                  height: 3,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: taskStripeColor(dayItems[i], ext, colorScheme),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            // «+N» если задач больше, чем влезло полосок.
            if (overflow > 0)
              Text(
                '+$overflow',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: textTheme.labelSmall?.copyWith(
                  color: textMuted,
                  fontSize: 9,
                  height: 1.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
