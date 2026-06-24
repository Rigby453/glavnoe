// FL-TODAY-04: Список задач дня с двумя секциями.
// - "Main today": задачи priority=main со значком щита.
// - "Later": остальные задачи, по времени.
// Действия свайпа НАСТРАИВАЕМЫ (swipe_action_provider): пользователь выбирает,
// что делает свайп вправо и влево из набора done/skip/delete/snooze.
// Дефолты сохраняют прежнее поведение: вправо = done (зелёный), влево = skip (серый).
// Тап по задаче открывает лист редактирования.
//
// ANIMATIONS.md §1.1+§1.2: карточка обёрнута в Pressable (scale/lift).
// ANIMATIONS.md §2.3: AnimatedCheck + AnimatedDefaultTextStyle для done-строк.
//
// UX-LAYOUT §9.4: одноразовый нёдж-хинт при первом появлении списка задач —
// первая ожидающая карточка чуть смещается вправо и возвращается обратно,
// намекая на свайп-действие. Отключается при reduce-motion.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/animated_check.dart';
import '../../../core/animations/app_toast.dart';
import '../../../core/animations/constants.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/swipe_action_provider.dart';
import '../../../core/settings/swipe_hint_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tag_parser.dart';
import '../../../services/notifications/notification_service.dart';
import '../../plan/widgets/recurrence_providers.dart';
import '../task_colors.dart';
import 'add_task_sheet.dart';

class TaskList extends ConsumerStatefulWidget {
  const TaskList({
    required this.items,
    required this.day,
    super.key,
  });

  /// Все задачи дня (из watchTodayItems), отсортированы по scheduledAt
  final List<ItemsTableData> items;

  /// День, в контексте которого открывается лист редактирования
  final DateTime day;

  @override
  ConsumerState<TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<TaskList>
    with SingleTickerProviderStateMixin {
  // Контроллер нёджа: смещение вправо → обратно за ~700 мс.
  // null пока не запущен или после завершения.
  AnimationController? _nudgeController;
  Animation<double>? _nudgeAnim;

  // Индекс первой ожидающей карточки в общем списке items —
  // только она получает трансформ нёджа.
  int? _nudgeItemIndex;

  // Защита от двойного срабатывания свайп-действия (баг 6): для done/skip/snooze
  // confirmDismiss возвращает false, карточка живёт до ребилда стрима и её можно
  // свайпнуть ещё раз → второй materializeOccurrence создал бы дубль. Пока
  // действие по ключу карточки выполняется, повторный свайп игнорируем.
  final Set<String> _inFlightActions = {};

  @override
  void initState() {
    super.initState();
    // Откладываем проверку до первого кадра: нам нужен BuildContext для
    // reduceMotionOf() и Riverpod-провайдер уже прочитан.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartNudge());
  }

  void _maybeStartNudge() {
    if (!mounted) return;

    // Нёдж не нужен если reduce-motion включён.
    if (reduceMotionOf(context)) return;

    // Нёдж не нужен если пользователь уже видел подсказку.
    final alreadySeen = ref.read(swipeHintSeenProvider);
    if (alreadySeen) return;

    // Нёдж не нужен если нет swipeable (pending) задач.
    final pendingIndex = widget.items.indexWhere((i) => i.status == 'pending');
    if (pendingIndex < 0) return;

    // Создаём контроллер: 700 мс общая длительность (≤ slow=300 × 2 + пауза).
    // Нёдж не является UI-переходом в смысле §0 ANIMATIONS.md, это декоративная
    // подсказка — поэтому допустимо 700 мс без блокировки интерфейса.
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Смещение: 0 → +22 px → 0, кривая easeInOut для плавности.
    // 22 px достаточно чтобы зелёный фон был заметен, но не пугал.
    final anim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 22.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 22.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(controller);

    setState(() {
      _nudgeItemIndex = pendingIndex;
      _nudgeController = controller;
      _nudgeAnim = anim;
    });

    // Запускаем нёдж один раз, затем помечаем подсказку как просмотренную.
    controller.forward().then((_) {
      if (mounted) {
        ref.read(swipeHintSeenProvider.notifier).markSeen();
        setState(() {
          _nudgeItemIndex = null;
          _nudgeController = null;
          _nudgeAnim = null;
        });
      }
      controller.dispose();
    });
  }

  @override
  void dispose() {
    _nudgeController?.dispose();
    super.dispose();
  }

  // Свёрнута/развёрнута секция «Выполнено» — эфемерное локальное состояние.
  // По умолчанию секция СВЁРНУТА (скрыта): пользователю важно видеть актуальное.
  bool _completedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    // Разделяем: pending отдельно, завершённые (done/skipped) — в секцию «Выполнено».
    final pendingItems =
        items.where((i) => i.status == 'pending').toList();
    final completedItems =
        items.where((i) => i.status != 'pending').toList();

    if (items.isEmpty) {
      final ext = Theme.of(context).extension<FocusThemeExtension>();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            context.s('today.empty'),
            textAlign: TextAlign.center,
            // textFaint: placeholder/empty-state цвет (01-color.md §textFaint)
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ext?.textFaint,
                ),
          ),
        ),
      );
    }

    // Из pending-пула разделяем по приоритету (main / остальные).
    final mainItems =
        pendingItems.where((i) => i.priority == 'main').toList();
    final laterItems =
        pendingItems.where((i) => i.priority != 'main').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Секция «Главное» (только pending) ---
        if (mainItems.isNotEmpty) ...[
          _SectionHeader(title: context.s('today.main_tasks')),
          ...mainItems.map((i) => _buildRow(context, i)),
          const SizedBox(height: 16),
        ],
        // --- Секция «Остальное» (только pending) ---
        if (laterItems.isNotEmpty) ...[
          _SectionHeader(title: context.s('today.later_section')),
          ...laterItems.map((i) => _buildRow(context, i)),
          const SizedBox(height: 16),
        ],
        // --- Секция «Выполнено» (collapsed by default) ---
        if (completedItems.isNotEmpty)
          _CompletedSectionHeader(
            count: completedItems.length,
            expanded: _completedExpanded,
            onTap: () =>
                setState(() => _completedExpanded = !_completedExpanded),
          ),
        if (_completedExpanded)
          ...completedItems.map((i) => _buildRow(context, i)),
      ],
    );
  }

  Widget _buildRow(BuildContext context, ItemsTableData item) {
    // Определяем индекс этого item в общем списке для нёджа.
    final itemIndex = widget.items.indexOf(item);
    final isNudgeTarget = _nudgeItemIndex != null &&
        _nudgeAnim != null &&
        itemIndex == _nudgeItemIndex;

    // Завершённые/пропущенные — без свайпа, но в ТОЙ ЖЕ обёртке Dismissible
    // (direction: none): у обеих веток одинаковый runtimeType и ключ, поэтому
    // element переживает смену статуса, _TaskCardState ловит переход
    // pending→done в didUpdateWidget и AnimatedCheck проигрывается (§2.3).
    if (item.status != 'pending') {
      return Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.none,
        child: _TaskCard(item: item, day: widget.day),
      );
    }

    // Направление → действие берётся из настроек (swipeActionsProvider).
    // Дефолты сохраняют текущее поведение: вправо = done, влево = skip.
    final config = ref.watch(swipeActionsProvider);
    final rightAction = config.right;
    final leftAction = config.left;

    Widget dismissible = Dismissible(
      key: ValueKey(item.id),
      // Фон/иконка соответствуют выбранному действию для каждого направления.
      background: _swipeBg(
        color: rightAction.color(context).withAlpha(40),
        icon: rightAction.icon,
        iconColor: rightAction.color(context),
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBg(
        color: leftAction.color(context).withAlpha(40),
        icon: leftAction.icon,
        iconColor: leftAction.color(context),
        alignment: Alignment.centerRight,
      ),
      // confirmDismiss возвращает true только для delete (реальное удаление
      // строки), для done/skip/snooze — false: строка не удаляется физически,
      // а перерисуется с новым состоянием из реактивного стрима.
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd
            ? rightAction
            : leftAction;
        return _runSwipeAction(context, item, action);
      },
      child: _TaskCard(key: ValueKey(item.id), item: item, day: widget.day),
    );

    // Оборачиваем первую ожидающую карточку в нёдж-трансформ.
    // AnimatedBuilder пересчитывает только эту карточку — остальные не перерисовываются.
    if (isNudgeTarget) {
      dismissible = AnimatedBuilder(
        animation: _nudgeAnim!,
        builder: (ctx, child) => Transform.translate(
          offset: Offset(_nudgeAnim!.value, 0),
          child: child,
        ),
        child: dismissible,
      );
    }

    return dismissible;
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16), // radius.md
      ),
      child: Icon(icon, color: iconColor),
    );
  }

  /// Выполняет действие свайпа [action] над [item].
  /// Возвращает true ТОЛЬКО для delete (Dismissible физически удаляет строку);
  /// для done/skip/snooze — false (строка перерисуется из реактивного стрима).
  Future<bool> _runSwipeAction(
    BuildContext context,
    ItemsTableData item,
    SwipeAction action,
  ) async {
    // Баг 6: для done/skip/snooze карточка не исчезает (confirmDismiss=false) до
    // ребилда стрима. Без защиты повторный быстрый свайп виртуального повтора
    // вызвал бы второй materializeOccurrence (дубль concrete-строки). Игнорируем
    // повторный запуск, пока действие по этому ключу ещё в процессе.
    if (_inFlightActions.contains(item.id)) return false;
    _inFlightActions.add(item.id);
    try {
      switch (action) {
        case SwipeAction.done:
          await _doDone(context, item);
          return false;
        case SwipeAction.skip:
          await _doSkip(item);
          return false;
        case SwipeAction.snooze:
          await _doSnooze(context, item);
          return false;
        case SwipeAction.delete:
          await _doDelete(context, item);
          return true;
      }
    } finally {
      _inFlightActions.remove(item.id);
    }
  }

  /// done: markDone / materializeOccurrence(status: done) + тост с Undo.
  Future<void> _doDone(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    final isVirtual = isVirtualOccurrenceId(item.id);
    String? targetId = item.id;
    if (isVirtual) {
      targetId = await dao.materializeOccurrence(
        anchorIdFromVirtual(item.id),
        dateFromVirtual(item.id) ?? item.scheduledAt,
        status: 'done',
      );
    } else {
      await dao.markDone(item.id);
      // Выполненной задаче напоминание больше не нужно — снимаем.
      await ref.read(notificationServiceProvider).cancelTaskReminder(item.id);
    }
    // §3.1: тост «задача выполнена» с кнопкой Undo (отмена завершения).
    if (context.mounted && targetId != null) {
      final undoId = targetId;
      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.marked_done')}',
        onUndo: () async {
          await ref.read(itemsDaoProvider).updateItem(
                undoId,
                const ItemsTableCompanion(status: Value('pending')),
              );
        },
      );
    }
  }

  /// skip: markSkipped / materializeOccurrence(status: skipped). Без тоста.
  Future<void> _doSkip(ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    if (isVirtualOccurrenceId(item.id)) {
      await dao.materializeOccurrence(
        anchorIdFromVirtual(item.id),
        dateFromVirtual(item.id) ?? item.scheduledAt,
        status: 'skipped',
      );
    } else {
      await dao.markSkipped(item.id);
      // Пропущенной задаче напоминание больше не нужно — снимаем.
      await ref.read(notificationServiceProvider).cancelTaskReminder(item.id);
    }
  }

  /// snooze: переносит scheduledAt на завтра (тот же час). Для виртуального
  /// повтора материализует день в concrete-строку со сдвигом scheduledAt.
  /// Тост-подтверждение (без Undo).
  Future<void> _doSnooze(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    final notifications = ref.read(notificationServiceProvider);
    final tomorrow = item.scheduledAt.add(const Duration(days: 1));
    // id строки, для которой нужно пересчитать напоминание после сдвига даты.
    String? rescheduledId;
    if (isVirtualOccurrenceId(item.id)) {
      // Материализуем повтор сразу на завтрашнее время — день анкера получает
      // EXDATE, а concrete-строка встаёт на завтра в pending.
      rescheduledId = await dao.materializeOccurrence(
        anchorIdFromVirtual(item.id),
        dateFromVirtual(item.id) ?? item.scheduledAt,
        scheduledAt: tomorrow,
      );
    } else {
      await dao.updateItem(
        item.id,
        ItemsTableCompanion(
          scheduledAt: Value(tomorrow),
          updatedAt: Value(DateTime.now()),
        ),
      );
      rescheduledId = item.id;
    }
    // Перепланируем локальное напоминание под новый scheduledAt: старое
    // напоминание (на сегодняшнее время) выстрелило бы не вовремя. Сначала
    // снимаем прежнее, затем — если у задачи задан reminderMinutesBefore —
    // планируем новое на tomorrow − N (scheduleTaskReminder сам отменит старое
    // и пропустит планирование, если момент уже в прошлом).
    if (rescheduledId != null) {
      final minutes = item.reminderMinutesBefore;
      if (minutes == null) {
        await notifications.cancelTaskReminder(rescheduledId);
      } else {
        final fireAt = tomorrow.subtract(Duration(minutes: minutes));
        await notifications.scheduleTaskReminder(
          rescheduledId,
          item.title,
          fireAt,
        );
      }
    }
    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.snoozed_tomorrow')}',
      );
    }
  }

  /// delete: реально удаляет задачу через DAO.deleteItem + тост с Undo,
  /// который восстанавливает строку (re-insert тех же полей).
  /// Для виртуального повтора сначала материализуем concrete-строку, затем
  /// удаляем её (день анкера всё равно получает EXDATE — повтор не вернётся).
  Future<void> _doDelete(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    String? deletedId = item.id;
    if (isVirtualOccurrenceId(item.id)) {
      deletedId = await dao.materializeOccurrence(
        anchorIdFromVirtual(item.id),
        dateFromVirtual(item.id) ?? item.scheduledAt,
      );
    }
    if (deletedId == null) return;
    // Полный снимок для Undo: строка (toCompanion(false) включает
    // reminderMinutesBefore/moduleLink/color) + подзадачи (deleteItem удаляет их
    // каскадно — без снимка Undo вернул бы задачу без чеклиста, баг 4).
    final snapshot = await dao.getItemById(deletedId);
    final subtasksDao = ref.read(subtasksDaoProvider);
    final subtasksSnapshot = await subtasksDao.getSubtasks(deletedId);
    await dao.deleteItem(deletedId);
    // Снимаем запланированное напоминание удалённой задачи (если было).
    await ref.read(notificationServiceProvider).cancelTaskReminder(deletedId);
    // §3.3: тост «удалено» с кнопкой Undo.
    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.removed,
        message: '"${item.title}" ${context.s('today.deleted')}',
        onUndo: snapshot == null
            ? null
            : () async {
                // Восстанавливаем строку с тем же id (она затумбстоунена, но
                // повторная вставка вернёт её локально; синк разрулит LWW).
                await ref.read(itemsDaoProvider).insertItem(
                      snapshot.toCompanion(false),
                    );
                // Восстанавливаем подзадачи под тот же itemId.
                await subtasksDao.replaceForItem(
                  snapshot.id,
                  subtasksSnapshot
                      .map((s) => s.toCompanion(false))
                      .toList(),
                );
              },
      );
    }
  }
}

/// Маленький индикатор прогресса подзадач на плашке задачи: «◷ N/M».
/// Скрыт, если у задачи нет подзадач. Для виртуального повтора серии берёт
/// шаблон с якоря (превью прогресса дня до материализации).
class _SubtaskProgressBadge extends ConsumerWidget {
  const _SubtaskProgressBadge({required this.item});

  final ItemsTableData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceId = isVirtualOccurrenceId(item.id)
        ? anchorIdFromVirtual(item.id)
        : item.id;
    final dao = ref.watch(subtasksDaoProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final color = ext?.textMuted ??
        Theme.of(context).colorScheme.onSurface.withAlpha(160);

    return StreamBuilder<List<SubtasksTableData>>(
      stream: dao.watchSubtasks(sourceId),
      builder: (ctx, snapshot) {
        final subtasks = snapshot.data ?? const [];
        if (subtasks.isEmpty) return const SizedBox.shrink();
        final doneCount = subtasks.where((s) => s.done).length;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist_outlined, size: 12, color: color),
              const SizedBox(width: 2),
              Text(
                '$doneCount/${subtasks.length}',
                style: textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return Padding(
      // sm=8 снизу, md=16 сверху чтобы отделить секции
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        title,
        // titleSmall: 14sp w600 — подзаголовок списка, body-font (02-type-space.md)
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              // textMuted для заголовков секций — нейтрально, не конкурирует с задачами
              color: ext?.textMuted,
            ),
      ),
    );
  }
}

/// Заголовок секции «Выполнено (N)» со шевроном, тапается для раскрытия/свёртки.
/// Эфемерное состояние _completedExpanded хранится в _TaskListState.
class _CompletedSectionHeader extends StatelessWidget {
  const _CompletedSectionHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final color = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(160);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        // Симметричный отступ: md=16 сверху как у _SectionHeader, sm=8 снизу
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${context.s('today.completed_section')} ($count)',
                style: textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
            // Шеврон: вниз = раскрыто, вправо = свёрнуто
            AnimatedRotation(
              turns: expanded ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 180), // fast=180
              child: Icon(Icons.chevron_right, size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка задачи — StatefulWidget для корректного отслеживания
/// перехода статуса pending→done через didUpdateWidget.
/// AnimatedCheck анимирует галочку только при этом переходе,
/// но не при первом открытии экрана (когда задача уже done).
class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.item,
    required this.day,
    super.key,
  });

  final ItemsTableData item;
  final DateTime day;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  // true ровно на тот rebuild, в котором статус сменился на done —
  // AnimatedCheck получает animateOnAppear и проигрывает анимацию один раз.
  bool _justCompleted = false;

  @override
  void didUpdateWidget(_TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _justCompleted =
        oldWidget.item.status != 'done' && widget.item.status == 'done';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final isDone = widget.item.status == 'done';
    final isSkipped = widget.item.status == 'skipped';
    final isCompleted = isDone || isSkipped;
    final isMain = widget.item.priority == 'main';

    // textFaint для завершённых/пропущенных — мягкое затухание без явного серого
    final completedColor = ext?.textFaint ?? colorScheme.onSurface.withAlpha(120);

    // §2.3 strikethrough с fade через AnimatedDefaultTextStyle
    // titleMedium для main, titleSmall для остальных (02-type-space.md §1)
    final baseStyle = isMain
        ? (textTheme.titleMedium ?? const TextStyle())
        : (textTheme.titleSmall ?? const TextStyle());
    final titleStyle = baseStyle.copyWith(
      decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: isCompleted ? completedColor : colorScheme.onSurface,
      color: isCompleted ? completedColor : colorScheme.onSurface,
    );

    // Иконка модуля — отображается слева когда задача привязана к модулю
    final moduleIcon = _moduleLinkIcon(widget.item.moduleLink, ext, colorScheme);

    // Пользовательский цвет-метка задачи (null = нет).
    final taskColor = taskColorFromKey(widget.item.color);

    final card = Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          // Если задача привязана к модулю — тап открывает модуль;
          // иначе — обычный лист редактирования.
          onTap: widget.item.moduleLink != null
              ? () => _openModule(context, widget.item.moduleLink!)
              : () => showAddTaskSheet(context, day: widget.day, existing: widget.item),
          // Долгое нажатие при наличии moduleLink → открыть лист редактирования
          onLongPress: widget.item.moduleLink != null
              ? () => showAddTaskSheet(context, day: widget.day, existing: widget.item)
              : null,
          leading: moduleIcon != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    moduleIcon,
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.Hm().format(widget.item.scheduledAt),
                      style: textTheme.labelSmall?.copyWith(color: ext?.textFaint),
                    ),
                  ],
                )
              : Text(
                  DateFormat.Hm().format(widget.item.scheduledAt),
                  // labelSmall для временной метки — tertiary info
                  style: textTheme.labelSmall?.copyWith(color: ext?.textFaint),
                ),
          title: _TaskTitleWithTags(
            item: widget.item,
            titleStyle: titleStyle,
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  widget.item.type,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: ext?.textFaint),
                ),
              ),
              // Маленький индикатор прогресса подзадач (◷ N/M), если они есть.
              _SubtaskProgressBadge(item: widget.item),
            ],
          ),
          trailing: _trailing(context, colorScheme, ext, isDone),
        ),
      );

    // Цветная полоса-метка слева на скруглённой карточке (когда задан цвет).
    // Для бесцветных задач — карточка без изменений (не ломаем текущий вид).
    final content = taskColor == null
        ? card
        : ClipRRect(
            borderRadius: BorderRadius.circular(16), // radius.md (Card shape)
            child: Stack(
              children: [
                card,
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: 4,
                  child: Container(width: 4, color: taskColor),
                ),
              ],
            ),
          );

    return Pressable(child: content);
  }

  /// Возвращает иконку модуля для данного значения moduleLink.
  /// null — если ссылка отсутствует.
  Widget? _moduleLinkIcon(
    String? moduleLink,
    FocusThemeExtension? ext,
    ColorScheme colorScheme,
  ) {
    if (moduleLink == null) return null;
    final color = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);
    final icon = switch (moduleLink) {
      'workout'       => Icons.fitness_center,
      'sleep'         => Icons.bedtime_outlined,
      // meal:* — иконка ресторана для всех приёмов
      String s when s.startsWith('meal:') => Icons.restaurant_outlined,
      _ => null,
    };
    if (icon == null) return null;
    return Icon(icon, size: 18, color: color);
  }

  /// Навигирует в соответствующий модуль по значению moduleLink.
  void _openModule(BuildContext context, String moduleLink) {
    if (moduleLink == 'workout') {
      context.push('/workouts');
    } else if (moduleLink == 'sleep') {
      context.push('/sleep-report');
    } else if (moduleLink.startsWith('meal:')) {
      // meal:<slot> → открыть Food и доскроллить к нужному приёму
      // (FoodScreen.targetMeal, см. /food?meal=). Если приёма ещё нет в логе —
      // экран откроется обычно, без доскролла.
      context.push('/food?meal=${moduleLink.substring(5)}');
    }
  }

  Widget? _trailing(
    BuildContext context,
    ColorScheme colorScheme,
    FocusThemeExtension? ext,
    bool isDone,
  ) {
    if (isDone) {
      // §2.3: AnimatedCheck — success-цвет (03-components §1: done = success)
      return AnimatedCheck(
        checked: true,
        color: ext?.success ?? colorScheme.primary,
        animateOnAppear: _justCompleted,
      );
    }
    if (widget.item.status == 'skipped') {
      // textFaint для пропущенных — нейтрально, не конкурирует
      return Icon(Icons.remove_circle_outline,
          color: ext?.textFaint ?? colorScheme.onSurface.withAlpha(120));
    }
    // Щит — accent только для main (03-components §1: active/selected state)
    if (widget.item.priority == 'main') {
      return Tooltip(
        message: context.s('today.shield_tooltip'),
        child: Icon(Icons.shield_outlined, color: colorScheme.primary, size: 20),
      );
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Заголовок задачи: чистый title (без #тегов) + чипы тегов под текстом.
// Если тегов нет — просто обёрнутый AnimatedDefaultTextStyle (как прежде).
// ---------------------------------------------------------------------------

class _TaskTitleWithTags extends StatelessWidget {
  const _TaskTitleWithTags({
    required this.item,
    required this.titleStyle,
  });

  final ItemsTableData item;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    final parsed = parseTaskTags(item.title);
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);

    final titleWidget = AnimatedDefaultTextStyle(
      style: titleStyle,
      duration: const Duration(milliseconds: 200),
      curve: kCurveSnap,
      child: Text(parsed.cleanTitle.isEmpty ? item.title : parsed.cleanTitle),
    );

    if (parsed.tags.isEmpty) return titleWidget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleWidget,
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            for (final tag in parsed.tags)
              Text(
                '#$tag',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tagColor,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}
