// FL-TODAY-02: Кольцо прогресса для MAIN-задач
// CustomPainter рисует дугу 0→2π×(done/total)
// Источник истины по анимациям: /docs/ANIMATIONS.md §4.1
// Дуга: kDurationSlow (300ms) + kCurveLift (easeOutCubic)
// При 100%: пружина scale 1.0→1.05→1.0, 300ms, kCurveSpring (elasticOut)
// Если total=0 — серое полное кольцо без анимации

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';

class ProgressRing extends StatefulWidget {
  const ProgressRing({
    required this.items,
    super.key,
  });

  /// Список MAIN-задач текущего дня (из watchMainItems)
  final List<ItemsTableData> items;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with TickerProviderStateMixin {
  // Контроллер дуги: kDurationSlow (300ms) — /docs/ANIMATIONS.md §4.1
  late AnimationController _arcController;
  late Animation<double> _progressAnimation;

  // Контроллер пружины при 100%: 300ms — /docs/ANIMATIONS.md §4.1
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  double _currentProgress = 0;

  // Кэшированное значение disableAnimations; обновляется в didChangeDependencies
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    // Длительности будут скорректированы в didChangeDependencies после первого
    // вызова, но контроллеры нужно создать сразу.
    _arcController = AnimationController(
      duration: kDurationSlow,
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _arcController, curve: kCurveLift),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = _buildScaleTween();
  }

  /// TweenSequence пружины: 1.0→1.05 (weight 30) →1.0 (weight 70)
  /// /docs/ANIMATIONS.md §4.1
  Animation<double> _buildScaleTween() {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 70,
      ),
    ]).animate(
      CurvedAnimation(parent: _scaleController, curve: kCurveSpring),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery нельзя читать в initState — берём здесь.
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      // Пересчитываем длительности согласно текущему режиму
      _arcController.duration =
          effectiveDuration(context, kDurationSlow);
      _scaleController.duration =
          effectiveDuration(context, const Duration(milliseconds: 300));
    }
    // Инициализируем начальное состояние без анимации при первом показе
    _updateProgress(animate: false);
  }

  @override
  void didUpdateWidget(ProgressRing old) {
    super.didUpdateWidget(old);
    final newProgress = _computeProgress();
    if (newProgress != _currentProgress) {
      _animateTo(newProgress);
    }
  }

  double _computeProgress() {
    final total = widget.items.length;
    if (total == 0) return 0;
    final done = widget.items
        .where((i) => i.status == 'done' || i.status == 'skipped')
        .length;
    return done / total;
  }

  void _updateProgress({bool animate = true}) {
    final target = _computeProgress();
    if (animate) {
      _animateTo(target);
    } else {
      _currentProgress = target;
      _progressAnimation = Tween<double>(
        begin: target,
        end: target,
      ).animate(CurvedAnimation(parent: _arcController, curve: kCurveLift));
    }
  }

  void _animateTo(double target) {
    final from = _currentProgress;
    final wasComplete = _currentProgress >= 1.0;
    _currentProgress = target;

    // Пересчитываем длительность с учётом reduce motion
    _arcController.duration =
        _reduceMotion ? Duration.zero : kDurationSlow;
    _scaleController.duration = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);

    _progressAnimation = Tween<double>(
      begin: from,
      end: target,
    ).animate(CurvedAnimation(parent: _arcController, curve: kCurveLift));

    _arcController
      ..reset()
      ..forward().then((_) {
        // Пружина запускается после завершения дуги при достижении 100%
        // и только если раньше не было 100% — /docs/ANIMATIONS.md §4.1
        if (target >= 1.0 && !wasComplete && mounted) {
          _scaleController
            ..reset()
            ..forward();
        }
      });
  }

  @override
  void dispose() {
    _arcController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = widget.items.length;
    final done = total == 0
        ? 0
        : widget.items
            .where((i) => i.status == 'done' || i.status == 'skipped')
            .length;

    return AnimatedBuilder(
      animation: Listenable.merge([_progressAnimation, _scaleAnimation]),
      builder: (context, _) {
        return Transform.scale(
          // Пружина активна только когда _scaleController запущен
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _RingPainter(
                progress: total == 0 ? 1.0 : _progressAnimation.value,
                isEmpty: total == 0,
                accentColor: colorScheme.primary,
                // Серый трек — onSurface с низкой прозрачностью
                trackColor: colorScheme.onSurface.withAlpha(30),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total == 0 ? '—' : '$done/$total',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        context.s('today.ring_main'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.isEmpty,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final bool isEmpty;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2; // Начало сверху (12 часов)

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Всегда рисуем полный трек
    canvas.drawCircle(center, radius, trackPaint);

    // Если данных нет — только серый круг
    if (isEmpty) return;

    final progressPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.isEmpty != isEmpty ||
      old.accentColor != accentColor;
}
