// FL-TODAY-04: Список задач дня с двумя секциями.
// - "Main today": задачи priority=main со значком щита.
// - "Later": остальные задачи, по времени.
// Свайп вправо = done (зелёный), свайп влево = skip (серый).
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
import 'package:intl/intl.dart';

import '../../../core/animations/animated_check.dart';
import '../../../core/animations/app_toast.dart';
import '../../../core/animations/constants.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/swipe_hint_provider.dart';
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            context.s('today.empty'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
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

    final colorScheme = Theme.of(context).colorScheme;

    Widget dismissible = Dismissible(
      key: ValueKey(item.id),
      // Свайп вправо = done
      background: _swipeBg(
        color: Colors.green.withAlpha(40),
        icon: Icons.check,
        iconColor: Colors.green,
        alignment: Alignment.centerLeft,
      ),
      // Свайп влево = skip
      secondaryBackground: _swipeBg(
        color: colorScheme.onSurface.withAlpha(20),
        icon: Icons.remove_circle_outline,
        iconColor: colorScheme.onSurface.withAlpha(140),
        alignment: Alignment.centerRight,
      ),
      // Выполняем действие и возвращаем false: строка не удаляется,
      // а перерисуется с новым статусом из реактивного стрима.
      confirmDismiss: (direction) async {
        final dao = ref.read(itemsDaoProvider);
        if (direction == DismissDirection.startToEnd) {
          await dao.markDone(item.id);
          // §3.1: тост «задача выполнена» с кнопкой Undo (отмена завершения)
          if (context.mounted) {
            showAppToast(
              context,
              variant: AppToastVariant.done,
              message: '"${item.title}" ${context.s('today.marked_done')}',
              onUndo: () async {
                await ref.read(itemsDaoProvider).updateItem(
                      item.id,
                      const ItemsTableCompanion(
                        status: Value('pending'),
                      ),
                    );
              },
            );
          }
        } else {
          await dao.markSkipped(item.id);
          // Для skip тост не показываем
        }
        return false;
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
    final isDone = widget.item.status == 'done';
    final isSkipped = widget.item.status == 'skipped';
    final isCompleted = isDone || isSkipped;

    // §2.3 strikethrough с fade через AnimatedDefaultTextStyle
    final titleStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: isCompleted
          ? colorScheme.onSurface.withAlpha(120)
          : colorScheme.onSurface,
      color: isCompleted
          ? colorScheme.onSurface.withAlpha(120)
          : colorScheme.onSurface,
    );

    return Pressable(
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: () => showAddTaskSheet(context, day: widget.day, existing: widget.item),
          leading: Text(
            DateFormat.Hm().format(widget.item.scheduledAt),
            style: textTheme.labelMedium,
          ),
          title: AnimatedDefaultTextStyle(
            style: titleStyle,
            duration: const Duration(milliseconds: 200),
            curve: kCurveSnap,
            child: Text(widget.item.title),
          ),
          subtitle: Text(widget.item.type, style: textTheme.bodySmall),
          trailing: _trailing(context, colorScheme, isDone),
        ),
      ),
    );
  }

  Widget? _trailing(BuildContext context, ColorScheme colorScheme, bool isDone) {
    if (isDone) {
      // §2.3: AnimatedCheck вместо статичного Icon. Анимация — только при
      // свежем переходе pending→done (_justCompleted), не при открытии экрана.
      return AnimatedCheck(
        checked: true,
        color: Colors.green,
        animateOnAppear: _justCompleted,
      );
    }
    if (widget.item.status == 'skipped') {
      return Icon(Icons.remove_circle_outline,
          color: colorScheme.onSurface.withAlpha(120));
    }
    // Баг 3: Tooltip объясняет назначение щита без лишних элементов в UI.
    if (widget.item.priority == 'main') {
      return Tooltip(
        message: context.s('today.shield_tooltip'),
        child: Icon(Icons.shield_outlined, color: colorScheme.primary, size: 20),
      );
    }
    return null;
  }
}
