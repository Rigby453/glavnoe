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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day_window.dart';
import '../../../core/widgets/kai_loader.dart';
import '../../today/task_colors.dart';
import 'day_timeline.dart' show dayItemsProvider;
import 'plan_providers.dart';
import 'recurrence_providers.dart';
import 'task_detail_card.dart';
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

/// Двузначное число с ведущим нулём (для форматирования времени).
String _two(int n) => n.toString().padLeft(2, '0');

/// «HH:MM» из минут от полуночи (зажато в пределах суток для отображения).
String formatMinutesOfDay(int minutesOfDay) {
  final clamped = minutesOfDay < 0
      ? 0
      : (minutesOfDay > 24 * 60 ? 24 * 60 : minutesOfDay);
  final h = (clamped ~/ 60) % 24;
  final m = clamped % 60;
  return '${_two(h)}:${_two(m)}';
}

/// Диапазон времени блока: «14:30–15:15» из старта [start] и длительности
/// [durationMinutes]. Конец считается по минутам от старта (без перехода суток
/// в отображении — конец зажимается формулой выше). Чистая функция.
String formatBlockTimeRange(DateTime start, int durationMinutes) {
  final startMin = minutesFromMidnight(start);
  final endMin = startMin + durationMinutes;
  return '${formatMinutesOfDay(startMin)}–${formatMinutesOfDay(endMin)}';
}

/// Сколько информации помещается в блок данной высоты [height] — чистая
/// функция, чтобы поведение «масштабируй контент под высоту» было тестируемым.
/// Очень низкий блок — только заголовок; средний — заголовок + время; высокий —
/// заголовок (до 2 строк) + время + строка типа/повтора.
enum BlockContentLevel { titleOnly, titleAndTime, titleTimeAndMeta }

/// Пороги подобраны под labelSmall/высоту строки ~14px и паддинги блока.
BlockContentLevel blockContentLevel(double height) {
  if (height >= 64) return BlockContentLevel.titleTimeAndMeta;
  if (height >= 34) return BlockContentLevel.titleAndTime;
  return BlockContentLevel.titleOnly;
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

  // Пользовательский цвет-метка имеет приоритет над типом/приоритетом:
  // полупрозрачная заливка + цветная рамка-полоса, текст остаётся читаемым.
  final userColor = taskColorFromKey(item.color);
  if (userColor != null) {
    return (
      bg: userColor.withValues(alpha: 0.16),
      fg: onSurface,
      border: userColor,
    );
  }

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

    // Реактивный диапазон недели через rangeItemsProvider. Границы — локальная
    // полночь, согласованы с watchItemsInRange/watchTodayItems.
    final from = localDayStart(weekStart);
    final to = from.add(const Duration(days: 7));
    final itemsAsync = ref.watch(rangeItemsProvider((from, to)));

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
              RepaintBoundary(
                // RepaintBoundary изолирует перерисовку блока: во время drag/resize
                // перерисовывается только этот слой, а не вся колонка/сетка.
                child: _EventBlock(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  day: day,
                  hourHeight: hourHeight,
                  columnWidth: width,
                  lane: lanes[i].lane,
                  laneCount: lanes[i].laneCount,
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Активный жест блока: перенос (drag) или изменение длительности (resize).
enum _GestureKind { none, drag, resize }

/// Эфемерное состояние жеста блока. Хранится в ValueNotifier, чтобы во время
/// жеста перерисовывался только Positioned + плавающая подсказка, а не весь
/// контент блока (заголовок/время/мета) и тем более не вся колонка/сетка.
class _BlockGesture {
  const _BlockGesture(this.kind, this.topPx, this.heightPx);
  const _BlockGesture.none()
      : kind = _GestureKind.none,
        topPx = 0,
        heightPx = 0;

  final _GestureKind kind;
  final double topPx;
  final double heightPx;

  bool get active => kind != _GestureKind.none;
}

/// Один блок-событие. Long-press начинает перенос (не мешает скроллу списка);
/// нижняя ручка с увеличенной зоной хвата меняет длительность; короткий тап
/// открывает карточку-деталь. Во время жеста — лифт (тень/масштаб), тактильная
/// отдача и плавающая подсказка времени.
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
  // Эфемерное состояние жеста. ValueNotifier (а не setState) — чтобы кадры
  // drag/resize перерисовывали только геометрию и подсказку, не весь контент.
  final ValueNotifier<_BlockGesture> _gesture =
      ValueNotifier(const _BlockGesture.none());

  // Зона хвата нижней ручки крупнее видимой полоски — Закон Фиттса.
  static const double _handleHitHeight = 22.0;
  static const double _laneGap = 2.0;
  // Минимальная высота блока во время resize в пикселях (= минимум 15 минут
  // визуально, но не меньше, чтобы хват не схлопнулся).
  static const double _minResizePx = 18.0;

  @override
  void dispose() {
    _gesture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colors = _blockColors(widget.item, ext, scheme);

    final startMin = minutesFromMidnight(widget.item.scheduledAt);
    final baseTop = minutesToOffset(startMin, widget.hourHeight);
    final baseHeight =
        durationToHeight(widget.item.durationMinutes, widget.hourHeight);

    // Геометрия дорожек: равные колонки внутри ширины.
    final laneWidth =
        (widget.columnWidth - _laneGap * (widget.laneCount - 1)) /
            widget.laneCount;
    final left = (laneWidth + _laneGap) * widget.lane;
    final width = laneWidth < 0 ? 0.0 : laneWidth;

    // Контент строится один раз и передаётся как child в ValueListenableBuilder,
    // поэтому при каждом кадре жеста он НЕ перестраивается (только обёртка).
    final content = _BlockContent(
      item: widget.item,
      colors: colors,
      compact: widget.compact,
      baseHeight: baseHeight,
      onResizeStart: () {
        HapticFeedback.selectionClick();
        _gesture.value =
            _BlockGesture(_GestureKind.resize, baseTop, baseHeight);
      },
      onResizeUpdate: (dy) {
        final g = _gesture.value;
        final cur = g.active ? g.heightPx : baseHeight;
        final next = cur + dy;
        _gesture.value = _BlockGesture(
          _GestureKind.resize,
          baseTop,
          next < _minResizePx ? _minResizePx : next,
        );
      },
      onResizeEnd: _commitResize,
      handleHitHeight: _handleHitHeight,
    );

    return ValueListenableBuilder<_BlockGesture>(
      valueListenable: _gesture,
      child: content,
      builder: (context, g, child) {
        final top = g.active ? g.topPx : baseTop;
        final height = g.active ? g.heightPx : baseHeight;
        final dragging = g.kind == _GestureKind.drag;
        final resizing = g.kind == _GestureKind.resize;

        // Плавающая подсказка: при drag — новое время начала; при resize —
        // длительность/конец. Привязка к 15 мин показывается уже снэпнутой.
        Widget? floatingLabel;
        if (dragging) {
          final snapMin = offsetToSnappedMinutes(top, widget.hourHeight);
          floatingLabel = _GestureLabel(text: formatMinutesOfDay(snapMin));
        } else if (resizing) {
          final rawMinutes = (height / widget.hourHeight * 60).round();
          final dur = snapDuration(rawMinutes);
          floatingLabel = _GestureLabel(
            text: '${formatMinutesOfDay(startMin + dur)}  ·  '
                '${_durationShort(dur)}',
          );
        }

        // Лифт во время жеста: лёгкий масштаб + тень (ANIMATIONS.md §1.1/§1.2 —
        // приподнятый элемент = «взят»).
        final lifted = g.active;

        return Positioned(
          top: top,
          left: left,
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Короткий тап → карточка-деталь (а не сразу форма).
            onTap: () => showTaskDetailSheet(
              context,
              item: widget.item,
              day: widget.day,
            ),
            // Long-press начинает перенос (не конфликтует со скроллом списка).
            onLongPressStart: (_) {
              HapticFeedback.mediumImpact();
              _gesture.value =
                  _BlockGesture(_GestureKind.drag, baseTop, baseHeight);
            },
            onLongPressMoveUpdate: (d) {
              final cur = _gesture.value;
              _gesture.value = _BlockGesture(
                _GestureKind.drag,
                baseTop + d.offsetFromOrigin.dy,
                cur.heightPx,
              );
            },
            onLongPressEnd: (_) => _commitMove(),
            child: AnimatedScale(
              scale: lifted ? 1.03 : 1.0,
              duration: effectiveDuration(context, kDurationSnap),
              curve: kCurveSnap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Тень-лифт поверх обычной заливки только во время жеста.
                  if (lifted)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned.fill(child: child!),
                  if (floatingLabel != null)
                    Positioned(top: 2, right: 2, child: floatingLabel),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Сохраняет новое время после переноса: snap к 15 минутам, обновляет
  /// scheduledAt (и дату — в week колонка фиксирует день widget.day).
  Future<void> _commitMove() async {
    final g = _gesture.value;
    _gesture.value = const _BlockGesture.none();
    if (g.kind != _GestureKind.drag) return;
    HapticFeedback.selectionClick();
    final snappedMin = offsetToSnappedMinutes(g.topPx, widget.hourHeight);
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
    final g = _gesture.value;
    _gesture.value = const _BlockGesture.none();
    if (g.kind != _GestureKind.resize) return;
    HapticFeedback.selectionClick();
    final rawMinutes = (g.heightPx / widget.hourHeight * 60).round();
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

/// Короткая длительность: 45 → "45m", 90 → "1h30m". Для подсказки resize.
String _durationShort(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m}m';
}

/// Статичный контент блока (заливка, рамка, заголовок/время/мета + ручка
/// resize). Строится один раз на изменение данных — не перестраивается на
/// каждом кадре жеста (передаётся как child в ValueListenableBuilder).
class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.item,
    required this.colors,
    required this.compact,
    required this.baseHeight,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.handleHitHeight,
  });

  final ItemsTableData item;
  final ({Color bg, Color fg, Color border}) colors;
  final bool compact;
  final double baseHeight;
  final VoidCallback onResizeStart;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;
  final double handleHitHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final level = blockContentLevel(baseHeight);
    final timeRange = formatBlockTimeRange(item.scheduledAt, item.durationMinutes);
    final isDone = item.status == 'done';

    return Container(
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
                  item.title,
                  // До 2 строк когда блок высокий; иначе 1 строка.
                  maxLines: level == BlockContentLevel.titleTimeAndMeta &&
                          !compact
                      ? 2
                      : 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.fg,
                    fontWeight: FontWeight.w700,
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (level != BlockContentLevel.titleOnly)
                  Text(
                    timeRange,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.fg.withValues(alpha: 0.85),
                    ),
                  ),
                if (level == BlockContentLevel.titleTimeAndMeta &&
                    isVirtualOccurrenceId(item.id))
                  Text(
                    context.s('recur.repeats_daily'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.fg.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          // Нижняя ручка изменения длительности: видимая полоска + крупная
          // невидимая зона хвата (Закон Фиттса).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: handleHitHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => onResizeStart(),
              onVerticalDragUpdate: (d) => onResizeUpdate(d.delta.dy),
              onVerticalDragEnd: (_) => onResizeEnd(),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 28,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 3),
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
    );
  }
}

/// Плавающая подсказка времени/длительности во время жеста.
class _GestureLabel extends StatelessWidget {
  const _GestureLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
