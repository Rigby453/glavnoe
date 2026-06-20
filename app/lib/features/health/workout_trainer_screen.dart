// Режим «тренер» — последовательный проход по упражнениям шаблона тренировки.
// Фазы: work (выполнение подхода) и rest (обратный отсчёт отдыха).
// Офлайн-первый: startSession/finishSession пишут только в Drift.
// Phase 2, SPEC C5.
// RESTYLE 2026-06-19: bold design system — typography/color/spacing/buttons.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
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
  // Идентификатор текущей сессии (записан в Drift при входе)
  String? _sessionId;
  DateTime? _startedAt;

  // Состояние прохода
  int _exerciseIndex = 0; // текущее упражнение
  int _setIndex = 0; // текущий подход (0-based)
  _TrainerPhase _phase = _TrainerPhase.work;

  // Таймер обратного отсчёта (для фазы rest)
  int _restSecondsLeft = 0;
  Timer? _restTimer;

  // Упражнения — кешируем при первом получении
  List<WorkoutExercisesTableData>? _exercises;

  // Флаг: сессия уже завершена (finishSession вызван)
  bool _finished = false;

  // Контроллер анимации смены упражнения (scale при переходе)
  late AnimationController _transitionCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Анимация scale при смене упражнения — быстрая (kDurationFast 180ms)
    _transitionCtrl = AnimationController(
      vsync: this,
      // Продолжительность будет уточнена при первом build через effectiveDuration
      duration: kDurationFast,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _transitionCtrl, curve: kCurveSnap),
    );
    _transitionCtrl.value = 1.0; // начальное состояние — показан
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _transitionCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Анимация смены фазы / упражнения с учётом reduce-motion
  // ---------------------------------------------------------------------------

  void _animateTransition(VoidCallback stateUpdate) {
    final dur = effectiveDuration(context, kDurationFast);
    _transitionCtrl.duration = dur;
    // fade-scale out → обновляем состояние → fade-scale in
    if (dur == Duration.zero) {
      // reduce-motion: мгновенно
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

  // ---------------------------------------------------------------------------
  // Инициализация сессии
  // ---------------------------------------------------------------------------

  Future<void> _initSession(
    WorkoutsTableData workout,
    List<WorkoutExercisesTableData> exercises,
  ) async {
    if (_sessionId != null) return; // уже инициализирована
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

  // ---------------------------------------------------------------------------
  // Логика переходов
  // ---------------------------------------------------------------------------

  WorkoutExercisesTableData get _currentExercise =>
      _exercises![_exerciseIndex];

  int get _totalExercises => _exercises!.length;

  /// Нажата кнопка «Set done» — переходим к отдыху или следующему упражнению.
  void _onSetDone() {
    final ex = _currentExercise;
    final isLastSet = _setIndex >= ex.sets - 1;

    if (!isLastSet) {
      // Ещё есть подходы → фаза отдыха
      _animateTransition(() {
        _phase = _TrainerPhase.rest;
        _restSecondsLeft = ex.restSeconds;
      });
      _startRestTimer();
    } else {
      // Все подходы выполнены → следующее упражнение или финиш
      _restTimer?.cancel();
      final isLastExercise = _exerciseIndex >= _totalExercises - 1;
      if (isLastExercise) {
        _doFinish();
      } else {
        _animateTransition(() {
          _exerciseIndex++;
          _setIndex = 0;
          _phase = _TrainerPhase.work;
        });
      }
    }
  }

  /// Пропустить отдых — сразу переходим к следующему подходу.
  void _skipRest() {
    _restTimer?.cancel();
    _animateTransition(() {
      _setIndex++;
      _phase = _TrainerPhase.work;
    });
  }

  /// Запустить обратный отсчёт отдыха.
  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restSecondsLeft <= 1) {
        _restTimer?.cancel();
        // Автоматический переход к следующему подходу
        _animateTransition(() {
          _setIndex++;
          _phase = _TrainerPhase.work;
        });
      } else {
        setState(() => _restSecondsLeft--);
      }
    });
  }

  /// Завершить тренировку: финишируем сессию и показываем экран «Done».
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

  /// Попытка выйти раньше — диалог подтверждения.
  Future<bool> _confirmStop() async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('workout.stop_title')),
        content: Text(ctx.s('workout.stop_body')),
        actions: [
          // TextButton — продолжить (лёгкое навигационное действие)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('workout.continue_btn')),
          ),
          // OutlinedButton с ember — деструктивное «остановить»
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

  // ---------------------------------------------------------------------------
  // Форматирование
  // ---------------------------------------------------------------------------

  String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _elapsedMinutes() {
    if (_startedAt == null) return 0;
    return DateTime.now().difference(_startedAt!).inMinutes;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutProvider(widget.workoutId));
    final exercisesAsync =
        ref.watch(workoutExercisesProvider(widget.workoutId));

    final workout = workoutAsync.valueOrNull;
    final exercises = exercisesAsync.valueOrNull;

    // Ожидание данных из Drift — KaiLoader вместо CircularProgressIndicator
    if (workout == null || exercises == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: KaiLoader(label: context.s('loading.workout'))),
      );
    }

    // Инициализируем сессию один раз (при первом построении с данными)
    if (_sessionId == null && !_finished) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _initSession(workout, exercises),
      );
    }

    if (_phase == _TrainerPhase.done) {
      return _buildDoneScreen(context);
    }

    // Кешируем упражнения (нужны для логики, даже если стрим обновится)
    _exercises ??= exercises;

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
          // Прогресс «Exercise 2 of 5» — AppBar title через display font
          title: Text(progressLabel),
          actions: [
            // TextButton — «Остановить» (вторичное лёгкое действие в AppBar)
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
        // Анимация смены упражнения: scale + fade (reduce-motion: без анимации)
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
  // Фаза work
  // ---------------------------------------------------------------------------

  Widget _buildWorkPhase(
    BuildContext context,
    WorkoutExercisesTableData ex,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    // Строка «Set 2 of 3 · 10 reps · 40 kg»
    final setLabel = StringBuffer(
      '${context.s('workout.set_label')} ${_setIndex + 1} ${context.s('workout.of')} ${ex.sets}',
    );
    setLabel.write(' · ${ex.reps} ${context.s('workout.reps_label')}');
    if (ex.weightKg != null) {
      final w = ex.weightKg!;
      final wStr =
          w == w.truncateToDouble() ? '${w.round()} kg' : '$w kg';
      setLabel.write(' · $wStr');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Крупное название упражнения — displaySmall (32sp, display serif font)
          // Это «большой таймер/счётчик» тренера → display role per spec
          Text(
            ex.name,
            style: textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // «Set 2 of 3 · 10 reps · 40 kg» — titleMedium + textMuted
          Text(
            setLabel.toString(),
            style: textTheme.titleMedium?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.center,
          ),
          if (ex.technique != null && ex.technique!.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Подсказка по технике — bodyMedium + textFaint
            Text(
              ex.technique!,
              style: textTheme.bodyMedium?.copyWith(color: ext.textFaint),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          // FilledButton — единственная первичная CTA (Set done)
          // ACCENT DISCIPLINE: только этот элемент в фазе work получает accent
          FilledButton(
            onPressed: _onSetDone,
            child: Text(
              context.s('workout.set_done'),
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Фаза rest
  // ---------------------------------------------------------------------------

  Widget _buildRestPhase(
    BuildContext context,
    WorkoutExercisesTableData ex,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Определяем цвет таймера: ember при ≤10с (срочно), иначе нейтральный textMuted
    // ACCENT DISCIPLINE: отдых — нейтральный; ember только когда срочно
    final timerColor = _restSecondsLeft <= 10 ? ext.ember : ext.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // «Rest» — titleLarge + textMuted (информационный заголовок)
          Text(
            context.s('workout.rest_phase'),
            style: textTheme.titleLarge?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Обратный отсчёт — displayLarge (56sp, display serif font)
          // Это главный «дисплейный» элемент экрана
          // Цвет: ember когда ≤10с (срочно), иначе текст по умолчанию
          Text(
            _mmss(_restSecondsLeft),
            style: textTheme.displayLarge?.copyWith(color: timerColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // «Next: Exercise · Set N of M» — bodyMedium + textFaint
          Text(
            '${context.s('workout.next_label')}: ${ex.name} · '
            '${context.s('workout.set_label')} ${_setIndex + 2} '
            '${context.s('workout.of')} ${ex.sets}',
            style: textTheme.bodyMedium?.copyWith(color: ext.textFaint),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          // OutlinedButton — «Skip rest» (вторичное действие, не filled)
          // ACCENT DISCIPLINE: не первичное действие → не FilledButton
          OutlinedButton(
            onPressed: _skipRest,
            child: Text(context.s('workout.skip_rest')),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран завершения
  // ---------------------------------------------------------------------------

  Widget _buildDoneScreen(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final mins = _elapsedMinutes();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Иконка завершения — success color (не accent)
              // ACCENT DISCIPLINE: done/completed = success, не accent
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: ext.success,
              ),
              const SizedBox(height: 24),
              // «Did it as planned!» — headlineMedium (32sp, display serif)
              Text(
                context.s('workout.did_it'),
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // «N мин» — titleLarge + textMuted (вторичная метрика)
              Text(
                plMinutes(context, mins),
                style: textTheme.titleLarge?.copyWith(color: ext.textMuted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // FilledButton — единственная CTA на экране «done»
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.s('btn.done')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
