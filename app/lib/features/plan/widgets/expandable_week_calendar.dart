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
// день задачи = ЛОКАЛЬНАЯ дата scheduledAt (localDayKey).

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day_window.dart';
import 'plan_providers.dart';
import 'week_strip.dart' show selectedDayProvider, dateOnly, isSameDate;

/// Высота одной строки календаря (неделя). Свёрнутый календарь = одна такая
/// строка; развёрнутый = [_rows] строк.
const double _kRowHeight = 56;

/// Высота шапки месяца (стрелки + название) в развёрнутом состоянии.
const double _kHeaderHeight = 32;

/// Высота строки подписей дней недели (Пн..Вс) — видна всегда.
const double _kWeekdayLabelHeight = 18;

class ExpandableWeekCalendar extends ConsumerStatefulWidget {
  const ExpandableWeekCalendar({super.key, this.maxCalendarHeight});

  /// Максимальная высота всего виджета (логические пиксели). Передаётся из
  /// _bodyContent через LayoutBuilder, чтобы раскрытый 6-рядный месяц не вышел
  /// за пределы родительской Column и не вызвал RenderFlex overflow (Bug #2).
  /// null = поведение по умолчанию (без ограничений, достаточно места).
  final double? maxCalendarHeight;

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

  // Slop для вертикального drag: пока суммарное смещение пальца не превысит
  // [_kDragSlop], не двигаем _controller.value. Это убирает «дрожь» раскрытия
  // при тапе со смазом (микро-движение по вертикали уже не трогает анимацию).
  static const double _kDragSlop = kTouchSlop; // ~18 lp
  double _dragAccum = 0;
  bool _dragActive = false;

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

  void _onVerticalDragStart(DragStartDetails details) {
    _dragAccum = 0;
    _dragActive = false;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final extent = _expandExtent;
    if (extent <= 0) return;
    final delta = details.primaryDelta ?? 0;
    // Пока не набрали slop — копим дельту, но не двигаем анимацию: так тап со
    // смазом по вертикали не вызывает дрожь раскрытия.
    if (!_dragActive) {
      _dragAccum += delta;
      if (_dragAccum.abs() < _kDragSlop) return;
      _dragActive = true;
    }
    // Тянем вниз (+delta) — раскрываем; вверх — сворачиваем.
    _controller.value += delta / extent;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // Жест не преодолел slop (фактически тап) — анимацию не трогаем.
    if (!_dragActive) return;
    _dragActive = false;
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
    ref.read(selectedDayProvider.notifier).state = dateOnly(day);
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

    // Дни с задачами (локальная дата scheduledAt) во всём видимом диапазоне сетки.
    final gridRangeStart = localDayStart(gridStart);
    final gridRangeEnd =
        localDayStart(gridStart).add(Duration(days: _rows * 7));
    final items = ref
            .watch(rangeItemsProvider((gridRangeStart, gridRangeEnd)))
            .valueOrNull ??
        const <ItemsTableData>[];
    final daysWithItems = <String>{};
    for (final i in items) {
      daysWithItems.add(localDayKey(i.scheduledAt));
    }

    // Подписи дней недели — из gridStart (всегда понедельник), локализованные.
    final weekdayLabels = List<String>.generate(
        7, (i) => DateFormat.E().format(gridStart.add(Duration(days: i))));

    return GestureDetector(
      // Вертикальный drag — раскрытие/сворачивание; горизонтальный — листание.
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Ограничиваем высоту сетки, если передан maxCalendarHeight (Bug #2).
          // Естественная высота: 1 ряд (свёрнуто) → _rows рядов (раскрыто).
          // При ограничении вычитаем фиксированные части (подписи + грабер +
          // шапка пропорционально t), чтобы сумма всех детей не превышала
          // maxCalendarHeight и родительская Column не переполнялась.
          final naturalGridH = _kRowHeight + _expandExtent * t;
          final effectiveGridH = widget.maxCalendarHeight != null
              ? naturalGridH.clamp(
                  _kRowHeight,
                  (widget.maxCalendarHeight! -
                          _kWeekdayLabelHeight -
                          24.0 -
                          _kHeaderHeight * t)
                      .clamp(_kRowHeight, double.infinity))
              : naturalGridH;
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
                                icon: Icon(
                                  PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                                  color: textMuted,
                                ),
                                onPressed: () => _changeMonth(-1),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(firstOfMonth),
                                style: textTheme.titleSmall,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                                  color: textMuted,
                                ),
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
                            // Запрещаем перенос по буквам при крупном textScale:
                            // аббревиатура дня (Пн/Mo/…) должна быть в одну
                            // строку или обрезаться, но не рендериться вертикально.
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
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
              // effectiveGridH = naturalGridH при отсутствии ограничения;
              // иначе — зажато по maxCalendarHeight (Bug #2 fix).
              ClipRect(
                child: SizedBox(
                  height: effectiveGridH,
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
                                            isSelected: isSameDate(d, sel),
                                            isToday: isSameDate(d, todayNorm),
                                            isOutsideMonth: d.month != month,
                                            hasItems: daysWithItems
                                                .contains(localDayKey(d)),
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
              // GestureDetector здесь решает баг «два тапа»: внешний GD обрабатывает
              // только drag-события и игнорирует тапы (в dragEnd _dragActive==false →
              // ранний выход). Тап по грабберу теперь явно переключает состояние.
              // SizedBox(height: 24) даёт достаточную тач-зону вокруг 4px-пилюли.
              GestureDetector(
                onTap: () => _settle(_controller.value < 0.5),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textFaint.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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
          // mainAxisSize.min + Flexible/FittedBox: при крупном тексте (scale 1.5+)
          // число дня масштабируется внутрь фиксированной 40px-окружности, а не
          // выталкивает колонку за её пределы (иначе RenderFlex overflow).
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${day.day}',
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
