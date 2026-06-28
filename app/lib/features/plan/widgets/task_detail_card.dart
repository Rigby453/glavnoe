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
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/animations/app_sheet.dart';
import '../../../core/categories/category_dot.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/attachment_view.dart';
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
    // R20 per design-tokens.json sheet.radius
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  /// Ключ подписи повтора по частоте. Для виртуального повтора правило не лежит
  /// на самой строке (recurrenceRule=null) — показываем нейтральное «Repeats».
  String get _repeatLabelKey {
    final rule = RecurrenceRule.parse(item.recurrenceRule);
    return switch (rule?.freq) {
      RecurFreq.daily => 'recur.repeats_daily',
      RecurFreq.weekly => 'recur.repeats_weekly',
      RecurFreq.monthly => 'recur.repeats_monthly',
      null => 'recur.repeats',
    };
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

    // Первый тег категории — для CategoryDot (Kaname §4: нет цветных полос,
    // категория показывается 10dp точкой рядом с заголовком).
    final tagsStr = item.tags ?? '';
    final firstTag = tagsStr.isNotEmpty
        ? tagsStr.split(',').map((t) => t.trim()).firstWhere(
              (t) => t.isNotEmpty,
              orElse: () => '',
            )
        : '';

    final timeRange = formatBlockTimeRange(item.scheduledAt, item.durationMinutes);
    final typeLabel = context.s('today.type_${item.type}');
    final priorityLabel = context.s('today.priority_${item.priority}');
    final isDone = item.status == 'done';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ручка-индикатор нижнего листа (§4.3 handle)
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: (ext?.textFaint ?? scheme.onSurface)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Заголовок: CategoryDot (если есть тег) + текст + крестик.
            // Нет цветной полосы (Kaname §4: no left colour fill-bars on cards).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 10dp категорийная точка вместо 4dp полосы
                if (firstTag.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 10),
                    child: CategoryDot(tag: firstTag, size: 10),
                  ),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    style: textTheme.titleMedium?.copyWith(
                      // w500 вместо w700 (design tokens: max w600, обычно w500)
                      fontWeight: FontWeight.w500,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                // Крестик закрытия — Phosphor X
                IconButton(
                  icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.regular)),
                  tooltip: context.s('btn.close'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Время.
            _DetailRow(
              icon: PhosphorIcons.clock(PhosphorIconsStyle.regular),
              text: timeRange,
              color: textMuted,
            ),
            const SizedBox(height: 6),
            // Тип · приоритет.
            _DetailRow(
              icon: PhosphorIcons.info(PhosphorIconsStyle.regular),
              text: '$typeLabel · $priorityLabel',
              color: textMuted,
            ),
            // Повтор серии — подпись по частоте (для виртуала берём правило якоря).
            if (_isSeriesItem) ...[
              const SizedBox(height: 6),
              _DetailRow(
                icon: PhosphorIcons.repeat(PhosphorIconsStyle.regular),
                text: context.s(_repeatLabelKey),
                color: textMuted,
              ),
            ],
            // Место/локация (локальное поле). Показываем строку только если
            // задано; пустое/null — не рисуем (как вложения/подзадачи).
            if ((item.location ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(
                icon: PhosphorIcons.mapPin(PhosphorIconsStyle.regular),
                text: item.location!.trim(),
                color: textMuted,
              ),
            ],

            // Чеклист подзадач с инлайн-отметкой + прогресс (schemaVersion 14).
            // Для виртуального повтора серии показываем шаблон с якоря (read-only
            // превью); инлайн-тогл доступен только для concrete-строк.
            _SubtaskChecklist(
              sourceItemId:
                  _isVirtual ? anchorIdFromVirtual(item.id) : item.id,
              editable: !_isVirtual,
              textMuted: textMuted,
            ),

            // Вложения (фото/видео). Для виртуального повтора берём с якоря.
            // Если вложений нет — секция ничего не рисует (без пустого места).
            _AttachmentsSection(
              sourceItemId:
                  _isVirtual ? anchorIdFromVirtual(item.id) : item.id,
              textMuted: textMuted,
            ),

            const SizedBox(height: 20),

            // Действия: Done / Skip.
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: Icon(
                      PhosphorIcons.check(PhosphorIconsStyle.regular),
                      size: 18,
                    ),
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
                    icon: Icon(
                      PhosphorIcons.minusCircle(PhosphorIconsStyle.regular),
                      size: 18,
                    ),
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
                icon: Icon(
                  PhosphorIcons.pencilSimple(PhosphorIconsStyle.regular),
                  size: 18,
                ),
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
                      icon: Icon(
                        PhosphorIcons.calendarX(PhosphorIconsStyle.regular),
                        size: 18,
                      ),
                      label: Text(context.s('recur.stop')),
                      onPressed: () => _stopRepeating(context, ref),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        PhosphorIcons.broom(PhosphorIconsStyle.regular),
                        size: 18,
                      ),
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
                  icon: Icon(
                    PhosphorIcons.trash(PhosphorIconsStyle.regular),
                    size: 18,
                  ),
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

/// Чеклист подзадач задачи с инлайн-отметкой done и счётчиком прогресса «N/M».
/// Реактивно слушает SubtasksDao.watchSubtasks. Если подзадач нет — ничего
/// не рисует (SizedBox.shrink), чтобы не захламлять карточку.
class _SubtaskChecklist extends ConsumerWidget {
  const _SubtaskChecklist({
    required this.sourceItemId,
    required this.editable,
    required this.textMuted,
  });

  /// id задачи, чьи подзадачи показываем (для виртуала — id якоря/шаблона).
  final String sourceItemId;

  /// Можно ли менять done инлайн (false для виртуального повтора-превью).
  final bool editable;

  final Color textMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(subtasksDaoProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<SubtasksTableData>>(
      stream: dao.watchSubtasks(sourceItemId),
      builder: (ctx, snapshot) {
        final subtasks = snapshot.data ?? const [];
        if (subtasks.isEmpty) return const SizedBox.shrink();
        final doneCount = subtasks.where((s) => s.done).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            // Заголовок с прогрессом «N/M».
            Row(
              children: [
                Icon(
                  PhosphorIcons.listChecks(PhosphorIconsStyle.regular),
                  size: 16,
                  color: textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  context.s('today.subtasks_label'),
                  style: textTheme.bodyMedium?.copyWith(color: textMuted),
                ),
                const Spacer(),
                Text(
                  '$doneCount/${subtasks.length}',
                  style: textTheme.bodySmall?.copyWith(color: textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final s in subtasks)
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: s.done,
                      onChanged: editable
                          ? (v) => dao.setDone(s.id, v ?? false)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.title,
                      style: textTheme.bodyMedium?.copyWith(
                        decoration: s.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: s.done ? textMuted : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Секция вложений (фото/видео) задачи в карточке-детали. Read-only:
/// горизонтальная лента превью без кнопок удаления; тап по превью открывает
/// вложение на весь экран (фото — зум, видео — File-плеер на Android).
/// Реактивно слушает ItemAttachmentsDao.watchAttachments. Если вложений нет —
/// ничего не рисует (SizedBox.shrink), чтобы не было пустого места.
///
/// Источник рендера общий с add_task_sheet (core/widgets/attachment_view.dart),
/// поэтому Android (File) и web (base64 data-URI) покрыты тем же кодом.
class _AttachmentsSection extends ConsumerWidget {
  const _AttachmentsSection({
    required this.sourceItemId,
    required this.textMuted,
  });

  /// id задачи, чьи вложения показываем (для виртуала — id якоря/шаблона).
  final String sourceItemId;

  final Color textMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(itemAttachmentsDaoProvider);
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<ItemAttachmentsTableData>>(
      stream: dao.watchAttachments(sourceItemId),
      builder: (ctx, snapshot) {
        final attachments = snapshot.data ?? const [];
        if (attachments.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  PhosphorIcons.paperclip(PhosphorIconsStyle.regular),
                  size: 16,
                  color: textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  context.s('today.attachments_label'),
                  style: textTheme.bodyMedium?.copyWith(color: textMuted),
                ),
                const Spacer(),
                Text(
                  '${attachments.length}',
                  style: textTheme.bodySmall?.copyWith(color: textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Горизонтальная лента превью — не переполняет узкий экран.
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final a = attachments[i];
                  return AttachmentThumb(
                    attachment: a,
                    onTap: () => viewAttachmentFullscreen(
                      context,
                      a,
                      onUnsupportedVideo: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.s('today.attachment_web_video_unsupported'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
