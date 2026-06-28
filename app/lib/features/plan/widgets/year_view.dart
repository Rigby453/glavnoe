// Год-вид Plan (как в Google Calendar): сетка всех 12 месяцев выбранного года.
// Каждый месяц — компактная мини-сетка дней (Пн..Вс по столбцам). На днях с
// задачами — индикатор «занятости»: заливка-точка под числом, насыщенность
// которой растёт с числом задач (1 → бледная, 3+ → полная accent).
//
// Тап по дню → выбрать его (selectedDayProvider) и переключиться на дневной
// вид (как в month_view). Свайп влево/вправо листает ГОДА. Заголовок — год.
//
// Данные эффективны: один watch на весь год (yearTaskCountsProvider агрегирует
// кол-во задач по локальным дням через GROUP-в-Dart), НЕ 365 отдельных запросов.
// Бакетинг дня согласован с month_view: локальная дата scheduledAt (localDayKey).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day_window.dart';
import '../../../core/widgets/kai_loader.dart';
import 'plan_providers.dart';
import 'week_strip.dart' show selectedDayProvider, isSameDate;

/// Ключи локализованных однобуквенных подписей дней недели (Пн..Вс) для
/// мини-месяцев. Переиспользуем существующие weekday-строки (берём 1-й символ
/// в виджете, чтобы шапка мини-месяца была максимально узкой).
const List<String> _weekdayKeys = [
  'plan.weekday_mon',
  'plan.weekday_tue',
  'plan.weekday_wed',
  'plan.weekday_thu',
  'plan.weekday_fri',
  'plan.weekday_sat',
  'plan.weekday_sun',
];

class YearView extends ConsumerWidget {
  const YearView({super.key});

  /// Сдвигает выбранный год на [delta], сохраняя месяц/день (с клампом дня).
  void _changeYear(WidgetRef ref, int delta) {
    final sel = ref.read(selectedDayProvider);
    final targetYear = sel.year + delta;
    final lastDay = DateTime(targetYear, sel.month + 1, 0).day;
    ref.read(selectedDayProvider.notifier).state = DateTime(
      targetYear,
      sel.month,
      sel.day.clamp(1, lastDay),
    );
  }

  /// Тап по дню: выбрать его и перейти на дневной вид (как в month_view).
  void _selectDay(WidgetRef ref, DateTime day) {
    ref.read(selectedDayProvider.notifier).state = DateTime(
      day.year,
      day.month,
      day.day,
    );
    ref.read(planViewProvider.notifier).state = PlanView.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;

    final sel = ref.watch(selectedDayProvider);
    final year = sel.year;

    // ОДИН watch на весь год: агрегированные счётчики задач по локальным дням.
    final countsAsync = ref.watch(yearTaskCountsProvider(year));
    // Пока данные ещё не пришли (первый emit) — KaiLoader вместо пустых ячеек.
    // Образец: day_timeline.dart (isLoading && valueOrNull==null).
    if (countsAsync.isLoading && countsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }
    final counts = countsAsync.valueOrNull ?? const <String, int>{};

    final today = DateTime.now();

    return GestureDetector(
      // Горизонтальный свайп листает ГОДА (направление как в month_view:
      // свайп вправо = назад). onHorizontalDragEnd не мешает тапам по дням.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() <= 300) return;
        _changeYear(ref, v > 0 ? -1 : 1);
      },
      child: Column(
        children: [
          // Заголовок года со стрелками — паттерн идентичен MonthView.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                    color: textMuted,
                  ),
                  onPressed: () => _changeYear(ref, -1),
                ),
                Expanded(
                  child: Text(
                    '$year',
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                    color: textMuted,
                  ),
                  onPressed: () => _changeYear(ref, 1),
                ),
              ],
            ),
          ),
          // Сетка всех 12 мини-месяцев. Цель: на широком вебе ВСЕ 12 видны без
          // прокрутки (как в Google Calendar). Кол-во колонок — от ширины
          // (~220dp на колонку, 2..4). Высоту ячейки подбираем так, чтобы все
          // ряды поместились по высоте; если для читаемости места не хватает
          // (узкий телефон / крупный textScale) — даём небольшой вертикальный
          // скролл вместо нечитаемого сжатия.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const padH = 12.0;
                const padBottom = 12.0;
                const spacing = 8.0;
                // Минимальная читаемая высота мини-месяца (заголовок + шапка
                // дней + строки недель). Ниже — лучше скролл, чем мелочь.
                const minCellH = 132.0;

                final cols = (constraints.maxWidth / 220).floor().clamp(2, 4);
                final rows = (12 / cols).ceil();

                final availW = constraints.maxWidth - padH * 2;
                final cellW = (availW - spacing * (cols - 1)) / cols;
                // Естественная (слегка портретная) высота мини-месяца.
                final naturalH = cellW / 0.82;

                final availH = constraints.maxHeight - padBottom;
                final fitCellH = (availH - spacing * (rows - 1)) / rows;

                double cellH;
                ScrollPhysics physics;
                if (naturalH <= fitCellH) {
                  // Естественный размер помещается — без скролла.
                  cellH = naturalH;
                  physics = const NeverScrollableScrollPhysics();
                } else if (fitCellH >= minCellH) {
                  // Сжимаем до высоты экрана — всё ещё читаемо, без скролла
                  // (целевой случай широкого веба: все 12 видны).
                  cellH = fitCellH;
                  physics = const NeverScrollableScrollPhysics();
                } else {
                  // Места мало для читаемости — фиксируем минимум и скроллим.
                  cellH = minCellH;
                  physics = const AlwaysScrollableScrollPhysics();
                }

                return GridView.builder(
                  physics: physics,
                  padding: const EdgeInsets.fromLTRB(padH, 0, padH, padBottom),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: cellW / cellH,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    // RepaintBoundary вокруг каждого мини-месяца: год-вид —
                    // много ячеек; изолируем перерисовку (перф §6).
                    return RepaintBoundary(
                      child: _MiniMonth(
                        year: year,
                        month: month,
                        counts: counts,
                        today: today,
                        selected: sel,
                        onSelectDay: (d) => _selectDay(ref, d),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Компактная мини-сетка одного месяца: заголовок месяца + однобуквенная шапка
/// дней недели + строки чисел (Пн..Вс). На днях с задачами — индикатор-точка,
/// насыщенность которой растёт с числом задач. Сегодня выделено рамкой.
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.counts,
    required this.today,
    required this.selected,
    required this.onSelectDay,
  });

  final int year;
  final int month;
  final Map<String, int> counts;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;

    final firstOfMonth = DateTime(year, month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // Mon=0..Sun=6
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Заголовок мини-месяца: короткое имя ('Jan'/'янв').
    final monthLabel = DateFormat('MMM').format(firstOfMonth);

    // Ячейки сетки: пустышки до первого дня + числа 1..N.
    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _MiniDayCell(
          day: d,
          count: counts[localDayKey(DateTime(year, month, d))] ?? 0,
          isToday: isSameDate(DateTime(year, month, d), today),
          isSelected: isSameDate(DateTime(year, month, d), selected),
          onTap: () => onSelectDay(DateTime(year, month, d)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            monthLabel,
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Однобуквенная шапка дней недели (узкая под мини-сетку).
        Row(
          children: [
            for (final key in _weekdayKeys)
              Expanded(
                child: Center(
                  child: Text(
                    // Первый символ локализованной подписи (М/В/С… или M/T/W…).
                    _firstChar(context.s(key)),
                    style: textTheme.labelSmall?.copyWith(
                      color: textFaint,
                      fontSize: 9,
                      height: 1.0,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Сетка чисел месяца: 7 колонок, без скролла (мини-месяц целиком виден).
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            children: cells,
          ),
        ),
      ],
    );
  }

  /// Безопасно берёт первый символ строки (или пусто).
  static String _firstChar(String s) =>
      s.characters.isEmpty ? '' : s.characters.first;
}

/// Одна ячейка дня в мини-месяце. Индикатор «занятости»: число рисуется поверх
/// круглой подложки accent, прозрачность которой растёт с числом задач
/// (1 → бледная, 3+ → полная). Сегодня — тонкая рамка accent. Выбранный день —
/// сплошная accent-заливка (как маркер в month_view).
class _MiniDayCell extends StatelessWidget {
  const _MiniDayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final hasTasks = count > 0;

    // Интенсивность заливки по «занятости»: 1→0.30, 2→0.55, 3+→0.80 непрозр.
    final double busyOpacity = count <= 0
        ? 0.0
        : count == 1
        ? 0.30
        : count == 2
        ? 0.55
        : 0.80;

    // Цвет подложки: выбранный — полная accent; иначе — accent с busyOpacity.
    final Color? fill = isSelected
        ? colorScheme.primary
        : hasTasks
        ? colorScheme.primary.withValues(alpha: busyOpacity)
        : null;

    // Цвет числа: поверх насыщенной заливки — onPrimary (контраст);
    // на бледной/без заливки — onSurface.
    final bool denseFill = isSelected || busyOpacity >= 0.55;
    final Color textColor = denseFill
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Center(
          child: Container(
            // Фиксированный компактный кружок; FittedBox ужимает число при
            // крупном текст-скейле, поэтому overflow невозможен.
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: colorScheme.primary, width: 1.0)
                  : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '$day',
                  maxLines: 1,
                  softWrap: false,
                  style: textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: isSelected || isToday || count >= 3
                        ? FontWeight.w700
                        : FontWeight.w400,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
