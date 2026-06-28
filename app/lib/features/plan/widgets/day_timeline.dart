// FL-PLAN-02 (Kaname §4.1): таймлайн задач выбранного дня.
// Использует общий TimelineList (§4.1) вместо собственных карточек.
// Маппинг ItemsTableData → TimelineEntry: узел по виду (main/done/event/task),
// иконка типа/модуля справа, CategoryDot по первому тегу, countdown для exam/deadline.
// Бизнес-логика (провайдеры, DAO-пути) без изменений.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/routing/block_tool_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tag_parser.dart';
import '../../../core/widgets/kai_loader.dart';
import '../../../core/widgets/timeline/timeline_entry.dart';
import '../../../core/widgets/timeline/timeline_list.dart';
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

    // KaiLoader вместо CircularProgressIndicator
    if (itemsAsync.isLoading && itemsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }

    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    // Фильтр поиска: подстрока заголовка + #хэштег + тип
    final query = ref.watch(planSearchQueryProvider);
    final filtered = query.trim().isEmpty
        ? items
        : items.where((i) => planSearchMatches(i, query)).toList();

    // Закрепляем экзамены/дедлайны вверху, выполненные — вниз
    final pinned = filtered
        .where((i) => i.type == 'exam' || i.type == 'deadline')
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final rest =
        filtered.where((i) => i.type != 'exam' && i.type != 'deadline').toList();
    final ordered = [...pinned, ...rest];
    final sorted = [
      ...ordered.where((i) => i.status != 'done'),
      ...ordered.where((i) => i.status == 'done'),
    ];

    if (sorted.isEmpty) {
      return _EmptyState(day: selectedDay);
    }

    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final ember = ext?.ember ?? scheme.secondary;
    final now = TimeOfDay.now();

    final entries = sorted
        .map((item) => _toEntry(
              context: context,
              ref: ref,
              item: item,
              day: selectedDay,
              ember: ember,
              textTheme: textTheme,
            ))
        .toList();

    return SingleChildScrollView(
      // 96dp снизу под FAB
      padding: const EdgeInsets.only(bottom: 96),
      child: TimelineList(
        entries: entries,
        showNowLine: true,
        nowTime: now,
        // 24dp горизонтальный отступ экрана (design-tokens §spacing.lg)
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Пустое состояние
// ---------------------------------------------------------------------------

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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIcons.calendarCheck(PhosphorIconsStyle.regular),
                    size: 48,
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
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => showImportSheet(context, day: day),
                    icon: Icon(
                      PhosphorIcons.uploadSimple(PhosphorIconsStyle.regular),
                      size: 18,
                    ),
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

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

/// Преобразует [ItemsTableData] в [TimelineEntry] для виджета [TimelineList].
///
/// Бизнес-логика: узел по виду (mainPending/done/event/task), иконка типа/модуля,
/// CategoryDot по первому тегу, countdown-виджет для exam/deadline.
TimelineEntry _toEntry({
  required BuildContext context,
  required WidgetRef ref,
  required ItemsTableData item,
  required DateTime day,
  required Color ember,
  required TextTheme textTheme,
}) {
  final isDone = item.status == 'done';
  final isMain = item.priority == 'main' && !isDone;
  final isUrgent = item.type == 'exam' || item.type == 'deadline';

  // Вид узла на хребте: приоритет → done → mainPending → event/task
  final kind = isDone
      ? TimelineNodeKind.done
      : isMain
          ? TimelineNodeKind.mainPending
          : (item.type == 'event' || isUrgent)
              ? TimelineNodeKind.event
              : TimelineNodeKind.task;

  // Чистый заголовок без #тегов (schemaVersion 18 — теги в отдельном поле)
  final parsed = parseTaskTags(item.title);
  final title = parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : item.title;

  // Первый тег категории (из поля tags, schemaVersion 18; fallback — из title)
  final tagsStr = item.tags ?? '';
  final String firstTag;
  if (tagsStr.isNotEmpty) {
    firstTag = tagsStr
        .split(',')
        .map((t) => t.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
  } else if (parsed.tags.isNotEmpty) {
    firstTag = parsed.tags.first;
  } else {
    firstTag = '';
  }

  // Обратный отсчёт для экзаменов/дедлайнов — в trailing-виджете справа
  Widget? trailing;
  if (isUrgent) {
    trailing = Text(
      _countdownLabel(context, item.scheduledAt),
      style: textTheme.labelSmall?.copyWith(
        color: ember,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  return TimelineEntry(
    id: item.id,
    time: TimeOfDay(
      hour: item.scheduledAt.hour,
      minute: item.scheduledAt.minute,
    ),
    title: title,
    kind: kind,
    isMain: isMain,
    isDone: isDone,
    typeIcon: _typeIconFor(item),
    categoryTag: firstTag.isEmpty ? null : firstTag,
    trailing: trailing,
    // Тап: openBlockTool (если есть moduleLink), иначе редактирование
    onTap: () {
      if (!openBlockTool(context, ref, item)) {
        showAddTaskSheet(context, day: day, existing: item);
      }
    },
  );
}

/// Иконка типа задачи / привязки к модулю (Phosphor, regular).
/// Возвращает null для обычных задач (тип task, без moduleLink).
IconData? _typeIconFor(ItemsTableData item) {
  final link = item.moduleLink;
  if (link != null) {
    if (link == 'workout') {
      return PhosphorIcons.barbell(PhosphorIconsStyle.regular);
    }
    if (link == 'sleep') {
      return PhosphorIcons.moon(PhosphorIconsStyle.regular);
    }
    if (link == 'focus') {
      return PhosphorIcons.timer(PhosphorIconsStyle.regular);
    }
    if (link == 'breathing') {
      return PhosphorIcons.wind(PhosphorIconsStyle.regular);
    }
    if (link == 'meditation') {
      return PhosphorIcons.flowerLotus(PhosphorIconsStyle.regular);
    }
    if (link == 'warmup') {
      return PhosphorIcons.personSimpleWalk(PhosphorIconsStyle.regular);
    }
    if (link.startsWith('meal:')) {
      return PhosphorIcons.forkKnife(PhosphorIconsStyle.regular);
    }
  }
  if (item.type == 'exam' || item.type == 'deadline') {
    return PhosphorIcons.alarm(PhosphorIconsStyle.regular);
  }
  if (item.type == 'event') {
    return PhosphorIcons.calendar(PhosphorIconsStyle.regular);
  }
  return null;
}

/// Обратный отсчёт до даты задачи (экзамен/дедлайн).
String _countdownLabel(BuildContext context, DateTime at) {
  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  final d1 = DateTime(at.year, at.month, at.day);
  final days = d1.difference(d0).inDays;
  if (days < 0) return context.s('plan.countdown_overdue');
  if (days == 0) return context.s('plan.countdown_today');
  if (days == 1) return context.s('plan.countdown_tomorrow');
  return '${context.s('plan.countdown_in_days_prefix')}$days'
      '${context.s('plan.countdown_in_days_suffix')}';
}
