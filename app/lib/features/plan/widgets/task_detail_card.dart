// FL-PLAN-GRID: Компактная карточка-деталь задачи для сетки времени.
//
// Тап по блоку в DayTimeGrid/WeekTimeGrid открывает эту карточку (а не сразу
// форму редактирования). Карточка показывает цвет, заголовок, диапазон времени,
// тип/приоритет и (для виртуального повтора серии) пометку «повторяется
// ежедневно». Действия: Edit (→ showAddTaskSheet), Done/Skip (с материализацией
// виртуальных повторов, как в task_list), Delete / Stop repeating / Delete series.
//
// Без чистой математики (она в time_grid.dart) — это только UI + проксирование
// в существующие DAO-пути, чтобы поведение совпадало с Today и add_task_sheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/app_sheet.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../today/task_colors.dart';
import '../../today/widgets/add_task_sheet.dart';
import '../recurrence.dart';
import 'recurrence_providers.dart';
import 'time_grid.dart' show formatBlockTimeRange;

/// Открывает карточку-деталь задачи [item] для дня [day] как нижний лист.
Future<void> showTaskDetailSheet(
  BuildContext context, {
  required ItemsTableData item,
  required DateTime day,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => Material(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      child: TaskDetailCard(item: item, day: day),
    ),
  );
}

/// Карточка-деталь одной задачи. Все действия закрывают лист и делегируют
/// в существующие DAO-пути (Today/add_task_sheet), чтобы поведение совпадало.
class TaskDetailCard extends ConsumerWidget {
  const TaskDetailCard({super.key, required this.item, required this.day});

  final ItemsTableData item;
  final DateTime day;

  bool get _isVirtual => isVirtualOccurrenceId(item.id);

  bool get _isSeriesAnchor =>
      !_isVirtual && RecurrenceRule.parse(item.recurrenceRule) != null;

  /// Серийный элемент (виртуальный повтор или якорь) — показываем серийные
  /// действия и пометку «повторяется ежедневно».
  bool get _isSeriesItem => _isVirtual || _isSeriesAnchor;

  String? get _seriesAnchorId {
    if (_isVirtual) return anchorIdFromVirtual(item.id);
    if (_isSeriesAnchor) return item.id;
    return null;
  }

  // --- Действия (зеркалят Today / add_task_sheet) ---

  Future<void> _markStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final dao = ref.read(itemsDaoProvider);
    if (_isVirtual) {
      // Материализуем день серии в реальную строку с применённым статусом
      // (анкер получает EXDATE на дату) — как в task_list.dart.
      await dao.materializeOccurrence(
        anchorIdFromVirtual(item.id),
        dateFromVirtual(item.id) ?? item.scheduledAt,
        status: status,
      );
    } else if (status == 'done') {
      await dao.markDone(item.id);
    } else {
      await dao.markSkipped(item.id);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _edit(BuildContext context) async {
    Navigator.of(context).pop();
    await showAddTaskSheet(context, day: day, existing: item);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: context.s('today.delete_task_title'),
      body: '"${item.title}"',
      confirmLabel: context.s('btn.delete'),
    );
    if (confirmed != true) return;
    await ref.read(itemsDaoProvider).deleteItem(item.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _stopRepeating(BuildContext context, WidgetRef ref) async {
    final anchorId = _seriesAnchorId;
    if (anchorId == null) return;
    await ref.read(itemsDaoProvider).stopSeries(anchorId, DateTime.now());
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteSeries(BuildContext context, WidgetRef ref) async {
    final anchorId = _seriesAnchorId;
    if (anchorId == null) return;
    final confirmed = await _confirm(
      context,
      title: context.s('recur.delete_series'),
      body: '"${item.title}"',
      confirmLabel: context.s('btn.delete'),
    );
    if (confirmed != true) return;
    await ref.read(itemsDaoProvider).deleteItem(anchorId);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.s('btn.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final textMuted = ext?.textMuted ?? scheme.onSurface.withValues(alpha: 0.7);

    // Цвет-полоса слева: пользовательский цвет имеет приоритет, иначе по типу.
    final userColor = taskColorFromKey(item.color);
    final stripeColor = userColor ??
        (item.type == 'exam' || item.type == 'deadline'
            ? (ext?.ember ?? scheme.secondary)
            : (item.priority == 'main' ? scheme.primary : scheme.outline));

    final timeRange = formatBlockTimeRange(item.scheduledAt, item.durationMinutes);
    final typeLabel = context.s('today.type_${item.type}');
    final priorityLabel = context.s('today.priority_${item.priority}');
    final isDone = item.status == 'done';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с цветной полосой-меткой.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 36,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Время.
            _DetailRow(
              icon: Icons.access_time,
              text: timeRange,
              color: textMuted,
            ),
            const SizedBox(height: 6),
            // Тип · приоритет.
            _DetailRow(
              icon: Icons.label_outline,
              text: '$typeLabel · $priorityLabel',
              color: textMuted,
            ),
            // Повтор серии.
            if (_isSeriesItem) ...[
              const SizedBox(height: 6),
              _DetailRow(
                icon: Icons.event_repeat_outlined,
                text: context.s('recur.repeats_daily'),
                color: textMuted,
              ),
            ],
            const SizedBox(height: 20),

            // Действия: Done / Skip.
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(context.s('btn.done')),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _markStatus(context, ref, 'done');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(context.s('btn.skip')),
                    onPressed: () => _markStatus(context, ref, 'skipped'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Edit на всю ширину.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.s('btn.edit')),
                onPressed: () => _edit(context),
              ),
            ),
            const SizedBox(height: 8),

            // Удаление: для серии — Stop / Delete series; иначе обычный Delete.
            if (_isSeriesItem)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.event_busy_outlined, size: 18),
                      label: Text(context.s('recur.stop')),
                      onPressed: () => _stopRepeating(context, ref),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: Text(context.s('recur.delete_series')),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      onPressed: () => _deleteSeries(context, ref),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(context.s('today.delete_task_btn')),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: () => _delete(context, ref),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Строка детали: иконка + текст приглушённым цветом.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: textTheme.bodyMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}
