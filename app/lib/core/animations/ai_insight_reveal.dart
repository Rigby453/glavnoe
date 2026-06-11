// AI-анимации §7.3: fade-in появления AI-контента.
// opacity 0→1 + translateY +8→0, 400 мс easeOutCubic, задержка [delay] мс.
// Анимирует один раз при монтировании. При reduce motion — сразу видимый child.

import 'package:flutter/material.dart';

import 'constants.dart';

/// Обёртка появления AI-контента (§7.3 ANIMATIONS.md).
///
/// При монтировании ждёт [delay], затем анимирует:
///   - opacity: 0 → 1
///   - translateY: +8px → 0
///   - duration: 300 мс (kDurationSlow), curve: kCurveLift (easeOutCubic)
///
/// При reduce motion — немедленно показывает [child] без анимации.
class AiInsightReveal extends StatefulWidget {
  const AiInsightReveal({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 100),
  });

  final Widget child;

  /// Задержка перед стартом анимации (§7.3: 100 мс после появления контейнера).
  final Duration delay;

  @override
  State<AiInsightReveal> createState() => _AiInsightRevealState();
}

class _AiInsightRevealState extends State<AiInsightReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // kDurationSlow = 300 мс (§7.3)
      duration: kDurationSlow,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: kCurveLift, // easeOutCubic
    );

    // translateY: 8 → 0 (§7.3: «translateY(+8px → 0)»)
    _translateY = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: kCurveLift),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Если reduce motion — сразу в конечное состояние, без задержки
    if (reduceMotionOf(context)) {
      _controller.value = 1.0;
    } else {
      _startWithDelay();
    }
  }

  Future<void> _startWithDelay() async {
    if (!mounted) return;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // При reduce motion — анимация уже в value=1.0, поэтому виджет
    // будет полностью виден без какого-либо motion.
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _translateY.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
