// Редактор шаблона тренировки (Phase 2).
// Список упражнений: name, sets×reps, вес, отдых.
// Тап → диалог редактирования; свайп → удалить.
// «Start workout» → /workouts/:id/train (режим «тренер», под-блок 2).
// RESTYLE 2026-06-19: bold design system — typography/color/spacing/buttons.
//
// Паттерн безопасного удаления упражнений (ADR-delete-safe):
//   - Свайп влево (SwipeToDelete) ИЛИ кнопка-корзина trailing IconButton
//   - Оба пути идут через _deleteExercise(), который:
//     1. Сохраняет снапшот упражнения ДО удаления
//     2. Удаляет через DAO
//     3. Показывает Undo-snackbar через showUndoSnackBar
//     4. По нажатию Undo: вызывает dao.restoreExercise(snapshot)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/rest_default_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import 'workouts_screen.dart'
    show promptWorkoutName, workoutExercisesProvider, workoutProvider;

// ConsumerStatefulWidget (не ConsumerWidget) — нужен mounted-check
// после асинхронных операций удаления в SwipeToDelete.onDismissed.
class WorkoutEditorScreen extends ConsumerStatefulWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutEditorScreen> createState() =>
      _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends ConsumerState<WorkoutEditorScreen> {

  // --- Действия ---------------------------------------------------------------

  Future<void> _rename(WorkoutsTableData workout) async {
    final name = await promptWorkoutName(
      context,
      title: context.s('workout.rename_title'),
      initial: workout.name,
    );
    if (name != null && name.isNotEmpty && name != workout.name) {
      await ref.read(workoutsDaoProvider).renameWorkout(workout.id, name);
    }
  }

  Future<void> _addExercise() async {
    // Читаем глобальный дефолт отдыха, чтобы новое упражнение показывало
    // и сохраняло именно это значение — card == training с первого раза.
    final globalRestSeconds = ref.read(restDefaultProvider);
    final result = await showDialog<_ExerciseFormResult>(
      context: context,
      builder: (ctx) => _ExerciseDialog(
        title: ctx.s('workout.add_exercise_title'),
        defaultRestSeconds: globalRestSeconds,
      ),
    );
    if (result == null) return;
    await ref.read(workoutsDaoProvider).addExercise(
          workoutId: widget.workoutId,
          name: result.name,
          sets: result.sets,
          reps: result.reps,
          weightKg: result.weightKg,
          restSeconds: result.restSeconds,
          technique: result.technique,
        );
  }

  Future<void> _editExercise(WorkoutExercisesTableData ex) async {
    final globalRestSeconds = ref.read(restDefaultProvider);
    final result = await showDialog<_ExerciseFormResult>(
      context: context,
      builder: (ctx) => _ExerciseDialog(
        title: ctx.s('workout.edit_exercise_title'),
        initial: ex,
        defaultRestSeconds: globalRestSeconds,
      ),
    );
    if (result == null) return;
    await ref.read(workoutsDaoProvider).updateExercise(
          ex.id,
          name: result.name,
          sets: result.sets,
          reps: result.reps,
          weightKg: result.weightKg,
          clearWeight: result.weightKg == null,
          restSeconds: result.restSeconds,
          technique: result.technique,
          clearTechnique: result.technique == null || result.technique!.isEmpty,
        );
  }

  // --- Единый путь удаления упражнения + Undo ---------------------------------

  /// Удалить упражнение и показать Undo-snackbar.
  /// Вызывается как из SwipeToDelete.onDelete, так и из кнопки-корзины.
  Future<void> _deleteExercise(WorkoutExercisesTableData ex) async {
    // Снапшот ДО удаления — для восстановления по Undo
    final snapshot = ex;
    final dao = ref.read(workoutsDaoProvider);

    await dao.removeExercise(snapshot.id);

    if (!mounted) return;

    // Сообщение: имя упражнения + ключ 'workout.exercise_removed'
    final message = '"${snapshot.name}" — ${context.s('workout.exercise_removed')}';
    showUndoSnackBar(
      context,
      message: message,
      onUndo: () async {
        await dao.restoreExercise(snapshot);
      },
    );
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    // Глобальный дефолт отдыха — для отображения «Default (MM:SS)» в карточках.
    final globalDefaultSeconds = ref.watch(restDefaultProvider);

    final workout = ref.watch(workoutProvider(widget.workoutId)).valueOrNull;
    final exercises =
        ref.watch(workoutExercisesProvider(widget.workoutId)).valueOrNull ??
            const <WorkoutExercisesTableData>[];

    // Загрузка данных — KaiLoader вместо CircularProgressIndicator
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: KaiLoader(label: context.s('loading.generic'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Название тренировки — через AppBarTheme (titleTextStyle = display font 22sp)
        title: Text(workout.name),
        actions: [
          // TextButton — лёгкое действие (переименование)
          TextButton.icon(
            icon: Icon(Icons.edit_outlined, size: 18, color: ext.textMuted),
            label: Text(
              context.s('workout.rename'),
              style: textTheme.labelLarge?.copyWith(
                color: ext.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            onPressed: () => _rename(workout),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: exercises.isEmpty
                ? _emptyExercises(context, ext, textTheme)
                : ListView.builder(
                    // 24dp горизонтальный отступ; 16dp сверху
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    itemCount: exercises.length,
                    itemBuilder: (context, i) {
                      final ex = exercises[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        // SwipeToDelete: свайп влево → _deleteExercise
                        child: SwipeToDelete(
                          key: ValueKey(ex.id),
                          onDelete: () => _deleteExercise(ex),
                          child: _ExerciseCard(
                            exercise: ex,
                            onTap: () => _editExercise(ex),
                            onDelete: () => _deleteExercise(ex),
                            onHistory: () => context.push(
                              '/workouts/exercise/${ex.id}/history'
                              '?name=${Uri.encodeQueryComponent(ex.name)}',
                            ),
                            ext: ext,
                            textTheme: textTheme,
                            globalDefaultSeconds: globalDefaultSeconds,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Нижняя панель кнопок
          SafeArea(
            top: false,
            child: Padding(
              // 24dp горизонтальный отступ — spec §4.1
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  // OutlinedButton — вторичное повторяемое действие
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.s('workout.add_exercise')),
                      onPressed: _addExercise,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // FilledButton — единственная первичная CTA (Start workout)
                  // ACCENT DISCIPLINE: только этот элемент получает accent fill
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        Icons.play_arrow,
                        size: 18,
                        color: colorScheme.onPrimary,
                      ),
                      label: Text(context.s('workout.start_workout')),
                      onPressed: exercises.isEmpty
                          ? null
                          : () => context.push('/workouts/${widget.workoutId}/train'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyExercises(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка пустого состояния — textFaint (тихий, не акцентный)
            Icon(
              Icons.fitness_center_outlined,
              size: 56,
              color: ext.textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              context.s('workout.empty_exercises'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка упражнения (заменяет ListTile — больше воздуха, card container)
// ---------------------------------------------------------------------------

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
    required this.onDelete,
    required this.onHistory,
    required this.ext,
    required this.textTheme,
    required this.globalDefaultSeconds,
  });

  final WorkoutExercisesTableData exercise;
  final VoidCallback onTap;
  /// Колбэк удаления — вызывается из кнопки-корзины trailing
  final VoidCallback onDelete;
  /// Колбэк перехода к истории упражнения (Feature B) — иконка-график
  final VoidCallback onHistory;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  /// Глобальный дефолт отдыха из restDefaultProvider — для отображения
  /// «Default (MM:SS)» когда restSeconds == kUseDefaultRest/-1 или 60.
  final int globalDefaultSeconds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка нейтральная — textMuted (не accent)
              Icon(Icons.accessibility_new_outlined, color: ext.textMuted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название упражнения — titleSmall (body font, w600, 14sp)
                    Text(exercise.name, style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    // Метаданные сетов/повторов — bodySmall + textMuted
                    Text(
                      _exerciseSubtitle(context, exercise, globalDefaultSeconds),
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textMuted,
                      ),
                    ),
                    // Техника (опционально) — bodySmall + textFaint
                    if (exercise.technique != null &&
                        exercise.technique!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.technique!,
                        style: textTheme.bodySmall?.copyWith(
                          color: ext.textFaint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Кнопка истории упражнения (Feature B) — прошлые подходы + динамика.
              // textMuted (не textFaint): это самостоятельная точка входа в
              // дневник упражнения, она должна замечаться, а не теряться.
              IconButton(
                icon: Icon(
                  Icons.show_chart,
                  size: 20,
                  color: ext.textMuted,
                ),
                tooltip: context.s('workout.view_history'),
                onPressed: onHistory,
              ),
              // Кнопка-корзина — второй способ удаления помимо свайпа
              // textFaint цвет — мягкий, не агрессивный
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: ext.textFaint,
                ),
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
// Subtitle: «3×10 · 40 kg · rest Default (02:00)» или «rest 90s»
// ---------------------------------------------------------------------------

/// Форматирует секунды как MM:SS (например 120 → «02:00»).
String _mmss(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _exerciseSubtitle(
  BuildContext context,
  WorkoutExercisesTableData ex,
  int globalDefaultSeconds,
) {
  final parts = <String>[];
  parts.add('${ex.sets}×${ex.reps}'); // sets×reps (× = U+00D7)
  if (ex.weightKg != null) {
    final w = ex.weightKg!;
    // Показываем без дробной части если число целое
    final formatted =
        w == w.truncateToDouble() ? '${w.round()} kg' : '$w kg';
    parts.add(formatted);
  }
  // Отдых: «Default (MM:SS)» для сентинелей, «Ns» для явных значений.
  final restStr = isUseDefaultRest(ex.restSeconds)
      ? context
          .s('workout.rest_default_fmt')
          .replaceAll('{value}', _mmss(globalDefaultSeconds))
      : '${ex.restSeconds}s';
  parts.add('${context.s('workout.rest_phase')} $restStr');
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Результат диалога редактирования упражнения
// ---------------------------------------------------------------------------

class _ExerciseFormResult {
  const _ExerciseFormResult({
    required this.name,
    required this.sets,
    required this.reps,
    this.weightKg,
    required this.restSeconds,
    this.technique,
  });

  final String name;
  final int sets;
  final int reps;
  final double? weightKg;
  final int restSeconds;
  final String? technique;
}

// ---------------------------------------------------------------------------
// Диалог создания / редактирования упражнения
// ---------------------------------------------------------------------------

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({
    required this.title,
    this.initial,
    this.defaultRestSeconds = kUseDefaultRest,
  });

  final String title;
  final WorkoutExercisesTableData? initial;

  /// Разрешённое глобальное время отдыха (секунды, из restDefaultProvider).
  /// Показывается как плейсхолдер поля отдыха когда поле пустое
  /// («Default (MM:SS)»). Не используется как сохраняемое значение — пустое
  /// поле сохраняется как kUseDefaultRest (-1), явно введённое число — как есть.
  final int defaultRestSeconds;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late final TextEditingController _name;
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  late final TextEditingController _technique;

  @override
  void initState() {
    super.initState();
    final ex = widget.initial;
    _name = TextEditingController(text: ex?.name ?? '');
    _sets = TextEditingController(text: (ex?.sets ?? 3).toString());
    _reps = TextEditingController(text: (ex?.reps ?? 10).toString());
    _weight = TextEditingController(
      text: ex?.weightKg != null ? ex!.weightKg.toString() : '',
    );
    // Поле отдыха:
    //   - Новое упражнение (ex == null): пустое — плейсхолдер покажет «Default (MM:SS)»;
    //     пользователь видит глобальный дефолт, сохраняется kUseDefaultRest (-1).
    //   - Существующее упражнение: сентинель (kUseDefaultRest или 60) → пустое
    //     (значение остаётся «по умолчанию»); явное значение → показываем цифру.
    final storedRest = ex?.restSeconds;
    final showEmpty =
        storedRest == null || isUseDefaultRest(storedRest);
    _rest = TextEditingController(text: showEmpty ? '' : storedRest.toString());
    _technique = TextEditingController(text: ex?.technique ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    _technique.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final sets = int.tryParse(_sets.text.trim()) ?? 3;
    final reps = int.tryParse(_reps.text.trim()) ?? 10;
    final weightKg = double.tryParse(_weight.text.trim());
    // Поле отдыха: пустое → kUseDefaultRest (тренажёр возьмёт глобальный дефолт);
    // введённое число → явное per-exercise значение (хранится как есть).
    final restTrimmed = _rest.text.trim();
    final parsedRest = int.tryParse(restTrimmed);
    final restSeconds =
        (restTrimmed.isEmpty || parsedRest == null) ? kUseDefaultRest : parsedRest;
    final technique = _technique.text.trim().isEmpty
        ? null
        : _technique.text.trim();

    // restSeconds: kUseDefaultRest (-1) проходит без клампа; явные значения зажаты
    // в [0, kRestDefaultMaxSeconds] (тот же лимит, что показан в helperText).
    final clampedRest = restSeconds == kUseDefaultRest
        ? restSeconds
        : restSeconds.clamp(0, kRestDefaultMaxSeconds);

    Navigator.of(context).pop(_ExerciseFormResult(
      name: name,
      sets: sets.clamp(1, 999),
      reps: reps.clamp(1, 999),
      weightKg: weightKg,
      restSeconds: clampedRest,
      technique: technique,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // headlineSmall через AlertDialog — наследует titleTextStyle из ThemeData
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.s('workout.exercise_name'),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sets,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.s('workout.sets'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _reps,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.s('workout.reps'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: context.s('workout.weight_kg'),
                      hintText: context.s('workout.optional'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rest,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.s('workout.rest_s'),
                      // Плейсхолдер «Default (MM:SS)» — показывает глобальный дефолт,
                      // когда поле пустое (= kUseDefaultRest будет сохранён).
                      hintText: widget.defaultRestSeconds > 0
                          ? context
                              .s('workout.rest_default_fmt')
                              .replaceAll(
                                  '{value}',
                                  _mmss(widget.defaultRestSeconds))
                          : null,
                      // Лимит отдыха (clamp(0, 3600) в _submit) показан явно
                      // в минутах, чтобы большие значения не обрезались молча.
                      helperText: context
                          .s('common.max_value_hint')
                          .replaceAll(
                              '{n}', (kRestDefaultMaxSeconds ~/ 60).toString()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _technique,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.s('workout.technique_tip'),
                hintText: context.s('workout.optional'),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        // TextButton — отмена (навигационный нудж, не основное действие)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        // FilledButton — единственное первичное действие диалога (Save)
        FilledButton(
          onPressed: _submit,
          child: Text(context.s('btn.save')),
        ),
      ],
    );
  }
}

/// Тестовая обёртка: возвращает приватный диалог добавления упражнения, чтобы
/// его можно было запумпить в виджет-тесте (проверка helperText лимита отдыха,
/// overflow) без БД и провайдеров. Не использовать в продакшен-коде.
@visibleForTesting
Widget exerciseDialogForTest({String title = 'Add exercise'}) =>
    _ExerciseDialog(title: title);
