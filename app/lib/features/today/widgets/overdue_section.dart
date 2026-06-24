// Секция «Просрочено» в экране Today.
//
// Показывается ВВЕРХУ списка задач (выше main/later), только когда есть
// просроченные actionable элементы (task / deadline / exam, status=pending,
// scheduledAt < сегодняшнего полудня).
//
// Действия по типу:
//   - task    → «На завтра»: сдвигает scheduledAt на +1 день, сохраняя время.
//   - deadline → «Выбрать дату»: showDatePicker, обновляет scheduledAt.
//   - exam    → такое же поведение как deadline.
//   - Все типы: done (✓) и skip (○) через иконки — как в основном списке.
//
// Все записи идут через DAO (Drift-first), sync-queue получает изменения через
// dao.updateItem → стандартный путь offline-first.
//
// Цвет секции — ember (из FocusThemeExtension) — UX-LAYOUT §6: ember = срочное.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/app_toast.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// Riverpod-провайдер просроченных actionable элементов (task/deadline/exam).
/// Отдельный от overduePendingProvider (который только task — для утреннего разбора).
final overdueActionableProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchOverdueActionable(DateTime.now());
});

/// Виджет секции «Просрочено» — встраивается в начало списка Today.
/// Если просроченных нет — возвращает SizedBox.shrink().
class OverdueSection extends ConsumerWidget {
  const OverdueSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(overdueActionableProvider).valueOrNull ??
        const <ItemsTableData>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final ember = ext?.ember ?? const Color(0xFFFF6A3D);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции — ember-цвет для явного «внимание!»
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: ember),
              const SizedBox(width: 6),
              Text(
                '${context.s('today.overdue_section')} (${items.length})',
                style: textTheme.titleSmall?.copyWith(
                  color: ember,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Строки просроченных элементов
        ...items.map((item) => _OverdueRow(item: item)),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Одна строка просроченного элемента.
/// Первичное действие зависит от type (task → завтра, deadline/exam → выбор даты).
/// Вторично: done (✓) и skip (○).
class _OverdueRow extends ConsumerWidget {
  const _OverdueRow({required this.item});

  final ItemsTableData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final ember = ext?.ember ?? const Color(0xFFFF6A3D);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Слегка подкрашиваем карточку ember-тинтом (6% прозрачности) через Card.color.
    // ListTile.tileColor не задаём — Card уже несёт цвет.
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: Color.lerp(
        Theme.of(context).cardTheme.color ??
            (ext?.surfaceElevated ?? colorScheme.surface),
        ember,
        0.06,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // Дата просрочки (как давно) слева
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 14, color: ember),
            const SizedBox(height: 2),
            Text(
              DateFormat.MMMd().format(item.scheduledAt),
              style: textTheme.labelSmall?.copyWith(color: ember),
            ),
          ],
        ),
        title: Text(
          item.title,
          style: textTheme.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.type,
          style: textTheme.bodySmall?.copyWith(
            color: ext?.textFaint ?? colorScheme.onSurface.withAlpha(120),
          ),
        ),
        trailing: _RowActions(item: item),
        onTap: null, // Тап на саму карточку пассивный; действия — в trailing
      ),
    );
  }
}

/// Компактный блок действий в trailing: первичная кнопка + done + skip.
class _RowActions extends ConsumerWidget {
  const _RowActions({required this.item});

  final ItemsTableData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final isTask = item.type == 'task';
    // deadline и exam → «выбрать дату»

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Первичное действие (зависит от type) ---
        if (isTask)
          _MoveToTomorrowButton(item: item)
        else
          _PickDateButton(item: item),
        // --- Вторичные: done ---
        IconButton(
          tooltip: context.s('today.swipe_done'),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.check_circle_outline,
            size: 20,
            color: ext?.success ?? Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => _markDone(context, ref, item),
        ),
        // --- skip ---
        IconButton(
          tooltip: context.s('today.swipe_skip'),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.remove_circle_outline,
            size: 20,
            color: ext?.textFaint ??
                Theme.of(context).colorScheme.onSurface.withAlpha(120),
          ),
          onPressed: () => _markSkipped(ref, item),
        ),
      ],
    );
  }

  /// done: markDone + тост с Undo (соответствует поведению основного списка).
  Future<void> _markDone(
      BuildContext context, WidgetRef ref, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    await dao.markDone(item.id);
    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.marked_done')}',
        onUndo: () async {
          await ref.read(itemsDaoProvider).updateItem(
                item.id,
                const ItemsTableCompanion(status: Value('pending')),
              );
        },
      );
    }
  }

  /// skip: markSkipped (без тоста — соответствует поведению основного списка).
  Future<void> _markSkipped(WidgetRef ref, ItemsTableData item) async {
    await ref.read(itemsDaoProvider).markSkipped(item.id);
  }
}

/// Кнопка «На завтра» для просроченной task.
/// Сдвигает scheduledAt на +1 день, сохраняя время суток (review_engine.moveToDay).
class _MoveToTomorrowButton extends ConsumerWidget {
  const _MoveToTomorrowButton({required this.item});

  final ItemsTableData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final ember = ext?.ember ?? const Color(0xFFFF6A3D);

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: ember,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _moveToTomorrow(context, ref),
      child: Text(
        context.s('today.overdue_move_tomorrow'),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _moveToTomorrow(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    // Следующий день, сохраняем время суток оригинала (как moveToDay в review_engine)
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day + 1,
      item.scheduledAt.hour,
      item.scheduledAt.minute,
    );
    await ref.read(itemsDaoProvider).updateItem(
          item.id,
          ItemsTableCompanion(
            scheduledAt: Value(tomorrow),
            updatedAt: Value(now),
          ),
        );
    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.overdue_moved_tomorrow')}',
      );
    }
  }
}

/// Кнопка «Выбрать дату» для просроченного deadline/exam.
/// Открывает стандартный showDatePicker (тематизированный) и обновляет scheduledAt,
/// сохраняя оригинальное время суток (если оно есть, т.е. не полночь 00:00).
class _PickDateButton extends ConsumerWidget {
  const _PickDateButton({required this.item});

  final ItemsTableData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final ember = ext?.ember ?? const Color(0xFFFF6A3D);

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: ember,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _pickDate(context, ref),
      child: Text(
        context.s('today.overdue_pick_date'),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    // Минимальная дата для выбора — завтра (не разрешаем снова ставить прошедшую)
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return; // пользователь отменил

    // Сохраняем время суток оригинала (если задано — не полночь)
    final origTime = item.scheduledAt;
    final newAt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      origTime.hour,
      origTime.minute,
    );

    await ref.read(itemsDaoProvider).updateItem(
          item.id,
          ItemsTableCompanion(
            scheduledAt: Value(newAt),
            updatedAt: Value(now),
          ),
        );

    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.overdue_date_updated')}',
      );
    }
  }
}
