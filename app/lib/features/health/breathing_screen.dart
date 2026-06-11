// Экран дыхательных упражнений (SPEC C5 Ф2 «дыхание/медитации»).
// Гид-таймер без аудио/видео и без сохранения сессий в БД.
// Анимация круга следует ANIMATIONS.md §0: effectiveDuration + reduceMotionOf.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/constants.dart';
import 'breathing_engine.dart';

// Доступные длительности сессии
const _sessionDurations = [
  (label: '1 min',  minutes: 1),
  (label: '3 min',  minutes: 3),
  (label: '5 min',  minutes: 5),
];

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
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

  // --- Анимация круга ---
  late AnimationController _circleController;
  late Animation<double> _circleScale;

  // Целевой масштаб для AnimationController: 0.6=выдох, 1.0=вдох
  double _targetScale = 0.6;

  BreathingPreset get _preset => breathingPresets[_presetIndex];
  Duration get _totalDuration => Duration(minutes: _durationMinutes);

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
      vsync: this,
      // Длительность анимации масштаба = длительности фазы (будем обновлять)
      duration: const Duration(seconds: 4),
    );
    _circleScale = Tween<double>(begin: 0.6, end: 0.6).animate(
      CurvedAnimation(parent: _circleController, curve: kCurveLift),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _circleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Запуск / остановка
  // ---------------------------------------------------------------------------

  void _start() {
    final total = _totalDuration;
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
    setState(() {
      _running = false;
      _done = false;
      _elapsed = Duration.zero;
      _remaining = Duration.zero;
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

  /// Вычисляет целевой масштаб круга и, при смене фазы, запускает анимацию.
  String _lastPhaseLabel = '';

  void _updateCircleAnimation() {
    if (!mounted) return;
    // reduceMotion: при включённом режиме — не анимируем
    final reduce = reduceMotionOf(context);

    final result = phaseAt(_preset.phases, _elapsed);
    final phase = result.phase;

    if (reduce) {
      // Статичный круг — только подписи меняются, не нужно двигать controller
      return;
    }

    if (phase.label != _lastPhaseLabel) {
      // Новая фаза — запускаем анимацию к новому целевому размеру
      _lastPhaseLabel = phase.label;
      final newTarget = phase.hold
          ? _targetScale          // hold: сохраняем предыдущий масштаб
          : (phase.expand ? 1.0 : 0.6);

      if (!phase.hold) {
        final phaseDuration = phase.duration;
        _circleController.duration = phaseDuration;

        final from = _targetScale;
        _targetScale = newTarget;

        _circleScale = Tween<double>(begin: from, end: newTarget).animate(
          CurvedAnimation(parent: _circleController, curve: kCurveLift),
        );
        _circleController.forward(from: 0.0);
      }
      // hold: controller останавливается с текущим значением
      else {
        _circleController.stop();
      }
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Breathing')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
        Text('Choose a technique', style: textTheme.headlineSmall),
        const SizedBox(height: 16),

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
        const SizedBox(height: 24),

        Text('Duration', style: textTheme.titleMedium),
        const SizedBox(height: 8),

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
        ),
        const Spacer(),

        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
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
    final reduce = reduceMotionOf(context);

    final result = phaseAt(_preset.phases, _elapsed);
    final phase = result.phase;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Круг — центральный элемент
        Center(
          child: AnimatedBuilder(
            animation: _circleController,
            builder: (context, _) {
              final scale = reduce ? 0.8 : _circleScale.value;
              return _BreathCircle(
                scale: scale,
                color: colorScheme.primary,
              );
            },
          ),
        ),
        const SizedBox(height: 32),

        // Подпись фазы
        Center(
          child: Text(
            phase.label,
            style: textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),

        // Оставшееся время сессии
        Center(
          child: Text(
            _formatDuration(_remaining),
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 48),

        OutlinedButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          onPressed: _stop,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Экран завершения сессии
  // ---------------------------------------------------------------------------

  Widget _buildDone(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Session complete · $_durationMinutes min',
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Виджет круга
// ---------------------------------------------------------------------------

/// Круг, масштабируемый от 0.6 до 1.0 по фазе дыхания.
/// Размер базового квадрата 240×240, scale применяется через Transform.scale.
class _BreathCircle extends StatelessWidget {
  const _BreathCircle({required this.scale, required this.color});

  final double scale;
  final Color color;

  static const _baseSize = 220.0;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: _baseSize,
        height: _baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.25),
          border: Border.all(
            color: color.withValues(alpha: 0.7),
            width: 3,
          ),
        ),
        child: Center(
          child: Container(
            width: _baseSize * 0.5,
            height: _baseSize * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
