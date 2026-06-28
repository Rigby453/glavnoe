// FL-PLAN: Закреплённая карточка ближайшего экзамена/дедлайна.
// Отображается НАД прокручиваемым контентом Plan (Day и Week).
// Использует ember-цвет (accent-discipline: только для urgent/overdue).
// UX-LAYOUT.md §5 §9 п.2: «EXAM COMING» — закреплена вверху ленты,
// не уезжает при скролле, пока дедлайн актуален.
//
// Сворачивание (Task B): состояние помнится через pinnedDeadlineCollapsedProvider.
// Свёрнуто → тонкая строка-чип (⚑ название, дата + ▾); развёрнуто → полная
// карточка + аффорданс свернуть (▴). Ничего не удаляется — вернуть = тап.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../today/widgets/add_task_sheet.dart';
import 'plan_providers.dart';
import 'week_strip.dart' show selectedDayProvider;

/// Закреплённая карточка ближайшего предстоящего экзамена или дедлайна.
/// Если нет ни одного — виджет не занимает места (SizedBox.shrink).
class PinnedExamCard extends ConsumerWidget {
  const PinnedExamCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItem = ref.watch(nearestExamDeadlineProvider);

    // Пока загружается или ошибка — ничего не показываем
    final item = asyncItem.valueOrNull;
    if (item == null) return const SizedBox.shrink();

    final collapsed = ref.watch(pinnedDeadlineCollapsedProvider);

    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ember = ext?.ember ?? colorScheme.secondary;
    final surface = colorScheme.surface;

    // Открывает редактирование задачи; переключает день на день экзамена.
    void openEditor() {
      final examDay = DateTime(
        item.scheduledAt.year,
        item.scheduledAt.month,
        item.scheduledAt.day,
      );
      ref.read(selectedDayProvider.notifier).state = examDay;
      showAddTaskSheet(context, day: examDay, existing: item);
    }

    void toggleCollapsed() =>
        ref.read(pinnedDeadlineCollapsedProvider.notifier).toggle();

    if (collapsed) {
      return _CollapsedChip(
        item: item,
        ember: ember,
        surface: surface,
        textTheme: textTheme,
        onTap: toggleCollapsed,
      );
    }

    final countdown = _countdownLabel(context, item.scheduledAt);
    final typeKey = item.type == 'exam'
        ? 'plan.pinned_type_exam'
        : 'plan.pinned_type_deadline';

    return GestureDetector(
      // Тап по телу карточки — открыть редактирование (как раньше).
      onTap: openEditor,
      child: Container(
        // 24dp горизонтальный отступ, 12dp вертикальный (02-type-space §4.1)
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          // Ember-рамка — сигнал срочности (accent-discipline)
          border: Border.all(color: ember, width: 1.5),
        ),
        child: Row(
          children: [
            // Иконка типа — ember
            Icon(
              item.type == 'exam'
                  ? PhosphorIcons.graduationCap(PhosphorIconsStyle.regular)
                  : PhosphorIcons.alarm(PhosphorIconsStyle.regular),
              color: ember,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Метка «exam» / «deadline» — labelSmall, ember, sentence case
                  Text(
                    context.s(typeKey),
                    style: textTheme.labelSmall?.copyWith(
                      color: ember,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Название задачи — titleSmall
                  Text(
                    item.title,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Обратный отсчёт — ember, выровнен вправо
            Text(
              countdown,
              style: textTheme.bodySmall?.copyWith(
                color: ember,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            // Аффорданс свернуть — тап сворачивает карточку.
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                PhosphorIcons.caretUp(PhosphorIconsStyle.regular),
                color: ember,
                size: 20,
              ),
              tooltip: context.s('plan.pinned_collapse_tooltip'),
              onPressed: toggleCollapsed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Свёрнутый вид: тонкая одна строка-чип «⚑ {название}, {дата}» + стрелка ▾.
/// Тап по всей строке разворачивает карточку обратно.
class _CollapsedChip extends StatelessWidget {
  const _CollapsedChip({
    required this.item,
    required this.ember,
    required this.surface,
    required this.textTheme,
    required this.onTap,
  });

  final ItemsTableData item;
  final Color ember;
  final Color surface;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.scheduledAt;
    final now = DateTime.now();
    // Год показываем только если не текущий (как _formatSelectedDate).
    final dateLabel = date.year == now.year
        ? DateFormat('d MMM').format(date)
        : DateFormat('d MMM y').format(date);
    final title = item.title;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ember, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              item.type == 'exam'
                  ? PhosphorIcons.graduationCap(PhosphorIconsStyle.regular)
                  : PhosphorIcons.alarm(PhosphorIconsStyle.regular),
              color: ember,
              size: 16,
            ),
            const SizedBox(width: 8),
            // «{название}, {дата}» — одна строка с ellipsis.
            Expanded(
              child: Text(
                '$title, $dateLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: ember,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Стрелка — аффорданс развернуть.
            Icon(
              PhosphorIcons.caretDown(PhosphorIconsStyle.regular),
              color: ember,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Обратный отсчёт до даты задачи (reuse логики из day_timeline.dart).
String _countdownLabel(BuildContext context, DateTime at) {
  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  final d1 = DateTime(at.year, at.month, at.day);
  final days = d1.difference(d0).inDays;
  if (days < 0) return context.s('plan.countdown_overdue');
  if (days == 0) return context.s('plan.countdown_today');
  if (days == 1) return context.s('plan.countdown_tomorrow');
  return '${context.s('plan.countdown_in_days_prefix')}$days${context.s('plan.countdown_in_days_suffix')}';
}
