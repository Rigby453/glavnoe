// Редактор шаблона тренировки (Phase 2).
// Список упражнений: name, sets×reps, вес, отдых.
// Тап → диалог редактирования; свайп → удалить.
// «Start workout» → /workouts/:id/train (режим «тренер», под-блок 2).
// RESTYLE 2026-06-19: bold design system — typography/color/spacing/buttons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import 'workouts_screen.dart'
    show promptWorkoutName, workoutExercisesProvider, workoutProvider;

class WorkoutEditorScreen extends ConsumerWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId});

  final String workoutId;

  // --- Действия ---------------------------------------------------------------

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    WorkoutsTableData workout,
  ) async {
    final name = await promptWorkoutName(
      context,
      title: context.s('workout.rename_title'),
      initial: workout.name,
    );
    if (name != null && name.isNotEmpty && name != workout.name) {
      await ref.read(workoutsDaoProvider).renameWorkout(workout.id, name);
    }
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ExerciseFormResult>(
      context: context,
      builder: (ctx) => _ExerciseDialog(title: ctx.s('workout.add_exercise_title')),
    );
    if (result == null) return;
    await ref.read(workoutsDaoProvider).addExercise(
          workoutId: workoutId,
          name: result.name,
          sets: result.sets,
          reps: result.reps,
          weightKg: result.weightKg,
          restSeconds: result.restSeconds,
          technique: result.technique,
        );
  }

  Future<void> _editExercise(
    BuildContext context,
    WidgetRef ref,
    WorkoutExercisesTableData ex,
  ) async {
    final result = await showDialog<_ExerciseFormResult>(
      context: context,
      builder: (ctx) => _ExerciseDialog(
        title: ctx.s('workout.edit_exercise_title'),
        initial: ex,
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

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final workout = ref.watch(workoutProvider(workoutId)).valueOrNull;
    final exercises =
        ref.watch(workoutExercisesProvider(workoutId)).valueOrNull ??
            const <WorkoutExercisesTableData>[];

    // Загрузка данных — KaiLoader вместо CircularProgressIndicator
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: KaiLoader(label: 'Loading…')),
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
            onPressed: () => _rename(context, ref, workout),
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
                        child: Dismissible(
                          key: ValueKey(ex.id),
                          direction: DismissDirection.endToStart,
                          // Фон свайпа — ember (деструктивное действие)
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: ext.ember.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: ext.ember,
                            ),
                          ),
                          onDismissed: (_) => ref
                              .read(workoutsDaoProvider)
                              .removeExercise(ex.id),
                          child: _ExerciseCard(
                            exercise: ex,
                            onTap: () => _editExercise(context, ref, ex),
                            ext: ext,
                            textTheme: textTheme,
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
                      onPressed: () => _addExercise(context, ref),
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
                          : () => context.push('/workouts/$workoutId/train'),
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
    required this.ext,
    required this.textTheme,
  });

  final WorkoutExercisesTableData exercise;
  final VoidCallback onTap;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

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
                      _exerciseSubtitle(context, exercise),
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
              // Стрелка вправо — textFaint (не accent)
              Icon(Icons.chevron_right, color: ext.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtitle: «3×10 · 40 kg · rest 60s»
// ---------------------------------------------------------------------------

String _exerciseSubtitle(BuildContext context, WorkoutExercisesTableData ex) {
  final parts = <String>[];
  parts.add('${ex.sets}×${ex.reps}'); // sets×reps (× = U+00D7)
  if (ex.weightKg != null) {
    final w = ex.weightKg!;
    // Показываем без дробной части если число целое
    final formatted =
        w == w.truncateToDouble() ? '${w.round()} kg' : '$w kg';
    parts.add(formatted);
  }
  // «rest Ns»
  parts.add('${context.s('workout.rest_phase')} ${ex.restSeconds}s');
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
  });

  final String title;
  final WorkoutExercisesTableData? initial;

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
    _rest = TextEditingController(
        text: (ex?.restSeconds ?? 60).toString());
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
    final restSeconds = int.tryParse(_rest.text.trim()) ?? 60;
    final technique = _technique.text.trim().isEmpty
        ? null
        : _technique.text.trim();

    Navigator.of(context).pop(_ExerciseFormResult(
      name: name,
      sets: sets.clamp(1, 999),
      reps: reps.clamp(1, 999),
      weightKg: weightKg,
      restSeconds: restSeconds.clamp(0, 3600),
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
