// Режим «тренер» — последовательный проход по упражнениям шаблона тренировки.
// Фазы: work (выполнение подхода) и rest (обратный отсчёт отдыха).
// Офлайн-первый: startSession/finishSession пишут только в Drift.
// Phase 2, SPEC C5.
// RESTYLE 2026-06-19: bold design system — typography/color/spacing/buttons.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/settings/rest_default_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
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
  // Идентификатор текущей сессии (записан в Drift при входе)
  String? _sessionId;
  DateTime? _startedAt;

  // Состояние прохода
  int _exerciseIndex = 0; // текущее упражнение
  int _setIndex = 0; // текущий подход (0-based)
  _TrainerPhase _phase = _TrainerPhase.work;

  // Feature B / #22+F — фактические reps/weight текущего подхода.
  // Пред-заполняются плановыми значениями упражнения (см. _resetSetInputs),
  // так что «тап насквозь» без правок залогирует осмысленные числа.
  // Правка и логирование происходят во время фазы ОТДЫХА (#22+F): после «Готово»
  // показываем редактируемые поля reps/weight выполненного подхода, и пишем лог
  // при ЗАВЕРШЕНИИ отдыха/переходе дальше с текущими значениями (без дублей).
  int _currentReps = 0;
  double? _currentWeightKg; // null = собственный вес (bodyweight)
  bool _setInputsReady = false; // плановые значения уже подставлены?

  // #22+F: текстовые контроллеры полей ввода reps/weight (клавиатура).
  // Источник истины — _currentReps/_currentWeightKg; контроллеры лишь зеркалят
  // их для редактирования с клавиатуры. Синхронизируются в _syncInputControllers.
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // #22+F: защита от дублей лога. Один подход логируется РОВНО один раз —
  // в момент, когда мы покидаем этот подход (конец отдыха / переход дальше).
  bool _currentSetLogged = false;

  // Границы регулировки фактических reps/weight
  static const int _repsMin = 0;
  static const int _repsMax = 999;
  static const double _weightStep = 2.5; // шаг изменения веса в кг
  static const double _weightMax = 999.0;

  // Таймер обратного отсчёта (для фазы rest)
  int _restSecondsLeft = 0;
  Timer? _restTimer;
  bool _restPaused = false; // отдых на паузе → отсчёт заморожен

  // Границы регулировки времени отдыха (±15с)
  static const int _restAdjustStep = 15;
  static const int _restMinSeconds = 5;
  static const int _restMaxSeconds = 600;

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
    // #22+F: контроллеры полей ввода reps/weight — обязательный dispose.
    _repsController.dispose();
    _weightController.dispose();
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

  /// Подставить плановые reps/weight упражнения как стартовые значения подхода.
  /// Вызывается при первом показе work-фазы и при каждой смене упражнения.
  /// Не вызывает setState сам — рассчитан на вызов внутри _animateTransition
  /// или прямо перед setState в build-инициализации.
  void _resetSetInputs() {
    final ex = _currentExercise;
    _currentReps = ex.reps;
    _currentWeightKg = ex.weightKg; // может быть null → bodyweight
    _setInputsReady = true;
    _currentSetLogged = false; // новый подход → ещё не залогирован
    _syncInputControllers();
  }

  /// Привести текст контроллеров в соответствие с _currentReps/_currentWeightKg.
  /// Вызывается после степперов и при подстановке плановых значений, чтобы поля
  /// с клавиатуры и кнопки +/- показывали одно и то же число.
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

  /// Изменить фактические повторения на delta (с клампом).
  void _adjustReps(int delta) {
    setState(() {
      _currentReps = (_currentReps + delta).clamp(_repsMin, _repsMax);
      _syncInputControllers();
    });
  }

  /// Изменить фактический вес на delta кг (с клампом).
  /// Из bodyweight (null) первый «+» стартует с 0, «−» остаётся bodyweight.
  void _adjustWeight(double delta) {
    setState(() {
      final base = _currentWeightKg ?? 0.0;
      final next = base + delta;
      _currentWeightKg = next <= 0 ? null : next.clamp(0.0, _weightMax);
      _syncInputControllers();
    });
  }

  /// #22+F: ввод reps с клавиатуры (digitsOnly). Пустое поле → 0.
  void _onRepsTextChanged(String text) {
    final parsed = int.tryParse(text) ?? 0;
    setState(() {
      _currentReps = parsed.clamp(_repsMin, _repsMax);
    });
  }

  /// #22+F: ввод веса с клавиатуры (digitsOnly, кг). Пустое поле → bodyweight.
  void _onWeightTextChanged(String text) {
    setState(() {
      if (text.isEmpty) {
        _currentWeightKg = null; // bodyweight
      } else {
        final parsed = double.tryParse(text);
        _currentWeightKg = parsed?.clamp(0.0, _weightMax);
      }
    });
  }

  /// #22+F: записать текущий подход в Drift РОВНО один раз (без дублей).
  /// Вызывается при выходе из подхода: конец отдыха (авто/skip), переход к
  /// следующему упражнению или финиш на последнем подходе. Идемпотентна за счёт
  /// флага _currentSetLogged (сбрасывается в _resetSetInputs / при смене set).
  Future<void> _logCurrentSet() async {
    if (_currentSetLogged) return;
    if (_sessionId == null) return; // сессия ещё не инициализирована
    _currentSetLogged = true;
    await ref.read(workoutsDaoProvider).logSet(
          sessionId: _sessionId!,
          exerciseId: _currentExercise.id,
          setIndex: _setIndex,
          reps: _currentReps,
          weightKg: _currentWeightKg,
        );
  }

  /// Нажата кнопка «Готово» — логируем подход и переходим к отдыху или к
  /// следующему упражнению. Лог пишется НЕМЕДЛЕННО при тапе (до смены фазы),
  /// чтобы подход был зафиксирован даже если пользователь сразу выходит.
  /// _logCurrentSet идемпотентна → повторный вызов из _commitSetAndAdvance
  /// (конец отдыха / skip rest) не создаст дубля.
  Future<void> _onSetDone() async {
    // Логируем текущий подход сразу — ДО смены фазы.
    await _logCurrentSet();
    if (!mounted) return;

    final ex = _currentExercise;
    final isLastSet = _setIndex >= ex.sets - 1;

    if (!isLastSet) {
      // Ещё есть подходы → фаза отдыха.
      // Эффективное время отдыха: per-exercise, если задан явно (#23),
      // иначе — глобальный дефолт из rest_default_provider.
      final restSeconds = effectiveRestSeconds(
        exerciseRestSeconds: ex.restSeconds,
        globalDefaultSeconds: ref.read(restDefaultProvider),
      );
      _animateTransition(() {
        _phase = _TrainerPhase.rest;
        _restSecondsLeft = restSeconds;
        _restPaused = false; // новый отдых всегда стартует «играющим»
      });
      _startRestTimer();
    } else {
      // Последний подход упражнения → отдыха нет, логируем сразу с фактическими.
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
          // Новое упражнение → подставляем его плановые reps/weight.
          _resetSetInputs();
        });
      }
    }
  }

  /// #22+F: завершить текущий подход (записать лог с фактическими значениями) и
  /// перейти к следующему. Вызывается из конца отдыха: авто-таймер и «Пропустить
  /// отдых». _logCurrentSet идемпотентна → дублей нет.
  Future<void> _commitSetAndAdvance() async {
    await _logCurrentSet();
    if (!mounted) return;
    _animateTransition(() {
      _setIndex++;
      _phase = _TrainerPhase.work;
      // Следующий подход того же упражнения → снова плановые значения + сброс флага.
      _resetSetInputs();
    });
  }

  /// Пропустить отдых — логируем подход (фактические значения) и идём дальше.
  void _skipRest() {
    _restTimer?.cancel();
    _commitSetAndAdvance();
  }

  /// Запустить обратный отсчёт отдыха.
  /// Тик уважает паузу: пока _restPaused — отсчёт заморожен и автоперехода нет.
  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // На паузе ничего не делаем — отсчёт стоит, автоперехода нет
      if (_restPaused) return;
      if (_restSecondsLeft <= 1) {
        _restTimer?.cancel();
        // Автопереход: логируем подход с фактическими значениями и идём дальше.
        _commitSetAndAdvance();
      } else {
        setState(() => _restSecondsLeft--);
      }
    });
  }

  /// Переключить паузу/возобновление обратного отсчёта отдыха.
  void _toggleRestPause() {
    if (_restPaused) {
      // Возобновляем: снимаем паузу и перезапускаем тиканье
      setState(() => _restPaused = false);
      _startRestTimer();
    } else {
      // Пауза: останавливаем таймер, сохраняя оставшиеся секунды
      _restTimer?.cancel();
      setState(() => _restPaused = true);
    }
  }

  /// Изменить текущее время отдыха на delta секунд (±15с), с клампом.
  /// Регулировка не меняет состояние паузы: играющий остаётся играющим,
  /// на паузе — на паузе (таймер не перезапускаем).
  void _adjustRest(int delta) {
    setState(() {
      _restSecondsLeft =
          (_restSecondsLeft + delta).clamp(_restMinSeconds, _restMaxSeconds);
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

    // Feature B: однократно подставляем плановые reps/weight первого упражнения
    // как стартовые значения подхода (до первого рендера work-фазы).
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
          // Прогресс «Exercise 2 of 5» — AppBar title через display font
          title: Text(progressLabel),
          actions: [
            // Кнопка «Техника» — открывает ExerciseDetailSheet для текущего
            // упражнения. Скрыта (no-op / не рендерится) если упражнение
            // не найдено в каталоге — безопасно для кастомных упражнений.
            Builder(
              builder: (_) {
                final catalogEntry = exerciseById(ex.name);
                if (catalogEntry == null) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: context.s('exercise.detail.info_tooltip'),
                  onPressed: () => showExerciseDetail(context, catalogEntry),
                );
              },
            ),
            // История текущего упражнения (Feature B) — прошлые подходы +
            // динамика веса. Самая логичная точка входа: пользователь смотрит
            // на упражнение прямо сейчас и хочет понять свой прогресс.
            IconButton(
              icon: const Icon(Icons.show_chart),
              tooltip: context.s('workout.view_history'),
              onPressed: () => context.push(
                '/workouts/exercise/${ex.id}/history'
                '?name=${Uri.encodeQueryComponent(ex.name)}',
              ),
            ),
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
  // #22+F — ввод фактических reps/weight ВО ВРЕМЯ ОТДЫХА
  // Редактируемые поля (клавиатура) + степперы +/-. Пред-заполнены планом,
  // правятся на фактические; лог пишется при завершении отдыха (без дублей).
  // ---------------------------------------------------------------------------

  /// Ряд из двух полей ввода: reps (целое) и weight (кг, шаг 2.5, опционально).
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
            // Пустое поле = собственный вес → плейсхолдер «Bodyweight».
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

  /// Одно поле: подпись + ряд «− [TextField] +».
  /// TextField — клавиатурный ввод (digitsOnly); степперы +/- рядом.
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
        // Подпись поля — bodySmall + textFaint (тихая)
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onMinus,
              icon: const Icon(Icons.remove),
              color: ext.textMuted,
              visualDensity: VisualDensity.compact,
            ),
            // Редактируемое значение с клавиатуры (только цифры).
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
                maxLines: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintStyle:
                      textTheme.bodySmall?.copyWith(color: ext.textFaint),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                ),
              ),
            ),
            IconButton(
              onPressed: onPlus,
              icon: const Icon(Icons.add),
              color: ext.textMuted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
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
    // ACCENT DISCIPLINE: отдых — нейтральный; ember только когда срочно.
    // На паузе отсчёт заморожен → нейтральный textMuted (не «срочный» ember).
    final timerColor =
        (!_restPaused && _restSecondsLeft <= 10) ? ext.ember : ext.textMuted;

    // Заголовок: «Rest» или «Paused» — чтобы заморозка таймера была очевидна
    final restLabel = _restPaused
        ? context.s('workout.rest_paused')
        : context.s('workout.rest_phase');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // «Rest» / «Paused» — titleLarge + textMuted (информационный заголовок).
          // На паузе добавляем иконку паузы, чтобы заморозка читалась с первого взгляда.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_restPaused) ...[
                Icon(Icons.pause, size: 20, color: ext.textMuted),
                const SizedBox(width: 8),
              ],
              Text(
                restLabel,
                style: textTheme.titleLarge?.copyWith(color: ext.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Ряд: −15с · обратный отсчёт · +15с.
          // Кнопки ±15с — нейтральные IconButton (вторичные), отсчёт — дисплей.
          // ACCENT DISCIPLINE: цветной только отсчёт (и то ember лишь когда срочно).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _restSecondsLeft <= _restMinSeconds
                    ? null
                    : () => _adjustRest(-_restAdjustStep),
                icon: const Icon(Icons.remove),
                color: ext.textMuted,
                tooltip: context.s('workout.subtract_time'),
              ),
              const SizedBox(width: 8),
              // Обратный отсчёт — displayLarge (56sp, display serif font).
              // Главный «дисплейный» элемент экрана.
              Text(
                _mmss(_restSecondsLeft),
                style: textTheme.displayLarge?.copyWith(color: timerColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _restSecondsLeft >= _restMaxSeconds
                    ? null
                    : () => _adjustRest(_restAdjustStep),
                icon: const Icon(Icons.add),
                color: ext.textMuted,
                tooltip: context.s('workout.add_time'),
              ),
            ],
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
          const SizedBox(height: 28),
          // #22+F: пока тикает таймер — правим фактические reps/weight ТОЛЬКО ЧТО
          // выполненного подхода. Подпись поясняет, что логируется именно он.
          Text(
            '${context.s('workout.logged_set')} '
            '${context.s('workout.set_label')} ${_setIndex + 1} '
            '${context.s('workout.of')} ${ex.sets}',
            style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _buildSetInputs(context, textTheme, ext),
          const Spacer(),
          // OutlinedButton — пауза/возобновление (вторичное действие, нейтральное).
          // ACCENT DISCIPLINE: не первичное действие → не FilledButton/accent.
          OutlinedButton.icon(
            onPressed: _toggleRestPause,
            icon: Icon(_restPaused ? Icons.play_arrow : Icons.pause),
            label: Text(
              _restPaused
                  ? context.s('workout.resume_rest')
                  : context.s('workout.pause_rest'),
            ),
          ),
          const SizedBox(height: 12),
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
