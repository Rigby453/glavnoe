// AI-анимации §7.2: skeleton-загрузчик инсайта.
// Shimmer слева направо по блокам-заглушкам, без внешних пакетов.
// Gradient: surface → border → surface (ColorScheme-токены).

import 'package:flutter/material.dart';

import 'constants.dart';
import '../theme/app_theme.dart';

/// Карточко-подобный блок из N строк-заглушек с shimmer-эффектом (§7.2).
///
/// [lines] — количество строк (последняя короче ~60% ширины).
/// [height] — высота одной строки в пикселях.
///
/// При reduce motion — статичные блоки без шиммера.
class AiSkeleton extends StatefulWidget {
  const AiSkeleton({
    super.key,
    this.lines = 3,
    this.height = 14.0,
  });

  final int lines;
  final double height;

  @override
  State<AiSkeleton> createState() => _AiSkeletonState();
}

class _AiSkeletonState extends State<AiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // цикл shimmer: 1400 мс из §7.2
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // Цвета shimmer из FocusThemeExtension: border → borderStrong → border (§7.2)
    final baseColor = ext?.border ?? colorScheme.surfaceContainerHighest;
    final shineColor = ext?.borderStrong ?? colorScheme.outlineVariant;
    final n = widget.lines.clamp(1, 20);
    final lineH = widget.height;
    // Вертикальный отступ между строками = 8 логических пикселей
    const gap = 8.0;

    if (reduceMotionOf(context)) {
      // Статичные блоки без анимации
      return _StaticLines(
        lines: n,
        height: lineH,
        gap: gap,
        color: baseColor,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Shimmer движется слева направо.
        // t идёт 0→1; сдвигаем gradient begin/end через диапазон -1..2 (перекрывает виджет).
        final t = _controller.value;
        // Горизонтальное смещение: gradient начинается за левым краем (-1) и уходит за правый (+2).
        final shimmerOffset = -1.0 + t * 3.0; // -1..+2

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(n, (i) {
            final isLast = i == n - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: i < n - 1 ? gap : 0),
              child: _ShimmerLine(
                height: lineH,
                // Последняя строка — 60% ширины
                widthFactor: isLast ? 0.6 : 1.0,
                baseColor: baseColor,
                shineColor: shineColor,
                shimmerOffset: shimmerOffset,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Одна строка-заглушка с shimmer-градиентом через ShaderMask.
class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({
    required this.height,
    required this.widthFactor,
    required this.baseColor,
    required this.shineColor,
    required this.shimmerOffset,
  });

  final double height;
  final double widthFactor;
  final Color baseColor;
  final Color shineColor;
  final double shimmerOffset;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          // Gradient: base → shine → base (§7.2 "surface → border → surface")
          return LinearGradient(
            colors: [baseColor, shineColor, baseColor],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(shimmerOffset - 0.5, 0),
            end: Alignment(shimmerOffset + 0.5, 0),
          ).createShader(bounds);
        },
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white, // ShaderMask перекрашивает через srcIn
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// Статичные блоки без шиммера (reduce motion).
class _StaticLines extends StatelessWidget {
  const _StaticLines({
    required this.lines,
    required this.height,
    required this.gap,
    required this.color,
  });

  final int lines;
  final double height;
  final double gap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (i) {
        final isLast = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: i < lines - 1 ? gap : 0),
          child: FractionallySizedBox(
            widthFactor: isLast ? 0.6 : 1.0,
            alignment: Alignment.centerLeft,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
