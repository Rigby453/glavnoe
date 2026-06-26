// FL-PLAN-02: Таймлайн задач выбранного дня.
// Реактивно читает задачи через watchTodayItems(selectedDay) из ItemsDao.
// Каждая карточка: время + заголовок + значок типа.
// Тап на карточку → showAddTaskSheet в режиме редактирования.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/routing/block_tool_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tag_parser.dart';
import '../../../core/widgets/kai_loader.dart';
import '../../today/task_colors.dart';
import '../../import/import_sheet.dart';
import '../../today/widgets/add_task_sheet.dart';
import 'plan_providers.dart';
import 'recurrence_providers.dart';
import 'week_strip.dart';

/// Задачи выбранного дня — раскрытые: конкретные строки + виртуальные повторы
/// серий. Реэкспортирует expandedDayItemsProvider (тот же источник, что и
/// Today-экран), поэтому повторы появляются и в списке, и в сетке Plan.
final dayItemsProvider = Provider.autoDispose
    .family<AsyncValue<List<ItemsTableData>>, DateTime>((ref, date) {
  return ref.watch(expandedDayItemsProvider(date));
});

class DayTimeline extends ConsumerWidget {
  const DayTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final itemsAsync = ref.watch(dayItemsProvider(selectedDay));

    // KaiLoader вместо CircularProgressIndicator (03-components §17 / kai_loader.dart)
    if (itemsAsync.isLoading && itemsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }

    // valueOrNull: не блокируем UI на loading — список появится как только
    // стрим доставит данные; ошибка логируется через itemsAsync.error
    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    // Фильтр поиска: подстрока заголовка + #хэштег + тип (см. planSearchMatches).
    final query = ref.watch(planSearchQueryProvider);
    final filtered = query.trim().isEmpty
        ? items
        : items.where((i) => planSearchMatches(i, query)).toList();

    // Закрепляем экзамены/дедлайны вверху ленты (UX-LAYOUT.md §5, §9 п.2).
    // Stable-sort: сначала pinned (exam/deadline), отсортированные по scheduledAt
    // (ближайший = первый, просроченные — раньше всех по дате); затем остальные
    // в исходном хронологическом порядке без изменений.
    final pinned = filtered
        .where((i) => i.type == 'exam' || i.type == 'deadline')
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final rest =
        filtered.where((i) => i.type != 'exam' && i.type != 'deadline').toList();
    final ordered = [...pinned, ...rest];
    // Выполненные задачи уходят ВНИЗ списка (как в Google Calendar / списках дел):
    // невыполненные сохраняют свой порядок, done — в конце (стабильно).
    final sorted = [
      ...ordered.where((i) => i.status != 'done'),
      ...ordered.where((i) => i.status == 'done'),
    ];

    if (sorted.isEmpty) {
      return _EmptyState(day: selectedDay);
    }
    return ListView.separated(
      // 24dp горизонтальный отступ экрана (02-type-space §4.1); 96dp снизу под FAB
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      itemCount: sorted.length,
      // Комфортный зазор между карточками (02-type-space §4.1)
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = sorted[index];
        return _ItemCard(
          item: item,
          selectedDay: selectedDay,
        );
      },
    );
  }
}

/// Карточка одной задачи/события в таймлайне.
/// ConsumerWidget — нужен ref для openBlockTool (единая маршрутизация).
class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item, required this.selectedDay});

  final ItemsTableData item;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // ThemeExtension — источник дополнительных цветов (01-color.md)
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;

    final borderColor = ext?.border ?? colorScheme.outline;
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;

    // Экзамены/дедлайны — ember-рамка (03-components §10 Ember card variant)
    final isUrgent = item.type == 'exam' || item.type == 'deadline';
    final ember = ext?.ember ?? colorScheme.secondary;
    final cardBorderColor = isUrgent ? ember : borderColor;
    final cardBorderWidth = isUrgent ? 1.5 : 0.5; // hairline для обычных карточек

    // Иконка модуля (аффорданс) — textMuted, ненавязчиво
    final moduleIcon = _moduleLinkIcon(item.moduleLink, ext, colorScheme);

    // Пользовательский цвет-метка задачи (null = нет).
    final taskColor = taskColorFromKey(item.color);

    return InkWell(
      // Короткий тап: инструмент модуля (если есть moduleLink), иначе редактирование.
      // openBlockTool возвращает false для null/неизвестных moduleLink.
      onTap: () {
        if (!openBlockTool(context, ref, item)) {
          showAddTaskSheet(context, day: selectedDay, existing: item);
        }
      },
      // Долгий тап при наличии moduleLink → всегда редактирование
      onLongPress: item.moduleLink != null
          ? () => showAddTaskSheet(context, day: selectedDay, existing: item)
          : null,
      borderRadius: BorderRadius.circular(16), // radius.md
      child: Container(
        // 16dp внутренний отступ карточки (02-type-space §4.1)
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: cardBorderWidth),
        ),
        child: Row(
          children: [
            // Цветная полоса-метка задачи (когда задан цвет). Для бесцветных —
            // ничего не добавляем, текущий вид карточки не меняется.
            if (taskColor != null) ...[
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: taskColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Время — bodySmall для метаданных (02-type-space §1)
            SizedBox(
              width: 44,
              child: Text(
                DateFormat.Hm().format(item.scheduledAt),
                style: textTheme.bodySmall?.copyWith(
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Заголовок (растягивается)
            Expanded(
              child: _TimelineItemTitle(
                item: item,
                textTheme: textTheme,
                textMuted: textMuted,
                colorScheme: colorScheme,
                ember: ember,
                isUrgent: isUrgent,
              ),
            ),
            const SizedBox(width: 8),
            // Иконка модуля (аффорданс) — показывается если задача привязана
            if (moduleIcon != null) ...[
              moduleIcon,
              const SizedBox(width: 6),
            ],
            // Значок типа
            _TypeBadge(type: item.type),
          ],
        ),
      ),
    );
  }
}

/// Текст обратного отсчёта до даты (для экзаменов/дедлайнов).
String _countdownLabel(BuildContext context, DateTime at) {
  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  final d1 = DateTime(at.year, at.month, at.day);
  final days = d1.difference(d0).inDays;
  if (days < 0) return context.s('plan.countdown_overdue');
  if (days == 0) return context.s('plan.countdown_today');
  if (days == 1) return context.s('plan.countdown_tomorrow');
  // «in N days» — префикс + число + суффикс
  return '${context.s('plan.countdown_in_days_prefix')}$days${context.s('plan.countdown_in_days_suffix')}';
}

/// Маленький значок типа задачи.
/// Exam/deadline → ember (correct per accent discipline spec).
/// Event → нейтральный textMuted/accentMuted (не accent fill).
/// Task → textFaint (минимальный вес).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();

    final ember = ext?.ember ?? colorScheme.secondary;
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;

    // Accent discipline: только ember для urgent, нейтрали для event/task
    final (label, color) = switch (type) {
      'exam'     => (context.s('plan.type_exam'), ember),
      'deadline' => (context.s('plan.type_deadline'), ember),
      'event'    => (context.s('plan.type_event'), textMuted),
      _          => (context.s('plan.type_task'), textFaint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // Фон с малой прозрачностью — не accent fill
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999), // radius.pill
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
            ),
      ),
    );
  }
}

/// Иконка для значения moduleLink. null если ссылки нет или moduleLink неизвестен.
Widget? _moduleLinkIcon(
  String? moduleLink,
  FocusThemeExtension? ext,
  ColorScheme colorScheme,
) {
  if (moduleLink == null) return null;
  final color = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);
  final icon = switch (moduleLink) {
    'workout'    => Icons.fitness_center,
    'sleep'      => Icons.bedtime_outlined,
    'focus'      => Icons.timer_outlined,
    'warmup'     => Icons.accessibility_new_outlined,
    'breathing'  => Icons.air,
    'meditation' => Icons.self_improvement,
    // meal:* — иконка ресторана для всех приёмов пищи
    String s when s.startsWith('meal:') => Icons.restaurant_outlined,
    _ => null,
  };
  if (icon == null) return null;
  return Icon(icon, size: 16, color: color);
}

// _openModule удалён — используй openBlockTool из core/routing/block_tool_router.dart

// ---------------------------------------------------------------------------
// Заголовок задачи в таймлайне: чистый title (без #тегов) + чипы тегов.
// ---------------------------------------------------------------------------

class _TimelineItemTitle extends StatelessWidget {
  const _TimelineItemTitle({
    required this.item,
    required this.textTheme,
    required this.textMuted,
    required this.colorScheme,
    required this.ember,
    required this.isUrgent,
  });

  final ItemsTableData item;
  final TextTheme textTheme;
  final Color textMuted;
  final ColorScheme colorScheme;
  final Color ember;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final parsed = parseTaskTags(item.title);
    final displayTitle =
        parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : item.title;
    final titleStyle = (item.priority == 'main'
            ? textTheme.titleMedium
            : textTheme.titleSmall)
        ?.copyWith(
      decoration: item.status == 'done' ? TextDecoration.lineThrough : null,
      color: item.status == 'done' ? textMuted : colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayTitle,
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Обратный отсчёт для экзаменов/дедлайнов — ember
        if (isUrgent)
          Text(
            _countdownLabel(context, item.scheduledAt),
            style: textTheme.bodySmall?.copyWith(
              color: ember,
              fontWeight: FontWeight.w600,
            ),
          ),
        // Теги под заголовком
        if (parsed.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final tag in parsed.tags)
                  Text(
                    '#$tag',
                    style: textTheme.labelSmall?.copyWith(color: textMuted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Пустое состояние — нет задач на выбранный день.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;
    final textFaint = ext?.textFaint ?? colorScheme.onSurface;

    // LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight) —
    // стандартный паттерн Flutter «центрируй когда влезает, скролль когда нет».
    // Без этого при 6-рядном раскрытом ExpandableWeekCalendar (~410px) на
    // маленьком экране Expanded давал DayTimeline < 200px, а Column(mainSize.min)
    // превышала доступное пространство → «BOTTOM OVERFLOWED BY 27 PIXELS».
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              // 32dp отступ с воздухом
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    // textFaint для пустых состояний (01-color.md textFaint)
                    color: textFaint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${context.s('plan.empty_prefix')}${DateFormat.MMMd().format(day)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ext?.textMuted ?? colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.s('plan.empty_hint'),
                    // bodySmall для подсказки (02-type-space §1)
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  // Кнопка-призыв: главная студенческая фича — импорт расписания.
                  // Показывается в пустом состоянии, чтобы пользователь сразу знал
                  // о возможности импорта (иначе она скрыта в меню AppBar).
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => showImportSheet(context, day: day),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(context.s('plan.import_tooltip')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
