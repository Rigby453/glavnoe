// Экран «Мои тренировки» (Phase 2).
// Список шаблонов тренировок; шаблон → редактор упражнений.
// Данные локальные (Drift), без синхронизации.
// RESTYLE 2026-06-19: bold design system — typography/color/spacing/buttons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/daos/workouts_dao.dart' show ExerciseWithLogs;
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/settings/fab_position_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import 'ai_workout_sheet.dart';
import 'exercise_muscle_groups.dart';

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

/// Упражнения, по которым есть залогированные подходы (для вкладки «Дневник»).
final exercisesWithLogsProvider =
    StreamProvider.autoDispose<List<ExerciseWithLogs>>((ref) {
  return ref.watch(workoutsDaoProvider).watchExercisesWithLogs();
});

// ---------------------------------------------------------------------------
// Вкладки экрана: «Тренировки» (список программ) и «Дневник» (прогресс/история).
// ---------------------------------------------------------------------------

enum _WorkoutsTab { workouts, diary }

// ---------------------------------------------------------------------------
// Экран списка
// ---------------------------------------------------------------------------

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  // Локальный стейт активной вкладки (не выходит за пределы экрана).
  _WorkoutsTab _tab = _WorkoutsTab.workouts;

  Future<void> _newWorkout(BuildContext context) async {
    final name = await _promptWorkoutName(
      context,
      title: context.s('workout.new_workout'),
    );
    if (name == null || name.isEmpty) return;
    final id = await ref.read(workoutsDaoProvider).createWorkout(name);
    if (context.mounted) context.push('/workouts/$id');
  }

  /// Удалить тренировку с возможностью Undo (снапшот упражнений ДО удаления).
  /// Диалог-подтверждения нет: Undo-snackbar — страховка (канон проекта).
  Future<void> _deleteWorkout(
    BuildContext context,
    WorkoutsTableData workout,
  ) async {
    final dao = ref.read(workoutsDaoProvider);
    // Снапшот упражнений ДО каскадного удаления
    final exerciseSnapshot =
        ref.read(workoutExercisesProvider(workout.id)).valueOrNull ??
            const <WorkoutExercisesTableData>[];

    await dao.deleteWorkout(workout.id);

    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${workout.name}" — ${context.s('workout.removed')}',
      onUndo: () async {
        await dao.restoreWorkout(workout, exerciseSnapshot);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWorkoutsTab = _tab == _WorkoutsTab.workouts;
    final fabLocation = ref.watch(fabPositionProvider).fabLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('workout.title')),
        actions: [
          // «Собрать программу» — анкета → шаблонная (free) или AI (premium) программа.
          IconButton(
            tooltip: context.s('workout.ai_title'),
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => showAiWorkoutSheet(context, ref),
          ),
        ],
      ),
      // FAB — только на вкладке «Тренировки» (создание программы). На «Дневнике»
      // создавать нечего — FAB скрыт.
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: isWorkoutsTab
          ? FloatingActionButton(
              heroTag: 'workouts_add_fab',
              tooltip: context.s('workout.new_workout'),
              onPressed: () => _newWorkout(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Переключатель вкладок — SegmentedButton в стиле плана (Day/Week).
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_WorkoutsTab>(
                segments: [
                  ButtonSegment(
                    value: _WorkoutsTab.workouts,
                    label: Text(
                      context.s('workout.tab_workouts'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment(
                    value: _WorkoutsTab.diary,
                    label: Text(
                      context.s('workout.tab_diary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: isWorkoutsTab
                ? _WorkoutsTabView(onDelete: _deleteWorkout)
                : const _DiaryTabView(),
          ),
        ],
      ),
    );
  }
}

/// Вкладка «Тренировки» — список программ + пустое состояние.
class _WorkoutsTabView extends ConsumerWidget {
  const _WorkoutsTabView({required this.onDelete});

  final Future<void> Function(BuildContext, WorkoutsTableData) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final workoutsAsync = ref.watch(workoutsListProvider);

    return workoutsAsync.when(
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
                // SwipeToDelete: свайп влево → удаление + Undo-snackbar
                child: SwipeToDelete(
                  key: ValueKey('workout_${w.id}'),
                  onDelete: () => onDelete(context, w),
                  child: _WorkoutCard(
                    key: ValueKey(w.id),
                    workout: w,
                    onDelete: () => onDelete(context, w),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

/// Вкладка «Дневник» — прогресс/история тренировок:
/// прошлые сессии + прогресс по упражнениям (с логами подходов).
class _DiaryTabView extends ConsumerWidget {
  const _DiaryTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    final exercises =
        ref.watch(exercisesWithLogsProvider).valueOrNull ?? const [];

    // Понятный общий empty-state, если данных нет вообще.
    if (sessions.isEmpty && exercises.isEmpty) {
      return const _DiaryEmptyState();
    }

    return ListView(
      // 24dp экранный отступ — spec §4.1
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
        if (sessions.isNotEmpty) ...[
          _SessionsSection(sessions: sessions),
          const SizedBox(height: 24),
        ],
        if (exercises.isNotEmpty) _ExerciseProgressSection(exercises: exercises),
      ],
    );
  }
}

/// Прошлые сессии: последние завершённые тренировки (дата + длительность).
class _SessionsSection extends StatelessWidget {
  const _SessionsSection({required this.sessions});

  final List<WorkoutSessionsTableData> sessions;

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции — titleMedium (body font, w600, нет serif)
        Text(context.s('workout.diary_sessions'), style: textTheme.titleMedium),
        const SizedBox(height: 12),
        // Каждая сессия — тапабельна → журнал дня «Тренировка <дата>».
        ...sessions.take(10).map(
              (s) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(
                    '/workouts/session/${s.id}'
                    '?date=${Uri.encodeQueryComponent(s.startedAt.toIso8601String())}'
                    '&name=${Uri.encodeQueryComponent(s.workoutName)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
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
                        // Аффорданс «открыть детали дня»
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: ext.textFaint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Прогресс по упражнениям: упражнения с залогированными подходами,
/// СГРУППИРОВАННЫЕ по группе мышц (Part 2). Тап → история подходов
/// конкретного упражнения (exercise_history_screen).
///
/// Группа мышс определяется по имени встроенного упражнения через reverse-lookup
/// из всех локалей (exercise_muscle_groups.dart); кастомные/переименованные
/// упражнения попадают в группу «Other». Заголовок группы скрывается, если
/// упражнения распределились в единственную группу (нечего разделять).
class _ExerciseProgressSection extends StatelessWidget {
  const _ExerciseProgressSection({required this.exercises});

  final List<ExerciseWithLogs> exercises;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Reverse-lookup строится из полной карты строк (все 11 локалей).
    final nameToGroup = buildExerciseNameToGroup(S.all);

    // Бакетим упражнения по группе мышц, сохраняя порядок «свежие первыми»
    // внутри группы (exercises уже отсортированы провайдером).
    final buckets = <MuscleGroup, List<ExerciseWithLogs>>{};
    for (final e in exercises) {
      final g = groupForName(e.name, nameToGroup);
      buckets.putIfAbsent(g, () => []).add(e);
    }
    final usedGroups =
        kMuscleGroupOrder.where((g) => buckets.containsKey(g)).toList();
    // Показывать под-заголовки групп только если групп больше одной.
    final showGroupHeaders = usedGroups.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.s('workout.diary_progress'), style: textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final group in usedGroups) ...[
          if (showGroupHeaders)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8, left: 8),
              child: Text(
                context.s(muscleGroupKey(group)),
                style: textTheme.labelLarge?.copyWith(
                  color: Theme.of(context)
                      .extension<FocusThemeExtension>()!
                      .textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ...buckets[group]!.map((e) => _ExerciseProgressRow(exercise: e)),
        ],
      ],
    );
  }
}

/// Одна строка «Прогресс по упражнению» → тап в историю упражнения.
class _ExerciseProgressRow extends StatelessWidget {
  const _ExerciseProgressRow({required this.exercise});

  final ExerciseWithLogs exercise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(
            '/workouts/exercise/${exercise.exerciseId}/history'
            '?name=${Uri.encodeQueryComponent(exercise.name)}',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                // Иконка прогресса — нейтральная (textMuted)
                Icon(Icons.show_chart, size: 18, color: ext.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: ext.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Пустое состояние «Дневника» — нет ни сессий, ни логов.
class _DiaryEmptyState extends StatelessWidget {
  const _DiaryEmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 56, color: ext.textFaint),
            const SizedBox(height: 16),
            Text(
              context.s('workout.diary_empty'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
          ],
        ),
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
