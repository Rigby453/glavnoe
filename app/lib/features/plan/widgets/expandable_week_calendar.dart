// Раскрывающийся календарь Plan (mobile): в свёрнутом состоянии — одна неделя
// (как WeekStrip), потянул ВНИЗ — плавно разворачивается в полный месяц
// (iOS-стиль), потянул ВВЕРХ — сворачивается обратно к неделе выбранного дня.
// Переключатель День/Неделя/Месяц в plan_screen остаётся параллельным способом.
//
// Эффект раскрытия — без PageView: рендерим всю сетку месяца, но в свёрнутом
// состоянии сдвигаем её вверх (Transform.translate) так, что видна только
// строка выбранной недели, и обрезаем высоту (ClipRect). При раскрытии сдвиг
// уходит в 0, а высота растёт до полного месяца.
//
// Бакетинг «дня с задачами» согласован с MonthView/watchTodayItems:
// день задачи = UTC-дата scheduledAt (.toUtc()).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import 'plan_providers.dart';
import 'week_strip.dart' show selectedDayProvider;

/// Высота одной строки календаря (неделя). Свёрнутый календарь = одна такая
/// строка; развёрнутый = [_rows] строк.
const double _kRowHeight = 56;

/// Высота шапки месяца (стрелки + название) в развёрнутом состоянии.
const double _kHeaderHeight = 32;

/// Высота строки подписей дней недели (Пн..Вс) — видна всегда.
const double _kWeekdayLabelHeight = 18;

class ExpandableWeekCalendar extends ConsumerStatefulWidget {
  const ExpandableWeekCalendar({super.key});

  @override
  ConsumerState<ExpandableWeekCalendar> createState() =>
      _ExpandableWeekCalendarState();
}

class _ExpandableWeekCalendarState
    extends ConsumerState<ExpandableWeekCalendar>
    with SingleTickerProviderStateMixin {
  // 0.0 — свёрнуто (неделя), 1.0 — раскрыто (месяц).
  late final AnimationController _controller;

  // Сетка текущего месяца, вычисляется в build и нужна обработчикам жестов.
  int _rows = 6;
  int _rowOfSelected = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kDurationNormal,
      value: 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Жесты ---

  /// Доп. высота, на которую раскрывается сетка (для маппинга drag → value).
  double get _expandExtent => (_rows - 1) * _kRowHeight;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final extent = _expandExtent;
    if (extent <= 0) return;
    // Тянем вниз (+delta) — раскрываем; вверх — сворачиваем.
    _controller.value += (details.primaryDelta ?? 0) / extent;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final bool expand;
    if (v.abs() > 300) {
      expand = v > 0; // быстрый флик вниз = раскрыть
    } else {
      expand = _controller.value > 0.5;
    }
    _settle(expand);
  }

  void _settle(bool expand) {
    if (!reduceMotionOf(context)) {
      HapticFeedback.selectionClick();
    }
    final target = expand ? 1.0 : 0.0;
    if (reduceMotionOf(context)) {
      _controller.value = target;
    } else {
      _controller.animateTo(target, duration: kDurationNormal, curve: kCurveLift);
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v == 0) return;
    final goBack = v > 0; // свайп вправо = назад
    final sel = ref.read(selectedDayProvider);
    if (_controller.value < 0.5) {
      // Свёрнуто — листаем по неделям (±7 дней).
      ref.read(selectedDayProvider.notifier).state =
          DateTime(sel.year, sel.month, sel.day + (goBack ? -7 : 7));
    } else {
      // Раскрыто — листаем по месяцам.
      _changeMonth(goBack ? -1 : 1);
    }
    if (!reduceMotionOf(context)) HapticFeedback.selectionClick();
  }

  void _changeMonth(int delta) {
    final sel = ref.read(selectedDayProvider);
    final target = DateTime(sel.year, sel.month + delta, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    final day = sel.day.clamp(1, lastDay);
    ref.read(selectedDayProvider.notifier).state =
        DateTime(target.year, target.month, day);
  }

  void _onDayTap(DateTime day) {
    ref.read(selectedDayProvider.notifier).state = day;
    // Тап в развёрнутом месяце — сворачиваемся к неделе выбранного дня.
    if (_controller.value > 0.5) _settle(false);
  }

  Future<void> _onDayLongPress(DateTime day) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null && mounted) {
      ref.read(selectedDayProvider.notifier).state =
          DateTime(picked.year, picked.month, picked.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;

    final sel = ref.watch(selectedDayProvider);
    final year = sel.year;
    final month = sel.month;

    // Геометрия месяца: понедельник первой недели, число строк.
    final firstOfMonth = DateTime(year, month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // Пн=0..Вс=6
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final gridStart =
        DateTime(year, month, 1 - leadingBlanks); // понедельник 1-й недели
    _rows = ((leadingBlanks + daysInMonth) / 7).ceil();
    _rowOfSelected = (leadingBlanks + sel.day - 1) ~/ 7;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Дни с задачами (UTC-дата scheduledAt) во всём видимом диапазоне сетки.
    final gridStartUtc =
        DateTime.utc(gridStart.year, gridStart.month, gridStart.day);
    final gridEndUtc = DateTime.utc(
        gridStart.year, gridStart.month, gridStart.day + _rows * 7);
    final items = ref
            .watch(rangeItemsProvider((gridStartUtc, gridEndUtc)))
            .valueOrNull ??
        const <ItemsTableData>[];
    final daysWithItems = <String>{};
    for (final i in items) {
      final u = i.scheduledAt.toUtc();
      daysWithItems.add('${u.year}-${u.month}-${u.day}');
    }

    // Подписи дней недели — из gridStart (всегда понедельник), локализованные.
    final weekdayLabels = List<String>.generate(
        7, (i) => DateFormat.E().format(gridStart.add(Duration(days: i))));

    return GestureDetector(
      // Вертикальный drag — раскрытие/сворачивание; горизонтальный — листание.
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Шапка месяца (видна только при раскрытии) ---
              ClipRect(
                child: SizedBox(
                  height: _kHeaderHeight * t,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: OverflowBox(
                      minHeight: _kHeaderHeight,
                      maxHeight: _kHeaderHeight,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: _kHeaderHeight,
                        child: IgnorePointer(
                          ignoring: t < 0.5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.chevron_left, color: textMuted),
                                onPressed: () => _changeMonth(-1),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(firstOfMonth),
                                style: textTheme.titleSmall,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon:
                                    Icon(Icons.chevron_right, color: textMuted),
                                onPressed: () => _changeMonth(1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // --- Подписи дней недели (Пн..Вс) — всегда ---
              SizedBox(
                height: _kWeekdayLabelHeight,
                child: Row(
                  children: [
                    for (final label in weekdayLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: textTheme.labelSmall?.copyWith(
                              color: textFaint,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // --- Сетка: одна неделя (свёрнуто) → весь месяц (раскрыто) ---
              ClipRect(
                child: SizedBox(
                  height: _kRowHeight + _expandExtent * t,
                  child: OverflowBox(
                    minHeight: _rows * _kRowHeight,
                    maxHeight: _rows * _kRowHeight,
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      // В свёрнутом виде сдвигаем сетку так, чтобы видна была
                      // строка выбранной недели; при раскрытии сдвиг → 0.
                      offset:
                          Offset(0, -_rowOfSelected * _kRowHeight * (1 - t)),
                      child: SizedBox(
                        height: _rows * _kRowHeight,
                        child: Column(
                          children: [
                            for (var r = 0; r < _rows; r++)
                              SizedBox(
                                height: _kRowHeight,
                                child: Row(
                                  children: [
                                    for (var c = 0; c < 7; c++)
                                      Builder(builder: (context) {
                                        final d = DateTime(
                                          gridStart.year,
                                          gridStart.month,
                                          gridStart.day + r * 7 + c,
                                        );
                                        return Expanded(
                                          child: _DayCell(
                                            day: d,
                                            isSelected: d == sel,
                                            isToday: d == todayNorm,
                                            isOutsideMonth: d.month != month,
                                            hasItems: daysWithItems.contains(
                                                '${d.year}-${d.month}-${d.day}'),
                                            onTap: () => _onDayTap(d),
                                            onLongPress: () =>
                                                _onDayLongPress(d),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // --- Ручка-грабер (подсказка о жесте) ---
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textFaint.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ячейка одного дня: число + точка-индикатор задач.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isOutsideMonth,
    required this.hasItems,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool isOutsideMonth;
  final bool hasItems;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;
    final reduceMotion = reduceMotionOf(context);

    // Accent discipline: fill только для выбранного, рамка для «сегодня».
    Color textColor = isSelected
        ? colorScheme.onPrimary
        : isToday
            ? colorScheme.primary
            : colorScheme.onSurface;
    // Дни соседних месяцев приглушаем.
    if (isOutsideMonth && !isSelected) {
      textColor = textFaint;
    }

    final Color dotColor = hasItems
        ? (isSelected ? colorScheme.onPrimary : textFaint)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : kDurationFast,
          curve: kCurveLift,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(color: colorScheme.primary, width: 1.0)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
