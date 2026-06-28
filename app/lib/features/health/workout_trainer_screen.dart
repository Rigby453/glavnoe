// Режим «тренер» — Kaname redesign §D.
// Фазы: work (выполнение подхода), rest (обратный отсчёт), done (успех).
// Work: большое название упражнения displayLarge, accent FilledButton «Done».
// Rest: big mono timer displayLarge, fact steppers, pause/skip.
// Done: KaiMascot(success) + headlineMedium + plMinutes + FilledButton.
// Офлайн-первый: startSession/finishSession → только Drift.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/settings/rest_default_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import 'exercise_detail_sheet.dart';
import 'exercise_library.dart';
import 'workouts_screen.dart' show workoutExercisesProvider, workoutProvider;

// ---------------------------------------------------------------------------
// Фазы тренировки
// ---------------------------------------------------------------------------

enum _TrainerPhase { work, rest, done }

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------

class WorkoutTrainerScreen extends ConsumerStatefulWidget {
  const WorkoutTrainerScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutTrainerScreen> createState() =>
      _WorkoutTrainerScreenState();
}

class _WorkoutTrainerScreenState extends ConsumerState<WorkoutTrainerScreen>
    with SingleTickerProviderStateMixin {
  String? _sessionId;
  DateTime? _startedAt;

  int _exerciseIndex = 0;
  int _setIndex = 0;
  _TrainerPhase _phase = _TrainerPhase.work;

  // Фактические reps/weight текущего подхода
  int _currentReps = 0;
  double? _currentWeightKg;
  bool _setInputsReady = false;
  bool _currentSetLogged = false;

  // Текстовые контроллеры для клавиатурного ввода
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  static const int _repsMin = 0;
  static const int _repsMax = 999;
  static const double _weightStep = 2.5;
  static const double _weightMax = 999.0;

  // Таймер отдыха
  int _restSecondsLeft = 0;
  Timer? _restTimer;
  bool _restPaused = false;

  static const int _restAdjustStep = 15;
  static const int _restMinSeconds = 5;
  static const int _restMaxSeconds = 600;

  List<WorkoutExercisesTableData>? _exercises;
  bool _finished = false;

  late AnimationController _transitionCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: kDurationFast,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _transitionCtrl, curve: kCurveSnap),
    );
    _transitionCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _transitionCtrl.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _animateTransition(VoidCallback stateUpdate) {
    final dur = effectiveDuration(context, kDurationFast);
    _transitionCtrl.duration = dur;
    if (dur == Duration.zero) {
      setState(stateUpdate);
    } else {
      _transitionCtrl.reverse().then((_) {
        if (mounted) {
          setState(stateUpdate);
          _transitionCtrl.forward();
        }
      });
    }
  }

  Future<void> _initSession(
    WorkoutsTableData workout,
    List<WorkoutExercisesTableData> exercises,
  ) async {
    if (_sessionId != null) return;
    _exercises = exercises;
    final now = DateTime.now();
    final id = await ref
        .read(workoutsDaoProvider)
        .startSession(workout.id, workout.name);
    if (mounted) {
      setState(() {
        _sessionId = id;
        _startedAt = now;
      });
    }
  }

  WorkoutExercisesTableData get _currentExercise =>
      _exercises![_exerciseIndex];

  int get _totalExercises => _exercises!.length;

  void _resetSetInputs() {
    final ex = _currentExercise;
    _currentReps = ex.reps;
    _currentWeightKg = ex.weightKg;
    _setInputsReady = true;
    _currentSetLogged = false;
    _syncInputControllers();
  }

  void _syncInputControllers() {
    final repsText = '$_currentReps';
    if (_repsController.text != repsText) _repsController.text = repsText;
    final w = _currentWeightKg;
    final weightText = w == null
        ? ''
        : (w == w.truncateToDouble() ? '${w.round()}' : '$w');
    if (_weightController.text != weightText) {
      _weightController.text = weightText;
    }
  }

  void _adjustReps(int delta) {
    setState(() {
      _currentReps = (_currentReps + delta).clamp(_repsMin, _repsMax);
      _syncInputControllers();
    });
  }

  void _adjustWeight(double delta) {
    setState(() {
      final base = _currentWeightKg ?? 0.0;
      final next = base + delta;
      _currentWeightKg = next <= 0 ? null : next.clamp(0.0, _weightMax);
      _syncInputControllers();
    });
  }

  void _onRepsTextChanged(String text) {
    final parsed = int.tryParse(text) ?? 0;
    setState(() {
      _currentReps = parsed.clamp(_repsMin, _repsMax);
    });
  }

  void _onWeightTextChanged(String text) {
    setState(() {
      if (text.isEmpty) {
        _currentWeightKg = null;
      } else {
        final parsed = double.tryParse(text);
        _currentWeightKg = parsed?.clamp(0.0, _weightMax);
      }
    });
  }

  Future<void> _logCurrentSet() async {
    if (_currentSetLogged) return;
    if (_sessionId == null) return;
    _currentSetLogged = true;
    await ref.read(workoutsDaoProvider).logSet(
          sessionId: _sessionId!,
          exerciseId: _currentExercise.id,
          setIndex: _setIndex,
          reps: _currentReps,
          weightKg: _currentWeightKg,
        );
  }

  Future<void> _onSetDone() async {
    await _logCurrentSet();
    if (!mounted) return;

    final ex = _currentExercise;
    final isLastSet = _setIndex >= ex.sets - 1;

    if (!isLastSet) {
      final restSeconds = effectiveRestSeconds(
        exerciseRestSeconds: ex.restSeconds,
        globalDefaultSeconds: ref.read(restDefaultProvider),
      );
      _animateTransition(() {
        _phase = _TrainerPhase.rest;
        _restSecondsLeft = restSeconds;
        _restPaused = false;
      });
      _startRestTimer();
    } else {
      await _logCurrentSet();
      if (!mounted) return;
      _restTimer?.cancel();
      final isLastExercise = _exerciseIndex >= _totalExercises - 1;
      if (isLastExercise) {
        _doFinish();
      } else {
        _animateTransition(() {
          _exerciseIndex++;
          _setIndex = 0;
          _phase = _TrainerPhase.work;
          _resetSetInputs();
        });
      }
    }
  }

  Future<void> _commitSetAndAdvance() async {
    await _logCurrentSet();
    if (!mounted) return;
    _animateTransition(() {
      _setIndex++;
      _phase = _TrainerPhase.work;
      _resetSetInputs();
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _commitSetAndAdvance();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restPaused) return;
      if (_restSecondsLeft <= 1) {
        _restTimer?.cancel();
        _commitSetAndAdvance();
      } else {
        setState(() => _restSecondsLeft--);
      }
    });
  }

  void _toggleRestPause() {
    if (_restPaused) {
      setState(() => _restPaused = false);
      _startRestTimer();
    } else {
      _restTimer?.cancel();
      setState(() => _restPaused = true);
    }
  }

  void _adjustRest(int delta) {
    setState(() {
      _restSecondsLeft =
          (_restSecondsLeft + delta).clamp(_restMinSeconds, _restMaxSeconds);
    });
  }

  Future<void> _doFinish() async {
    _restTimer?.cancel();
    if (_sessionId != null && !_finished) {
      _finished = true;
      await ref.read(workoutsDaoProvider).finishSession(_sessionId!);
    }
    if (mounted) {
      setState(() => _phase = _TrainerPhase.done);
    }
  }

  Future<bool> _confirmStop() async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('workout.stop_title')),
        content: Text(ctx.s('workout.stop_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('workout.continue_btn')),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: ext.ember,
              side: BorderSide(color: ext.ember),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.s('workout.stop')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _elapsedMinutes() {
    if (_startedAt == null) return 0;
    return DateTime.now().difference(_startedAt!).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutProvider(widget.workoutId));
    final exercisesAsync =
        ref.watch(workoutExercisesProvider(widget.workoutId));

    final workout = workoutAsync.valueOrNull;
    final exercises = exercisesAsync.valueOrNull;

    if (workout == null || exercises == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: KaiLoader(label: context.s('loading.workout'))),
      );
    }

    if (_sessionId == null && !_finished) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _initSession(workout, exercises),
      );
    }

    if (_phase == _TrainerPhase.done) {
      return _buildDoneScreen(context);
    }

    _exercises ??= exercises;
    if (!_setInputsReady) _resetSetInputs();

    final ex = _currentExercise;
    final progressLabel =
        '${context.s('workout.exercise_of')} ${_exerciseIndex + 1} '
        '${context.s('workout.of')} $_totalExercises';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final stop = await _confirmStop();
        if (stop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(progressLabel),
          actions: [
            // Техника — phosphor info
            Builder(
              builder: (_) {
                final catalogEntry = exerciseById(ex.name);
                if (catalogEntry == null) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(PhosphorIcons.info()),
                  tooltip: context.s('exercise.detail.info_tooltip'),
                  onPressed: () => showExerciseDetail(context, catalogEntry),
                );
              },
            ),
            // История — chartLineUp
            IconButton(
              icon: Icon(PhosphorIcons.chartLineUp()),
              tooltip: context.s('workout.view_history'),
              onPressed: () => context.push(
                '/workouts/exercise/${ex.id}/history'
                '?name=${Uri.encodeQueryComponent(ex.name)}',
              ),
            ),
            // Остановить — текстовая кнопка
            TextButton(
              onPressed: () async {
                final stop = await _confirmStop();
                if (stop && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.s('workout.stop')),
            ),
          ],
        ),
        body: ScaleTransition(
          scale: _scaleAnim,
          child: FadeTransition(
            opacity: _transitionCtrl,
            child: _phase == _TrainerPhase.work
                ? _buildWorkPhase(context, ex)
                : _buildRestPhase(context, ex),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Фаза work — большое название + accent FilledButton
  // ---------------------------------------------------------------------------

  Widget _buildWorkPhase(
    BuildContext context,
    WorkoutExercisesTableData ex,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    // «Set 2/3» — краткий label
    final setLabel =
        '${context.s('workout.set_label')} ${_setIndex + 1} ${context.s('workout.of')} ${ex.sets}';

    // Детали планового подхода
    final planDetail = StringBuffer('${ex.reps} ${context.s('workout.reps_label')}');
    if (ex.weightKg != null) {
      final w = ex.weightKg!;
      planDetail.write(' · ${w == w.truncateToDouble() ? '${w.round()}' : '$w'} ${context.s('workout.weight_short')}');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Barbell icon — декоративный
          Center(
            child: Icon(
              PhosphorIcons.barbell(PhosphorIconsStyle.fill),
              size: 36,
              color: colorScheme.primary.withAlpha(80),
            ),
          ),
          const SizedBox(height: 16),
          // Название упражнения — displaySmall, центр
          Text(
            ex.name,
            style: textTheme.displaySmall,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // «Set 2/3» + план
          Text(
            setLabel,
            style: textTheme.titleMedium?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            planDetail.toString(),
            style: textTheme.bodyMedium?.copyWith(color: ext.textFaint),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (ex.technique != null && ex.technique!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              ex.technique!,
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          // Accent FilledButton — единственная CTA фазы work
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _onSetDone,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.s('workout.set_done'),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Факт-степперы во время отдыха
  // ---------------------------------------------------------------------------

  Widget _buildSetInputs(
    BuildContext context,
    TextTheme textTheme,
    FocusThemeExtension ext,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildEditableField(
            context: context,
            textTheme: textTheme,
            ext: ext,
            label: context.s('workout.reps_label'),
            controller: _repsController,
            onChanged: _onRepsTextChanged,
            onMinus: _currentReps <= _repsMin ? null : () => _adjustReps(-1),
            onPlus: _currentReps >= _repsMax ? null : () => _adjustReps(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEditableField(
            context: context,
            textTheme: textTheme,
            ext: ext,
            label: context.s('workout.weight_kg'),
            controller: _weightController,
            hintText: context.s('workout.bodyweight'),
            onChanged: _onWeightTextChanged,
            onMinus: _currentWeightKg == null
                ? null
                : () => _adjustWeight(-_weightStep),
            onPlus: (_currentWeightKg ?? 0) >= _weightMax
                ? null
                : () => _adjustWeight(_weightStep),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required BuildContext context,
    required TextTheme textTheme,
    required FocusThemeExtension ext,
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
    String? hintText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onMinus,
              icon: Icon(PhosphorIcons.minus()),
              color: ext.textMuted,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintStyle: textTheme.bodySmall?.copyWith(color: ext.textFaint),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                ),
              ),
            ),
            IconButton(
              onPressed: onPlus,
              icon: Icon(PhosphorIcons.plus()),
              color: ext.textMuted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Фаза rest — big mono timer + fact steppers
  // ---------------------------------------------------------------------------

  Widget _buildRestPhase(
    BuildContext context,
    WorkoutExercisesTableData ex,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    // Цвет таймера: ember при ≤10с (срочно), иначе нейтральный
    final timerColor =
        (!_restPaused && _restSecondsLeft <= 10) ? ext.ember : colorScheme.onSurface;

    final restLabel = _restPaused
        ? context.s('workout.rest_paused')
        : context.s('workout.rest_phase');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // «Rest» / «Paused» label
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_restPaused) ...[
                  Icon(PhosphorIcons.pause(), size: 18, color: ext.textMuted),
                  const SizedBox(width: 8),
                ],
                Text(
                  restLabel,
                  style: textTheme.titleMedium?.copyWith(color: ext.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ряд ±15с · большой таймер · ±15с
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _restSecondsLeft <= _restMinSeconds
                      ? null
                      : () => _adjustRest(-_restAdjustStep),
                  icon: Icon(PhosphorIcons.minus()),
                  color: ext.textMuted,
                  tooltip: context.s('workout.subtract_time'),
                ),
                const SizedBox(width: 4),
                // Big mono timer — displayLarge с tabular figures
                Text(
                  _mmss(_restSecondsLeft),
                  style: textTheme.displayLarge?.copyWith(
                    color: timerColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _restSecondsLeft >= _restMaxSeconds
                      ? null
                      : () => _adjustRest(_restAdjustStep),
                  icon: Icon(PhosphorIcons.plus()),
                  color: ext.textMuted,
                  tooltip: context.s('workout.add_time'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // «Next: Exercise · Set N+1/M»
            Text(
              '${context.s('workout.next_label')}: ${ex.name} · '
              '${context.s('workout.set_label')} ${_setIndex + 2} '
              '${context.s('workout.of')} ${ex.sets}',
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            // Подпись над fact-steppers
            Text(
              '${context.s('workout.logged_set')} '
              '${context.s('workout.set_label')} ${_setIndex + 1} '
              '${context.s('workout.of')} ${ex.sets}',
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Fact steppers: reps / weight
            _buildSetInputs(context, textTheme, ext),
            const SizedBox(height: 24),
            // Пауза/возобновление (OutlinedButton)
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _toggleRestPause,
                icon: Icon(
                  _restPaused
                      ? PhosphorIcons.play(PhosphorIconsStyle.fill)
                      : PhosphorIcons.pause(),
                  size: 18,
                ),
                label: Text(
                  _restPaused
                      ? context.s('workout.resume_rest')
                      : context.s('workout.pause_rest'),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Skip rest (OutlinedButton)
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _skipRest,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.s('workout.skip_rest')),
              ),
            ),
          ],
        ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран завершения — KaiMascot(success) + headlineMedium + FilledButton
  // ---------------------------------------------------------------------------

  Widget _buildDoneScreen(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final mins = _elapsedMinutes();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // KaiMascot success — радость завершения
              const Center(
                child: KaiMascot(size: 80, emotion: KaiEmotion.success),
              ),
              const SizedBox(height: 28),
              // Заголовок — headlineMedium, центр
              Text(
                context.s('workout.did_it'),
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Время — titleLarge + textMuted
              Text(
                plMinutes(context, mins),
                style: textTheme.titleLarge?.copyWith(color: ext.textMuted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Единственная CTA
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.s('btn.done'),
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
