// FL-PLAN-01: Горизонтальная полоса недель с прокруткой через PageView.
// selectedDayProvider — StateProvider<DateTime> (только дата, без времени),
// по умолчанию сегодня. Тап на ячейку меняет провайдер.
// Выбранная ячейка подсвечивается colorScheme.primary (lime в Focus теме).
// Анимация смены страницы — lateral, duration=200ms (normal из design-tokens).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weekday_label.dart';

/// Возвращает [date] нормализованной до полуночи локального времени
/// (отбрасывает компонент времени). Используется при записи в
/// [selectedDayProvider], чтобы сравнения дат по `==` работали надёжно.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Сравнивает две даты по году/месяцу/дню, игнорируя время и таймзону-сдвиг
/// в часах. Надёжнее, чем `a == b`, если в одну из дат случайно попало время.
bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Выбранный день в плане. Нормализован до полуночи локального времени.
/// По умолчанию — сегодня.
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class WeekStrip extends ConsumerStatefulWidget {
  const WeekStrip({super.key});

  @override
  ConsumerState<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<WeekStrip> {
  late final PageController _pageController;

  // Страница 0 соответствует текущей неделе.
  // Отрицательные индексы — прошлые недели; положительные — будущие.
  // Используем большое смещение (1000) чтобы можно было листать в обе стороны.
  static const int _initialPage = 1000;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Первый день (понедельник) недели, содержащей [date].
  DateTime _weekStart(DateTime date) {
    // weekday: 1=пн, 7=вс
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  /// Дата для ячейки [offset] от начала недели [weekStart].
  DateTime _dayOf(DateTime weekStart, int offset) => DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + offset,
      );

  /// Переключает strip на неделю, содержащую [date], и выбирает [date].
  void _jumpToDate(DateTime date) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final baseWeekStart = _weekStart(todayNorm);
    final targetWeekStart = _weekStart(date);

    // Количество недель от базовой (текущей) до целевой
    final weekDiff =
        targetWeekStart.difference(baseWeekStart).inDays ~/ 7;
    final targetPage = _initialPage + weekDiff;

    // Уважаем reduce-motion (ANIMATIONS.md §10)
    final duration = effectiveDuration(context, kDurationNormal);
    _pageController.animateToPage(
      targetPage,
      duration: duration == Duration.zero ? Duration.zero : kDurationNormal,
      curve: kCurveLift,
    );
    ref.read(selectedDayProvider.notifier).state = date;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Вычисляем базовую неделю (понедельник текущей недели)
    final baseWeekStart = _weekStart(todayNorm);

    return SizedBox(
      height: 72,
      child: PageView.builder(
        controller: _pageController,
        pageSnapping: true,
        itemBuilder: (context, pageIndex) {
          // pageIndex - _initialPage = смещение в неделях от сегодня
          final weekOffset = pageIndex - _initialPage;
          final weekStart = _dayOf(baseWeekStart, weekOffset * 7);

          return _WeekRow(
            weekStart: weekStart,
            selectedDay: selectedDay,
            today: todayNorm,
            onDayTap: (day) {
              ref.read(selectedDayProvider.notifier).state = day;
            },
            onDayLongPress: (day) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2020),
                lastDate: DateTime(2099),
              );
              if (picked != null) {
                _jumpToDate(picked);
              }
            },
          );
        },
      ),
    );
  }
}

/// Одна строка из 7 ячеек для недели, начинающейся с [weekStart].
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.onDayTap,
    required this.onDayLongPress,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + i,
        );
        return Expanded(
          child: _DayCell(
            day: day,
            isSelected: day == selectedDay,
            isToday: day == today,
            onTap: () => onDayTap(day),
            onLongPress: () => onDayLongPress(day),
          ),
        );
      }),
    );
  }
}

/// Ячейка одного дня: короткое название дня недели + число.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final reduceMotion = reduceMotionOf(context);

    // Accent discipline: fill только для selected; accent text для today
    final Color bgColor =
        isSelected ? colorScheme.primary : Colors.transparent;
    final Color textColor = isSelected
        ? colorScheme.onPrimary  // контрастный текст поверх accent fill
        : isToday
            ? colorScheme.primary  // accent только для маркера «сегодня»
            : colorScheme.onSurface;
    final Color mutedTextColor = isSelected
        ? colorScheme.onPrimary.withValues(alpha: 0.8)
        : textMuted;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        // Уважаем reduce-motion (ANIMATIONS.md §10)
        duration: reduceMotion ? Duration.zero : kDurationFast,
        curve: kCurveLift,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          // radius.sm = 8 (02-type-space §4.2)
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              // Короткое название дня: Mon, Tue, etc. Безопасно для локалей с
              // 1–2-символьной аббревиатурой (ru «пн», ja «月»): иначе
              // substring(0,3) бросал бы RangeError.
              shortWeekdayLabel(day),
              maxLines: 1,
              overflow: TextOverflow.clip,
              // labelSmall для коротких меток (02-type-space §1)
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              day.day.toString(),
              maxLines: 1,
              overflow: TextOverflow.clip,
              // bodyMedium для числа дня
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
