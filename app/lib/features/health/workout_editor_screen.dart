// Редактор шаблона тренировки (Phase 2).
// Список упражнений: name, sets×reps, вес, отдых.
// Тап → диалог редактирования; свайп → удалить.
// Кнопка «Start workout» не реализована (под-блок 2).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
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
      title: 'Rename workout',
      initial: workout.name,
    );
    if (name != null && name.isNotEmpty && name != workout.name) {
      await ref.read(workoutsDaoProvider).renameWorkout(workout.id, name);
    }
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ExerciseFormResult>(
      context: context,
      builder: (_) => const _ExerciseDialog(title: 'Add exercise'),
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
      builder: (_) => _ExerciseDialog(
        title: 'Edit exercise',
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
    final workout = ref.watch(workoutProvider(workoutId)).valueOrNull;
    final exercises =
        ref.watch(workoutExercisesProvider(workoutId)).valueOrNull ??
            const <WorkoutExercisesTableData>[];

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(workout.name),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(context, ref, workout),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: exercises.isEmpty
                ? _emptyExercises(context)
                : ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, i) {
                      final ex = exercises[i];
                      return Dismissible(
                        key: ValueKey(ex.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Theme.of(context).colorScheme.error,
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        onDismissed: (_) => ref
                            .read(workoutsDaoProvider)
                            .removeExercise(ex.id),
                        child: ListTile(
                          title: Text(ex.name),
                          subtitle: Text(_exerciseSubtitle(ex)),
                          onTap: () => _editExercise(context, ref, ex),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add exercise'),
                  onPressed: () => _addExercise(context, ref),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyExercises(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withAlpha(80);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 56, color: muted),
          const SizedBox(height: 16),
          Text(
            'No exercises yet —\ntap "Add exercise" to get started',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtitle: «3×10 · 40 kg · rest 60s»
// ---------------------------------------------------------------------------

String _exerciseSubtitle(WorkoutExercisesTableData ex) {
  final parts = <String>[];
  parts.add('${ex.sets}×${ex.reps}'); // sets×reps (× = U+00D7)
  if (ex.weightKg != null) {
    final w = ex.weightKg!;
    // Показываем без дробной части если число целое
    final formatted =
        w == w.truncateToDouble() ? '${w.round()} kg' : '$w kg';
    parts.add(formatted);
  }
  parts.add('rest ${ex.restSeconds}s');
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
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Exercise name'),
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
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _reps,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Reps'),
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
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'optional',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rest,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Rest (s)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _technique,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Technique tip',
                hintText: 'optional',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
