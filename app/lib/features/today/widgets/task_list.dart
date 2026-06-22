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

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

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

    final mainItems = items.where((i) => i.priority == 'main').toList();
    final laterItems = items.where((i) => i.priority != 'main').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mainItems.isNotEmpty) ...[
          _SectionHeader(title: context.s('today.main_tasks')),
          ...mainItems.map((i) => _buildRow(context, i)),
          const SizedBox(height: 16),
        ],
        if (laterItems.isNotEmpty) ...[
          _SectionHeader(title: context.s('today.later_section')),
          ...laterItems.map((i) => _buildRow(context, i)),
        ],
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
    }
  }

  /// snooze: переносит scheduledAt на завтра (тот же час). Для виртуального
  /// повтора материализует день в concrete-строку со сдвигом scheduledAt.
  /// Тост-подтверждение (без Undo).
  Future<void> _doSnooze(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    final tomorrow = item.scheduledAt.add(const Duration(days: 1));
    if (isVirtualOccurrenceId(item.id)) {
      // Материализуем повтор сразу на завтрашнее время — день анкера получает
      // EXDATE, а concrete-строка встаёт на завтра в pending.
      await dao.materializeOccurrence(
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
    // Снимок строки для Undo (восстановление через re-insert).
    final snapshot = await dao.getItemById(deletedId);
    await dao.deleteItem(deletedId);
    // §3.3: тост «удалено» с кнопкой Undo.
    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.removed,
        message: '"${item.title}" ${context.s('today.deleted')}',
        onUndo: snapshot == null
            ? null
            : () async {
                await ref.read(itemsDaoProvider).insertItem(
                      snapshot.toCompanion(false),
                    );
              },
      );
    }
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
          title: AnimatedDefaultTextStyle(
            style: titleStyle,
            duration: const Duration(milliseconds: 200),
            curve: kCurveSnap,
            child: Text(widget.item.title),
          ),
          subtitle: Text(
            widget.item.type,
            style: textTheme.bodySmall?.copyWith(color: ext?.textFaint),
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
      // Food-экран не принимает параметр приёма пищи — открываем общий.
      // TODO: расширить food_screen.dart scroll-to-meal (follow-up задача).
      context.push('/food');
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
