// Экран дыхательных упражнений (SPEC C5 Ф2 «дыхание/медитации»).
// Гид-таймер без аудио/видео и без сохранения сессий в БД.
// Анимация круга следует ANIMATIONS.md §0: effectiveDuration + reduceMotionOf.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import 'breathing_engine.dart';

// Доступные длительности сессии
const _sessionDurations = [
  (label: '1 min',  minutes: 1),
  (label: '3 min',  minutes: 3),
  (label: '5 min',  minutes: 5),
];

/// Длительность fade-анимации подписи фазы.
const _kFadeDuration = Duration(milliseconds: 150);

/// Длительность анимации смены цвета круга.
const _kColorDuration = Duration(milliseconds: 300);

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with TickerProviderStateMixin {
  // --- Настройки ---
  int _presetIndex = 0;
  int _durationMinutes = 3;

  // --- Состояние сессии ---
  bool _running = false;
  bool _done = false;

  /// Прошедшее время внутри сессии (обновляется тикером).
  Duration _elapsed = Duration.zero;

  /// Оставшееся время (считается от totalDuration - elapsed).
  Duration _remaining = Duration.zero;

  Timer? _ticker;

  // --- Анимация круга (масштаб) ---
  late AnimationController _circleController;
  late Animation<double> _circleScale;

  // Целевой масштаб для AnimationController: 0.6=выдох, 1.0=вдох
  double _targetScale = 0.6;

  // --- Анимация цвета круга ---
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  Color _currentCircleColor = Colors.transparent;
  Color _targetCircleColor = Colors.transparent;

  // --- Анимация fade подписи фазы ---
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // --- Текущая фаза ---
  String _lastPhaseLabel = '';

  BreathingPreset get _preset => breathingPresets[_presetIndex];
  Duration get _totalDuration => Duration(minutes: _durationMinutes);

  @override
  void initState() {
    super.initState();

    // Анимация масштаба круга
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _circleScale = Tween<double>(begin: 0.6, end: 0.6).animate(
      CurvedAnimation(parent: _circleController, curve: kCurveLift),
    );

    // Анимация цвета круга
    _colorController = AnimationController(
      vsync: this,
      duration: _kColorDuration,
    );
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));

    // Анимация fade подписи фазы
    _fadeController = AnimationController(
      vsync: this,
      duration: _kFadeDuration,
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Инициализируем цвет после получения контекста
    _currentCircleColor = Theme.of(context).colorScheme.primary;
    _targetCircleColor = _currentCircleColor;
    _colorAnimation = ColorTween(
      begin: _currentCircleColor,
      end: _targetCircleColor,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _circleController.dispose();
    _colorController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Цвет круга по метке фазы
  // Фазы имеют семантику: Inhale=accent, Exhale=success, Hold=textMuted.
  // Hex не хардкодим — берём из темы через ext/colorScheme.
  // ---------------------------------------------------------------------------

  Color _colorForPhaseLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    switch (label) {
      case 'Inhale':
        // Вдох — accent (первичное, активное состояние)
        return cs.primary;
      case 'Exhale':
        // Выдох — success (расслабление, завершение цикла)
        return ext.success;
      case 'Hold':
      default:
        // Задержка — textMuted (нейтральная пауза)
        return ext.textMuted;
    }
  }

  // ---------------------------------------------------------------------------
  // Локализация метки фазы (label из engine остаётся на EN для switch-логики)
  // ---------------------------------------------------------------------------

  String _localizePhaseLabel(BuildContext ctx, String engineLabel) {
    switch (engineLabel) {
      case 'Inhale':
        return ctx.s('breathing.inhale');
      case 'Exhale':
        return ctx.s('breathing.exhale');
      case 'Hold':
        return ctx.s('breathing.hold');
      default:
        return engineLabel;
    }
  }

  // ---------------------------------------------------------------------------
  // Запуск / остановка
  // ---------------------------------------------------------------------------

  void _start() {
    final total = _totalDuration;
    // Инициализируем цвет для начальной фазы (Inhale)
    _currentCircleColor = _colorForPhaseLabel('Inhale');
    _targetCircleColor = _currentCircleColor;
    _colorAnimation = ColorTween(
      begin: _currentCircleColor,
      end: _targetCircleColor,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));
    _colorController.value = 1.0;
    _fadeController.value = 1.0;
    _lastPhaseLabel = '';
    setState(() {
      _running = true;
      _done = false;
      _elapsed = Duration.zero;
      _remaining = total;
    });
    _arm();
  }

  void _stop() {
    _ticker?.cancel();
    _circleController.stop();
    _colorController.stop();
    setState(() {
      _running = false;
      _done = false;
      _elapsed = Duration.zero;
      _remaining = Duration.zero;
      _lastPhaseLabel = '';
    });
  }

  void _arm() {
    _ticker?.cancel();
    // Обновляем каждые 50 мс для плавной подписи; визуальную анимацию
    // ведёт AnimationController отдельно.
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_running) return;
      setState(() {
        _elapsed += const Duration(milliseconds: 50);
        final newRemaining = _totalDuration - _elapsed;
        if (newRemaining <= Duration.zero) {
          _remaining = Duration.zero;
          _running = false;
          _done = true;
          _ticker?.cancel();
          _circleController.stop();
          _colorController.stop();
          return;
        }
        _remaining = newRemaining;
        _updateCircleAnimation();
      });
    });
    _updateCircleAnimation();
  }

  // ---------------------------------------------------------------------------
  // Анимация круга
  // ---------------------------------------------------------------------------

  /// Вычисляет целевой масштаб и цвет круга и, при смене фазы, запускает анимации.
  void _updateCircleAnimation() {
    if (!mounted) return;
    // reduceMotion: при включённом режиме — не анимируем масштаб
    final reduce = reduceMotionOf(context);

    final result = phaseAt(_preset.phases, _elapsed);
    final phase = result.phase;

    if (phase.label != _lastPhaseLabel) {
      // Новая фаза — запускаем fade-анимацию текста
      _triggerPhaseFade(phase.label, reduce);

      // Плавная смена цвета
      _animateColorToPhase(phase.label, reduce);

      if (!reduce) {
        // Анимация масштаба (только без reduce motion)
        if (!phase.hold) {
          final phaseDuration = phase.duration;
          _circleController.duration = phaseDuration;

          final from = _targetScale;
          _targetScale = phase.expand ? 1.0 : 0.6;

          _circleScale = Tween<double>(begin: from, end: _targetScale).animate(
            CurvedAnimation(parent: _circleController, curve: kCurveLift),
          );
          _circleController.forward(from: 0.0);
        } else {
          _circleController.stop();
        }
      }

      _lastPhaseLabel = phase.label;
    }
  }

  /// Fade-out → смена метки → fade-in текста фазы.
  Future<void> _triggerPhaseFade(String newLabel, bool reduce) async {
    if (reduce || !mounted) return;
    await _fadeController.reverse();
    // setState не нужен — _lastPhaseLabel меняется в вызывающем методе
    if (mounted) _fadeController.forward();
  }

  /// Плавная анимация смены цвета круга.
  void _animateColorToPhase(String phaseLabel, bool reduce) {
    if (!mounted) return;
    final newColor = _colorForPhaseLabel(phaseLabel);
    final fromColor = _colorAnimation.value ?? _currentCircleColor;
    _currentCircleColor = fromColor;
    _targetCircleColor = newColor;

    _colorController.stop();
    _colorAnimation = ColorTween(
      begin: fromColor,
      end: newColor,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));

    if (reduce) {
      _colorController.value = 1.0;
    } else {
      _colorController.forward(from: 0.0);
    }
  }

  // ---------------------------------------------------------------------------
  // Форматирование времени mm:ss
  // ---------------------------------------------------------------------------

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------------------------------------------------------------------------
  // Обратный счётчик секунд фазы
  // ---------------------------------------------------------------------------

  /// Оставшиеся секунды в текущей фазе (1, 2, 3 ... N).
  int _phaseSecondsLeft(BreathPhase phase, double phaseProgress) {
    final totalSecs = phase.duration.inSeconds;
    final elapsed = (phaseProgress * totalSecs).floor();
    final left = totalSecs - elapsed;
    return left.clamp(1, totalSecs);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('breathing.title'))),
      body: SafeArea(
        child: Padding(
          // 24dp screen margin — spec §4.1
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _done
              ? _buildDone(textTheme)
              : _running
                  ? _buildRunning(textTheme)
                  : _buildIdle(textTheme),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран выбора пресета и длительности
  // ---------------------------------------------------------------------------

  Widget _buildIdle(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // headlineSmall — display font (серифный), заголовок секции
        Text(context.s('breathing.choose_technique'), style: textTheme.headlineSmall),
        const SizedBox(height: 24),

        // Выбор пресета — ChoiceChip ряд
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(breathingPresets.length, (i) {
            return ChoiceChip(
              label: Text(breathingPresets[i].name),
              selected: _presetIndex == i,
              onSelected: (_) => setState(() => _presetIndex = i),
            );
          }),
        ),
        const SizedBox(height: 32),

        Text(context.s('breathing.duration'), style: textTheme.titleMedium),
        const SizedBox(height: 12),

        // Выбор длительности — SegmentedButton
        SegmentedButton<int>(
          segments: _sessionDurations
              .map((d) => ButtonSegment<int>(
                    value: d.minutes,
                    label: Text(d.label),
                  ))
              .toList(),
          selected: {_durationMinutes},
          onSelectionChanged: (s) =>
              setState(() => _durationMinutes = s.first),
          showSelectedIcon: false,
        ),
        const Spacer(),

        // Единственное первичное действие — FilledButton (Start)
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(context.s('breathing.start')),
          onPressed: _start,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Экран активной сессии
  // ---------------------------------------------------------------------------

  Widget _buildRunning(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final reduce = reduceMotionOf(context);

    final result = phaseAt(_preset.phases, _elapsed);
    final phase = result.phase;
    final secsLeft = _phaseSecondsLeft(phase, result.phaseProgress);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Круг — центральный элемент с текстом фазы и счётчиком внутри
        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_circleController, _colorController, _fadeController]),
            builder: (context, _) {
              final scale = reduce ? 0.8 : _circleScale.value;
              final circleColor = _colorAnimation.value ?? colorScheme.primary;
              return _BreathCircle(
                scale: scale,
                color: circleColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Подпись фазы: displaySmall — крупный, display font (серифный)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        _localizePhaseLabel(context, phase.label),
                        style: textTheme.displaySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Счётчик секунд — titleLarge, приглушённый
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        '$secsLeft',
                        style: textTheme.titleLarge?.copyWith(
                          color: ext.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),

        // Оставшееся время сессии — крупный display-таймер
        Center(
          child: Text(
            _formatDuration(_remaining),
            style: textTheme.headlineMedium?.copyWith(
              color: ext.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 56),

        // Вторичное действие — OutlinedButton (не перетягивает акцент у круга)
        OutlinedButton.icon(
          icon: const Icon(Icons.stop),
          label: Text(context.s('breathing.stop')),
          onPressed: _stop,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Экран завершения сессии
  // ---------------------------------------------------------------------------

  Widget _buildDone(TextTheme textTheme) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Иконка завершения — success (а не accent, per spec §1 ACCENT DISCIPLINE)
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: ext.success,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '${context.s('breathing.session_complete')} · ${plMinutes(context, _durationMinutes)}',
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 56),
        // Единственное первичное действие — FilledButton
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.done')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Виджет круга
// ---------------------------------------------------------------------------

/// Гид дыхания: большое ФИКСИРОВАННОЕ внешнее кольцо (цель) + внутренний
/// заполненный круг, который растёт к кольцу на вдохе и сжимается на выдохе.
///
/// [scale] — значение контроллера фазы в диапазоне 0.6 (выдох) … 1.0 (вдох).
/// Оно НЕ масштабирует весь виджет, а задаёт диаметр внутреннего круга:
/// 0.6 → ~0.30 базового размера, 1.0 → ~0.92 (почти заполняет кольцо).
/// Внешнее кольцо всегда базового размера 220×220 — статичный ориентир.
/// [child] — контент по центру (подпись фазы + счётчик), НЕ масштабируется.
class _BreathCircle extends StatelessWidget {
  const _BreathCircle({
    required this.scale,
    required this.color,
    this.child,
  });

  final double scale;
  final Color color;
  final Widget? child;

  static const _baseSize = 220.0;

  // Диапазон диаметра внутреннего круга как доли от _baseSize.
  static const _minInnerFraction = 0.30; // выдох (scale = 0.6)
  static const _maxInnerFraction = 0.92; // вдох  (scale = 1.0)

  @override
  Widget build(BuildContext context) {
    // Маппинг 0.6..1.0 → 0.30..0.92, с защитой от выхода за границы.
    final t = ((scale - 0.6) / 0.4).clamp(0.0, 1.0);
    final innerFraction =
        _minInnerFraction + t * (_maxInnerFraction - _minInnerFraction);
    final innerSize = _baseSize * innerFraction;

    return SizedBox(
      width: _baseSize,
      height: _baseSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Внешнее кольцо — фиксированный ориентир (контур, не масштабируется).
          Container(
            width: _baseSize,
            height: _baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
          ),
          // Внутренний заполненный круг — растёт/сжимается по фазе.
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.20),
            ),
          ),
          // Текст по центру — полный размер, поверх круга, без масштабирования.
          ?child,
        ],
      ),
    );
  }
}
