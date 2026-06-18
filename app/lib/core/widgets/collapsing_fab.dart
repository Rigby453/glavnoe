// Виджет FAB, который сворачивается в иконку при прокрутке вниз
// и разворачивается обратно при прокрутке вверх (UX-LAYOUT.md §4, §9.1).
//
// Использование:
//   Scaffold(
//     floatingActionButton: CollapsingFab(
//       onPressed: () { ... },
//       icon: Icon(Icons.add),
//       label: Text('+ Add'),
//     ),
//   )
//
// Слушает UserScrollNotification, поднимающиеся от ближайшего прокручиваемого
// потомка (ListView, SingleChildScrollView и т.д.). Если reduce-motion включён
// (MediaQuery.disableAnimations), переключение происходит мгновенно (snap).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../animations/constants.dart';

class CollapsingFab extends StatefulWidget {
  const CollapsingFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    // Дополнительный отступ снизу (поверх стандартного FAB-отступа).
    // Гарантирует зазор ≥16dp над таб-баром даже на нестандартных темах.
    this.extraBottomMargin = 0.0,
    this.tooltip,
  });

  final VoidCallback onPressed;

  /// Иконка FAB (отображается всегда).
  final Widget icon;

  /// Текстовая метка (отображается только в развёрнутом состоянии).
  final Widget label;

  /// Tooltip для accessibility.
  final String? tooltip;

  /// Дополнительный нижний отступ в dp.
  final double extraBottomMargin;

  @override
  State<CollapsingFab> createState() => _CollapsingFabState();
}

class _CollapsingFabState extends State<CollapsingFab>
    with SingleTickerProviderStateMixin {
  // true = развёрнут (+Add), false = свёрнут (только иконка)
  bool _expanded = true;

  late final AnimationController _ctrl;
  late final Animation<double> _widthFactor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // Реальная длительность подставляется в didChangeDependencies после
      // того как контекст стал доступен. Инициализируем нулём как заглушку.
      duration: Duration.zero,
      value: 1.0, // начинаем в развёрнутом состоянии
    );
    _widthFactor = CurvedAnimation(
      parent: _ctrl,
      curve: kCurveLift,
      reverseCurve: kCurveLift.flipped,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем длительность с учётом reduce-motion
    _ctrl.duration = effectiveDuration(context, kDurationFast);
    _ctrl.reverseDuration = effectiveDuration(context, kDurationFast);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onScrollNotification(UserScrollNotification notification) {
    if (notification.depth != 0) return; // реагируем только на верхний скроллер

    final scrollingDown = notification.direction == ScrollDirection.reverse;
    final scrollingUp = notification.direction == ScrollDirection.forward;

    if (scrollingDown && _expanded) {
      setState(() => _expanded = false);
      _ctrl.reverse();
    } else if (scrollingUp && !_expanded) {
      setState(() => _expanded = true);
      _ctrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.extraBottomMargin > 0
        ? Padding(
            padding: EdgeInsets.only(bottom: widget.extraBottomMargin),
            child: _buildFab(context),
          )
        : _buildFab(context);
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        _onScrollNotification(n);
        return false; // не поглощаем уведомление
      },
      child: padding,
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: widget.onPressed,
      tooltip: widget.tooltip,
      icon: widget.icon,
      // Метка оборачивается в SizeTransition по ширине.
      // При _expanded==false ширина = 0 → visually compact, но кнопка остаётся
      // FloatingActionButton.extended (одна реализация вместо двух).
      label: ClipRect(
        child: SizeTransition(
          sizeFactor: _widthFactor,
          axis: Axis.horizontal,
          // alignment: centerLeft — анимация схлопывается слева направо
          // (axisAlignment: -1 устарел в Flutter 3.41+, заменён на alignment)
          alignment: Alignment.centerLeft,
          child: widget.label,
        ),
      ),
    );
  }
}
