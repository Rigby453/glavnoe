// FL-DIARY-HISTORY: Год-календарь дневника (heatmap по настроению).
// - 12 мини-месяцев года; каждый день окрашен по mood записи day_logs за
//   этот день (если есть). Цвет получается интерполяцией между ext.danger
//   (плохое настроение) и ext.success (хорошее) — без хардкода цветов мимо
//   темы (используются только токены FocusThemeExtension).
// - Тап по дню → DiaryDayDetailScreen (просмотр + правка записи ЛЮБОГО дня).
// - Год переключается стрелками ‹ YYYY ›, нижняя граница — 2020 (как в
//   DateNavigator), верхняя — текущий год (нельзя смотреть в будущее).
// - Структура мини-месяца зеркалит features/plan/widgets/year_view.dart
//   (_MiniMonth/_MiniDayCell), но красит по настроению, а не по «занятости».
//
// Иконки: Phosphor. Карточки/легенда: surface1 + hairline + R14.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import 'diary_day_detail_screen.dart';
import 'diary_history_providers.dart';

const List<String> _moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];

/// Ключи однобуквенных подписей дней недели (Пн..Вс) — переиспользуем
/// существующие строки plan-модуля (уже локализованы на все языки).
const List<String> _weekdayKeys = [
  'plan.weekday_mon',
  'plan.weekday_tue',
  'plan.weekday_wed',
  'plan.weekday_thu',
  'plan.weekday_fri',
  'plan.weekday_sat',
  'plan.weekday_sun',
];

class DiaryHistoryScreen extends ConsumerStatefulWidget {
  const DiaryHistoryScreen({super.key});

  @override
  ConsumerState<DiaryHistoryScreen> createState() =>
      _DiaryHistoryScreenState();
}

class _DiaryHistoryScreenState extends ConsumerState<DiaryHistoryScreen> {
  late int _year;

  static const int _firstYear = 2020;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  void _changeYear(int delta) {
    final next = _year + delta;
    if (next < _firstYear || next > DateTime.now().year) return;
    setState(() => _year = next);
  }

  Future<void> _openDay(DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiaryDayDetailScreen(date: day),
      ),
    );
    // После возврата (возможна правка) — обновляем heatmap года.
    ref.invalidate(dayLogsInYearProvider(_year));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final yearData = ref.watch(dayLogsInYearProvider(_year));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.s('diary.history_screen_title'),
          style: textTheme.headlineSmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Переключатель года ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(PhosphorIcons.caretLeft()),
                  onPressed:
                      _year > _firstYear ? () => _changeYear(-1) : null,
                ),
                Text('$_year', style: textTheme.headlineSmall),
                IconButton(
                  icon: Icon(PhosphorIcons.caretRight()),
                  onPressed: _year < DateTime.now().year
                      ? () => _changeYear(1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Легенда цветов настроения ---
            Text(
              context.s('diary.history_legend'),
              style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(5, (i) {
                final mood = i + 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: moodColor(ext, mood),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_moodEmojis[i], style: const TextStyle(fontSize: 14)),
                  ],
                );
              }),
            ),
            const SizedBox(height: 20),

            // --- Год-сетка из 12 мини-месяцев ---
            yearData.when(
              data: (moods) => _YearGrid(
                year: _year,
                moods: moods,
                onSelectDay: _openDay,
              ),
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: KaiLoader(label: context.s('loading.generic')),
                ),
              ),
              error: (err, st) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.s('error.generic').replaceFirst('{err}', '$err'),
                  style: textTheme.bodyMedium?.copyWith(color: ext.ember),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Адаптивная сетка из 12 мини-месяцев. Колонок столько, сколько помещается
/// по ширине (минимум 170dp на колонку) — на узком телефоне это 1 колонка
/// (месяцы идут друг под другом, страница скроллится целиком), на широком
/// экране — 2-4 колонки.
class _YearGrid extends StatelessWidget {
  const _YearGrid({
    required this.year,
    required this.moods,
    required this.onSelectDay,
  });

  final int year;
  final Map<String, int> moods;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final cols = (constraints.maxWidth / 170).floor().clamp(1, 4);
        final cellW =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        final cellH = cellW / 0.78; // чуть выше плана — крупнее круги дней

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: cellW / cellH,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            return RepaintBoundary(
              child: _MiniMonth(
                year: year,
                month: month,
                moods: moods,
                today: today,
                onSelectDay: onSelectDay,
              ),
            );
          },
        );
      },
    );
  }
}

/// Мини-сетка одного месяца: заголовок + однобуквенная шапка дней недели +
/// строки чисел (Пн..Вс). Каждый день окрашен по настроению (если есть запись).
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.moods,
    required this.today,
    required this.onSelectDay,
  });

  final int year;
  final int month;
  final Map<String, int> moods;
  final DateTime today;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textFaint = ext?.textFaint ?? Theme.of(context).colorScheme.onSurface;

    final firstOfMonth = DateTime(year, month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // Mon=0..Sun=6
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final monthLabel = DateFormat('MMM').format(firstOfMonth);

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _MoodDayCell(
          day: d,
          mood: moods['$year-$month-$d'],
          isToday: year == today.year && month == today.month && d == today.day,
          isFuture: DateTime(year, month, d).isAfter(todayMidnight),
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
        Row(
          children: [
            for (final key in _weekdayKeys)
              Expanded(
                child: Center(
                  child: Text(
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

  static String _firstChar(String s) =>
      s.characters.isEmpty ? '' : s.characters.first;
}

/// Одна ячейка дня: круг, залитый цветом настроения (если есть запись).
/// Без записи — прозрачный (только число). Сегодня — тонкая accent-рамка.
/// Будущие дни — приглушены и недоступны для тапа (логировать наперёд нельзя).
class _MoodDayCell extends StatelessWidget {
  const _MoodDayCell({
    required this.day,
    required this.mood,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final int day;
  final int? mood;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final Color? fill = mood != null ? moodColor(ext, mood!) : null;
    final bool dense = mood != null && mood! != 3;
    final Color textColor = fill != null
        ? colorScheme.onPrimary
        : (isFuture ? ext.textFaint : colorScheme.onSurface);

    return GestureDetector(
      onTap: isFuture ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isFuture ? 0.35 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: isToday
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
                      fontWeight:
                          isToday || dense ? FontWeight.w700 : FontWeight.w400,
                      height: 1.0,
                    ),
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
