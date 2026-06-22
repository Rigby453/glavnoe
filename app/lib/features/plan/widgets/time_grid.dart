// FL-PLAN-GRID: Сетка времени в стиле Google Calendar для Day/Week.
// Вертикальная ось часов (0–24), блоки-события позиционируются по scheduledAt
// и durationMinutes. Поддержка drag (перенос времени), resize (длительность),
// тап → редактирование. Чистая математика вынесена в top-level функции —
// они покрыты юнит-тестами (test/time_grid_test.dart). Жесты на устройстве
// нужно проверять вручную.
//
// Конвенция времени: scheduledAt трактуется как локальное «настенное» время
// (так его показывает DayTimeline через DateFormat.Hm без .toLocal). Поэтому
// позиция считается по .hour/.minute, а при сохранении новое время строится
// через локальный DateTime(...), как в add_task_sheet.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kai_loader.dart';
import '../../today/widgets/add_task_sheet.dart';
import 'day_timeline.dart' show dayItemsProvider;
import 'plan_providers.dart';
import 'recurrence_providers.dart';
import 'week_strip.dart' show selectedDayProvider;

// ===========================================================================
// Чистая математика (тестируемые top-level функции)
// ===========================================================================

/// Высота одного часа в логических пикселях (по умолчанию).
const double kHourHeight = 56.0;

/// Шаг привязки при drag/resize — 15 минут.
const int kSnapMinutes = 15;

/// Минимальная длительность события в минутах.
const int kMinDurationMinutes = 15;

/// Минут от полуночи для [time] (учитывает только часы/минуты).
int minutesFromMidnight(DateTime time) => time.hour * 60 + time.minute;

/// Вертикальное смещение (top) блока для времени [minutesOfDay] минут от
/// полуночи при высоте часа [hourHeight].
double minutesToOffset(int minutesOfDay, double hourHeight) =>
    minutesOfDay * hourHeight / 60.0;

/// Высота блока для длительности [durationMinutes] при высоте часа [hourHeight].
/// Не меньше [minHeight] ради читаемости коротких событий.
double durationToHeight(
  int durationMinutes,
  double hourHeight, {
  double minHeight = 24.0,
}) {
  final raw = durationMinutes * hourHeight / 60.0;
  return raw < minHeight ? minHeight : raw;
}

/// Перевод вертикального смещения [offset] обратно в минуты от полуночи,
/// привязанные к шагу [snapMinutes]. Результат зажат в [0, 24*60].
int offsetToSnappedMinutes(
  double offset,
  double hourHeight, {
  int snapMinutes = kSnapMinutes,
}) {
  final rawMinutes = offset / hourHeight * 60.0;
  final snapped = (rawMinutes / snapMinutes).round() * snapMinutes;
  if (snapped < 0) return 0;
  const maxMinutes = 24 * 60;
  if (snapped > maxMinutes) return maxMinutes;
  return snapped;
}

/// Привязывает произвольное число минут к шагу [snapMinutes] и не даёт
/// результату упасть ниже [minDuration]. Используется при resize.
int snapDuration(
  int minutes, {
  int snapMinutes = kSnapMinutes,
  int minDuration = kMinDurationMinutes,
}) {
  final snapped = (minutes / snapMinutes).round() * snapMinutes;
  return snapped < minDuration ? minDuration : snapped;
}

/// Раскладка перекрывающихся событий по равным колонкам-«дорожкам».
/// Возвращает для каждого индекса входного списка пару (lane, laneCount):
/// номер дорожки и общее число дорожек в его группе пересечений.
/// Группа — связное множество событий, пересекающихся по времени; внутри
/// группы события распределяются жадно по первой свободной дорожке.
/// [items] должны идти в порядке возрастания начала (как из DAO).
List<({int lane, int laneCount})> computeOverlapLanes(
  List<({int startMin, int endMin})> items,
) {
  final result = List<({int lane, int laneCount})>.filled(
    items.length,
    (lane: 0, laneCount: 1),
  );
  if (items.isEmpty) return result;

  // Индексы по возрастанию начала (стабильно к исходному порядку).
  final order = List<int>.generate(items.length, (i) => i)
    ..sort((a, b) {
      final c = items[a].startMin.compareTo(items[b].startMin);
      return c != 0 ? c : a.compareTo(b);
    });

  var groupStart = 0; // позиция в order, где началась текущая группа
  var groupMaxEnd = -1;
  final laneEnds = <int>[]; // конец события в каждой активной дорожке

  void finalizeGroup(int endExclusive) {
    final count = laneEnds.isEmpty ? 1 : laneEnds.length;
    for (var k = groupStart; k < endExclusive; k++) {
      final idx = order[k];
      result[idx] = (lane: result[idx].lane, laneCount: count);
    }
  }

  for (var k = 0; k < order.length; k++) {
    final idx = order[k];
    final it = items[idx];
    // Новая группа, если событие начинается после конца всей предыдущей группы.
    if (it.startMin >= groupMaxEnd) {
      if (k > 0) finalizeGroup(k);
      groupStart = k;
      groupMaxEnd = it.endMin;
      laneEnds
        ..clear()
        ..add(it.endMin);
      result[idx] = (lane: 0, laneCount: 1);
      continue;
    }
    // Ищем первую дорожку, освободившуюся к началу события.
    var placed = -1;
    for (var lane = 0; lane < laneEnds.length; lane++) {
      if (laneEnds[lane] <= it.startMin) {
        placed = lane;
        laneEnds[lane] = it.endMin;
        break;
      }
    }
    if (placed == -1) {
      placed = laneEnds.length;
      laneEnds.add(it.endMin);
    }
    result[idx] = (lane: placed, laneCount: laneEnds.length);
    if (it.endMin > groupMaxEnd) groupMaxEnd = it.endMin;
  }
  finalizeGroup(order.length);
  return result;
}

// ===========================================================================
// Общие константы раскладки
// ===========================================================================

const double _kGutterWidth = 44.0; // ширина левой колонки с метками часов
const double _kHeaderHeight = 44.0; // высота шапки с днями недели (week)
const int _kHoursInDay = 24;
const int _kDefaultScrollHour = 7; // прокрутка по умолчанию ~7:00

/// Цвет блока события по типу/приоритету (accent discipline: ember только
/// для urgent, accent только для main, остальное — нейтрали).
({Color bg, Color fg, Color border}) _blockColors(
  ItemsTableData item,
  FocusThemeExtension? ext,
  ColorScheme scheme,
) {
  final ember = ext?.ember ?? scheme.secondary;
  final accent = scheme.primary;
  final surfaceElevated = ext?.surfaceElevated ?? scheme.surface;
  final onSurface = scheme.onSurface;

  if (item.type == 'exam' || item.type == 'deadline') {
    return (bg: ember.withValues(alpha: 0.16), fg: ember, border: ember);
  }
  if (item.priority == 'main') {
    return (bg: accent.withValues(alpha: 0.16), fg: onSurface, border: accent);
  }
  final border = ext?.border ?? scheme.outline;
  return (bg: surfaceElevated, fg: onSurface, border: border);
}

// ===========================================================================
// Day grid
// ===========================================================================

/// Дневная сетка времени: одна колонка, питается dayItemsProvider(selectedDay).
class DayTimeGrid extends ConsumerWidget {
  const DayTimeGrid({super.key, this.hourHeight = kHourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final itemsAsync = ref.watch(dayItemsProvider(selectedDay));

    if (itemsAsync.isLoading && itemsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }
    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    final query = ref.watch(planSearchQueryProvider).toLowerCase();
    final filtered = query.isEmpty
        ? items
        : items.where((i) => i.title.toLowerCase().contains(query)).toList();

    return _TimeGridScaffold(
      hourHeight: hourHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colWidth = constraints.maxWidth - _kGutterWidth;
          return Stack(
            children: [
              _HourLinesAndGutter(hourHeight: hourHeight),
              Positioned(
                left: _kGutterWidth,
                top: 0,
                width: colWidth < 0 ? 0 : colWidth,
                height: hourHeight * _kHoursInDay,
                child: _DayColumn(
                  day: selectedDay,
                  items: filtered,
                  hourHeight: hourHeight,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Week grid
// ===========================================================================

/// Недельная сетка: 7 колонок-дней с общей осью часов.
class WeekTimeGrid extends ConsumerWidget {
  const WeekTimeGrid({super.key, this.hourHeight = kHourHeight});

  final double hourHeight;

  DateTime _weekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final weekStart = _weekStart(selectedDay);
    final days = List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );

    // Реактивный диапазон недели через rangeItemsProvider. Границы — UTC-полночь,
    // согласованы с watchItemsInRange/watchTodayItems.
    final fromUtc =
        DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final toUtc = fromUtc.add(const Duration(days: 7));
    final itemsAsync = ref.watch(rangeItemsProvider((fromUtc, toUtc)));

    if (itemsAsync.isLoading && itemsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }
    final allItems = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    final query = ref.watch(planSearchQueryProvider).toLowerCase();
    final items = query.isEmpty
        ? allItems
        : allItems.where((i) => i.title.toLowerCase().contains(query)).toList();

    // Группируем по календарному дню (по локальной дате scheduledAt).
    Map<DateTime, List<ItemsTableData>> byDay = {
      for (final d in days) d: <ItemsTableData>[],
    };
    for (final it in items) {
      final dt = it.scheduledAt;
      final key = DateTime(dt.year, dt.month, dt.day);
      byDay[key]?.add(it);
    }

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth =
            (constraints.maxWidth - _kGutterWidth) / 7.0;
        // Пытаемся уместить 7 колонок; если совсем узко — горизонтальный скролл.
        const minColWidth = 40.0;
        final fits = colWidth >= minColWidth;
        final effectiveColWidth = fits ? colWidth : minColWidth;
        final totalWidth =
            _kGutterWidth + effectiveColWidth * 7;

        final grid = SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              // Шапка с днями недели
              SizedBox(
                height: _kHeaderHeight,
                child: Row(
                  children: [
                    const SizedBox(width: _kGutterWidth),
                    for (final d in days)
                      SizedBox(
                        width: effectiveColWidth,
                        child: _WeekDayHeader(
                          day: d,
                          isToday: d == todayNorm,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _TimeGridScaffold(
                  hourHeight: hourHeight,
                  child: Stack(
                    children: [
                      _HourLinesAndGutter(hourHeight: hourHeight),
                      for (var i = 0; i < days.length; i++)
                        Positioned(
                          left: _kGutterWidth + effectiveColWidth * i,
                          top: 0,
                          width: effectiveColWidth,
                          height: hourHeight * _kHoursInDay,
                          child: _DayColumn(
                            day: days[i],
                            items: byDay[days[i]] ?? const [],
                            hourHeight: hourHeight,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (fits) return grid;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: totalWidth, child: grid),
        );
      },
    );
  }
}

/// Шапка одной колонки недели: день недели + число, today подсвечен.
class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? scheme.onSurface;
    final textTheme = Theme.of(context).textTheme;
    final color = isToday ? scheme.primary : scheme.onSurface;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat.E().format(day).substring(0, 3),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: textTheme.labelSmall?.copyWith(
            color: isToday ? scheme.primary : textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          day.day.toString(),
          maxLines: 1,
          style: textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Общая обвязка: вертикальный скролл с авто-прокруткой на ~7:00
// ===========================================================================

class _TimeGridScaffold extends StatefulWidget {
  const _TimeGridScaffold({required this.hourHeight, required this.child});

  final double hourHeight;
  final Widget child;

  @override
  State<_TimeGridScaffold> createState() => _TimeGridScaffoldState();
}

class _TimeGridScaffoldState extends State<_TimeGridScaffold> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.hourHeight * _kDefaultScrollHour,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      child: SizedBox(
        height: widget.hourHeight * _kHoursInDay,
        child: widget.child,
      ),
    );
  }
}

/// Левый «жёлоб» с метками часов и горизонтальные линии часов на всю ширину.
class _HourLinesAndGutter extends StatelessWidget {
  const _HourLinesAndGutter({required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? scheme.outline;
    final textFaint = ext?.textFaint ?? scheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        for (var h = 0; h <= _kHoursInDay; h++)
          Positioned(
            top: h * hourHeight,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _kGutterWidth,
                  child: h < _kHoursInDay
                      ? Padding(
                          padding: const EdgeInsets.only(right: 6, top: 0),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            textAlign: TextAlign.right,
                            style: textTheme.labelSmall?.copyWith(
                              color: textFaint,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Container(height: 0.5, color: border),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// Колонка одного дня с блоками-событиями (drag/resize/tap)
// ===========================================================================

class _DayColumn extends ConsumerWidget {
  const _DayColumn({
    required this.day,
    required this.items,
    required this.hourHeight,
    this.compact = false,
  });

  final DateTime day;
  final List<ItemsTableData> items;
  final double hourHeight;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.expand();

    // Считаем дорожки перекрытий.
    final spans = items
        .map((i) => (
              startMin: minutesFromMidnight(i.scheduledAt),
              endMin: minutesFromMidnight(i.scheduledAt) + i.durationMinutes,
            ))
        .toList();
    final lanes = computeOverlapLanes(spans);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            for (var i = 0; i < items.length; i++)
              _EventBlock(
                key: ValueKey(items[i].id),
                item: items[i],
                day: day,
                hourHeight: hourHeight,
                columnWidth: width,
                lane: lanes[i].lane,
                laneCount: lanes[i].laneCount,
                compact: compact,
              ),
          ],
        );
      },
    );
  }
}

/// Один блок-событие. Drag по вертикали меняет время; нижняя ручка меняет
/// длительность; тап открывает редактирование.
class _EventBlock extends ConsumerStatefulWidget {
  const _EventBlock({
    super.key,
    required this.item,
    required this.day,
    required this.hourHeight,
    required this.columnWidth,
    required this.lane,
    required this.laneCount,
    required this.compact,
  });

  final ItemsTableData item;
  final DateTime day;
  final double hourHeight;
  final double columnWidth;
  final int lane;
  final int laneCount;
  final bool compact;

  @override
  ConsumerState<_EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends ConsumerState<_EventBlock> {
  // Активный drag/resize: накопленное смещение в пикселях.
  double? _dragTopPx; // null = не тащим
  double? _resizeHeightPx; // null = не ресайзим

  static const double _handleHeight = 14.0;
  static const double _laneGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final colors = _blockColors(widget.item, ext, scheme);

    final startMin = minutesFromMidnight(widget.item.scheduledAt);
    final baseTop = minutesToOffset(startMin, widget.hourHeight);
    final baseHeight =
        durationToHeight(widget.item.durationMinutes, widget.hourHeight);

    final top = _dragTopPx ?? baseTop;
    final height = _resizeHeightPx ?? baseHeight;

    // Геометрия дорожек: равные колонки внутри ширины.
    final laneWidth =
        (widget.columnWidth - _laneGap * (widget.laneCount - 1)) /
            widget.laneCount;
    final left = (laneWidth + _laneGap) * widget.lane;

    final timeLabel = DateFormat.Hm().format(widget.item.scheduledAt);

    return Positioned(
      top: top,
      left: left,
      width: laneWidth < 0 ? 0 : laneWidth,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAddTaskSheet(
          context,
          day: widget.day,
          existing: widget.item,
        ),
        // Перенос по вертикали (long-press-drag, чтобы не мешать скроллу).
        // offsetFromOrigin — абсолютное смещение от точки начала long-press,
        // поэтому новый top считается напрямую от базовой позиции.
        onLongPressStart: (_) => setState(() => _dragTopPx = baseTop),
        onLongPressMoveUpdate: (d) =>
            setState(() => _dragTopPx = baseTop + d.offsetFromOrigin.dy),
        onLongPressEnd: (_) => _commitMove(baseTop),
        child: Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: colors.border, width: 3),
              top: BorderSide(color: colors.border.withValues(alpha: 0.4)),
              right: BorderSide(color: colors.border.withValues(alpha: 0.4)),
              bottom: BorderSide(color: colors.border.withValues(alpha: 0.4)),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: widget.compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.fg,
                        fontWeight: FontWeight.w600,
                        decoration: widget.item.status == 'done'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (!widget.compact && height > 34)
                      Text(
                        timeLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.fg.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
              // Ручка изменения длительности у нижнего края.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _handleHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) =>
                      setState(() => _resizeHeightPx = baseHeight),
                  onVerticalDragUpdate: (d) {
                    setState(() {
                      final next = (_resizeHeightPx ?? baseHeight) + d.delta.dy;
                      _resizeHeightPx = next < 16 ? 16 : next;
                    });
                  },
                  onVerticalDragEnd: (_) => _commitResize(),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 24,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Сохраняет новое время после переноса: snap к 15 минутам, обновляет
  /// scheduledAt (и дату — в week колонка фиксирует день widget.day).
  Future<void> _commitMove(double baseTop) async {
    final px = _dragTopPx;
    setState(() => _dragTopPx = null);
    if (px == null) return;
    final snappedMin = offsetToSnappedMinutes(px, widget.hourHeight);
    final newStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      snappedMin ~/ 60,
      snappedMin % 60,
    );
    if (newStart == widget.item.scheduledAt) return;
    final dao = ref.read(itemsDaoProvider);
    // Виртуальный повтор серии: материализуем этот день с новым временем
    // (анкер получает EXDATE на дату), иначе updateItem по синтетическому id
    // был бы no-op и перенос потерялся бы.
    if (isVirtualOccurrenceId(widget.item.id)) {
      await dao.materializeOccurrence(
        anchorIdFromVirtual(widget.item.id),
        dateFromVirtual(widget.item.id) ?? widget.day,
        status: widget.item.status,
        scheduledAt: newStart,
      );
      return;
    }
    await dao.updateItem(
          widget.item.id,
          ItemsTableCompanion(
            scheduledAt: Value(newStart),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Сохраняет новую длительность после resize: snap к 15, минимум 15.
  Future<void> _commitResize() async {
    final px = _resizeHeightPx;
    setState(() => _resizeHeightPx = null);
    if (px == null) return;
    final rawMinutes = (px / widget.hourHeight * 60).round();
    final newDuration = snapDuration(rawMinutes);
    if (newDuration == widget.item.durationMinutes) return;
    final dao = ref.read(itemsDaoProvider);
    // Виртуальный повтор серии: материализуем этот день с новой длительностью.
    if (isVirtualOccurrenceId(widget.item.id)) {
      await dao.materializeOccurrence(
        anchorIdFromVirtual(widget.item.id),
        dateFromVirtual(widget.item.id) ?? widget.day,
        status: widget.item.status,
        durationMinutes: newDuration,
      );
      return;
    }
    await dao.updateItem(
          widget.item.id,
          ItemsTableCompanion(
            durationMinutes: Value(newDuration),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
