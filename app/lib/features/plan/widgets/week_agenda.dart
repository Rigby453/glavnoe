// Недельный вид Plan: повестка из 7 дней недели, содержащей выбранный день.
// Каждый день — заголовок + его задачи. Использует тот же dayItemsProvider
// (watchTodayItems), что и дневной вид и экран Today — единая логика «дня».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day_window.dart';
import '../../../core/utils/tag_parser.dart';
import '../../today/widgets/add_task_sheet.dart';
import 'day_timeline.dart' show dayItemsProvider;
import 'plan_providers.dart' show planSearchMatches, planSearchQueryProvider;
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

    final weekStartLocal = localDayStart(weekStart);
    final count =
        await ref.read(itemsDaoProvider).cloneWeekEvents(weekStartLocal);
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
      // 24dp горизонтальный отступ (02-type-space §4.1); 96dp снизу под FAB
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
        // Вторичное действие — TextButton (03-components §6)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: Icon(PhosphorIcons.copy(PhosphorIconsStyle.regular), size: 18),
            label: Text(context.s('plan.clone_week_button')),
            onPressed: () => _cloneWeek(context, ref, weekStart),
          ),
        ),
        const SizedBox(height: 8),
        for (final day in days) _DaySection(day: day),
      ],
    );
  }
}

/// 3-дневная агенда: список из секции выбранного дня и двух следующих
/// (selectedDay, +1, +2), хронологически. Списочный аналог ThreeDayTimeGrid —
/// переиспользует тот же _DaySection (заголовок дня + задачи + фильтр поиска),
/// что и недельная агенда, поэтому поведение строк/поиска идентично.
class ThreeDayAgenda extends ConsumerWidget {
  const ThreeDayAgenda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final days = List.generate(
      3,
      (i) => DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day + i,
      ),
    );

    return ListView(
      // 24dp горизонтальный отступ (02-type-space §4.1); 96dp снизу под FAB
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
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
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;
    final border = ext?.border ?? colorScheme.outline;

    final itemsAsync = ref.watch(dayItemsProvider(day));
    // Пока данные ещё не пришли (первый emit) — флаг загрузки для секции дня.
    // Образец: day_timeline.dart (isLoading && valueOrNull==null).
    final isDayLoading = itemsAsync.isLoading && itemsAsync.valueOrNull == null;
    final allItems = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    // Фильтр поиска: подстрока заголовка + #хэштег + тип (см. planSearchMatches).
    // Применяется и в недельной агенде, и в 3-дневной (общий _DaySection).
    final query = ref.watch(planSearchQueryProvider);
    final items = query.trim().isEmpty
        ? allItems
        : allItems.where((i) => planSearchMatches(i, query)).toList();

    final today = DateTime.now();
    final isToday =
        day == DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              // Flexible + ellipsis: при крупном textScale (1.5) длинная дата
              // вместе с лейблом «today» не должна переполнять строку (overflow-гейт).
              Flexible(
                child: Text(
                  DateFormat('EEE, MMM d').format(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // titleSmall для заголовков дней в week-agenda (02-type-space §1)
                  style: textTheme.titleSmall?.copyWith(
                    // Акцент только на today-маркер (accent discipline)
                    color: isToday ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                // Лейбл «today» — accent только здесь как маркер текущего дня
                Text(
                  context.s('plan.week_today_label'),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isDayLoading)
          // Тонкий горизонтальный прогресс-бар пока БД ещё не отдала данные.
          // LinearProgressIndicator компактнее KaiLoader и не ломает ритм
          // многострочной агенды (7 или 3 дня на одном экране).
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(),
            ),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // Тире вместо пустоты — textFaint (01-color.md)
            child: Text('—', style: textTheme.bodySmall?.copyWith(color: textFaint)),
          )
        else
          ...items.map((i) => _AgendaRow(item: i, day: day)),
        // Hairline разделитель 0.5dp (02-type-space §4.3)
        Divider(height: 12, thickness: 0.5, color: border),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final done = item.status == 'done';

    // Иконка модуля — textMuted, ненавязчиво (только если есть ссылка)
    final moduleIcon = _moduleLinkIcon(item.moduleLink, ext, colorScheme);

    // Парсим теги из заголовка: показываем чистый заголовок + чипы тегов.
    final parsed = parseTaskTags(item.title);
    final displayTitle =
        parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : item.title;

    return InkWell(
      onTap: item.moduleLink != null
          ? () => _openModule(context, item.moduleLink!)
          : () => showAddTaskSheet(context, day: day, existing: item),
      onLongPress: item.moduleLink != null
          ? () => showAddTaskSheet(context, day: day, existing: item)
          : null,
      child: Padding(
        // Комфортный вертикальный отступ строки
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            // Время — bodySmall для метаданных (02-type-space §1)
            SizedBox(
              width: 44,
              child: Text(
                DateFormat.Hm().format(item.scheduledAt),
                style: textTheme.bodySmall?.copyWith(color: textMuted),
              ),
            ),
            const SizedBox(width: 8),
            // Для main-задачи бейдж не нужен — акцент идёт через шрифт/цвет заголовка
            // Иконка модуля — показывается если задача привязана к модулю
            if (moduleIcon != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: moduleIcon,
              ),
            // Заголовок + чипы тегов (если есть). Expanded предотвращает overflow.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // bodyMedium для текста задач
                    style: textTheme.bodyMedium?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? textMuted : colorScheme.onSurface,
                    ),
                  ),
                  // Теги под заголовком — тихий стиль (textMuted, labelSmall)
                  if (parsed.tags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 0,
                      children: [
                        for (final tag in parsed.tags)
                          Text(
                            '#$tag',
                            style: textTheme.labelSmall
                                ?.copyWith(color: textMuted),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Иконка для значения moduleLink. null если ссылки нет.
Widget? _moduleLinkIcon(
  String? moduleLink,
  FocusThemeExtension? ext,
  ColorScheme colorScheme,
) {
  if (moduleLink == null) return null;
  final color = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);
  final icon = switch (moduleLink) {
    'workout' => PhosphorIcons.barbell(PhosphorIconsStyle.regular),
    'sleep'   => PhosphorIcons.moon(PhosphorIconsStyle.regular),
    String s when s.startsWith('meal:') => PhosphorIcons.forkKnife(PhosphorIconsStyle.regular),
    _ => null,
  };
  if (icon == null) return null;
  return Icon(icon, size: 14, color: color);
}

/// Навигирует в соответствующий модуль по значению moduleLink.
void _openModule(BuildContext context, String moduleLink) {
  if (moduleLink == 'workout') {
    context.push('/workouts');
  } else if (moduleLink == 'sleep') {
    context.push('/sleep-report');
  } else if (moduleLink.startsWith('meal:')) {
    // meal:<slot> → открыть Food и доскроллить к этому приёму.
    context.push('/food?meal=${moduleLink.substring(5)}');
  }
}
