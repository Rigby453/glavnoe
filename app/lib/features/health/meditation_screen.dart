// Экран медитаций — 5 текстовых сессий с обратным отсчётом.
// Без аудио и без новых пакетов — только Flutter SDK.
// Анимация arc следует ANIMATIONS.md §0: MediaQuery.disableAnimations →
// пропустить анимацию, просто показать оставшееся время.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Модель данных
// ---------------------------------------------------------------------------

class _Step {
  const _Step({required this.text, required this.seconds});
  final String text;
  final int seconds;
}

class _Session {
  const _Session({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.steps,
  });
  final String id;
  final String name;
  final int duration; // минуты
  final String description;
  final List<_Step> steps;
}

const _sessions = <_Session>[
  _Session(
    id: 'body_scan',
    name: 'Body Scan',
    duration: 10,
    description: 'Release tension from head to toe',
    steps: [
      _Step(
        text:
            'Find a comfortable position — sitting or lying down. Close your eyes gently and take three slow, deep breaths. Let your body settle.',
        seconds: 60,
      ),
      _Step(
        text:
            'Bring your attention to the top of your head. Notice any sensations — tingling, warmth, or pressure. Simply observe without judgment.',
        seconds: 90,
      ),
      _Step(
        text:
            'Slowly move your awareness down through your face, neck, and shoulders. If you feel tension, breathe into that area and let it soften on the exhale.',
        seconds: 90,
      ),
      _Step(
        text:
            'Scan through your chest, belly, and lower back. Notice the gentle rise and fall of your breath. You don\'t need to change anything.',
        seconds: 90,
      ),
      _Step(
        text:
            'Move your attention down through your legs, ankles, and feet. Feel each toe. Your whole body is now relaxed and at ease.',
        seconds: 90,
      ),
      _Step(
        text:
            'Rest in this state of calm awareness for a moment. When you\'re ready, gently wiggle your fingers and toes and slowly open your eyes.',
        seconds: 90,
      ),
    ],
  ),
  _Session(
    id: 'focus_reset',
    name: 'Focus Reset',
    duration: 5,
    description: 'Clear mental fog between study blocks',
    steps: [
      _Step(
        text:
            'Sit upright, feet flat on the floor. Set your intention: you are clearing your mind to return to peak focus.',
        seconds: 30,
      ),
      _Step(
        text:
            'Take a deep breath in for 4 counts, hold for 4, and exhale for 4. Repeat this twice more at your own pace.',
        seconds: 60,
      ),
      _Step(
        text:
            'Picture a blank, white screen in your mind. If any thoughts appear, gently acknowledge them and let them drift off the screen.',
        seconds: 60,
      ),
      _Step(
        text:
            'Bring to mind one clear goal for your next work session. See it briefly, then release the image.',
        seconds: 60,
      ),
      _Step(
        text:
            'Take one final deep breath. Open your eyes. You are ready to focus.',
        seconds: 30,
      ),
    ],
  ),
  _Session(
    id: 'exam_calm',
    name: 'Exam Calm',
    duration: 7,
    description: 'Ease anxiety before tests and presentations',
    steps: [
      _Step(
        text:
            'Acknowledge that some nervousness is normal — it means you care. Take a slow breath and remind yourself: you have prepared for this.',
        seconds: 60,
      ),
      _Step(
        text:
            'Inhale deeply through your nose for 4 counts. Hold gently for 4 counts. Exhale slowly through your mouth for 6 counts. Repeat three times.',
        seconds: 90,
      ),
      _Step(
        text:
            'Name five things you can see around you. Four things you can touch. Three things you can hear. This grounds you in the present moment.',
        seconds: 90,
      ),
      _Step(
        text:
            'Recall one moment when you succeeded despite feeling anxious. Feel that memory in your body — the relief, the confidence that followed.',
        seconds: 60,
      ),
      _Step(
        text:
            'Silently tell yourself: "I am calm, I am clear, I know what to do." Take one final deep breath and step forward with confidence.',
        seconds: 60,
      ),
    ],
  ),
  _Session(
    id: 'sleep_prep',
    name: 'Sleep Prep',
    duration: 15,
    description: 'Wind down and ease into restful sleep',
    steps: [
      _Step(
        text:
            'Lie down in a comfortable position. Dim any remaining lights. Let your arms rest at your sides and allow your body to feel heavy and supported.',
        seconds: 60,
      ),
      _Step(
        text:
            'Take five long, slow breaths. With each exhale, feel yourself sinking a little deeper into the mattress. There is nothing you need to do right now.',
        seconds: 90,
      ),
      _Step(
        text:
            'Relax your face completely — forehead, eyes, jaw. Let your tongue rest softly on the floor of your mouth. Release any held expression.',
        seconds: 90,
      ),
      _Step(
        text:
            'Soften your shoulders, chest, and arms. Feel warmth spreading through your hands and fingers as your muscles let go.',
        seconds: 90,
      ),
      _Step(
        text:
            'Let your legs become heavy. Release your thighs, calves, and feet. Imagine the tension flowing down and out through your toes.',
        seconds: 120,
      ),
      _Step(
        text:
            'Picture a quiet, safe place — a forest path, a calm shore, a cozy room. You are safe, warm, and completely at rest. Let sleep come naturally.',
        seconds: 120,
      ),
      _Step(
        text:
            'There is nowhere to be, nothing to do. Your only task now is to rest. Breathe slowly... and drift...',
        seconds: 120,
      ),
    ],
  ),
  _Session(
    id: 'stress_relief',
    name: 'Stress Relief',
    duration: 8,
    description: 'Release tension and restore balance',
    steps: [
      _Step(
        text:
            'Stop what you\'re doing. Sit or stand comfortably. Acknowledge: right now, in this moment, you are safe.',
        seconds: 40,
      ),
      _Step(
        text:
            'Breathe in through your nose for 4 counts. Hold for 2. Breathe out through your mouth for 6. Feel your nervous system begin to slow.',
        seconds: 80,
      ),
      _Step(
        text:
            'Tense every muscle in your body for 5 seconds — fists, shoulders, face, legs. Then release all at once. Notice the flood of relaxation.',
        seconds: 80,
      ),
      _Step(
        text:
            'Observe what is stressing you from a distance — as if watching clouds pass across a sky. The clouds are not the sky. The stress is not you.',
        seconds: 80,
      ),
      _Step(
        text:
            'Think of one small action you can take after this session. Just one. Set everything else aside for now.',
        seconds: 60,
      ),
      _Step(
        text:
            'Take three final deep breaths. With each exhale, release a little more tension. You are more resilient than you know.',
        seconds: 60,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Session list screen
// ---------------------------------------------------------------------------

class MeditationScreen extends StatelessWidget {
  const MeditationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('meditation.title'))),
      body: ListView.separated(
        // 24dp screen margin — spec §4.1
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        itemCount: _sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _SessionCard(session: session, ext: ext, textTheme: textTheme);
        },
      ),
    );
  }
}

/// Карточка сессии — выделена в StatelessWidget для чистоты.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.ext,
    required this.textTheme,
  });

  final _Session session;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _SessionPlayerScreen(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Аватар — нейтральный (accentMuted фон, textMuted иконка)
              // Accent только для активной/выбранной сессии — здесь нейтрально
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ext.accentMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.spa_outlined,
                  color: ext.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название сессии — titleMedium
                    Text(session.name, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    // Описание — bodyMedium (основной текст)
                    Text(session.description, style: textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    // Мета-строка: длительность + шаги — bodySmall + textFaint
                    Text(
                      '${plMinutes(context, session.duration)} · ${plSteps(context, session.steps.length)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textFaint,
                      ),
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
// Session player screen
// ---------------------------------------------------------------------------

class _SessionPlayerScreen extends StatefulWidget {
  const _SessionPlayerScreen({required this.session});
  final _Session session;

  @override
  State<_SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends State<_SessionPlayerScreen>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  int _remaining = 0;
  Timer? _timer;

  // Первый шаг стартуем в didChangeDependencies (а НЕ в initState): _startStep
  // читает MediaQuery.disableAnimationsOf(context), а обращение к
  // InheritedWidget до завершения initState бросает исключение (red-screen).
  bool _started = false;

  // AnimationController для дуги обратного отсчёта
  late AnimationController _arcController;

  bool get _isLastStep => _stepIndex >= widget.session.steps.length - 1;
  _Step get _currentStep => widget.session.steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Стартуем первый шаг один раз, когда MediaQuery уже доступен.
    if (!_started) {
      _started = true;
      _startStep(widget.session.steps[0]);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _arcController.dispose();
    super.dispose();
  }

  void _startStep(_Step step) {
    _timer?.cancel();
    _remaining = step.seconds;

    // reduce motion → не анимировать дугу
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!reduce) {
      _arcController.duration = Duration(seconds: step.seconds);
      _arcController.forward(from: 0);
    } else {
      _arcController.value = 0;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remaining--;
      });
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
      _advanceStep();
    }
  }

  void _advanceStep() {
    setState(() {
      _stepIndex++;
    });
    _startStep(widget.session.steps[_stepIndex]);
  }

  void _showCompletionDialog() {
    _timer?.cancel();
    _arcController.stop();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final ext = Theme.of(dialogContext).extension<FocusThemeExtension>()!;
        return AlertDialog(
          // Иконка завершения — success color (не accent, per ACCENT DISCIPLINE)
          icon: Icon(Icons.spa_outlined, size: 40, color: ext.success),
          title: Text(dialogContext.s('meditation.session_complete')),
          content: Text(
            '"${widget.session.name}" — '
            '${dialogContext.s('meditation.session_complete_body')}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
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
    final stepCount = widget.session.steps.length;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
        centerTitle: true,
      ),
      body: SafeArea(
        // LayoutBuilder + SingleChildScrollView гарантируют, что контент НИКОГДА
        // не переполняет экран (исходный red-screen «overflowed by 99751px»):
        // при достатке места колонка растягивается на всю высоту (minHeight),
        // при нехватке — скроллится. Текст шага получает гибкую (Flexible)
        // высоту вместо Expanded, который ломался под неограниченной высотой.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // 24dp screen margin, 16dp top — spec §4.1
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Вычитаем вертикальный padding, чтобы IntrinsicHeight знал
                  // целевую высоту без переполнения.
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Прогресс шагов — bodySmall + textMuted
                      Text(
                        '${context.s('meditation.step')} ${_stepIndex + 1} / $stepCount',
                        style: textTheme.bodySmall?.copyWith(
                          color: ext.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Линейный прогресс — accent (несёт смысл прогресса)
                      LinearProgressIndicator(
                        value: (_stepIndex + 1) / stepCount,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 40),

                      // Дуга таймера — accent (первичная метрика текущего шага)
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: reduce
                            ? _StaticArcTimer(
                                remaining: _remaining,
                                total: _currentStep.seconds,
                                color: colorScheme.primary,
                                textTheme: textTheme,
                              )
                            : AnimatedBuilder(
                                animation: _arcController,
                                builder: (_, _) => CustomPaint(
                                  painter: _ArcPainter(
                                    progress: 1 - _arcController.value,
                                    color: colorScheme.primary,
                                    trackColor: ext.border,
                                  ),
                                  child: Center(
                                    // Таймер внутри дуги — displaySmall
                                    child: Text(
                                      _formatSeconds(_remaining),
                                      style: textTheme.displaySmall,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 40),

                      // Текст шага — bodyLarge, центрально. Flexible забирает
                      // доступное пространство, но не переполняет (под
                      // IntrinsicHeight у Column ограниченная высота).
                      Flexible(
                        child: Center(
                          child: Text(
                            _currentStep.text,
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Единственное первичное действие — FilledButton
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (_isLastStep) {
                              _showCompletionDialog();
                            } else {
                              _arcController.stop();
                              _advanceStep();
                            }
                          },
                          child: Text(
                            _isLastStep
                                ? context.s('meditation.finish')
                                : context.s('meditation.next'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Вторичное действие — TextButton (низкий приоритет)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.s('meditation.end_session')),
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

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    if (m > 0) {
      return '$m:${sec.toString().padLeft(2, '0')}';
    }
    return '${sec}s';
  }
}

// ---------------------------------------------------------------------------
// CustomPainters
// ---------------------------------------------------------------------------

/// Дуга таймера: прогресс уменьшается по мере хода времени.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress; // 1.0 → полная дуга, 0.0 → пустая
  final Color color;
  final Color trackColor; // из темы (ext.border)

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 8;

    // Фоновая дорожка — border color (нейтральный)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Прогресс-дуга — accent (несёт смысл таймера)
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
      old.progress != progress || old.color != color || old.trackColor != color;
}

/// Статичная дуга + время для reduce-motion режима.
class _StaticArcTimer extends StatelessWidget {
  const _StaticArcTimer({
    required this.remaining,
    required this.total,
    required this.color,
    required this.textTheme,
  });

  final int remaining;
  final int total;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final progress = total > 0 ? remaining / total : 0.0;
    final m = remaining ~/ 60;
    final s = remaining % 60;
    final label = m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';

    return CustomPaint(
      painter: _ArcPainter(
        progress: progress,
        color: color,
        trackColor: ext.border,
      ),
      child: Center(
        // displaySmall для крупного таймера внутри дуги
        child: Text(label, style: textTheme.displaySmall),
      ),
    );
  }
}
