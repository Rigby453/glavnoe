// Экран медитаций — 5 текстовых сессий с обратным отсчётом.
// Без аудио и без новых пакетов — только Flutter SDK.
// Анимация arc следует ANIMATIONS.md §0: MediaQuery.disableAnimations →
// пропустить анимацию, просто показать оставшееся время.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/mood/meditation_mood_log.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/undo_snack_bar.dart';
import 'meditation_custom_providers.dart';
import 'meditation_editor_screen.dart';

// ---------------------------------------------------------------------------
// Модель данных
// ---------------------------------------------------------------------------

// Шаг встроенной сессии: textKey — l10n-ключ текста инструкции.
class _Step {
  const _Step({required this.textKey, required this.seconds});
  final String textKey;
  final int seconds;
}

// ---------------------------------------------------------------------------
// Унифицированная рантайм-модель плеера
//
// Встроенные сессии хранят l10n-КЛЮЧИ (textKey/nameKey), пользовательские —
// СЫРОЙ текст. Плеер не должен знать о различии: при открытии сессии мы один раз
// резолвим всё в [_RunSession] — встроенные через context.s(), пользовательские
// пропускаем как есть. Дальше плеер просто показывает готовые строки.
// ---------------------------------------------------------------------------

class _RunStep {
  const _RunStep({required this.text, required this.seconds});
  final String text; // уже резолвленная строка (готова к показу)
  final int seconds;
}

class _RunSession {
  const _RunSession({
    required this.id,
    required this.name,
    required this.steps,
  });
  final String id; // для лога настроения (sessionId)
  final String name; // уже резолвленное имя
  final List<_RunStep> steps;
}

// Сессия медитации: nameKey/descKey/steps — l10n-ключи; id и duration — стабильные.
class _Session {
  const _Session({
    required this.id,
    required this.nameKey,
    required this.duration,
    required this.descKey,
    required this.steps,
  });
  final String id;
  final String nameKey;
  final int duration; // минуты
  final String descKey;
  final List<_Step> steps;
}

const _sessions = <_Session>[
  _Session(
    id: 'body_scan',
    nameKey: 'meditation.body_scan.name',
    duration: 10,
    descKey: 'meditation.body_scan.desc',
    steps: [
      _Step(textKey: 'meditation.body_scan.step1', seconds: 60),
      _Step(textKey: 'meditation.body_scan.step2', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step3', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step4', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step5', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step6', seconds: 90),
    ],
  ),
  _Session(
    id: 'focus_reset',
    nameKey: 'meditation.focus_reset.name',
    duration: 5,
    descKey: 'meditation.focus_reset.desc',
    steps: [
      _Step(textKey: 'meditation.focus_reset.step1', seconds: 30),
      _Step(textKey: 'meditation.focus_reset.step2', seconds: 60),
      _Step(textKey: 'meditation.focus_reset.step3', seconds: 60),
      _Step(textKey: 'meditation.focus_reset.step4', seconds: 60),
      _Step(textKey: 'meditation.focus_reset.step5', seconds: 30),
    ],
  ),
  _Session(
    id: 'exam_calm',
    nameKey: 'meditation.exam_calm.name',
    duration: 7,
    descKey: 'meditation.exam_calm.desc',
    steps: [
      _Step(textKey: 'meditation.exam_calm.step1', seconds: 60),
      _Step(textKey: 'meditation.exam_calm.step2', seconds: 90),
      _Step(textKey: 'meditation.exam_calm.step3', seconds: 90),
      _Step(textKey: 'meditation.exam_calm.step4', seconds: 60),
      _Step(textKey: 'meditation.exam_calm.step5', seconds: 60),
    ],
  ),
  _Session(
    id: 'sleep_prep',
    nameKey: 'meditation.sleep_prep.name',
    duration: 15,
    descKey: 'meditation.sleep_prep.desc',
    steps: [
      _Step(textKey: 'meditation.sleep_prep.step1', seconds: 60),
      _Step(textKey: 'meditation.sleep_prep.step2', seconds: 90),
      _Step(textKey: 'meditation.sleep_prep.step3', seconds: 90),
      _Step(textKey: 'meditation.sleep_prep.step4', seconds: 90),
      _Step(textKey: 'meditation.sleep_prep.step5', seconds: 120),
      _Step(textKey: 'meditation.sleep_prep.step6', seconds: 120),
      _Step(textKey: 'meditation.sleep_prep.step7', seconds: 120),
    ],
  ),
  _Session(
    id: 'stress_relief',
    nameKey: 'meditation.stress_relief.name',
    duration: 8,
    descKey: 'meditation.stress_relief.desc',
    steps: [
      _Step(textKey: 'meditation.stress_relief.step1', seconds: 40),
      _Step(textKey: 'meditation.stress_relief.step2', seconds: 80),
      _Step(textKey: 'meditation.stress_relief.step3', seconds: 80),
      _Step(textKey: 'meditation.stress_relief.step4', seconds: 80),
      _Step(textKey: 'meditation.stress_relief.step5', seconds: 60),
      _Step(textKey: 'meditation.stress_relief.step6', seconds: 60),
    ],
  ),
];

// Резолвит встроенную сессию (l10n-ключи) в рантайм-модель плеера.
_RunSession _builtinToRun(BuildContext context, _Session session) {
  return _RunSession(
    id: session.id,
    name: context.s(session.nameKey),
    steps: session.steps
        .map((st) => _RunStep(text: context.s(st.textKey), seconds: st.seconds))
        .toList(),
  );
}

// Резолвит пользовательскую сессию (СЫРОЙ текст) в рантайм-модель плеера.
_RunSession _customToRun(CustomMeditation m) {
  return _RunSession(
    id: m.id,
    name: m.name,
    steps: m.steps
        .map((st) => _RunStep(text: st.text, seconds: st.seconds))
        .toList(),
  );
}

void _openPlayer(BuildContext context, _RunSession session) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _SessionPlayerScreen(session: session),
    ),
  );
}

// ---------------------------------------------------------------------------
// Session list screen
// ---------------------------------------------------------------------------

class MeditationScreen extends ConsumerWidget {
  const MeditationScreen({super.key});

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MeditationEditorScreen()),
    );
  }

  /// Удаление пользовательской сессии с Undo (паттерн привычек/дыхания).
  Future<void> _deleteCustom(
    BuildContext context,
    WidgetRef ref,
    CustomMeditation m,
  ) async {
    final dao = ref.read(customMeditationDaoProvider);
    final snapshot = await dao.getById(m.id);
    if (snapshot == null) return;
    await dao.deleteSession(m.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${m.name}" ${context.s('meditation.removed')}',
      onUndo: () async => dao.restore(snapshot),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Пользовательские сессии из БД (пустой список, пока стрим грузится).
    final custom = ref.watch(customMeditationsProvider).valueOrNull ??
        const <CustomMeditation>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.s('meditation.title'))),
      body: ListView(
        // 24dp screen margin — spec §4.1
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        children: [
          // Встроенные сессии.
          for (final session in _sessions) ...[
            _SessionCard(session: session, ext: ext, textTheme: textTheme),
            const SizedBox(height: 12),
          ],
          // Пользовательские сессии — рядом со встроенными, тот же плеер.
          for (final m in custom) ...[
            _CustomSessionCard(
              session: m,
              ext: ext,
              textTheme: textTheme,
              onDelete: () => _deleteCustom(context, ref, m),
            ),
            const SizedBox(height: 12),
          ],
          // Создать свою сессию.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: Text(context.s('meditation.create_button')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка встроенной сессии — выделена в StatelessWidget для чистоты.
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
        onTap: () => _openPlayer(context, _builtinToRun(context, session)),
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
                    Text(context.s(session.nameKey), style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    // Описание — bodyMedium (основной текст)
                    Text(context.s(session.descKey), style: textTheme.bodyMedium),
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

/// Карточка пользовательской сессии: тот же макет + кнопка удаления (Undo).
class _CustomSessionCard extends StatelessWidget {
  const _CustomSessionCard({
    required this.session,
    required this.ext,
    required this.textTheme,
    required this.onDelete,
  });

  final CustomMeditation session;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Длительность сессии в минутах (минимум 1) для мета-строки.
    final minutes = (session.totalSeconds / 60).round().clamp(1, 1 << 30);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPlayer(context, _customToRun(session)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ext.accentMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.self_improvement_outlined,
                  color: ext.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Имя — СЫРОЙ пользовательский текст (данные).
                    Text(session.name, style: textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${plMinutes(context, minutes)} · ${plSteps(context, session.steps.length)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: ext.ember),
                tooltip: context.s('btn.delete'),
                onPressed: onDelete,
              ),
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

class _SessionPlayerScreen extends ConsumerStatefulWidget {
  const _SessionPlayerScreen({required this.session});
  final _RunSession session;

  @override
  ConsumerState<_SessionPlayerScreen> createState() =>
      _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends ConsumerState<_SessionPlayerScreen>
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
  _RunStep get _currentStep => widget.session.steps[_stepIndex];

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

  void _startStep(_RunStep step) {
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

    // Эмодзи для шкалы настроения — те же, что в diary_screen.dart.
    const moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // StatefulBuilder позволяет обновлять состояние выбора настроения
        // внутри диалога без setState на экране плеера.
        int? selectedMood; // null = ничего не выбрано (Done работает без)
        final noteController = TextEditingController();
        final reduce = MediaQuery.disableAnimationsOf(dialogContext);

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final ext = Theme.of(ctx).extension<FocusThemeExtension>()!;
            final colorScheme = Theme.of(ctx).colorScheme;
            final textTheme = Theme.of(ctx).textTheme;

            return AlertDialog(
              // Иконка завершения — success color (не accent, per ACCENT DISCIPLINE)
              icon: Icon(Icons.spa_outlined, size: 40, color: ext.success),
              title: Text(ctx.s('meditation.session_complete')),
              // Скроллируемый контент — защита от переполнения на маленьких экранах
              // (320px, textScaleFactor 1.5–2.0) с 5 эмодзи + текстовым полем.
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Сессия-название — bodyMedium (контекстная подпись)
                    Text(
                      '"${widget.session.name}"',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: ext.textMuted),
                    ),
                    const SizedBox(height: 12),
                    // Вопрос-приглашение — bodyLarge
                    Text(
                      ctx.s('meditation.mood_prompt'),
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    // Шкала настроения 1..5 — эмодзи с обёртыванием Wrap
                    // (защита от overflow при крупном шрифте или узком экране).
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(5, (i) {
                        final value = i + 1;
                        final selected = selectedMood == value;
                        return GestureDetector(
                          onTap: () => setDialogState(
                            () => selectedMood =
                                selected ? null : value,
                          ),
                          child: AnimatedContainer(
                            // snap=120ms (kDurationSnap)
                            duration: reduce
                                ? Duration.zero
                                : kDurationSnap,
                            curve: kCurveSnap,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // Выбрано: accentMuted фон + accent бордер
                              // Нет: прозрачный + border (нейтральный)
                              color: selected
                                  ? ext.accentMuted
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? colorScheme.primary
                                    : ext.border,
                                width: selected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              moodEmojis[i],
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    // Однострочное поле заметки (необязательно)
                    TextField(
                      controller: noteController,
                      maxLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: ctx.s('meditation.mood_note_hint'),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Снимаем текст ЗАРАНЕЕ — до dispose контроллера и до pop.
                    final noteText = noteController.text.trim();
                    final moodSnapshot = selectedMood;

                    // Закрываем диалог ПЕРВЫМ, чтобы Flutter успел убрать
                    // TextField из дерева до того, как мы вызовем dispose на
                    // noteController. Иначе анимация закрытия строит кадры
                    // с уже-disposed контроллером → red-screen.
                    if (ctx.mounted) Navigator.of(ctx).pop();

                    // Освобождаем контроллер ПОСЛЕ pop (диалог вышел из дерева).
                    noteController.dispose();

                    // Сохраняем только если выбрано настроение
                    if (moodSnapshot != null) {
                      final prefs = ref.read(sharedPreferencesProvider);
                      // appendMeditationMood защищён try/catch внутри — не бросает.
                      await appendMeditationMood(
                        prefs,
                        MeditationMoodEntry(
                          sessionId: widget.session.id,
                          mood: moodSnapshot,
                          note: noteText.isEmpty ? null : noteText,
                          loggedAt: DateTime.now(),
                        ),
                      );
                      // Показываем снэкбар только если экран плеера ещё живой.
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.s('meditation.mood_saved')),
                          ),
                        );
                      }
                    }
                    // Возвращаемся на экран списка сессий.
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Text(ctx.s('btn.done')),
                ),
              ],
            );
          },
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
