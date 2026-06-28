// Виджет FAB, который сворачивается в иконку при прокрутке вниз
// и разворачивается обратно при прокрутке вверх (UX-LAYOUT.md §4, §9.1).
//
// Использование (минимальное, все умолчания):
//   Scaffold(
//     floatingActionButton: CollapsingFab(onPressed: () { ... }),
//   )
//
// Использование с кастомной иконкой/меткой:
//   Scaffold(
//     floatingActionButton: CollapsingFab(
//       onPressed: () { ... },
//       icon: PhosphorIcon(PhosphorIcons.sparkle()),
//       label: Text(context.s('ai.generate')),
//     ),
//   )
//
// По умолчанию: иконка = Phosphor plus, метка = context.s('btn.add').
// Позиция: fixed bottom-right (стандартный слот Scaffold.floatingActionButton).
// FAB убирает setting позиции — позиция жёстко задана (Phase 4 redesign).
//
// Слушает UserScrollNotification, поднимающиеся от ближайшего прокручиваемого
// потомка (ListView, SingleChildScrollView и т.д.). При reduce-motion
// переключение мгновенное (Duration.zero).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../animations/constants.dart';
import '../l10n/app_strings.dart';

class CollapsingFab extends StatefulWidget {
  const CollapsingFab({
    super.key,
    required this.onPressed,
    // icon и label — опциональные: если не переданы, берутся Phosphor plus
    // и локализованная подпись. Старый код с icon/label явным образом
    // по-прежнему компилируется без изменений.
    this.icon,
    this.label,
    this.extraBottomMargin = 16.0,
    this.tooltip,
    this.elevation = 4.0,
    this.heroTag,
  });

  final VoidCallback onPressed;

  /// Иконка FAB. Если null — используется [PhosphorIcons.plus] (regular).
  final Widget? icon;

  /// Текстовая метка (отображается только в развёрнутом состоянии).
  /// Если null — используется локализованная «Add» через context.s('btn.add').
  final Widget? label;

  /// Tooltip для accessibility.
  final String? tooltip;

  /// Дополнительный нижний отступ в dp (поверх стандартного 16dp Scaffold).
  final double extraBottomMargin;

  /// Тень FAB. Переопределяет тему, где по умолчанию elevation=0.
  final double elevation;

  /// Уникальный hero-тег. Предотвращает коллизию дефолтных тегов.
  final Object? heroTag;

  @override
  State<CollapsingFab> createState() => _CollapsingFabState();
}

class _CollapsingFabState extends State<CollapsingFab>
    with SingleTickerProviderStateMixin {
  // true = развёрнут (иконка + метка), false = свёрнут (только иконка)
  bool _expanded = true;

  late final AnimationController _ctrl;
  late final Animation<double> _widthFactor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration.zero,
      value: 1.0,
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
    final dur = effectiveDuration(context, kDurationNormal);
    _ctrl.duration = dur;
    _ctrl.reverseDuration = dur;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onScrollNotification(UserScrollNotification notification) {
    if (notification.depth != 0) return;

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
    final fab = Padding(
      padding: EdgeInsets.only(bottom: widget.extraBottomMargin),
      child: _buildFab(context),
    );
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        _onScrollNotification(n);
        return false;
      },
      child: fab,
    );
  }

  Widget _buildFab(BuildContext context) {
    // Иконка: переданная или Phosphor plus (regular, 20dp)
    final icon = widget.icon ??
        PhosphorIcon(
          PhosphorIcons.plus(PhosphorIconsStyle.regular),
          size: 20,
        );

    // Метка: переданная или локализованная «Add»
    final labelChild = widget.label ?? Text(context.s('btn.add'));

    return FloatingActionButton.extended(
      heroTag: widget.heroTag,
      onPressed: widget.onPressed,
      tooltip: widget.tooltip,
      elevation: widget.elevation,
      focusElevation: widget.elevation + 2,
      hoverElevation: widget.elevation + 2,
      icon: icon,
      // ClipRect + SizeTransition: схлопывает метку к иконке при прокрутке вниз.
      label: ClipRect(
        child: SizeTransition(
          sizeFactor: _widthFactor,
          axis: Axis.horizontal,
          alignment: Alignment.centerLeft,
          child: labelChild,
        ),
      ),
    );
  }
}
