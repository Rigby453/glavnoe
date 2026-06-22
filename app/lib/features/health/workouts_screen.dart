// Экран «Мои тренировки» (Phase 2).
// Список шаблонов тренировок; шаблон → редактор упражнений.
// Данные локальные (Drift), без синхронизации.
// RESTYLE 2026-06-19: bold design system — typography/color/spacing/buttons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';

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
    final name = await _promptWorkoutName(
      context,
      title: context.s('workout.new_workout'),
    );
    if (name == null || name.isEmpty) return;
    final id = await ref.read(workoutsDaoProvider).createWorkout(name);
    if (context.mounted) context.push('/workouts/$id');
  }

  Future<void> _deleteWorkout(
    BuildContext context,
    WidgetRef ref,
    WorkoutsTableData workout,
  ) async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${workout.name}" — ${ctx.s('workout.delete_title')}'),
        content: Text(ctx.s('workout.delete_body')),
        actions: [
          // Отмена — TextButton (навигационный нудж)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('btn.cancel')),
          ),
          // Удаление — деструктивное действие: ember border + ember foreground
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: ext.ember,
              side: BorderSide(color: ext.ember),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.s('btn.delete')),
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
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final workoutsAsync = ref.watch(workoutsListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.s('workout.title'))),
      // FAB — единственное первичное действие (+ New Workout)
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workouts_add_fab',
        icon: const Icon(Icons.add),
        label: Text(context.s('workout.new_workout')),
        onPressed: () => _newWorkout(context, ref),
      ),
      body: workoutsAsync.when(
        // KaiLoader вместо CircularProgressIndicator
        loading: () => Center(
          child: KaiLoader(label: context.s('loading.workouts')),
        ),
        error: (e, _) => Center(
          child: Text(
            context.s('error.loading_workouts'),
            style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
          ),
        ),
        data: (workouts) {
          if (workouts.isEmpty) return const _EmptyState();
          return ListView(
            // 24dp screen margin — spec §4.1
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            children: [
              const SizedBox(height: 8),
              ...workouts.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WorkoutCard(
                    key: ValueKey(w.id),
                    workout: w,
                    onDelete: () => _deleteWorkout(context, ref, w),
                  ),
                ),
              ),
              const _HistorySection(),
            ],
          );
        },
      ),
    );
  }
}

/// Карточка одной тренировки.
/// ACCENT DISCIPLINE: иконка нейтральная (textMuted); акцент нет.
/// Удаление — ember (деструктивное).
class _WorkoutCard extends ConsumerWidget {
  const _WorkoutCard({
    required this.workout,
    required this.onDelete,
    super.key,
  });

  final WorkoutsTableData workout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final exercises =
        ref.watch(workoutExercisesProvider(workout.id)).valueOrNull ??
            const <WorkoutExercisesTableData>[];
    final count = exercises.length;
    final subtitle = plExercises(context, count);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/workouts/${workout.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка нейтральная — textMuted (не accent, не colorScheme.primary)
              Icon(Icons.fitness_center_outlined, color: ext.textMuted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название тренировки — titleMedium (body font, w600)
                    Text(workout.name, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    // Метаданные — bodySmall + textMuted
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Деструктивная кнопка удаления — ember (не accent)
              IconButton(
                tooltip: context.s('btn.delete'),
                icon: Icon(Icons.delete_outline, color: ext.ember),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// История: последние завершённые сессии.
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    if (sessions.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

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
          '${months[d.month - 1]} ${d.day} · ${plMinutes(context, mins)}';
    }

    return Padding(
      // Отступ сверху от списка тренировок
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок секции — titleMedium (body font, w600, нет serif)
          Text(context.s('workout.history'), style: textTheme.titleMedium),
          const SizedBox(height: 12),
          ...sessions.take(10).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Иконка завершения — success color (не accent)
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: ext.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line(s),
                          // bodySmall + textMuted — метаданные истории
                          style: textTheme.bodySmall?.copyWith(
                            color: ext.textMuted,
                          ),
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

/// Пустое состояние — нет тренировок.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Center(
      child: Padding(
        // 24dp горизонтальный отступ
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка пустого состояния — textFaint (терциарный, самый тихий)
            Icon(Icons.fitness_center_outlined, size: 56, color: ext.textFaint),
            const SizedBox(height: 16),
            Text(
              context.s('workout.empty_state'),
              textAlign: TextAlign.center,
              // bodyMedium + textMuted для пустого состояния
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
          ],
        ),
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
        decoration: InputDecoration(hintText: ctx.s('workout.name_hint')),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        // TextButton — лёгкое действие, навигационный нудж
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.s('btn.cancel')),
        ),
        // FilledButton — единственное основное действие диалога
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(ctx.s('btn.save')),
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
