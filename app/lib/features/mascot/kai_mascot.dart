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
//
// v2 (2026-06): добавлен моргания (blink) + micro-look (горизонтальный дрейф взгляда)
// для читаемой «живости» на idle, усиленный pulse для thinking.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
// Рендер в PNG (для нативного виджета — WIDGET.md §6)
// ---------------------------------------------------------------------------

/// Рендерит статичный кадр Kai в PNG-байты без виджет-дерева и без анимаций.
///
/// Используется скриптом генерации ассетов (test/generate_kai_assets_test.dart)
/// для создания PNG-кадров, которые кладутся в Android `drawable-{density}/`
/// и assets/kai_widget/ (iOS). Flutter/CustomPainter/Rive недоступны в нативном
/// виджете, поэтому заранее рендерим статичные PNG (WIDGET.md §6).
///
/// Параметры:
///   [emotion]     — одно из выражений [KaiEmotion].
///   [isHarsh]     — жёсткий тон (глаза уже, брови, ember-цвет).
///   [eyeColor]    — цвет глаз (= accent темы; для белых нейтральных глаз — Colors.white).
///   [bodyColor]   — цвет тела squircle (полупрозрачный тёмный для тёмных тем).
///   [borderColor] — цвет обводки (полупрозрачный, обычно совпадает с bodyColor).
///   [size]        — логический размер (в dp/pt), обычно 96.
///   [pixelRatio]  — плотность пикселей (1.0 = mdpi, 2.0 = xhdpi, 4.0 = xxxhdpi).
///
/// Возвращает PNG-байты с прозрачным фоном.
/// Анимационные параметры зафиксированы в «покое»:
///   дыхание = 0.5 (середина), моргание = 0 (глаза открыты),
///   взгляд = 0 (по центру), jitter = 0, thinkPulse = 0.
Future<List<int>> renderKaiPng({
  required KaiEmotion emotion,
  required bool isHarsh,
  required Color eyeColor,
  required Color bodyColor,
  required Color borderColor,
  required double size,
  double pixelRatio = 1.0,
}) async {
  // Реальный размер в физических пикселях
  final pxSize = size * pixelRatio;
  final canvasSize = ui.Size(pxSize, pxSize);

  // Вычисляем статичное состояние (без интерполяции, в «покое» для эмоции)
  final kaiState = _stateFor(emotion, isHarsh);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & canvasSize);

  final painter = _KaiPainter(
    state: kaiState,
    eyeColor: eyeColor,
    bodyColor: bodyColor,
    borderColor: borderColor,
    breathValue: 0.5,   // середина цикла дыхания — нейтральный масштаб
    jitterOffset: 0.0,  // нет дёргания
    blinkT: 0.0,        // глаза открыты
    microShiftX: 0.0,   // взгляд по центру
    thinkPulseValue: 0.0, // нет пульса
  );

  painter.paint(canvas, canvasSize);

  final picture = recorder.endRecording();
  final image = await picture.toImage(pxSize.round(), pxSize.round());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    throw StateError('renderKaiPng: toByteData вернул null для $emotion');
  }

  // Возвращаем Uint8List как List<int> (совместимо с dart:io File.writeAsBytes)
  return byteData.buffer.asUint8List().toList();
}

// ---------------------------------------------------------------------------
// Публичный виджет
// ---------------------------------------------------------------------------

/// Маскот Kai — мягкий squircle с двумя глазами-тире.
///
/// Параметры:
///   [size]    — размер квадрата, в который вписывается маскот (default 56).
///   [emotion] — одно из шести выражений [KaiEmotion].
///   [isHarsh] — жёсткий тон: глаза → узкие щели, цвет → ember, углы резче.
///               Компонуется с emotion, а не переопределяет его.
///   [onTap]   — необязательный коллбек (для дисмисса / цикла выражений).
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

class _KaiMascotState extends State<KaiMascot>
    with TickerProviderStateMixin {
  // --- Дыхание (idle, бесконечный цикл) ---
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;

  // --- Морфинг между выражениями ---
  late final AnimationController _morphCtrl;
  late _KaiState _from;
  late _KaiState _to;
  late Animation<double> _morphAnim;

  // --- Тревожное дёргание (только anxious) ---
  late final AnimationController _jitterCtrl;
  late final Animation<double> _jitterAnim;

  // --- Моргание (v2) ---
  // blinkT: 0 = глаза полностью открыты, 1 = полностью закрыты
  late final AnimationController _blinkCtrl;
  late final Animation<double> _blinkAnim;
  Timer? _blinkTimer;

  // --- Micro-look: тихий горизонтальный дрейф взгляда (v2) ---
  // Значение -1..+1 умножается на maxShiftPx в painter
  late final AnimationController _lookCtrl;
  late final Animation<double> _lookAnim;

  // --- Thinking-pulse: усиленный визуальный пульс при thinking (v2) ---
  // Отдельный быстрый контроллер для pulsing scaleY во время thinking
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

    // Морфинг: нормальная длительность
    _morphCtrl = AnimationController(
      vsync: this,
      duration: kDurationNormal,
    );
    _morphAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _morphCtrl, curve: kCurveLift),
    );

    // Тревожное дёргание
    _jitterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _jitterAnim = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _jitterCtrl, curve: Curves.easeInOut),
    );

    // Моргание: быстро (70 мс закрыть → 70 мс открыть = 140 мс полный цикл)
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _blinkAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
    );

    // Micro-look: медленный синус ~7 сек
    _lookCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    _lookAnim = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _lookCtrl, curve: Curves.easeInOut),
    );

    // Thinking-pulse: быстрее дыхания — 1.4 сек цикл, имитирует AI-пульс
    _thinkPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _thinkPulseAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _thinkPulseCtrl, curve: Curves.easeInOut),
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

    if (old.emotion != widget.emotion || old.isHarsh != widget.isHarsh) {
      final currentT = _morphAnim.value;
      _from = _lerpState(_from, _to, currentT);
      _to = _stateFor(widget.emotion, widget.isHarsh);

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

    _startLoops();
  }

  /// Планирует следующее моргание через псевдослучайный интервал 4–7 сек.
  /// «Случайность» детерминирована через widget.size и hashCode — разные
  /// экземпляры моргают не синхронно, но без math.Random (воспроизводимо).
  void _scheduleBlink() {
    _blinkTimer?.cancel();
    // Фаза 0..1 — уникальна для каждого экземпляра (size + hashCode)
    final phase = ((widget.size * 1000).toInt() ^ widget.hashCode) & 0xFFFF;
    // Интервал 4000..7000 мс на основе фазы + монотонного времени
    final baseMs = 4000 + (phase % 3000); // 4000–6999 мс
    _blinkTimer = Timer(Duration(milliseconds: baseMs), _doBlink);
  }

  /// Проигрывает один цикл моргания: закрыть → открыть → запланировать следующий.
  Future<void> _doBlink() async {
    if (!mounted) return;
    final reduce = reduceMotionOf(context);
    if (reduce) {
      _scheduleBlink();
      return;
    }
    // Закрываем глаза (0→1)
    await _blinkCtrl.forward();
    // Открываем (1→0)
    await _blinkCtrl.reverse();
    if (mounted) _scheduleBlink();
  }

  void _startLoops() {
    final reduce = reduceMotionOf(context);

    if (reduce) {
      // При reduce-motion все петли останавливаем
      _breathCtrl.stop();
      _jitterCtrl.stop();
      _blinkTimer?.cancel();
      _blinkCtrl.stop();
      _blinkCtrl.value = 0; // глаза открыты
      _lookCtrl.stop();
      _lookCtrl.value = 0;
      _thinkPulseCtrl.stop();
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

    // Моргание: запускаем если таймер не активен
    if (_blinkTimer == null || !_blinkTimer!.isActive) {
      _scheduleBlink();
    }

    // Micro-look: медленный ping-pong
    if (!_lookCtrl.isAnimating) {
      _lookCtrl.repeat(reverse: true);
    }

    // Thinking-pulse: только для thinking
    if (widget.emotion == KaiEmotion.thinking) {
      if (!_thinkPulseCtrl.isAnimating) {
        _thinkPulseCtrl.repeat(reverse: true);
      }
    } else {
      _thinkPulseCtrl.stop();
      _thinkPulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathCtrl.dispose();
    _morphCtrl.dispose();
    _jitterCtrl.dispose();
    _blinkCtrl.dispose();
    _lookCtrl.dispose();
    _thinkPulseCtrl.dispose();
    super.dispose();
  }

  /// Амплитуда дыхания по 04-kai.md §3.1:
  ///   anxious / thinking → заменено другой анимацией (дыхание 0)
  ///   harsh              → 0.01 (половина: напряжённое)
  ///   всё остальное      → 0.02 (±2%)
  double get _breathAmplitude {
    if (widget.emotion == KaiEmotion.anxious) return 0;
    if (widget.emotion == KaiEmotion.thinking) return 0;
    if (widget.isHarsh) return 0.01;
    return 0.02;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Цвет глаз: accent темы, при harsh → secondary (ember)
    final eyeColor = widget.isHarsh
        ? colorScheme.secondary
        : colorScheme.primary;
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
            _blinkAnim,
            _lookAnim,
            _thinkPulseAnim,
          ]),
          builder: (context, _) {
            // При reduce-motion: статичный нейтральный рендер
            if (reduce) {
              return CustomPaint(
                painter: _KaiPainter(
                  state: _stateFor(widget.emotion, widget.isHarsh),
                  eyeColor: eyeColor,
                  bodyColor: bodyColor,
                  borderColor: borderColor,
                  breathValue: 0,
                  jitterOffset: 0,
                  blinkT: 0,
                  microShiftX: 0,
                  thinkPulseValue: 0,
                ),
              );
            }

            final morphT = _morphAnim.value;
            final interpolated = _lerpState(_from, _to, morphT);

            // Дыхание (idle).
            final breathScale = 1.0 +
                (_breathAnim.value - 0.5) * (_breathAmplitude * 2);

            // Thinking-pulse: добавляет видимое вертикальное «дыхание» во время
            // обработки ИИ — усиленная пульсация scaleY (±4%) + opacity мерцание.
            final thinkPulse = _thinkPulseAnim.value;

            final jitter = _jitterAnim.value * 1.5; // px

            // Micro-look: тихое горизонтальное смещение (±1.5 px при size=56)
            // Не для anxious/thinking — там другие акценты
            final doMicroLook = widget.emotion != KaiEmotion.anxious;
            final microShiftX = doMicroLook
                ? _lookAnim.value * (widget.size * 0.027)
                : 0.0;

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
                    blinkT: _blinkAnim.value,
                    microShiftX: microShiftX,
                    thinkPulseValue: thinkPulse,
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

/// Чистая эмоциональная база — без учёта isHarsh.
/// Все шесть выражений по MASCOT.md §5.
_KaiState _emotionBase(KaiEmotion emotion) {
  // Базовая асимметрия: левый глаз на ~1.5 условных единицы выше правого.
  const leftBaseY = -1.5;
  const rightBaseY = 0.0;

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
        leftEyeOffsetY: leftBaseY - 1.5,
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
        leftEyeOffsetY: leftBaseY + 1.5,
        rightEyeOffsetY: rightBaseY + 1.5,
        showBrow: 0,
        opacity: 0.75,         // тускнее
      );
  }
}

/// Итоговое состояние: emotion-база + harsh-оверлей (04-kai.md §3.2).
_KaiState _stateFor(KaiEmotion emotion, bool isHarsh) {
  final base = _emotionBase(emotion);
  if (!isHarsh) return base;

  return _KaiState(
    cornerRadius: (base.cornerRadius - 0.08).clamp(0.40, 0.90),
    scaleY: base.scaleY + 0.04,
    leftEyeHeight: base.leftEyeHeight * 0.55,
    rightEyeHeight: base.rightEyeHeight * 0.55,
    leftEyeArch: base.leftEyeArch * 0.3,
    rightEyeArch: base.rightEyeArch * 0.3,
    leftEyeOffsetY: base.leftEyeOffsetY,
    rightEyeOffsetY: base.rightEyeOffsetY,
    showBrow: 1.0,
    opacity: base.opacity,
  );
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
    required this.blinkT,
    required this.microShiftX,
    required this.thinkPulseValue,
  });

  final _KaiState state;
  final Color eyeColor;
  final Color bodyColor;
  final Color borderColor;
  final double breathValue;    // 0..1, для pulse-эффектов
  final double jitterOffset;   // дёргание через Transform в виджете
  final double blinkT;         // 0 = открыты, 1 = закрыты (моргание)
  final double microShiftX;    // горизонтальный дрейф глаз (px)
  final double thinkPulseValue; // 0..1 — пульс при thinking

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    _drawBody(canvas, cx, cy, w, h);
    _drawEyes(canvas, cx, cy, w, h);

    if (state.showBrow > 0.01) {
      _drawBrows(canvas, cx, cy, w, h);
    }
  }

  /// Тело: squircle.
  /// При thinking: thinkPulseValue добавляет пульсацию scaleY (±4%) +
  /// слабое мерцание opacity (±8%) — делает Kai видимо «работающим».
  void _drawBody(Canvas canvas, double cx, double cy, double w, double h) {
    // Thinking-pulse: вертикальная пульсация формы
    final thinkScaleY = thinkPulseValue > 0
        ? state.scaleY + (thinkPulseValue - 0.5) * 0.08 // ±4%
        : state.scaleY;
    // Thinking-pulse: лёгкая пульсация прозрачности borderColor
    final thinkOpacityMod = thinkPulseValue > 0
        ? 1.0 + (thinkPulseValue - 0.5) * 0.16 // ±8% opacity
        : 1.0;

    final bodyH = h * thinkScaleY;
    final bodyW = w;

    final minSide = math.min(bodyW, bodyH);
    final r = minSide * (0.30 + state.cornerRadius * 0.20);

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

    final borderPaint = Paint()
      ..color = borderColor.withValues(
          alpha: (state.opacity * 0.8 * thinkOpacityMod).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(rrect, borderPaint);
  }

  /// Глаза с учётом моргания (blinkT) и micro-look (microShiftX).
  void _drawEyes(Canvas canvas, double cx, double cy, double w, double h) {
    final eyeW = w * 0.20;
    final eyeBaseH = h * 0.06;
    final eyeGap = w * 0.14;

    final eyeCenterY = cy + (h * 0.04);
    final unitPx = h * 0.025;

    // Micro-look: горизонтальный сдвиг обоих глаз вместе (взгляд влево/вправо)
    final leftCx = cx - eyeGap + microShiftX;
    final rightCx = cx + eyeGap + microShiftX;

    final leftCy = eyeCenterY + state.leftEyeOffsetY * unitPx;
    final rightCy = eyeCenterY + state.rightEyeOffsetY * unitPx;

    // Высота глаза: blinkT сплющивает до минимума (3% = почти-нитка)
    // Для away глаза уже почти нитки — blink их не меняет заметно
    final leftHBase = eyeBaseH * state.leftEyeHeight.clamp(0.04, 1.0) / 0.28;
    final rightHBase = eyeBaseH * state.rightEyeHeight.clamp(0.04, 1.0) / 0.28;

    // blinkT=1: высота → minH (1.0 px), blinkT=0: нормальная высота
    const minBlinkH = 1.0;
    final leftH = leftHBase + (minBlinkH - leftHBase) * blinkT;
    final rightH = rightHBase + (minBlinkH - rightHBase) * blinkT;

    // При moргании арки тоже немного поджимаются
    final archFade = 1.0 - blinkT * 0.8;

    final eyePaint = Paint()
      ..color = eyeColor.withValues(alpha: state.opacity)
      ..style = PaintingStyle.fill;

    _drawEye(
      canvas,
      cx: leftCx,
      cy: leftCy,
      eyeW: eyeW,
      eyeH: leftH,
      arch: state.leftEyeArch * archFade,
      paint: eyePaint,
    );
    _drawEye(
      canvas,
      cx: rightCx,
      cy: rightCy,
      eyeW: eyeW,
      eyeH: rightH,
      arch: state.rightEyeArch * archFade,
      paint: eyePaint,
    );
  }

  /// Один глаз: rounded-rect при arch==0, арка Безье при arch!=0.
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

    final x0 = cx - eyeW / 2;
    final x1 = cx + eyeW / 2;
    final archDy = eyeW * arch * 0.6;

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

  /// Брови: тонкие штрихи выше глаз (MASCOT.md §4: жёсткий тон).
  void _drawBrows(Canvas canvas, double cx, double cy, double w, double h) {
    final eyeGap = w * 0.14;
    final eyeBaseH = h * 0.06;
    final eyeCenterY = cy + (h * 0.04);
    final unitPx = h * 0.025;

    final leftCy = eyeCenterY + state.leftEyeOffsetY * unitPx;
    final rightCy = eyeCenterY + state.rightEyeOffsetY * unitPx;

    final browOffsetY = eyeBaseH * 1.8;
    final browW = w * 0.16;

    final browPaint = Paint()
      ..color = eyeColor.withValues(alpha: state.opacity * state.showBrow * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(h * 0.018, 1.0)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - eyeGap - browW / 2, leftCy - browOffsetY + h * 0.015),
      Offset(cx - eyeGap + browW / 2, leftCy - browOffsetY - h * 0.015),
      browPaint,
    );
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
        old.breathValue != breathValue ||
        old.blinkT != blinkT ||
        old.microShiftX != microShiftX ||
        old.thinkPulseValue != thinkPulseValue;
  }
}
