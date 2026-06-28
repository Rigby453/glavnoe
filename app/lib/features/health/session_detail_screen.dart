// Экран «Тренировка <дата>» — перестилизован под «Kaname» redesign (Phosphor + §4.2).
// Бизнес-логика (список упражнений + подходы из Drift, sessionSetGroupsProvider) СОХРАНЕНА.
// Изменения: Phosphor barbell, hairline-разделители между упражнениями, чистая типографика.
//
// Офлайн-первый: данные только из Drift через WorkoutsDao.watchSessionSetGroups.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/daos/workouts_dao.dart' show ExerciseSetGroup;
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

/// Группы подходов одной сессии, сгруппированные по упражнению.
final sessionSetGroupsProvider = StreamProvider.autoDispose
    .family<List<ExerciseSetGroup>, String>((ref, sessionId) {
  return ref.watch(workoutsDaoProvider).watchSessionSetGroups(sessionId);
});

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.startedAt,
    this.workoutName,
  });

  final String sessionId;

  /// Время начала сессии — для заголовка-даты.
  final DateTime? startedAt;

  /// Имя тренировки — подзаголовок (опционально).
  final String? workoutName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final title = startedAt != null
        ? DateFormat('EEE, MMM d').format(startedAt!)
        : context.s('workout.session_title');

    final groupsAsync = ref.watch(sessionSetGroupsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (workoutName != null && workoutName!.isNotEmpty)
              Text(
                workoutName!,
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: groupsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _emptyState(context, ext, textTheme),
        data: (groups) {
          if (groups.isEmpty) return _emptyState(context, ext, textTheme);
          return _ExerciseList(groups: groups, ext: ext, textTheme: textTheme);
        },
      ),
    );
  }

  Widget _emptyState(
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
            // Phosphor barbell — placeholder вместо KaiMascot (не реализован).
            Icon(
              PhosphorIcons.barbell(),
              size: 56,
              color: ext.textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              context.s('workout.session_empty'),
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
// Список упражнений: hairline-разделители между блоками (§4.2 dense list).
// ---------------------------------------------------------------------------

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.groups,
    required this.ext,
    required this.textTheme,
  });

  final List<ExerciseSetGroup> groups;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      itemCount: groups.length,
      separatorBuilder: (_, __) => Divider(
        height: 32,
        thickness: 0.5,
        color: ext.border,
      ),
      itemBuilder: (context, i) => _ExerciseBlock(
        group: groups[i],
        ext: ext,
        textTheme: textTheme,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Блок упражнения: имя + список подходов.
// ---------------------------------------------------------------------------

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.group,
    required this.ext,
    required this.textTheme,
  });

  final ExerciseSetGroup group;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final name = group.name ?? context.s('workout.deleted_exercise');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Маленький Phosphor barbell — идентификатор упражнения.
            Icon(PhosphorIcons.barbell(), size: 16, color: ext.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final log in group.sets)
          _SetRow(log: log, ext: ext, textTheme: textTheme),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Строка подхода: «Set N · 12 × 40 kg».
// ---------------------------------------------------------------------------

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.log,
    required this.ext,
    required this.textTheme,
  });

  final WorkoutSetLogsTableData log;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final weight = _formatWeight(context, log.weightKg);
    // «Подход N» — локализованный префикс (setIndex 0-based → +1).
    final label =
        context.s('workout.set_n').replaceAll('{n}', '${log.setIndex + 1}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Номер подхода — labelSmall + textFaint, фиксированная ширина.
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(color: ext.textFaint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Результат — bodyMedium, расширяется на оставшуюся ширину.
          Expanded(
            child: Text(
              '${log.reps} × $weight',
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(BuildContext context, double? w) {
    if (w == null) return context.s('workout.bodyweight');
    final v = w == w.truncateToDouble() ? '${w.round()}' : '$w';
    return '$v ${context.s('workout.weight_short')}';
  }
}
