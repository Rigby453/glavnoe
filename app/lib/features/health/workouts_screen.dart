// Экран «Мои тренировки» (Phase 2) — Kaname redesign §D.
// Список шаблонов тренировок; шаблон → редактор упражнений.
// Данные локальные (Drift), без синхронизации.
// Segment «Workouts / Diary»; program cards §4.2; diary = past sessions +
// per-exercise progress grouped by muscle. FAB → new program via FilledButton.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/daos/workouts_dao.dart' show ExerciseWithLogs;
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../features/mascot/kai_mascot.dart';
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
// Вкладки экрана
// ---------------------------------------------------------------------------

enum _WorkoutsTab { workouts, diary }

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
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

  Future<void> _deleteWorkout(
    BuildContext context,
    WorkoutsTableData workout,
  ) async {
    final dao = ref.read(workoutsDaoProvider);
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('workout.title')),
        actions: [
          // Phosphor sparkle — AI программа
          IconButton(
            tooltip: context.s('workout.ai_title'),
            icon: Icon(PhosphorIcons.sparkle()),
            onPressed: () => showAiWorkoutSheet(context, ref),
          ),
        ],
      ),
      // FAB — только на вкладке «Тренировки»
      floatingActionButton: isWorkoutsTab
          ? FloatingActionButton(
              heroTag: 'workouts_add_fab',
              tooltip: context.s('workout.new_workout'),
              onPressed: () => _newWorkout(context),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Icon(PhosphorIcons.plus()),
            )
          : null,
      body: Column(
        children: [
          // Сегментный переключатель Kaname-style
          _SegmentBar(
            tab: _tab,
            ext: ext,
            colorScheme: colorScheme,
            onChanged: (t) => setState(() => _tab = t),
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

// ---------------------------------------------------------------------------
// Сегментный переключатель (§4.2 — hairline, accentTint при выборе)
// ---------------------------------------------------------------------------

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.tab,
    required this.ext,
    required this.colorScheme,
    required this.onChanged,
  });

  final _WorkoutsTab tab;
  final FocusThemeExtension ext;
  final ColorScheme colorScheme;
  final ValueChanged<_WorkoutsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: ext.border, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: context.s('workout.tab_workouts'),
            selected: tab == _WorkoutsTab.workouts,
            ext: ext,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isFirst: true,
            onTap: () => onChanged(_WorkoutsTab.workouts),
          ),
          Container(width: 0.5, color: ext.border),
          _SegmentItem(
            label: context.s('workout.tab_diary'),
            selected: tab == _WorkoutsTab.diary,
            ext: ext,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isFirst: false,
            onTap: () => onChanged(_WorkoutsTab.diary),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.ext,
    required this.colorScheme,
    required this.textTheme,
    required this.isFirst,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final FocusThemeExtension ext;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: selected ? ext.accentTint : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(11) : Radius.zero,
              right: !isFirst ? const Radius.circular(11) : Radius.zero,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: selected ? colorScheme.primary : ext.textMuted,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вкладка «Тренировки» — список программ
// ---------------------------------------------------------------------------

class _WorkoutsTabView extends ConsumerWidget {
  const _WorkoutsTabView({required this.onDelete});

  final Future<void> Function(BuildContext, WorkoutsTableData) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final workoutsAsync = ref.watch(workoutsListProvider);

    return workoutsAsync.when(
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
          children: [
            ...workouts.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

/// Карточка одной программы тренировки — §4.2 object card:
/// surface1 + 0.5dp hairline + R14, leading barbell icon, trailing trash/chevron.
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
    final colorScheme = Theme.of(context).colorScheme;

    final exercises =
        ref.watch(workoutExercisesProvider(workout.id)).valueOrNull ??
            const <WorkoutExercisesTableData>[];
    final subtitle = plExercises(context, exercises.length);

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/workouts/${workout.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              // Barbell icon — textMuted (нейтральная)
              Icon(PhosphorIcons.barbell(), size: 20, color: ext.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Удалить — ember (деструктивное)
              IconButton(
                tooltip: context.s('btn.delete'),
                icon: Icon(PhosphorIcons.trash(), size: 18, color: ext.ember),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
              Icon(
                PhosphorIcons.caretRight(),
                size: 16,
                color: ext.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вкладка «Дневник» — прошлые сессии + прогресс по упражнениям
// ---------------------------------------------------------------------------

class _DiaryTabView extends ConsumerWidget {
  const _DiaryTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    final exercises =
        ref.watch(exercisesWithLogsProvider).valueOrNull ?? const [];

    if (sessions.isEmpty && exercises.isEmpty) {
      return const _DiaryEmptyState();
    }

    return ListView(
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

/// Прошлые сессии — hairline-divided rows (§4.2 dense list).
class _SessionsSection extends StatelessWidget {
  const _SessionsSection({required this.sessions});

  final List<WorkoutSessionsTableData> sessions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    String line(WorkoutSessionsTableData s) {
      final d = s.startedAt;
      final mins = s.finishedAt == null
          ? 0
          : s.finishedAt!.difference(s.startedAt).inMinutes;
      final dateStr = DateFormat('EEE, MMM d').format(d);
      return '${s.workoutName} · $dateStr · ${plMinutes(context, mins)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.s('workout.diary_sessions'), style: textTheme.titleSmall?.copyWith(color: ext.textMuted)),
        const SizedBox(height: 8),
        // Hairline-divided list (§4.2 dense list)
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: ext.border, width: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < sessions.take(10).length; i++) ...[
                if (i > 0)
                  Divider(height: 0, thickness: 0.5, color: ext.border, indent: 44),
                _SessionRow(
                  session: sessions[i],
                  line: line(sessions[i]),
                  ext: ext,
                  textTheme: textTheme,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.line,
    required this.ext,
    required this.textTheme,
  });

  final WorkoutSessionsTableData session;
  final String line;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        '/workouts/session/${session.id}'
        '?date=${Uri.encodeQueryComponent(session.startedAt.toIso8601String())}'
        '&name=${Uri.encodeQueryComponent(session.workoutName)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              size: 18,
              color: ext.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                line,
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(PhosphorIcons.caretRight(), size: 14, color: ext.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Прогресс по упражнениям, сгруппированный по группе мышц.
class _ExerciseProgressSection extends StatelessWidget {
  const _ExerciseProgressSection({required this.exercises});

  final List<ExerciseWithLogs> exercises;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final nameToGroup = buildExerciseNameToGroup(S.all);
    final buckets = <MuscleGroup, List<ExerciseWithLogs>>{};
    for (final e in exercises) {
      final g = groupForName(e.name, nameToGroup);
      buckets.putIfAbsent(g, () => []).add(e);
    }
    final usedGroups =
        kMuscleGroupOrder.where((g) => buckets.containsKey(g)).toList();
    final showGroupHeaders = usedGroups.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.s('workout.diary_progress'), style: textTheme.titleSmall?.copyWith(color: ext.textMuted)),
        const SizedBox(height: 8),
        for (final group in usedGroups) ...[
          if (showGroupHeaders)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                context.s(muscleGroupKey(group)),
                style: textTheme.labelSmall?.copyWith(
                  color: ext.textFaint,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Hairline-divided list per group
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: ext.border, width: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < buckets[group]!.length; i++) ...[
                  if (i > 0)
                    Divider(height: 0, thickness: 0.5, color: ext.border, indent: 44),
                  _ExerciseProgressRow(exercise: buckets[group]![i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ExerciseProgressRow extends StatelessWidget {
  const _ExerciseProgressRow({required this.exercise});

  final ExerciseWithLogs exercise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        '/workouts/exercise/${exercise.exerciseId}/history'
        '?name=${Uri.encodeQueryComponent(exercise.name)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Icon(PhosphorIcons.chartLineUp(), size: 18, color: ext.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                exercise.name,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(PhosphorIcons.caretRight(), size: 14, color: ext.textFaint),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Пустые состояния
// ---------------------------------------------------------------------------

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
            const KaiMascot(size: 64, emotion: KaiEmotion.neutral),
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KaiMascot(size: 64, emotion: KaiEmotion.neutral),
            const SizedBox(height: 16),
            Text(
              context.s('workout.empty_state'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 20),
            // Единственная CTA пустого состояния
            FilledButton.icon(
              icon: Icon(PhosphorIcons.plus(), size: 18),
              label: Text(context.s('workout.new_workout')),
              onPressed: () async {
                final name = await _promptWorkoutName(
                  context,
                  title: context.s('workout.new_workout'),
                );
                if (name == null || name.isEmpty) return;
                final id =
                    await ref.read(workoutsDaoProvider).createWorkout(name);
                if (context.mounted) context.push('/workouts/$id');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Общий диалог ввода имени
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
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(ctx.s('btn.save')),
        ),
      ],
    ),
  );
}

/// Публичная обёртка для редактора.
Future<String?> promptWorkoutName(
  BuildContext context, {
  required String title,
  String initial = '',
}) =>
    _promptWorkoutName(context, title: title, initial: initial);
