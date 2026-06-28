// Маскот «Kai» — pure-Flutter реализация через CustomPainter.
// v4 (Kaname redesign, 2026-06-28): бесформенная жидкая «галька» —
// суперэллипс без глаз, рта, бровей, лица любого вида.
// Источник истины: /docs/REDESIGN-KANAME.md §Kai.
//
// Шесть состояний (5 KaiEmotion + модификатор isHarsh):
//   neutral  — мягкая скруглённая галька, медленное дыхание, акцентный цвет.
//   success  — заполняется к кругу, пружинный bounce, на мгновение ярче.
//   thinking — вытягивается вертикально, пульс + внутренняя орбитальная частица.
//   anxious  — сжимается, микро-дрожание, цвет сдвигается к ember.
//   away     — оседает, тускнеет, медленные редкие морфы.
//   isHarsh  — более собранный, острее края, ember-тинт, снаппер. Компонуется
//              поверх любой эмоции (заменяет «глаза+брови» прежней реализации).
//
// При reduce-motion/high-contrast: статичная нейтральная галька без анимаций
// и без таймеров (тесты не жалуются на pending timer).
//
// Публичный API (не менять — вызывается из kai_loader, today_screen, paywall,
// onboarding, asset-gen теста):
//   enum KaiEmotion { neutral, success, thinking, anxious, away }
//   class KaiMascot({Key? key, double size, KaiEmotion emotion, bool isHarsh, VoidCallback? onTap})
//   Future<List<int>> renderKaiPng({...}) — статичный PNG для нативного виджета.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import 'kai_speech_bubble.dart';

// ---------------------------------------------------------------------------
// Enum выражений (публичный API — не менять имена)
// ---------------------------------------------------------------------------

/// Пять выражений Kai. Жёсткость — не эмоция; передаётся флагом [KaiMascot.isHarsh].
enum KaiEmotion {
  neutral,
  success,
  thinking,
  anxious,
  away,
}

// ---------------------------------------------------------------------------
// renderKaiPng (публичный API — сигнатуру не менять)
// ---------------------------------------------------------------------------

/// Рендерит статичный PNG-кадр Kai без виджет-дерева и без анимаций.
///
/// Используется скриптом генерации ассетов для нативного виджета.
///
/// [eyeColor]    — сохранён для совместимости вызывающего кода; в новой реализации
///                 Kai не имеет глаз — параметр не используется.
/// [bodyColor]   — интерпретируется как основной акцентный цвет заливки.
/// [borderColor] — сохранён для совместимости; не используется напрямую в отрисовке.
Future<List<int>> renderKaiPng({
  required KaiEmotion emotion,
  required bool isHarsh,
  required Color eyeColor,    // не используется (нет глаз); сохранён для совместимости
  required Color bodyColor,   // основной акцентный цвет заливки
  required Color borderColor, // не используется; сохранён для совместимости
  required double size,
  double pixelRatio = 1.0,
}) async {
  final pxSize = size * pixelRatio;
  final canvasSize = ui.Size(pxSize, pxSize);

  final kaiState = _stateFor(emotion, isHarsh);
  // Суб-блоб: осветлённая версия акцентного цвета
  final subBlobColor = Color.lerp(bodyColor, Colors.white, 0.30) ?? bodyColor;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & canvasSize);

  final painter = _KaiPainter(
    state: kaiState,
    accentColor: bodyColor,
    subBlobColor: subBlobColor,
    thinkOrbitT: 0.0, // статика — орбиты нет
  );

  painter.paint(canvas, canvasSize);

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.round(), pxSize.round());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    throw StateError('renderKaiPng: toByteData вернул null для $emotion');
  }

  return byteData.buffer.asUint8List().toList();
}

// ---------------------------------------------------------------------------
// Публичный виджет
// ---------------------------------------------------------------------------

/// Маскот Kai — жидкая «галька» без лица. Эмоция — через форму, цвет и движение.
///
/// [size]    — размер квадрата, в который вписывается маскот (default 56).
/// [emotion] — одно из пяти выражений [KaiEmotion].
/// [isHarsh] — жёсткий тон: острее края, ember-тинт, снаппер анимация.
///             Компонуется с emotion, а не переопределяет его.
/// [onTap]   — необязательный коллбек.
class KaiMascot extends StatefulWidget {
  const KaiMascot({
    super.key,
    this.size = 56,
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

// Количество ротируемых реплик при тапе (kai.tap_quip_0 .. kai.tap_quip_N-1).
const int _kTapQuipCount = 5;

class _KaiMascotState extends State<KaiMascot> with TickerProviderStateMixin {
  // --- Tap → neutral (кратковременный override поверх widget.emotion) ---
  bool _tapNeutral = false;
  Object? _tapNeutralToken;
  static const Duration _tapNeutralHold = Duration(milliseconds: 1200);

  // --- Счётчик тапов + речевой пузырь ---
  int _tapCount = 0;
  bool _showBubble = false;
  Timer? _bubbleTimer;
  static const int _kBubbleHoldMs = 2000;

  // --- Баунс при тапе ---
  late final AnimationController _bounceCtrl;
  late Animation<double> _bounceScaleAnim;
  late Animation<double> _bounceRotateAnim;

  // --- Дыхание (idle, ping-pong ~3.5 с) ---
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;

  // --- Морфинг между состояниями ---
  late final AnimationController _morphCtrl;
  late _KaiState _from;
  late _KaiState _to;
  late Animation<double> _morphAnim;

  // --- Дрожание (только для anxious) ---
  late final AnimationController _jitterCtrl;
  late final Animation<double> _jitterAnim;

  // --- Орбитальная частица / пульс (только для thinking) ---
  late final AnimationController _thinkPulseCtrl;
  late final Animation<double> _thinkPulseAnim;

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

    // Морфинг: нормальная длительность 280 мс
    _morphCtrl = AnimationController(
      vsync: this,
      duration: kDurationNormal,
    );
    _morphAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _morphCtrl, curve: kCurveLift),
    );

    // Дрожание (anxious): быстрый ping-pong 80 мс
    _jitterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _jitterAnim = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _jitterCtrl, curve: Curves.easeInOut),
    );

    // Орбитальная частица (thinking): 1.4 с полный оборот, линейный
    _thinkPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _thinkPulseAnim = Tween<double>(begin: 0, end: 1).animate(_thinkPulseCtrl);

    // Баунс-анимация при тапе: kDurationNormal (280 мс), упругая.
    // Scale: 1.0 → 1.15 → 0.92 → 1.0; Rotate: 0 → +0.10 → -0.10 → 0 рад.
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: kDurationNormal,
    );
    _bounceScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: kCurveSpring)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 0.92)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: kCurveLift)),
        weight: 30,
      ),
    ]).animate(_bounceCtrl);
    _bounceRotateAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.10)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 33,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.10, end: -0.10)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.10, end: 0.0)
            .chain(CurveTween(curve: kCurveLift)),
        weight: 33,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startLoops();
  }

  /// Эффективная эмоция: пока активен tap-override — neutral.
  KaiEmotion get _effectiveEmotion =>
      _tapNeutral ? KaiEmotion.neutral : widget.emotion;

  /// Запускает морфинг к [_effectiveEmotion] от текущего кадра.
  void _morphToEffective() {
    final currentT = _morphAnim.value;
    _from = _lerpState(_from, _to, currentT);
    _to = _stateFor(_effectiveEmotion, widget.isHarsh);

    final curve =
        _effectiveEmotion == KaiEmotion.success ? kCurveSpring : kCurveLift;
    _morphAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _morphCtrl, curve: curve),
    );
    _morphCtrl
      ..reset()
      ..forward();
  }

  /// Тап: bounce + пузырь + кратковременный neutral-override.
  /// При reduce-motion: только вызывает onTap + показывает пузырь без таймера.
  void _handleTap() {
    widget.onTap?.call();

    final reduce = reduceMotionOf(context);

    setState(() {
      _tapCount++;
      _showBubble = true;
    });

    if (!reduce) {
      _bounceCtrl
        ..reset()
        ..forward();
    }

    // Авто-скрытие пузыря — только при разрешённых анимациях.
    // При reduce-motion пузырь не скрываем автоматически (нет таймеров = нет pending).
    if (!reduce) {
      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(Duration(milliseconds: _kBubbleHoldMs), () {
        if (!mounted) return;
        setState(() => _showBubble = false);
      });
    }

    if (reduce) return;

    // Морфинг к neutral.
    final token = Object();
    _tapNeutralToken = token;
    if (!_tapNeutral) {
      setState(() => _tapNeutral = true);
      _morphToEffective();
      _startLoops();
    }

    Future.delayed(_tapNeutralHold, () {
      if (!mounted) return;
      if (_tapNeutralToken != token) return;
      setState(() => _tapNeutral = false);
      _morphToEffective();
      _startLoops();
    });
  }

  @override
  void didUpdateWidget(KaiMascot old) {
    super.didUpdateWidget(old);
    if (old.emotion != widget.emotion || old.isHarsh != widget.isHarsh) {
      _tapNeutral = false;
      _tapNeutralToken = null;
      _morphToEffective();
    }
    _startLoops();
  }

  void _startLoops() {
    final reduce = reduceMotionOf(context);

    if (reduce) {
      // Все петли останавливаем — никаких pending timers в тестах.
      _breathCtrl.stop();
      _jitterCtrl.stop();
      _jitterCtrl.value = 0;
      _thinkPulseCtrl.stop();
      _thinkPulseCtrl.value = 0;
      return;
    }

    // Idle-дыхание: всегда ping-pong
    if (!_breathCtrl.isAnimating) {
      _breathCtrl.repeat(reverse: true);
    }

    // Дрожание: только для anxious
    if (_effectiveEmotion == KaiEmotion.anxious) {
      if (!_jitterCtrl.isAnimating) {
        _jitterCtrl.repeat(reverse: true);
      }
    } else {
      _jitterCtrl.stop();
      _jitterCtrl.value = 0;
    }

    // Орбитальная частица: только для thinking (непрерывное вращение)
    if (_effectiveEmotion == KaiEmotion.thinking) {
      if (!_thinkPulseCtrl.isAnimating) {
        _thinkPulseCtrl.repeat();
      }
    } else {
      _thinkPulseCtrl.stop();
      _thinkPulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _breathCtrl.dispose();
    _morphCtrl.dispose();
    _jitterCtrl.dispose();
    _thinkPulseCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  /// Амплитуда дыхания (масштаб ±%).
  double get _breathAmplitude {
    if (_effectiveEmotion == KaiEmotion.anxious) return 0;
    if (_effectiveEmotion == KaiEmotion.thinking) return 0.01;
    if (widget.isHarsh) return 0.01;
    return 0.02;
  }

  /// Вычисляет итоговый акцентный цвет из схемы и состояния.
  /// При emberBlend > 0 цвет сдвигается к colorScheme.secondary (ember).
  Color _resolveAccent(ColorScheme cs, _KaiState state) {
    final base = cs.primary;
    if (state.emberBlend <= 0.001) return base;
    return Color.lerp(base, cs.secondary, state.emberBlend) ?? base;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Реплика при тапе: ротация по счётчику (детерминированно, воспроизводимо).
    final quipIndex = (_tapCount - 1).clamp(0, _kTapQuipCount - 1) % _kTapQuipCount;
    final quipText = context.s('kai.tap_quip_$quipIndex');

    // Речевой пузырь плавает над Kai (Stack + Positioned, clipBehavior: Clip.none).
    final bubbleWidget = Positioned(
      bottom: widget.size + 4,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : kDurationNormal,
          switchInCurve: kCurveLift,
          switchOutCurve: kCurveLift,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          child: _showBubble
              ? KaiSpeechBubble(
                  key: ValueKey(quipIndex),
                  message: quipText,
                  animate: !reduce,
                  tail: KaiBubbleTail.bottomCenter,
                  maxWidth: (widget.size * 3).clamp(160.0, 240.0),
                )
              : SizedBox(key: const ValueKey('empty')),
        ),
      ),
    );

    final kaiWidget = AnimatedBuilder(
      animation: Listenable.merge([
        _breathAnim,
        _morphAnim,
        _jitterAnim,
        _thinkPulseAnim,
        _bounceCtrl,
      ]),
      builder: (context, _) {
        // При reduce-motion: статичный neutral без трансформов.
        if (reduce) {
          final staticState = _stateFor(KaiEmotion.neutral, widget.isHarsh);
          final accent = _resolveAccent(colorScheme, staticState);
          final sub = Color.lerp(accent, Colors.white, 0.28) ?? accent;
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _KaiPainter(
              state: staticState,
              accentColor: accent,
              subBlobColor: sub,
              thinkOrbitT: 0,
            ),
          );
        }

        final morphT = _morphAnim.value;
        final interpolated = _lerpState(_from, _to, morphT);

        // Дыхание: ±breathAmplitude масштаб
        final breathScale =
            1.0 + (_breathAnim.value - 0.5) * (_breathAmplitude * 2);

        // Дрожание: ±1.5 px горизонтально (anxious)
        final jitter = _jitterAnim.value * 1.5;

        // Баунс при тапе
        final bounceScale = _bounceScaleAnim.value;
        final bounceRotate = _bounceRotateAnim.value;

        final accent = _resolveAccent(colorScheme, interpolated);
        final sub = Color.lerp(accent, Colors.white, 0.28) ?? accent;

        return Transform.rotate(
          angle: bounceRotate,
          child: Transform.scale(
            scale: breathScale * bounceScale,
            child: Transform.translate(
              offset: Offset(jitter, 0),
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _KaiPainter(
                  state: interpolated,
                  accentColor: accent,
                  subBlobColor: sub,
                  thinkOrbitT: _thinkPulseAnim.value,
                ),
              ),
            ),
          ),
        );
      },
    );

    // SizedBox фиксирует footprint; Stack(clipBehavior: Clip.none) позволяет
    // пузырю рисоваться выше и bounce слегка выходить за bounds.
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: kaiWidget),
            bubbleWidget,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Внутреннее состояние для морфинга
// ---------------------------------------------------------------------------

/// Описание визуального состояния Kai для интерполяции между эмоциями.
/// Все поля — нормализованные значения; конкретные пиксели вычисляются в painter.
class _KaiState {
  const _KaiState({
    required this.roundness,      // 0..1: 0 = более угловатый пебл, 1 = идеальный круг
    required this.scaleY,         // вертикальное растяжение (0.85..1.15)
    required this.asymmetry,      // лёгкая органическая асимметрия (0..0.08)
    required this.brightness,     // сдвиг яркости заливки (< 0 = темнее, > 0 = ярче)
    required this.emberBlend,     // 0..1: сдвиг цвета к ember (anxious / isHarsh)
    required this.opacity,        // общая прозрачность (away = 0.70)
    required this.subBlobScale,   // масштаб суб-блоба относительно основного (0..0.55)
    required this.subBlobOffsetX, // X-смещение суб-блоба (доли rx, < 0 = влево)
    required this.subBlobOffsetY, // Y-смещение суб-блоба (доли ry, < 0 = вверх)
  });

  final double roundness;
  final double scaleY;
  final double asymmetry;
  final double brightness;
  final double emberBlend;
  final double opacity;
  final double subBlobScale;
  final double subBlobOffsetX;
  final double subBlobOffsetY;
}

/// Чистая эмоциональная база (без isHarsh).
_KaiState _emotionBase(KaiEmotion emotion) {
  switch (emotion) {
    case KaiEmotion.neutral:
      return const _KaiState(
        roundness: 0.65,
        scaleY: 1.00,
        asymmetry: 0.040,
        brightness: 0.0,
        emberBlend: 0.0,
        opacity: 1.0,
        subBlobScale: 0.45,
        subBlobOffsetX: -0.18,
        subBlobOffsetY: -0.22,
      );

    case KaiEmotion.success:
      return const _KaiState(
        roundness: 0.90,    // почти круг — пружинный overshoot к форме
        scaleY: 0.97,
        asymmetry: 0.015,
        brightness: 0.18,   // кратковременная вспышка яркости
        emberBlend: 0.0,
        opacity: 1.0,
        subBlobScale: 0.50,
        subBlobOffsetX: -0.12,
        subBlobOffsetY: -0.24,
      );

    case KaiEmotion.thinking:
      return const _KaiState(
        roundness: 0.55,
        scaleY: 1.13,       // вытянут вертикально — «AI работает»
        asymmetry: 0.055,
        brightness: 0.05,
        emberBlend: 0.0,
        opacity: 1.0,
        subBlobScale: 0.38,
        subBlobOffsetX: -0.14,
        subBlobOffsetY: -0.28,
      );

    case KaiEmotion.anxious:
      return const _KaiState(
        roundness: 0.48,    // острее — тревожная напряжённость
        scaleY: 0.87,       // сжат вертикально
        asymmetry: 0.065,
        brightness: 0.0,
        emberBlend: 0.60,   // сильный сдвиг к ember
        opacity: 1.0,
        subBlobScale: 0.35,
        subBlobOffsetX: -0.10,
        subBlobOffsetY: -0.18,
      );

    case KaiEmotion.away:
      return const _KaiState(
        roundness: 0.62,
        scaleY: 1.04,       // осел, чуть приплюснут
        asymmetry: 0.030,
        brightness: -0.10,  // тускнее
        emberBlend: 0.0,
        opacity: 0.70,
        subBlobScale: 0.40,
        subBlobOffsetX: -0.14,
        subBlobOffsetY: -0.20,
      );
  }
}

/// Итоговое состояние: эмоция-база + isHarsh-оверлей.
_KaiState _stateFor(KaiEmotion emotion, bool isHarsh) {
  final base = _emotionBase(emotion);
  if (!isHarsh) return base;

  // isHarsh: более собранная, острее края, ember-тинт, меньше двухтонового.
  return _KaiState(
    roundness: (base.roundness - 0.08).clamp(0.38, 0.90),
    scaleY: base.scaleY + 0.03,
    asymmetry: base.asymmetry * 0.4,       // более контролируемая форма
    brightness: base.brightness,
    emberBlend: math.max(base.emberBlend, 0.35),
    opacity: base.opacity,
    subBlobScale: base.subBlobScale * 0.65, // меньше двухтонового выделения
    subBlobOffsetX: base.subBlobOffsetX,
    subBlobOffsetY: base.subBlobOffsetY,
  );
}

/// Линейная интерполяция между двумя состояниями.
_KaiState _lerpState(_KaiState a, _KaiState b, double t) {
  double lerp(double x, double y) => x + (y - x) * t;
  return _KaiState(
    roundness: lerp(a.roundness, b.roundness),
    scaleY: lerp(a.scaleY, b.scaleY),
    asymmetry: lerp(a.asymmetry, b.asymmetry),
    brightness: lerp(a.brightness, b.brightness),
    emberBlend: lerp(a.emberBlend, b.emberBlend),
    opacity: lerp(a.opacity, b.opacity),
    subBlobScale: lerp(a.subBlobScale, b.subBlobScale),
    subBlobOffsetX: lerp(a.subBlobOffsetX, b.subBlobOffsetX),
    subBlobOffsetY: lerp(a.subBlobOffsetY, b.subBlobOffsetY),
  );
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _KaiPainter extends CustomPainter {
  _KaiPainter({
    required this.state,
    required this.accentColor,   // итоговый акцентный цвет (уже смешан с ember если нужно)
    required this.subBlobColor,  // осветлённая версия accent для суб-блоба
    required this.thinkOrbitT,   // 0..1 — позиция орбитальной частицы (thinking)
  });

  final _KaiState state;
  final Color accentColor;
  final Color subBlobColor;
  final double thinkOrbitT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Базовый радиус: 42% от размера → остаётся в bounds при любом scaleY ≤ 1.15
    // (0.42 * 1.15 = 0.483 < 0.5)
    final baseR = math.min(w, h) * 0.42;
    final rx = baseR;
    final ry = baseR * state.scaleY;

    // Корректируем цвет заливки через brightness:
    //   brightness > 0 → осветляем (смешиваем с белым)
    //   brightness < 0 → затемняем (смешиваем с чёрным)
    final Color fillColor;
    if (state.brightness >= 0) {
      fillColor =
          Color.lerp(accentColor, Colors.white, state.brightness * 0.45) ??
              accentColor;
    } else {
      fillColor =
          Color.lerp(accentColor, Colors.black, (-state.brightness) * 0.35) ??
              accentColor;
    }

    // --- Основной блоб ---
    final mainPath =
        _buildBlobPath(cx, cy, rx, ry, state.roundness, state.asymmetry);

    canvas.drawPath(
      mainPath,
      Paint()
        ..color = fillColor.withValues(alpha: state.opacity)
        ..style = PaintingStyle.fill,
    );

    // --- Суб-блоб (двухтоновый акцент, верхний квадрант) ---
    // Даёт ощущение объёма без резкого градиента.
    if (state.subBlobScale > 0.05) {
      final subRx = rx * state.subBlobScale;
      final subRy = ry * state.subBlobScale;
      final subCx = cx + rx * state.subBlobOffsetX;
      final subCy = cy + ry * state.subBlobOffsetY;

      final subPath = _buildBlobPath(
        subCx, subCy, subRx, subRy,
        (state.roundness + 0.15).clamp(0.0, 1.0), // суб-блоб чуть круглее
        state.asymmetry * 0.5,
      );

      canvas.drawPath(
        subPath,
        Paint()
          ..color = subBlobColor.withValues(alpha: state.opacity * 0.50)
          ..style = PaintingStyle.fill,
      );
    }

    // --- Орбитальная частица (только для thinking) ---
    // Маленький светлый круг вращается внутри блоба, передавая идею «AI в процессе».
    if (thinkOrbitT > 0.001) {
      _drawOrbitParticle(canvas, cx, cy, rx, ry);
    }
  }

  /// Строит путь «жидкой гальки» через 4 кубических безье-кривых.
  ///
  /// Алгоритм: стандартная аппроксимация через коэффициент k — множитель контрольных
  /// точек. k=0.5523 → идеальный круг. k < 0.5523 → органичный «пебл» с чуть угловатыми
  /// краями (squircle-like). asymmetry сдвигает левый/правый и верхний/нижний радиусы.
  Path _buildBlobPath(
    double cx,
    double cy,
    double rx,
    double ry,
    double roundness,
    double asymmetry,
  ) {
    // k интерполируется: 0.40 (угловатый) → 0.5523 (круг).
    final k = 0.40 + roundness * 0.1523;

    // Лёгкая органическая асимметрия
    final rxL = rx * (1.0 - asymmetry * 0.30);
    final rxR = rx * (1.0 + asymmetry * 0.30);
    final ryT = ry * (1.0 - asymmetry * 0.15);
    final ryB = ry * (1.0 + asymmetry * 0.15);

    final path = Path()..moveTo(cx, cy - ryT);

    // Верхняя точка → правая точка
    path.cubicTo(
      cx + k * rxR, cy - ryT,
      cx + rxR, cy - k * ryT,
      cx + rxR, cy,
    );

    // Правая точка → нижняя точка
    path.cubicTo(
      cx + rxR, cy + k * ryB,
      cx + k * rxR, cy + ryB,
      cx, cy + ryB,
    );

    // Нижняя точка → левая точка
    path.cubicTo(
      cx - k * rxL, cy + ryB,
      cx - rxL, cy + k * ryB,
      cx - rxL, cy,
    );

    // Левая точка → верхняя точка
    path.cubicTo(
      cx - rxL, cy - k * ryT,
      cx - k * rxL, cy - ryT,
      cx, cy - ryT,
    );

    path.close();
    return path;
  }

  /// Орбитальная частица для thinking: маленький светлый круг внутри блоба,
  /// вращающийся по эллипсу на 65% от радиуса. Создаёт эффект «AI обрабатывает».
  void _drawOrbitParticle(
    Canvas canvas,
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    final angle = thinkOrbitT * 2 * math.pi;

    // Внутренняя орбита: 65% от радиуса блоба — без риска выхода за bounds
    final orbitRx = rx * 0.65;
    final orbitRy = ry * 0.65;

    final px = cx + orbitRx * math.cos(angle);
    final py = cy + orbitRy * math.sin(angle);

    final particleR = (rx * 0.10).clamp(1.5, 5.5);

    canvas.drawCircle(
      Offset(px, py),
      particleR,
      Paint()
        ..color = subBlobColor.withValues(alpha: state.opacity * 0.80)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_KaiPainter old) {
    return old.state.roundness != state.roundness ||
        old.state.scaleY != state.scaleY ||
        old.state.asymmetry != state.asymmetry ||
        old.state.brightness != state.brightness ||
        old.state.emberBlend != state.emberBlend ||
        old.state.opacity != state.opacity ||
        old.state.subBlobScale != state.subBlobScale ||
        old.state.subBlobOffsetX != state.subBlobOffsetX ||
        old.state.subBlobOffsetY != state.subBlobOffsetY ||
        old.accentColor != accentColor ||
        old.subBlobColor != subBlobColor ||
        old.thinkOrbitT != thinkOrbitT;
  }
}
