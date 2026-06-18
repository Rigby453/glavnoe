// Маскот «Kai» — pure-Flutter реализация через CustomPainter.
// Источник истины: /docs/MASCOT.md (ADR-032).
// Rive не используется; все анимации на AnimationController.
//
// Шесть выражений (KaiEmotion):
//   neutral  — тире-глаза, ровный squircle. База.
//   success  — арки глаз вверх (^ ^), форма пружинит к кругу.
//   thinking — один глаз прищурен, форма вытянута вертикально, лёгкая пульсация.
//   harsh    — глаза сплющены в тонкие тире, цвет → ember, «брови».
//   anxious  — глаза чуть крупнее, форма сжата/дёрганая.
//   away     — глаза-«нитки» (почти закрыты), форма немного осевшая.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/animations/constants.dart';

// ---------------------------------------------------------------------------
// Enum выражений
// ---------------------------------------------------------------------------

/// Шесть выражений Kai из MASCOT.md §5.
enum KaiEmotion {
  neutral,
  success,
  thinking,
  harsh,
  anxious,
  away,
}

// ---------------------------------------------------------------------------
// Публичный виджет
// ---------------------------------------------------------------------------

/// Маскот Kai — мягкий squircle с двумя глазами-тире.
///
/// Параметры:
///   [size]    — размер квадрата, в который вписывается маскот (default 44).
///   [emotion] — одно из шести выражений [KaiEmotion].
///   [isHarsh] — жёсткий тон: глаза → узкие щели, цвет → ember, углы резче.
///   [onTap]   — необязательный коллбек (для дисмисса / цикла выражений).
class KaiMascot extends StatefulWidget {
  const KaiMascot({
    super.key,
    this.size = 44,
    this.emotion = KaiEmotion.neutral,
    this.isHarsh = false,
    this.onTap,
  });

  final double size;
  final KaiEmotion emotion;
  final bool isHarsh;
  final VoidCallback? onTap;

  @override
  State<KaiMascot> createState() => _KaiMascotState();
}

class _KaiMascotState extends State<KaiMascot>
    with TickerProviderStateMixin {
  // --- Контроллер «дыхания» (idle, бесконечный цикл) ---
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim; // 0..1, «туда-обратно»

  // --- Контроллер перехода между выражениями ---
  late final AnimationController _morphCtrl;

  // Текущее и целевое состояние (для интерполяции)
  late _KaiState _from;
  late _KaiState _to;

  // Анимируемые значения (0..1)
  late Animation<double> _morphAnim;

  // --- Контроллер тревожного дёргания ---
  late final AnimationController _jitterCtrl;
  late final Animation<double> _jitterAnim;

  @override
  void initState() {
    super.initState();

    _from = _stateFor(widget.emotion, widget.isHarsh);
    _to = _from;

    // Дыхание: медленный цикл ~3.5 сек, reverse+forward
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _breathAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    // Морфинг: нормальная длительность → kDurationNormal
    _morphCtrl = AnimationController(
      vsync: this,
      duration: kDurationNormal,
    );
    _morphAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _morphCtrl, curve: kCurveLift),
    );

    // Тревожное дёргание: быстрые рывки
    _jitterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _jitterAnim = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _jitterCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startLoops();
  }

  @override
  void didUpdateWidget(KaiMascot old) {
    super.didUpdateWidget(old);

    // При смене выражения запускаем плавный переход
    if (old.emotion != widget.emotion || old.isHarsh != widget.isHarsh) {
      // Интерполируем из текущего визуального состояния
      final currentT = _morphAnim.value;
      _from = _lerpState(_from, _to, currentT);
      _to = _stateFor(widget.emotion, widget.isHarsh);

      // Специальная кривая для success — пружина
      final curve = widget.emotion == KaiEmotion.success
          ? kCurveSpring
          : kCurveLift;
      _morphAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _morphCtrl, curve: curve),
      );
      _morphCtrl
        ..reset()
        ..forward();
    }

    // Перезапуск фоновых петель при изменении reduce-motion
    _startLoops();
  }

  void _startLoops() {
    final reduce = reduceMotionOf(context);

    if (reduce) {
      // При reduce-motion все петли останавливаем
      _breathCtrl.stop();
      _jitterCtrl.stop();
      return;
    }

    // Idle-дыхание: ping-pong
    if (!_breathCtrl.isAnimating) {
      _breathCtrl.repeat(reverse: true);
    }

    // Тревожное дёргание только для anxious
    if (widget.emotion == KaiEmotion.anxious) {
      if (!_jitterCtrl.isAnimating) {
        _jitterCtrl.repeat(reverse: true);
      }
    } else {
      _jitterCtrl.stop();
      _jitterCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _morphCtrl.dispose();
    _jitterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Цвет глаз: accent темы, при harsh → secondary (ember)
    final eyeColor = widget.isHarsh
        ? colorScheme.secondary
        : colorScheme.primary;
    // Цвет тела: нейтральный, читается на любой теме
    final bodyColor = colorScheme.onSurface.withAlpha(28);
    final borderColor = colorScheme.onSurface.withAlpha(18);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _breathAnim,
            _morphAnim,
            _jitterAnim,
          ]),
          builder: (context, _) {
            // При reduce-motion: статичный нейтральный рендер
            if (reduce) {
              return CustomPaint(
                painter: _KaiPainter(
                  state: _stateFor(KaiEmotion.neutral, widget.isHarsh),
                  eyeColor: eyeColor,
                  bodyColor: bodyColor,
                  borderColor: borderColor,
                  breathValue: 0,
                  jitterOffset: 0,
                ),
              );
            }

            final morphT = _morphAnim.value;
            final interpolated = _lerpState(_from, _to, morphT);

            // Дыхание ±2% по масштабу
            final breathScale = 1.0 + (_breathAnim.value - 0.5) * 0.04;
            final jitter = _jitterAnim.value * 1.5; // px

            return Transform.scale(
              scale: breathScale,
              child: Transform.translate(
                offset: Offset(jitter, 0),
                child: CustomPaint(
                  painter: _KaiPainter(
                    state: interpolated,
                    eyeColor: eyeColor,
                    bodyColor: bodyColor,
                    borderColor: borderColor,
                    breathValue: _breathAnim.value,
                    jitterOffset: jitter,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Описание состояния для интерполяции
// ---------------------------------------------------------------------------

/// Внутреннее описание визуального состояния Kai для морфинга.
class _KaiState {
  const _KaiState({
    required this.cornerRadius,    // 0..1 (0 = острый, 1 = идеальный круг)
    required this.scaleY,          // вертикальное растяжение squircle (0.9..1.15)
    required this.leftEyeHeight,   // высота левого глаза (0..1, bar)
    required this.rightEyeHeight,  // высота правого глаза
    required this.leftEyeArch,     // изгиб левого глаза (-1..1, + = вверх)
    required this.rightEyeArch,
    required this.leftEyeOffsetY,  // смещение левого глаза по Y (px, относительно)
    required this.rightEyeOffsetY,
    required this.showBrow,        // показывать «бровь» над глазом (для harsh)
    required this.opacity,         // общая прозрачность (для away — чуть тускнее)
  });

  final double cornerRadius;
  final double scaleY;
  final double leftEyeHeight;
  final double rightEyeHeight;
  final double leftEyeArch;
  final double rightEyeArch;
  final double leftEyeOffsetY;
  final double rightEyeOffsetY;
  final double showBrow; // 0..1 (плавно показываем)
  final double opacity;
}

/// Статические состояния для каждого выражения.
_KaiState _stateFor(KaiEmotion emotion, bool isHarsh) {
  // Базовая асимметрия: левый глаз на ~1.5 условных единицы выше правого.
  // В координатах состояния это смещение Y: левый = -1.5, правый = 0.
  const leftBaseY = -1.5;
  const rightBaseY = 0.0;

  if (isHarsh) {
    return const _KaiState(
      cornerRadius: 0.52,      // немного резче
      scaleY: 1.04,
      leftEyeHeight: 0.15,    // тонкие щели
      rightEyeHeight: 0.15,
      leftEyeArch: 0,
      rightEyeArch: 0,
      leftEyeOffsetY: leftBaseY,
      rightEyeOffsetY: rightBaseY,
      showBrow: 1,             // бровь всегда при harsh
      opacity: 1,
    );
  }

  switch (emotion) {
    case KaiEmotion.neutral:
      return const _KaiState(
        cornerRadius: 0.60,
        scaleY: 1.0,
        leftEyeHeight: 0.28,
        rightEyeHeight: 0.28,
        leftEyeArch: 0,
        rightEyeArch: 0,
        leftEyeOffsetY: leftBaseY,
        rightEyeOffsetY: rightBaseY,
        showBrow: 0,
        opacity: 1,
      );

    case KaiEmotion.success:
      return const _KaiState(
        cornerRadius: 0.85,    // пружинит к кругу
        scaleY: 0.96,
        leftEyeHeight: 0.22,
        rightEyeHeight: 0.22,
        leftEyeArch: 0.9,     // арки вверх ^ ^
        rightEyeArch: 0.9,
        leftEyeOffsetY: leftBaseY - 1.5, // немного выше от радости
        rightEyeOffsetY: rightBaseY - 1.5,
        showBrow: 0,
        opacity: 1,
      );

    case KaiEmotion.thinking:
      return const _KaiState(
        cornerRadius: 0.55,
        scaleY: 1.10,          // вытягивается вертикально
        leftEyeHeight: 0.14,  // один глаз прищурен (левый)
        rightEyeHeight: 0.30,
        leftEyeArch: -0.2,    // лёгкий наклон
        rightEyeArch: 0,
        leftEyeOffsetY: leftBaseY,
        rightEyeOffsetY: rightBaseY,
        showBrow: 0,
        opacity: 1,
      );

    case KaiEmotion.harsh:
      // Emotion.harsh без флага isHarsh — используем как «строгий» вариант
      return const _KaiState(
        cornerRadius: 0.50,
        scaleY: 1.06,
        leftEyeHeight: 0.13,
        rightEyeHeight: 0.13,
        leftEyeArch: 0,
        rightEyeArch: 0,
        leftEyeOffsetY: leftBaseY,
        rightEyeOffsetY: rightBaseY,
        showBrow: 0.8,
        opacity: 1,
      );

    case KaiEmotion.anxious:
      return const _KaiState(
        cornerRadius: 0.45,    // углы заострились
        scaleY: 0.88,          // сжался
        leftEyeHeight: 0.35,  // глаза чуть крупнее
        rightEyeHeight: 0.35,
        leftEyeArch: 0,
        rightEyeArch: 0,
        leftEyeOffsetY: leftBaseY,
        rightEyeOffsetY: rightBaseY,
        showBrow: 0,
        opacity: 1,
      );

    case KaiEmotion.away:
      return const _KaiState(
        cornerRadius: 0.58,
        scaleY: 1.03,          // чуть осел
        leftEyeHeight: 0.06,  // глаза-«нитки»
        rightEyeHeight: 0.06,
        leftEyeArch: 0,
        rightEyeArch: 0,
        leftEyeOffsetY: leftBaseY + 1.5, // глаза «упали»
        rightEyeOffsetY: rightBaseY + 1.5,
        showBrow: 0,
        opacity: 0.75,         // тускнее
      );
  }
}

/// Линейная интерполяция между двумя состояниями.
_KaiState _lerpState(_KaiState a, _KaiState b, double t) {
  double lerp(double x, double y) => x + (y - x) * t;
  return _KaiState(
    cornerRadius: lerp(a.cornerRadius, b.cornerRadius),
    scaleY: lerp(a.scaleY, b.scaleY),
    leftEyeHeight: lerp(a.leftEyeHeight, b.leftEyeHeight),
    rightEyeHeight: lerp(a.rightEyeHeight, b.rightEyeHeight),
    leftEyeArch: lerp(a.leftEyeArch, b.leftEyeArch),
    rightEyeArch: lerp(a.rightEyeArch, b.rightEyeArch),
    leftEyeOffsetY: lerp(a.leftEyeOffsetY, b.leftEyeOffsetY),
    rightEyeOffsetY: lerp(a.rightEyeOffsetY, b.rightEyeOffsetY),
    showBrow: lerp(a.showBrow, b.showBrow),
    opacity: lerp(a.opacity, b.opacity),
  );
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _KaiPainter extends CustomPainter {
  _KaiPainter({
    required this.state,
    required this.eyeColor,
    required this.bodyColor,
    required this.borderColor,
    required this.breathValue,
    required this.jitterOffset,
  });

  final _KaiState state;
  final Color eyeColor;
  final Color bodyColor;
  final Color borderColor;
  final double breathValue; // 0..1, для тонкого pulse thinking
  final double jitterOffset; // не используется здесь — дёргание через Transform

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // --- Рисуем squircle тело ---
    _drawBody(canvas, cx, cy, w, h);

    // --- Рисуем глаза ---
    _drawEyes(canvas, cx, cy, w, h);

    // --- Брови (для harsh / emotion.harsh) ---
    if (state.showBrow > 0.01) {
      _drawBrows(canvas, cx, cy, w, h);
    }
  }

  /// Тело: squircle (суперэллипс n≈4 аппроксимирован через кубические Безье).
  /// Радиус углов управляется [state.cornerRadius] (0 = прямоугольник, 1 = круг).
  void _drawBody(Canvas canvas, double cx, double cy, double w, double h) {
    // Вертикальный масштаб
    final bodyH = h * state.scaleY;
    final bodyW = w;

    // Радиус скругления: от 30% до 50% меньшей стороны
    final minSide = math.min(bodyW, bodyH);
    final r = minSide * (0.30 + state.cornerRadius * 0.20);

    // Суперэллипс аппроксимация через RRect с большим скруглением:
    // для cornerRadius→1 r ≈ minSide/2 → круг.
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: bodyW,
      height: bodyH,
    );
    final rrect = RRect.fromRectXY(rect, r, r);

    final bodyPaint = Paint()
      ..color = bodyColor.withValues(alpha: state.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bodyPaint);

    // Тонкая граница
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: state.opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(rrect, borderPaint);
  }

  /// Глаза: два прямоугольника (тире) с возможной аркой.
  void _drawEyes(Canvas canvas, double cx, double cy, double w, double h) {
    // Размеры глаз относительно виджета
    final eyeW = w * 0.20;     // ширина глаза
    final eyeBaseH = h * 0.06; // базовая высота (полная)
    final eyeGap = w * 0.14;   // половина расстояния между глазами от центра

    // Центр глаза по Y (смещение в пикселях)
    final eyeCenterY = cy + (h * 0.04); // чуть ниже центра — «лицо»
    final unitPx = h * 0.025; // единица смещения

    final leftCx = cx - eyeGap;
    final rightCx = cx + eyeGap;

    final leftCy = eyeCenterY + state.leftEyeOffsetY * unitPx;
    final rightCy = eyeCenterY + state.rightEyeOffsetY * unitPx;

    final leftH = eyeBaseH * state.leftEyeHeight.clamp(0.04, 1.0) / 0.28;
    final rightH = eyeBaseH * state.rightEyeHeight.clamp(0.04, 1.0) / 0.28;

    final eyePaint = Paint()
      ..color = eyeColor.withValues(alpha: state.opacity)
      ..style = PaintingStyle.fill;

    _drawEye(
      canvas,
      cx: leftCx,
      cy: leftCy,
      eyeW: eyeW,
      eyeH: leftH,
      arch: state.leftEyeArch,
      paint: eyePaint,
    );
    _drawEye(
      canvas,
      cx: rightCx,
      cy: rightCy,
      eyeW: eyeW,
      eyeH: rightH,
      arch: state.rightEyeArch,
      paint: eyePaint,
    );
  }

  /// Рисует один глаз: при arch==0 — скруглённый прямоугольник;
  /// при arch>0 — арка (^ — дуга вверх); при arch<0 — дуга вниз.
  void _drawEye(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double eyeW,
    required double eyeH,
    required double arch,
    required Paint paint,
  }) {
    if (arch.abs() < 0.05) {
      // Простой rounded-rect тире
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: eyeW,
        height: math.max(eyeH, 1.0),
      );
      final radius = eyeH / 2;
      canvas.drawRRect(
        RRect.fromRectXY(rect, radius, radius),
        paint,
      );
      return;
    }

    // Арочный глаз — кубический Безье
    // Начало, конец — левый и правый край;
    // контрольные точки смещены вверх/вниз пропорционально arch.
    final x0 = cx - eyeW / 2;
    final x1 = cx + eyeW / 2;
    final archDy = eyeW * arch * 0.6; // вертикальный прогиб

    // Дуга через Path.quadraticBezierTo
    final strokeW = math.max(eyeH, 1.5);
    final strokePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(x0, cy)
      ..quadraticBezierTo(cx, cy - archDy, x1, cy);

    canvas.drawPath(path, strokePaint);
  }

  /// Брови: тонкие горизонтальные штрихи выше глаз (MASCOT.md §4: жёсткий тон).
  void _drawBrows(Canvas canvas, double cx, double cy, double w, double h) {
    final eyeGap = w * 0.14;
    final eyeBaseH = h * 0.06;
    final eyeCenterY = cy + (h * 0.04);
    final unitPx = h * 0.025;

    final leftCy = eyeCenterY + state.leftEyeOffsetY * unitPx;
    final rightCy = eyeCenterY + state.rightEyeOffsetY * unitPx;

    final browOffsetY = eyeBaseH * 1.8; // чуть выше глаза
    final browW = w * 0.16;

    final browPaint = Paint()
      ..color = eyeColor.withValues(alpha: state.opacity * state.showBrow * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(h * 0.018, 1.0)
      ..strokeCap = StrokeCap.round;

    // Левая бровь — слегка наклонена (нахмуренная)
    canvas.drawLine(
      Offset(cx - eyeGap - browW / 2, leftCy - browOffsetY + h * 0.015),
      Offset(cx - eyeGap + browW / 2, leftCy - browOffsetY - h * 0.015),
      browPaint,
    );
    // Правая бровь
    canvas.drawLine(
      Offset(cx + eyeGap - browW / 2, rightCy - browOffsetY - h * 0.015),
      Offset(cx + eyeGap + browW / 2, rightCy - browOffsetY + h * 0.015),
      browPaint,
    );
  }

  @override
  bool shouldRepaint(_KaiPainter old) {
    return old.state.cornerRadius != state.cornerRadius ||
        old.state.scaleY != state.scaleY ||
        old.state.leftEyeHeight != state.leftEyeHeight ||
        old.state.rightEyeHeight != state.rightEyeHeight ||
        old.state.leftEyeArch != state.leftEyeArch ||
        old.state.rightEyeArch != state.rightEyeArch ||
        old.state.leftEyeOffsetY != state.leftEyeOffsetY ||
        old.state.rightEyeOffsetY != state.rightEyeOffsetY ||
        old.state.showBrow != state.showBrow ||
        old.state.opacity != state.opacity ||
        old.eyeColor != eyeColor ||
        old.bodyColor != bodyColor ||
        old.breathValue != breathValue;
  }
}
