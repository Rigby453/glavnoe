// Режим «тренер» — последовательный проход по упражнениям шаблона тренировки.
// Фазы: work (выполнение подхода) и rest (обратный отсчёт отдыха).
// Офлайн-первый: startSession/finishSession пишут только в Drift.
// Phase 2, SPEC C5.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
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

class _WorkoutTrainerScreenState extends ConsumerState<WorkoutTrainerScreen> {
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

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
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
      setState(() {
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
        setState(() {
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
    setState(() {
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
        setState(() {
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop workout?'),
        content: const Text("Progress won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Stop'),
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

    // Ждём данных из Drift
    if (workout == null || exercises == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
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
        'Exercise ${_exerciseIndex + 1} of $_totalExercises';

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
            TextButton(
              onPressed: () async {
                final stop = await _confirmStop();
                if (stop && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Stop'),
            ),
          ],
        ),
        body: _phase == _TrainerPhase.work
            ? _buildWorkPhase(context, ex)
            : _buildRestPhase(context, ex),
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
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurface.withAlpha(120);

    // Строка «Set 2 of 3 · 10 reps · 40 kg»
    final setLabel = StringBuffer('Set ${_setIndex + 1} of ${ex.sets}');
    setLabel.write(' · ${ex.reps} reps');
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
          // Крупное название упражнения
          Text(
            ex.name,
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Set N of M · reps · weight
          Text(
            setLabel.toString(),
            style: textTheme.titleMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          if (ex.technique != null && ex.technique!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              ex.technique!,
              style: textTheme.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: _onSetDone,
            child: const Text('Set done'),
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
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurface.withAlpha(120);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            'Rest',
            style: textTheme.titleLarge?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Обратный отсчёт крупно
          Text(
            _mmss(_restSecondsLeft),
            style: textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Next: ${ex.name} · set ${_setIndex + 2} of ${ex.sets}',
            style: textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _skipRest,
            child: const Text('Skip rest'),
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
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Did it as planned!',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$mins min',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface.withAlpha(160),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
