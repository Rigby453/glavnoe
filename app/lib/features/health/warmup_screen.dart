// Экран «Зарядка / растяжка» — список готовых комплексов + гайдед-плеер.
//
// Образец — posture_screen.dart (список) и meditation_screen.dart (поэтапный
// плеер с таймером). Отличие от медитаций: шаги бывают двух видов —
// по времени (обратный отсчёт + пауза) и по повторам (счётчик, ручное «дальше»).
//
// БЕЗ стрика/геймификации и БЕЗ записи в БД: «сделал» — эфемерный факт
// (экран завершения). Контент берётся из warmup_routines.dart (только l10n-ключи).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import 'warmup_routines.dart';

// ---------------------------------------------------------------------------
// Список комплексов
// ---------------------------------------------------------------------------

class WarmupScreen extends StatelessWidget {
  const WarmupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('warmup.title'))),
      body: ListView(
        // 24dp screen margin — spec §4.1
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        children: [
          for (final routine in kWarmupRoutines) ...[
            _RoutineCard(routine: routine, ext: ext, textTheme: textTheme),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.ext,
    required this.textTheme,
  });

  final WarmupRoutine routine;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _WarmupPlayerScreen(routine: routine),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Аватар — нейтральный (accentMuted фон, textMuted иконка).
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ext.accentMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(routine.icon, color: ext.textMuted, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.s(routine.nameKey),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.s(routine.descKey),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    // Мета: число упражнений + примерное время.
                    Text(
                      '${plExercises(context, routine.steps.length)} · ~${plMinutes(context, routine.approxMinutes)}',
                      style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ext.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Гайдед-плеер
// ---------------------------------------------------------------------------

class _WarmupPlayerScreen extends StatefulWidget {
  const _WarmupPlayerScreen({required this.routine});

  final WarmupRoutine routine;

  @override
  State<_WarmupPlayerScreen> createState() => _WarmupPlayerScreenState();
}

class _WarmupPlayerScreenState extends State<_WarmupPlayerScreen> {
  int _stepIndex = 0;
  int _remaining = 0; // секунды (для шагов-таймеров)
  bool _paused = false;
  Timer? _timer;

  // Первый шаг стартуем в didChangeDependencies (а НЕ в initState): нужен
  // доступ к контексту/MediaQuery без ассертов InheritedWidget.
  bool _started = false;

  List<WarmupStep> get _steps => widget.routine.steps;
  WarmupStep get _currentStep => _steps[_stepIndex];
  bool get _isLastStep => _stepIndex >= _steps.length - 1;
  WarmupStep? get _nextStep => _isLastStep ? null : _steps[_stepIndex + 1];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startStep(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStep(int index) {
    _timer?.cancel();
    _paused = false;
    final step = _steps[index];
    _remaining = step.seconds ?? 0;

    // Шаг по повторам — без таймера (ручное «дальше»).
    if (step.isReps) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_paused) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _onStepDone();
      }
    });
  }

  void _onStepDone() {
    if (_isLastStep) {
      _showCompletionDialog();
    } else {
      _advance();
    }
  }

  void _advance() {
    setState(() => _stepIndex++);
    _startStep(_stepIndex);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  void _showCompletionDialog() {
    _timer?.cancel();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final ext =
            Theme.of(dialogContext).extension<FocusThemeExtension>()!;
        final textTheme = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          // Иконка завершения — success (не accent, per ACCENT DISCIPLINE).
          icon: Icon(Icons.check_circle_outline, size: 40, color: ext.success),
          title: Text(dialogContext.s('warmup.complete_title')),
          content: Text(
            dialogContext.s('warmup.complete_body'),
            style: textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // закрыть диалог
                if (mounted) Navigator.of(context).pop(); // вернуться к списку
              },
              child: Text(dialogContext.s('btn.done')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final step = _currentStep;
    final stepCount = _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s(widget.routine.nameKey)),
        centerTitle: true,
      ),
      body: SafeArea(
        // LayoutBuilder + SingleChildScrollView: контент НИКОГДА не переполняет
        // (320px / textScale 2.0). При достатке места — на всю высоту, иначе скролл.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Прогресс по упражнениям.
                      Text(
                        '${context.s('warmup.exercise')} ${_stepIndex + 1} / $stepCount',
                        style: textTheme.bodySmall
                            ?.copyWith(color: ext.textMuted),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_stepIndex + 1) / stepCount,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 32),

                      // Круг: таймер (обратный отсчёт) либо счётчик повторов.
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: step.isReps
                            ? _RepsCircle(
                                reps: step.reps!,
                                icon: step.icon,
                                color: colorScheme.primary,
                                trackColor: ext.border,
                                textTheme: textTheme,
                              )
                            : _TimerCircle(
                                remaining: _remaining,
                                total: step.seconds!,
                                color: colorScheme.primary,
                                trackColor: ext.border,
                                textTheme: textTheme,
                              ),
                      ),
                      const SizedBox(height: 32),

                      // Название упражнения.
                      Text(
                        context.s(step.nameKey),
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Описание — Flexible, переносится, не переполняет.
                      Flexible(
                        child: Center(
                          child: Text(
                            context.s(step.descKey),
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Превью следующего упражнения.
                      if (_nextStep != null)
                        Text(
                          '${context.s('warmup.next_up')}: ${context.s(_nextStep!.nameKey)}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: ext.textFaint),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),

                      // Пауза/продолжить — только для шагов-таймеров.
                      if (!step.isReps)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(
                              _paused ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text(
                              _paused
                                  ? context.s('warmup.resume')
                                  : context.s('warmup.pause'),
                            ),
                            onPressed: _togglePause,
                          ),
                        ),
                      if (!step.isReps) const SizedBox(height: 8),

                      // Первичное действие — следующий шаг / завершить.
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _onStepDone,
                          child: Text(
                            _isLastStep
                                ? context.s('warmup.finish')
                                : context.s('warmup.next'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Вторичное действие — выйти из рутины.
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.s('warmup.end')),
                      ),
                    ],
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
// Круги (таймер / повторы)
// ---------------------------------------------------------------------------

/// Круг с обратным отсчётом: дуга уменьшается по мере хода времени.
class _TimerCircle extends StatelessWidget {
  const _TimerCircle({
    required this.remaining,
    required this.total,
    required this.color,
    required this.trackColor,
    required this.textTheme,
  });

  final int remaining;
  final int total;
  final Color color;
  final Color trackColor;
  final TextTheme textTheme;

  String get _label {
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${remaining}s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    return CustomPaint(
      painter: _ArcPainter(
        progress: progress,
        color: color,
        trackColor: trackColor,
      ),
      child: Center(
        child: Text(_label, style: textTheme.displaySmall),
      ),
    );
  }
}

/// Круг для шага по повторам: иконка + «× N reps» (без таймера).
class _RepsCircle extends StatelessWidget {
  const _RepsCircle({
    required this.reps,
    required this.icon,
    required this.color,
    required this.trackColor,
    required this.textTheme,
  });

  final int reps;
  final IconData icon;
  final Color color;
  final Color trackColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Полная дуга (статичная) — шаг по повторам без отсчёта.
      painter: _ArcPainter(progress: 1, color: color, trackColor: trackColor),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              plReps(context, reps),
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Дуга прогресса (как в meditation_screen.dart).
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress; // 1.0 → полная дуга, 0.0 → пустая
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 8;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
