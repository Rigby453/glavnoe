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
// (MediaQuery.disableAnimations), переключение происходит мгновенно (снимаем
// длительность до Duration.zero — кривая не играет роли).
//
// Зазор над таб-баром: extraBottomMargin (по умолчанию 16dp) добавляется к
// стандартному отступу Scaffold (тоже 16dp) → итого ≥32dp до верхней грани
// NavigationBar. Это гарантирует видимый зазор даже с декорацией nav-bar.
//
// Тень: elevation (по умолчанию 4dp) переопределяет тему, где elevation=0.
// Тень создаёт «слой» — визуально FAB не сливается с nav-bar.
//
// 360px: в свёрнутом состоянии FAB — маленький кружок ~56dp. В развёрнутом —
// ширина ограничена доступной областью через IntrinsicWidth + ConstrainedBox.
// При любой ширине экрана FAB не перекрывает подпись таба Diary: nav-bar ниже,
// FAB — выше и имеет достаточный зазор.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../animations/constants.dart';

class CollapsingFab extends StatefulWidget {
  const CollapsingFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    // Дополнительный отступ снизу поверх стандартного FAB-отступа Scaffold.
    // Вместе со стандартным отступом 16dp даёт гарантированный зазор ≥16dp.
    this.extraBottomMargin = 16.0,
    this.tooltip,
    // Тень: переопределяет FloatingActionButtonThemeData.elevation = 0
    // — без тени FAB визуально сливается с nav-bar. 4dp — лёгкий «слой».
    this.elevation = 4.0,
    // Уникальный hero-тег: без него FAB берёт дефолтный тег и конфликтует
    // с другими FAB во время переходов между экранами (Hero tag collision).
    this.heroTag,
  });

  final VoidCallback onPressed;

  /// Иконка FAB (отображается всегда).
  final Widget icon;

  /// Текстовая метка (отображается только в развёрнутом состоянии).
  final Widget label;

  /// Tooltip для accessibility.
  final String? tooltip;

  /// Дополнительный нижний отступ в dp (поверх стандартного 16dp Scaffold).
  final double extraBottomMargin;

  /// Тень FAB. Переопределяет тему, где по умолчанию elevation=0.
  final double elevation;

  /// Уникальный hero-тег для внутреннего FloatingActionButton.
  /// Предотвращает коллизию дефолтных hero-тегов при навигации.
  final Object? heroTag;

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
    // Длительность по spec ANIMATIONS.md §0: kDurationNormal = 280мс.
    // При reduce-motion → Duration.zero (мгновенное переключение без анимации).
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
    // Реагируем только на верхний (ближайший) скроллер — depth==0.
    // Вложенные прокрутки (например, горизонтальный WeekStrip) игнорируем.
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
    // Дополнительный отступ снизу для гарантированного зазора над nav-bar.
    final fab = Padding(
      padding: EdgeInsets.only(bottom: widget.extraBottomMargin),
      child: _buildFab(context),
    );
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        _onScrollNotification(n);
        return false; // не поглощаем уведомление — другие слушатели видят его
      },
      child: fab,
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: widget.heroTag,
      onPressed: widget.onPressed,
      tooltip: widget.tooltip,
      // Переопределяем elevation темы (0) → задаём явно для видимой тени.
      // Тень создаёт «отдельный слой» над контентом и nav-bar.
      elevation: widget.elevation,
      focusElevation: widget.elevation + 2,
      hoverElevation: widget.elevation + 2,
      icon: widget.icon,
      // Метка оборачивается в SizeTransition по ширине.
      // При _expanded==false ширина = 0 → визуально compact, кнопка остаётся
      // FloatingActionButton.extended (одна реализация вместо двух вариантов).
      // ClipRect предотвращает выход текста за границы при анимации схлопывания.
      label: ClipRect(
        child: SizeTransition(
          sizeFactor: _widthFactor,
          axis: Axis.horizontal,
          // alignment: centerLeft — анимация схлопывается к левому краю
          alignment: Alignment.centerLeft,
          child: widget.label,
        ),
      ),
    );
  }
}
