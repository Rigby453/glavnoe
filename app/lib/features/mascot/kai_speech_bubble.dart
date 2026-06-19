// Речевой пузырь Kai — нейтральная карточка surface с «хвостиком» в сторону маскота.
// Источник истины: /docs/MASCOT.md §8 (рот/речевые пузыри запрещены как мультяшность,
// но это именно UI-подпись интерфейса, не комикс-пузырь).
//
// Дизайн: фон = colorScheme.surface, тонкая граница border (FocusThemeExtension),
// скруглённый прямоугольник + маленький треугольник-хвостик снизу (в сторону Kai).
// Анимация появления: fade + небольшой подъём снизу (8px), reduce-motion safe.
//
// Использование:
//   KaiSpeechBubble(message: 'Good morning')
//   KaiSpeechBubble(message: text, animate: true) // с анимацией при первом показе

import 'package:flutter/material.dart';

import '../../core/animations/constants.dart';
import '../../core/theme/app_theme.dart';

/// Выровнивание «хвостика» относительно пузыря.
enum KaiBubbleTail {
  /// Хвостик снизу, по центру (Kai ниже пузыря).
  bottomCenter,

  /// Хвостик справа посередине (Kai справа от пузыря).
  rightCenter,
}

/// Речевой пузырь Kai — короткий текст в нейтральном surface-контейнере.
///
/// [message]  — текст для отображения.
/// [animate]  — проигрывать ли fade+rise при первом появлении (default: true).
/// [tail]     — сторона «хвостика» (default: bottomCenter).
/// [maxWidth] — максимальная ширина пузыря (default: 240).
class KaiSpeechBubble extends StatefulWidget {
  const KaiSpeechBubble({
    super.key,
    required this.message,
    this.animate = true,
    this.tail = KaiBubbleTail.bottomCenter,
    this.maxWidth = 240,
  });

  final String message;
  final bool animate;
  final KaiBubbleTail tail;
  final double maxWidth;

  @override
  State<KaiSpeechBubble> createState() => _KaiSpeechBubbleState();
}

class _KaiSpeechBubbleState extends State<KaiSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slideY; // 0..1, умножается на 8px

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: kDurationNormal, // 280ms
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: kCurveLift),
    );
    _slideY = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: kCurveLift),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate) {
      final reduce = reduceMotionOf(context);
      if (reduce) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward();
      }
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(KaiSpeechBubble old) {
    super.didUpdateWidget(old);
    // При смене сообщения — повтор появления
    if (old.message != widget.message && widget.animate) {
      final reduce = reduceMotionOf(context);
      if (reduce) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final borderColor = ext?.border ?? theme.colorScheme.outline;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value * 8),
            child: child,
          ),
        );
      },
      child: CustomPaint(
        painter: _BubblePainter(
          color: theme.colorScheme.surface,
          borderColor: borderColor,
          tail: widget.tail,
        ),
        child: Padding(
          // Отступ: 12 горизонтально, 10 вертикально + дополнительно 8 снизу под хвостик
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            widget.tail == KaiBubbleTail.bottomCenter ? 18 : 10,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                // Цвет текста — стандартный onSurface, не accent (пузырь нейтральный)
                color: theme.colorScheme.onSurface.withValues(alpha: 0.87),
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter: скруглённый прямоугольник + треугольный хвостик
// ---------------------------------------------------------------------------

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.color,
    required this.borderColor,
    required this.tail,
  });

  final Color color;
  final Color borderColor;
  final KaiBubbleTail tail;

  static const double _radius = 12.0;
  static const double _tailW = 10.0; // ширина хвостика
  static const double _tailH = 8.0;  // высота хвостика

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Основной прямоугольник (без хвостика)
    final bodyH = tail == KaiBubbleTail.bottomCenter ? h - _tailH : h;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, bodyH),
      const Radius.circular(_radius),
    );

    // Хвостик
    Path tailPath;
    if (tail == KaiBubbleTail.bottomCenter) {
      final cx = w / 2;
      tailPath = Path()
        ..moveTo(cx - _tailW / 2, bodyH)
        ..lineTo(cx, h)
        ..lineTo(cx + _tailW / 2, bodyH)
        ..close();
    } else {
      // rightCenter
      final cy = h / 2;
      tailPath = Path()
        ..moveTo(w, cy - _tailW / 2)
        ..lineTo(w + _tailH, cy)
        ..lineTo(w, cy + _tailW / 2)
        ..close();
    }

    final combinedPath = Path()
      ..addRRect(bodyRect)
      ..addPath(tailPath, Offset.zero);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(combinedPath, fillPaint);

    // Граница: рисуем по частям — основной rect + хвостик
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Рисуем контур всего тела
    canvas.drawPath(combinedPath, borderPaint);
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.tail != tail;
}
