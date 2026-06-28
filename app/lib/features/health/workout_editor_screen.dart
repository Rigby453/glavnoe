// Редактор шаблона тренировки (Phase 2) — Kaname redesign §D.
// Список упражнений: name, sets×reps, вес, отдых.
// Тап → диалог редактирования; свайп → удалить.
// «Start workout» → /workouts/:id/train (режим «тренер»).
// Cards §4.2: surface1 + 0.5dp hairline + R14. Phosphor icons.
//
// Паттерн безопасного удаления упражнений (ADR-delete-safe):
//   - Свайп влево (SwipeToDelete) ИЛИ кнопка-корзина trailing IconButton
//   - Оба пути идут через _deleteExercise(), который:
//     1. Сохраняет снапшот ДО удаления
//     2. Удаляет через DAO
//     3. Показывает Undo-snackbar через showUndoSnackBar
//     4. По нажатию Undo: вызывает dao.restoreExercise(snapshot)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/rest_default_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../features/mascot/kai_mascot.dart';
import 'workouts_screen.dart'
    show promptWorkoutName, workoutExercisesProvider, workoutProvider;

class WorkoutEditorScreen extends ConsumerStatefulWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutEditorScreen> createState() =>
      _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends ConsumerState<WorkoutEditorScreen> {

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

  Future<void> _deleteExercise(WorkoutExercisesTableData ex) async {
    final snapshot = ex;
    final dao = ref.read(workoutsDaoProvider);
    await dao.removeExercise(snapshot.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: '"${snapshot.name}" — ${context.s('workout.exercise_removed')}',
      onUndo: () async {
        await dao.restoreExercise(snapshot);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final globalDefaultSeconds = ref.watch(restDefaultProvider);

    final workout = ref.watch(workoutProvider(widget.workoutId)).valueOrNull;
    final exercises =
        ref.watch(workoutExercisesProvider(widget.workoutId)).valueOrNull ??
            const <WorkoutExercisesTableData>[];

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: KaiLoader(label: context.s('loading.generic'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(workout.name),
        actions: [
          // Phosphor pencilSimple — переименование
          TextButton.icon(
            icon: Icon(PhosphorIcons.pencilSimple(), size: 16, color: ext.textMuted),
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
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    itemCount: exercises.length,
                    itemBuilder: (context, i) {
                      final ex = exercises[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.plus(), size: 18),
                      label: Text(context.s('workout.add_exercise')),
                      onPressed: _addExercise,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // FilledButton — единственная primary CTA (Start workout)
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        PhosphorIcons.play(PhosphorIconsStyle.fill),
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
            const KaiMascot(size: 64, emotion: KaiEmotion.neutral),
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
// Карточка упражнения — §4.2: surface1 + 0.5dp hairline + R14
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
  final VoidCallback onDelete;
  final VoidCallback onHistory;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final int globalDefaultSeconds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              // Barbell icon — нейтральная textMuted
              Icon(PhosphorIcons.barbell(), size: 20, color: ext.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _exerciseSubtitle(context, exercise, globalDefaultSeconds),
                      style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (exercise.technique != null &&
                        exercise.technique!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        exercise.technique!,
                        style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // История — chartLineUp, textMuted (самостоятельная точка входа)
              IconButton(
                icon: Icon(PhosphorIcons.chartLineUp(), size: 18, color: ext.textMuted),
                tooltip: context.s('workout.view_history'),
                onPressed: onHistory,
                visualDensity: VisualDensity.compact,
              ),
              // Удалить — trash, textFaint (мягче)
              IconButton(
                icon: Icon(PhosphorIcons.trash(), size: 18, color: ext.textFaint),
                tooltip: context.s('btn.delete'),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtitle: «3×10 · 40 kg · rest Default (02:00)»
// ---------------------------------------------------------------------------

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
  parts.add('${ex.sets}×${ex.reps}');
  if (ex.weightKg != null) {
    final w = ex.weightKg!;
    final wStr = w == w.truncateToDouble() ? '${w.round()}' : '$w';
    parts.add('$wStr ${context.s('workout.weight_short')}');
  }
  final restStr = isUseDefaultRest(ex.restSeconds)
      ? context
          .s('workout.rest_default_fmt')
          .replaceAll('{value}', _mmss(globalDefaultSeconds))
      : '${ex.restSeconds}${context.s('workout.seconds_short')}';
  parts.add('${context.s('workout.rest_phase')} $restStr');
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Результат диалога редактирования
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
    final storedRest = ex?.restSeconds;
    final showEmpty = storedRest == null || isUseDefaultRest(storedRest);
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
    final restTrimmed = _rest.text.trim();
    final parsedRest = int.tryParse(restTrimmed);
    final restSeconds =
        (restTrimmed.isEmpty || parsedRest == null) ? kUseDefaultRest : parsedRest;
    final technique = _technique.text.trim().isEmpty
        ? null
        : _technique.text.trim();
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
                      hintText: widget.defaultRestSeconds > 0
                          ? context
                              .s('workout.rest_default_fmt')
                              .replaceAll(
                                  '{value}',
                                  _mmss(widget.defaultRestSeconds))
                          : null,
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.s('btn.save')),
        ),
      ],
    );
  }
}

/// Тестовая обёртка.
@visibleForTesting
Widget exerciseDialogForTest({String title = 'Add exercise'}) =>
    _ExerciseDialog(title: title);
