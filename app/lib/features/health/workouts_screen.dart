// Экран «Мои тренировки» (Phase 2).
// Список шаблонов тренировок; шаблон → редактор упражнений.
// Данные локальные (Drift), без синхронизации.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

// ---------------------------------------------------------------------------
// Провайдеры (используются и редактором тренировки)
// ---------------------------------------------------------------------------

/// Все шаблоны тренировок, свежие сверху.
final workoutsListProvider =
    StreamProvider.autoDispose<List<WorkoutsTableData>>((ref) {
  return ref.watch(workoutsDaoProvider).watchWorkouts();
});

/// Упражнения одной тренировки (family по id).
final workoutExercisesProvider = StreamProvider.autoDispose
    .family<List<WorkoutExercisesTableData>, String>((ref, workoutId) {
  return ref.watch(workoutsDaoProvider).watchExercises(workoutId);
});

/// Один шаблон по id (null после удаления).
final workoutProvider = StreamProvider.autoDispose
    .family<WorkoutsTableData?, String>((ref, id) {
  return ref.watch(workoutsDaoProvider).watchWorkout(id);
});

/// Завершённые сессии за последние 30 дней (история, свежие сверху).
final recentSessionsProvider =
    StreamProvider.autoDispose<List<WorkoutSessionsTableData>>((ref) {
  return ref.watch(workoutsDaoProvider).watchRecentSessions(30);
});

// ---------------------------------------------------------------------------
// Экран списка
// ---------------------------------------------------------------------------

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  Future<void> _newWorkout(BuildContext context, WidgetRef ref) async {
    final name = await _promptWorkoutName(context, title: 'New workout');
    if (name == null || name.isEmpty) return;
    final id = await ref.read(workoutsDaoProvider).createWorkout(name);
    if (context.mounted) context.push('/workouts/$id');
  }

  Future<void> _deleteWorkout(
    BuildContext context,
    WidgetRef ref,
    WorkoutsTableData workout,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${workout.name}"?'),
        content: const Text('Its exercises will be removed too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(workoutsDaoProvider).deleteWorkout(workout.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutsListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New workout'),
        onPressed: () => _newWorkout(context, ref),
      ),
      body: workouts.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                ...workouts.map(
                  (w) => _WorkoutTile(
                    key: ValueKey(w.id),
                    workout: w,
                    onDelete: () => _deleteWorkout(context, ref, w),
                  ),
                ),
                const _HistorySection(),
              ],
            ),
    );
  }
}

/// История: последние завершённые сессии («Сделал по плану»).
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    if (sessions.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withAlpha(140);

    String line(WorkoutSessionsTableData s) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final d = s.startedAt;
      final mins = s.finishedAt == null
          ? 0
          : s.finishedAt!.difference(s.startedAt).inMinutes;
      return '${s.workoutName} · ${weekdays[d.weekday - 1]}, '
          '${months[d.month - 1]} ${d.day} · $mins min';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...sessions.take(10).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line(s),
                          style: textTheme.bodyMedium?.copyWith(color: muted),
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
}

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({
    required this.workout,
    required this.onDelete,
    super.key,
  });

  final WorkoutsTableData workout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises =
        ref.watch(workoutExercisesProvider(workout.id)).valueOrNull ??
            const <WorkoutExercisesTableData>[];
    final count = exercises.length;
    final subtitle =
        '$count exercise${count == 1 ? '' : 's'}';

    return ListTile(
      leading: const Icon(Icons.fitness_center),
      title: Text(workout.name),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: () => context.push('/workouts/${workout.id}'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withAlpha(80);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 56, color: muted),
          const SizedBox(height: 16),
          Text(
            'No workouts yet — create one\nand add exercises to it',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Общий диалог ввода имени (новая тренировка / переименование)
// ---------------------------------------------------------------------------

Future<String?> _promptWorkoutName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Workout name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Публичная обёртка для редактора (чтобы не дублировать диалог).
Future<String?> promptWorkoutName(
  BuildContext context, {
  required String title,
  String initial = '',
}) =>
    _promptWorkoutName(context, title: title, initial: initial);
