// Маскот «Kai» — pure-Flutter реализация через CustomPainter.
// Источник истины: /docs/MASCOT.md (ADR-032).
// Rive не используется; все анимации на AnimationController.
//
// Пять выражений (KaiEmotion):
//   neutral  — тире-глаза, ровный squircle. База.
//   success  — арки глаз вверх (^ ^), форма пружинит к кругу.
//   thinking — один глаз прищурен, форма вытянута вертикально, лёгкая пульсация.
//   anxious  — глаза чуть крупнее, форма сжата/дёрганая.
//   away     — глаза-«нитки» (почти закрыты), форма немного осевшая.
//
// Жёсткость (isHarsh) — отдельный флаг-оверлей: узкие глаза + брови + резкие углы.
// Это МАНЕРА (тон), не эмоция; компонуется поверх любой из пяти эмоций.
//
// v2 (2026-06): добавлен моргания (blink) + micro-look (горизонтальный дрейф взгляда)
// для читаемой «живости» на idle, усиленный pulse для thinking.
// v3 (2026-06): интерактивный тап — баунс/wiggle + речевой пузырь с rotate-строками.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import 'kai_speech_bubble.dart';

// ---------------------------------------------------------------------------
// Enum выражений
// ---------------------------------------------------------------------------

/// Пять выражений Kai из MASCOT.md §5.
/// Жёсткость (строгость) — не эмоция; передаётся флагом [KaiMascot.isHarsh].
enum KaiEmotion {
  neutral,
  success,
  thinking,
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

// Количество ротируемых реплик при тапе (kai.tap_quip_0 .. kai.tap_quip_N-1).
const int _kTapQuipCount = 5;

class _KaiMascotState extends State<KaiMascot>
    with TickerProviderStateMixin {
  // --- Tap → neutral ---
  // По тапу Kai ненадолго «успокаивается» к нейтральному выражению
  // (override поверх widget.emotion), затем возвращается к исходной эмоции.
  // _tapNeutralToken — маркер последнего тапа, чтобы отложенный сброс
  // не сработал, если за это время был ещё один тап.
  bool _tapNeutral = false;
  Object? _tapNeutralToken;
  // Длительность «нейтральной паузы» по тапу — нормальная анимация (280мс)
  // даёт время морфингу доехать до neutral, затем ещё короткая задержка.
  static const Duration _tapNeutralHold = Duration(milliseconds: 1200);

  // --- Tap-реакция v3: баунс + речевой пузырь ---
  // _tapCount — монотонный счётчик нажатий; индекс реплики = tapCount % N.
  int _tapCount = 0;
  bool _showBubble = false;
  Timer? _bubbleTimer; // таймер авто-скрытия пузыря, отменяется в dispose

  // Баунс: TweenSequence scale 1→1.15→0.92→1 за kDurationNormal (280мс).
  // Wiggle на пике: дополнительный легкий поворот (±6°) — rotateZ через Transform.
  late final AnimationController _bounceCtrl;
  late Animation<double> _bounceScaleAnim;
  late Animation<double> _bounceRotateAnim; // рад, маленькое значение

  // Длительность авто-скрытия пузыря (мс).
  static const int _kBubbleHoldMs = 2000;

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

    // Баунс-анимация при тапе: kDurationNormal (280мс), упругая.
    // Scale: 1.0 → 1.15 → 0.92 → 1.0 (TweenSequence)
    // Rotate: 0 → +0.10 → -0.10 → 0 рад (~±6°)
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

  /// Эффективная эмоция: пока активен tap-override — neutral, иначе widget.emotion.
  KaiEmotion get _effectiveEmotion =>
      _tapNeutral ? KaiEmotion.neutral : widget.emotion;

  /// Запускает морфинг к текущей [_effectiveEmotion] от текущего кадра.
  /// Используется и при смене widget.emotion, и при tap-override.
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

  /// Обработчик тапа: успокаиваем Kai к neutral на короткое время, затем
  /// возвращаемся к исходной эмоции. Внешний widget.onTap вызывается всегда.
  /// При reduce-motion морфинг не нужен — только показываем пузырь статично.
  void _handleTap() {
    widget.onTap?.call();

    final reduce = reduceMotionOf(context);

    // Увеличиваем счётчик тапов и показываем пузырь (всегда, независимо от motion).
    setState(() {
      _tapCount++;
      _showBubble = true;
    });

    // Баунс-анимация только при motion разрешён.
    if (!reduce) {
      _bounceCtrl
        ..reset()
        ..forward();
    }

    // Авто-скрытие пузыря: отменяем предыдущий таймер и запускаем новый.
    // Используем Timer (не Future.delayed), чтобы cancel() в dispose() предотвращал
    // pending-timer в тестах.
    // При reduce-motion пузырь не скрываем автоматически — пользователь сам тапнет снова
    // (нет анимации = нет таймеров; иначе тест жалуется на pending timer).
    if (!reduce) {
      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(Duration(milliseconds: _kBubbleHoldMs), () {
        if (!mounted) return;
        setState(() => _showBubble = false);
      });
    }

    if (reduce) return;

    // Морфинг к neutral (существующий механизм).
    final token = Object();
    _tapNeutralToken = token;
    if (!_tapNeutral) {
      setState(() => _tapNeutral = true);
      _morphToEffective();
      _startLoops();
    }

    Future.delayed(_tapNeutralHold, () {
      if (!mounted) return;
      if (_tapNeutralToken != token) return; // был ещё один тап позже
      setState(() => _tapNeutral = false);
      _morphToEffective();
      _startLoops();
    });
  }

  @override
  void didUpdateWidget(KaiMascot old) {
    super.didUpdateWidget(old);

    if (old.emotion != widget.emotion || old.isHarsh != widget.isHarsh) {
      // Смена входной эмоции снимает tap-override (приоритет у нового состояния).
      _tapNeutral = false;
      _tapNeutralToken = null;
      _morphToEffective();
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
    if (_effectiveEmotion == KaiEmotion.anxious) {
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
    if (_effectiveEmotion == KaiEmotion.thinking) {
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
    _bubbleTimer?.cancel();
    _breathCtrl.dispose();
    _morphCtrl.dispose();
    _jitterCtrl.dispose();
    _blinkCtrl.dispose();
    _lookCtrl.dispose();
    _thinkPulseCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  /// Амплитуда дыхания по 04-kai.md §3.1:
  ///   anxious / thinking → заменено другой анимацией (дыхание 0)
  ///   isHarsh=true       → 0.01 (половина: напряжённое дыхание тона)
  ///   всё остальное      → 0.02 (±2%)
  double get _breathAmplitude {
    if (_effectiveEmotion == KaiEmotion.anxious) return 0;
    if (_effectiveEmotion == KaiEmotion.thinking) return 0;
    if (widget.isHarsh) return 0.01;
    return 0.02;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Цвет глаз: оранжевый (secondary/ember) только для тревоги — эмоция.
    // Тон (isHarsh) влияет на ФОРМУ (узкие глаза, брови), но НЕ на цвет.
    final eyeColor = widget.emotion == KaiEmotion.anxious
        ? colorScheme.secondary
        : colorScheme.primary;
    final bodyColor = colorScheme.onSurface.withAlpha(28);
    final borderColor = colorScheme.onSurface.withAlpha(18);

    // Реплика при тапе: ротация по счётчику (не RNG — детерминированно, воспроизводимо).
    // _tapCount уже инкрементирован в _handleTap перед показом пузыря.
    final quipIndex = (_tapCount - 1).clamp(0, _kTapQuipCount - 1) % _kTapQuipCount;
    final quipText = context.s('kai.tap_quip_$quipIndex');

    // Пузырь: всплывает ПОВЕРХ (через Stack + Positioned), не занимает layout-место.
    // AnimatedSwitcher даёт плавный fade при появлении/скрытии.
    // Bubble позиционируется выше Kai через Positioned с отрицательным top —
    // Stack имеет clipBehavior: Clip.none, поэтому пузырь рисуется вне bounds.
    final bubbleWidget = Positioned(
      // Располагаем пузырь непосредственно над Kai: bottom = widget.size + 4 отступ.
      bottom: widget.size + 4,
      // Горизонтально центрируем относительно Kai через left=0/right=0.
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

    // Сам Kai с bounce + существующими анимациями.
    // Размещается в Stack на позиции (0,0) — занимает весь SizedBox.
    // OverflowBox позволяет Transform.scale выходить за границы SizedBox при баунсе,
    // иначе tight SizedBox обрезал бы scale > 1.0 и баунс оставался невидимым.
    final kaiWidget = AnimatedBuilder(
      animation: Listenable.merge([
        _breathAnim,
        _morphAnim,
        _jitterAnim,
        _blinkAnim,
        _lookAnim,
        _thinkPulseAnim,
        _bounceCtrl,
      ]),
      builder: (context, _) {
        // При reduce-motion: статичный нейтральный рендер без трансформов.
        if (reduce) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _KaiPainter(
              state: _stateFor(_effectiveEmotion, widget.isHarsh),
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
        final doMicroLook = _effectiveEmotion != KaiEmotion.anxious;
        final microShiftX = doMicroLook
            ? _lookAnim.value * (widget.size * 0.027)
            : 0.0;

        // Баунс при тапе: scale + rotate поверх дыхания.
        final bounceScale = _bounceScaleAnim.value;
        final bounceRotate = _bounceRotateAnim.value;

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
          ),
        );
      },
    );

    // Корневой виджет: SizedBox фиксирует footprint (widget.size × widget.size).
    // Stack(clipBehavior: Clip.none) позволяет:
    //   • пузырю рисоваться выше через Positioned(bottom: size+4) без layout-сдвига;
    //   • bounce Transform.scale > 1 немного выходить за bounds (видимый баунс).
    return GestureDetector(
      // По тапу Kai успокаивается к neutral и показывает пузырь.
      // Внешний onTap вызывается всегда.
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Kai занимает всю площадь SizedBox.
            Positioned.fill(child: kaiWidget),
            // Пузырь плавает над Kai без влияния на layout.
            bubbleWidget,
          ],
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
