// Фирменный момент (ANIMATIONS.md §5): полноэкранный оверлей «День завершён».
// Срабатывает на переход "не все main-задачи закрыты" → "все закрыты".
// Триггерный механизм (_wasAllDone, false→true, addPostFrameCallback) сохранён
// без изменений — он отлажен в предыдущей версии.
//
// Структура анимации (один AnimationController, total = 2300 мс):
//   Interval 0000–0300 мс  → фон     : fade-in зелёного оверлея opacity 0→0.95
//   Interval 0200–0600 мс  → галочка : scale 0→1 (elasticOut) + path draw
//   Interval 0400–0680 мс  → заголовок: fade+slide снизу вверх 16px (easeOutCubic)
//   Interval 0300–2300 мс  → конфетти: burst (радиальная скорость + гравитация)
//   Interval 0600–0900 мс  → стрик   : TweenSequence scale 1→1.3→1
// Закрытие: отдельный _closeController (300 мс, fade-out).
// Тап в любом месте ИЛИ таймер 4 с → запуск закрытия.
// Reduce motion: все длительности → 0, конфетти пропускается, таймер 4с остаётся.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/mascot_provider.dart';
import '../../../core/settings/tone_provider.dart';
import '../../mascot/kai_mascot.dart';

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Main-задачи на сегодня (отдельный поток для слоя празднования).
final _celebrationMainItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

/// Стрик пользователя — только текущий счётчик нужен.
final _celebrationStreakProvider =
    StreamProvider.autoDispose<StreakTableData?>((ref) {
  return ref.watch(streakDaoProvider).watchStreak();
});

// ---------------------------------------------------------------------------
// Виджет
// ---------------------------------------------------------------------------

/// Полноэкранный слой поверх Today.
/// В покое: SizedBox.shrink + IgnorePointer — ничего не рисует, тапы не ловит.
/// При срабатывании: оверлей по ANIMATIONS.md §5.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key});

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay>
    with TickerProviderStateMixin {
  // --- Контроллеры ---
  // Основной: вся анимация входа, 2300 мс
  late final AnimationController _enter;
  // Закрытие: fade-out, 300 мс
  late final AnimationController _close;

  // --- Анимации входа (инициализируются в initState) ---
  late final Animation<double> _bgOpacity;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkPath;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _streakBounce;

  // --- Анимация закрытия ---
  late final Animation<double> _closeOpacity;

  // --- Конфетти ---
  final List<_BurstParticle> _particles = [];
  final Random _rnd = Random();

  // --- Состояние ---
  bool _visible = false;
  Timer? _autoCloseTimer;

  // Триггерный стейт (из предыдущей версии, отлажен)
  bool? _wasAllDone;

  // Длительность основной анимации в мс
  static const int _kTotalMs = 2300;

  // ---------------------------------------------------------------------------
  // Инициализация
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    );

    _close = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Хелпер: нормированный Interval(startMs..endMs) / _kTotalMs
    Interval iv(int startMs, int endMs, [Curve curve = Curves.linear]) =>
        Interval(startMs / _kTotalMs, endMs / _kTotalMs, curve: curve);

    // Фон: opacity 0 → 0.95 (результирующий, без множителя — умножим в build)
    _bgOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: iv(0, 300)),
    );

    // Ревью 2026-06-11: интервалы ужаты — каждый UI-переход ≤300 мс.
    // Галочка: scale 0 → 1 с пружиной elasticOut (300 мс)
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: iv(200, 500, kCurveSpring)),
    );

    // Галочка: path draw 0 → 1 (линейно внутри интервала, easeOut)
    _checkPath = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: iv(200, 500, Curves.easeOut)),
    );

    // Заголовок: opacity 0 → 1 (280 мс)
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: iv(350, 630, kCurveLift)),
    );

    // Заголовок: slide — прогресс 0 → 1 (смещение вычисляется в build: 16*(1-val))
    _titleSlide = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: iv(350, 630, kCurveLift)),
    );

    // Стрик bounce: TweenSequence scale 1→1.3→1 (300 мс)
    _streakBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
    ]).animate(
      CurvedAnimation(parent: _enter, curve: iv(500, 800)),
    );

    // Закрытие: opacity 1 → 0
    _closeOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _close, curve: kCurveLift),
    );
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _enter.dispose();
    _close.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Логика триггера
  // ---------------------------------------------------------------------------

  bool _isAllDone(List<ItemsTableData> mains) =>
      mains.isNotEmpty &&
      mains.every((i) => i.status == 'done' || i.status == 'skipped');

  void _trigger(ColorScheme scheme, bool reduce) {
    // Строим частицы burst
    _particles
      ..clear()
      ..addAll(_buildParticles(scheme));

    _close.reset();
    setState(() => _visible = true);

    if (reduce) {
      // Reduce motion: сразу конечное состояние, без конфетти
      _enter.value = 1.0;
    } else {
      _enter.forward(from: 0);
    }

    // Автозакрытие 4 с (независимо от reduce motion)
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 4), _startClose);
  }

  void _startClose() {
    _autoCloseTimer?.cancel();
    if (!mounted) return;
    _close.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() => _visible = false);
        _enter.reset();
        _close.reset();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Частицы burst-конфетти
  // ---------------------------------------------------------------------------

  List<_BurstParticle> _buildParticles(ColorScheme scheme) {
    final colors = <Color>[
      scheme.primary,
      scheme.secondary,
      const Color(0xFFFFD166),
      const Color(0xFF06D6A0),
      const Color(0xFFEF476F),
    ];
    return List.generate(48, (_) {
      return _BurstParticle(
        angle: _rnd.nextDouble() * pi * 2,
        speed: 180 + _rnd.nextDouble() * 220,
        gravity: 420 + _rnd.nextDouble() * 180,
        color: colors[_rnd.nextInt(colors.length)],
        width: 6 + _rnd.nextDouble() * 6,
        height: 8 + _rnd.nextDouble() * 8,
        rotations: 1 + _rnd.nextDouble() * 4,
        phase: _rnd.nextDouble() * pi * 2,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = reduceMotionOf(context);

    // Следим за main-задачами; ловим переход false→true.
    final mains = ref.watch(_celebrationMainItemsProvider).valueOrNull;
    if (mains != null) {
      final allDone = _isAllDone(mains);
      final prev = _wasAllDone;
      _wasAllDone = allDone;
      if (prev == false && allDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _trigger(scheme, reduce);
        });
      }
    }

    // Стрик
    final streakVal =
        ref.watch(_celebrationStreakProvider).valueOrNull?.current ?? 0;

    if (!_visible) {
      // Покой: ничего не рисуем, тапы не перехватываем.
      return const IgnorePointer(child: SizedBox.shrink());
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startClose,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _close]),
        builder: (context, _) {
          return Opacity(
            // fade-out при закрытии
            opacity: _closeOpacity.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Слой 1: зелёный фон #1D9E75 @ 95%
                Opacity(
                  opacity: (_bgOpacity.value * 0.95).clamp(0.0, 0.95),
                  child: const ColoredBox(color: Color(0xFF1D9E75)),
                ),

                // Слой 2: конфетти burst (только при включённых анимациях)
                if (!reduce && _particles.isNotEmpty)
                  LayoutBuilder(
                    builder: (_, constraints) {
                      // Вычисляем прогресс конфетти: Interval(300..2300 мс)
                      final rawT = _enter.value; // 0..1 = 0..2300 мс
                      const confettiStart = 300 / _kTotalMs;
                      final confettiT = ((rawT - confettiStart) /
                              (1.0 - confettiStart))
                          .clamp(0.0, 1.0);
                      return CustomPaint(
                        size: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        painter: _BurstPainter(
                          particles: _particles,
                          progress: confettiT,
                        ),
                      );
                    },
                  ),

                // Слой 3: центральный контент (галочка, заголовок, стрик)
                _buildContent(context, streakVal, reduce),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Центральный контент
  // ---------------------------------------------------------------------------

  Widget _buildContent(BuildContext context, int streakVal, bool reduce) {
    final textTheme = Theme.of(context).textTheme;

    final checkPathVal = reduce ? 1.0 : _checkPath.value;
    final checkScaleVal = reduce ? 1.0 : _checkScale.value;
    final titleOpacityVal = reduce ? 1.0 : _titleOpacity.value;
    final titleOffsetY = reduce ? 0.0 : 16.0 * (1.0 - _titleSlide.value);
    final streakBounceVal = reduce ? 1.0 : _streakBounce.value;

    // Kai — показываем при showKai == true (MASCOT.md §6: ambient, не блокирует).
    final showKai = ref.read(showKaiProvider);
    final isHarsh = ref.read(toneProvider) == AppTone.harsh;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kai в режиме «success» (gentle) или нейтральный (harsh — сдержанный кивок,
          // MASCOT.md §6: при harsh нет сальто/кружка, только тихий выход).
          // Размер 96dp — увеличен для prominence в celebration-оверлее.
          if (showKai) ...[
            Opacity(
              opacity: checkScaleVal.clamp(0.0, 1.0),
              child: Transform.scale(
                // Harsh: нет spring-scale-эффекта — Kai появляется просто fade-in
                scale: isHarsh ? 1.0 : (0.6 + checkScaleVal * 0.4).clamp(0.0, 1.0),
                child: KaiMascot(
                  size: 96,
                  // Harsh: нейтральная эмоция (сдержанный «кивок», не радость)
                  emotion: isHarsh ? KaiEmotion.neutral : KaiEmotion.success,
                  isHarsh: isHarsh,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Большая галочка ~96px, scale с пружиной
          Transform.scale(
            scale: checkScaleVal,
            child: SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _LargeCheckPainter(progress: checkPathVal),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Заголовок + подзаголовок: fade + slide снизу вверх
          Opacity(
            opacity: titleOpacityVal,
            child: Transform.translate(
              offset: Offset(0, titleOffsetY),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.s('today.day_complete'),
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.s('today.day_complete_sub'),
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Стрик: появляется вместе с заголовком, через 600 мс — bounce
          Opacity(
            opacity: titleOpacityVal,
            child: Transform.translate(
              offset: Offset(0, titleOffsetY),
              child: Transform.scale(
                scale: streakBounceVal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$streakVal',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Большая галочка (96px, штрих белый/почти белый)
// Подход идентичен animated_check.dart: PathMetric + extractPath по прогрессу.
// ---------------------------------------------------------------------------

class _LargeCheckPainter extends CustomPainter {
  const _LargeCheckPainter({required this.progress});

  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Полупрозрачный круг-подложка
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.18 * progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Тонкий белый обод
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.55 * progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 1.5, rimPaint);

    // Галочка через PathMetric (рисуется от 0 до progress * length)
    final path = _buildPath(size);
    final metric = path.computeMetrics().first;
    final extracted = metric.extractPath(0, metric.length * progress);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extracted, checkPaint);
  }

  Path _buildPath(Size size) {
    final p = Path();
    p.moveTo(size.width * 0.20, size.height * 0.52);
    p.lineTo(size.width * 0.42, size.height * 0.72);
    p.lineTo(size.width * 0.80, size.height * 0.28);
    return p;
  }

  @override
  bool shouldRepaint(_LargeCheckPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Burst-конфетти: радиальная скорость + гравитация вниз + вращение + затухание
// ---------------------------------------------------------------------------

class _BurstParticle {
  const _BurstParticle({
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.color,
    required this.width,
    required this.height,
    required this.rotations,
    required this.phase,
  });

  final double angle;     // направление полёта (радианы)
  final double speed;     // начальная скорость (px / ед. прогресса конфетти)
  final double gravity;   // ускорение вниз (px / ед. прогресса²)
  final Color color;
  final double width;
  final double height;
  final double rotations; // оборотов за всю анимацию
  final double phase;     // начальный угол поворота
}

/// Рисует burst-конфетти из центра экрана.
/// [progress] — нормированный 0..1 по Interval(300..2300 мс).
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.particles, required this.progress});

  final List<_BurstParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    // Масштаб под экран (нормировано на 400 px = условный базовый размер)
    final s = size.shortestSide / 400;

    final paint = Paint()..style = PaintingStyle.fill;
    final t = progress;

    for (final p in particles) {
      // Физика: x = cos(a)*v*t, y = sin(a)*v*t + 0.5*g*t²
      final x = cx + p.speed * s * cos(p.angle) * t;
      final y = cy + p.speed * s * sin(p.angle) * t + 0.5 * p.gravity * s * t * t;

      // Затухание: последние 25% прогресса → opacity 1→0
      final opacity = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + t * p.rotations * pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.particles != particles;
}
