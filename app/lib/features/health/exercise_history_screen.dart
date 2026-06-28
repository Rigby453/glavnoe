// Экран истории упражнения — Kaname redesign §D.
// Показывает прошлые подходы, сгруппированные по дням, и спарклайн динамики веса.
// Офлайн-первый: данные только из Drift через WorkoutsDao.
// Empty state: KaiMascot(neutral, 64) + bodyMedium.
// Заголовок = имя упражнения из watchExercise(id); fallback на exerciseName / общий.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../features/mascot/kai_mascot.dart';

class ExerciseHistoryScreen extends ConsumerWidget {
  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseId,
    this.exerciseName,
  });

  final String exerciseId;
  final String? exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final exerciseAsync = ref.watch(_exerciseProvider(exerciseId));
    final title = exerciseAsync.valueOrNull?.name ??
        exerciseName ??
        context.s('workout.history_title');

    final historyAsync = ref.watch(_historyProvider(exerciseId));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: historyAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _empty(context, ext, textTheme),
        data: (logs) {
          if (logs.isEmpty) return _empty(context, ext, textTheme);
          return _buildHistory(context, ext, textTheme, logs);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Пустое состояние — KaiMascot(neutral, 64) + текст
  // ---------------------------------------------------------------------------

  Widget _empty(
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
              context.s('workout.history_empty'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // История: спарклайн + подходы по дням
  // ---------------------------------------------------------------------------

  Widget _buildHistory(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme textTheme,
    List<WorkoutSetLogsTableData> logs,
  ) {
    final groups = _groupByDay(logs);
    final sessionWeights = _topWeightPerSession(logs);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        // Спарклайн динамики (если есть числовой вес)
        if (sessionWeights.isNotEmpty) ...[
          _WeightDynamics(
            values: sessionWeights,
            ext: ext,
            textTheme: textTheme,
            accent: colorScheme.primary,
          ),
          const SizedBox(height: 24),
        ],
        // Подходы по дням — hairline-divided cards per day
        for (final group in groups) ...[
          _DayCard(group: group, ext: ext, textTheme: textTheme),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_DayGroup> _groupByDay(List<WorkoutSetLogsTableData> logs) {
    final byDay = <DateTime, List<WorkoutSetLogsTableData>>{};
    for (final log in logs) {
      final c = log.completedAt;
      final day = DateTime(c.year, c.month, c.day);
      byDay.putIfAbsent(day, () => []).add(log);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        _DayGroup(
          date: day,
          sets: byDay[day]!
            ..sort((a, b) => a.completedAt.compareTo(b.completedAt)),
        ),
    ];
  }

  List<double> _topWeightPerSession(List<WorkoutSetLogsTableData> logs) {
    final maxBySession = <String, double>{};
    final timeBySession = <String, DateTime>{};
    for (final log in logs) {
      final w = log.weightKg;
      if (w == null) continue;
      final sid = log.sessionId;
      final prev = maxBySession[sid];
      if (prev == null || w > prev) maxBySession[sid] = w;
      final t = timeBySession[sid];
      if (t == null || log.completedAt.isBefore(t)) {
        timeBySession[sid] = log.completedAt;
      }
    }
    final sessions = maxBySession.keys.toList()
      ..sort((a, b) => timeBySession[a]!.compareTo(timeBySession[b]!));
    return [for (final sid in sessions) maxBySession[sid]!];
  }
}

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

final _historyProvider = StreamProvider.autoDispose
    .family<List<WorkoutSetLogsTableData>, String>((ref, exerciseId) {
  return ref.watch(workoutsDaoProvider).watchExerciseHistory(exerciseId);
});

final _exerciseProvider = StreamProvider.autoDispose
    .family<WorkoutExercisesTableData?, String>((ref, exerciseId) {
  return ref.watch(workoutsDaoProvider).watchExercise(exerciseId);
});

// ---------------------------------------------------------------------------
// Модель дня
// ---------------------------------------------------------------------------

class _DayGroup {
  _DayGroup({required this.date, required this.sets});
  final DateTime date;
  final List<WorkoutSetLogsTableData> sets;
}

// ---------------------------------------------------------------------------
// Карточка дня — surface1 + hairline + R14, hairline-divided строки
// ---------------------------------------------------------------------------

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.group,
    required this.ext,
    required this.textTheme,
  });

  final _DayGroup group;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('EEE, MMM d').format(group.date);

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок дня
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.clockCounterClockwise(),
                  size: 14,
                  color: ext.textFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, thickness: 0.5, color: ext.border),
          // Строки подходов
          ...group.sets.asMap().entries.map((entry) {
            final i = entry.key;
            final log = entry.value;
            return Column(
              children: [
                if (i > 0)
                  Divider(
                    height: 0,
                    thickness: 0.5,
                    color: ext.border,
                    indent: 40,
                  ),
                _SetRow(log: log, ext: ext, textTheme: textTheme),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка подхода: «1 · 12 × 40 kg»
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        children: [
          // Номер подхода — тихая подпись
          SizedBox(
            width: 24,
            child: Text(
              '${log.setIndex + 1}',
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
            ),
          ),
          const SizedBox(width: 4),
          // reps × weight
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

// ---------------------------------------------------------------------------
// Спарклайн динамики рабочего веса — ряд столбиков (accent fill)
// ---------------------------------------------------------------------------

class _WeightDynamics extends StatelessWidget {
  const _WeightDynamics({
    required this.values,
    required this.ext,
    required this.textTheme,
    required this.accent,
  });

  final List<double> values;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final span = (maxVal - minVal).abs();

    String fmt(double w) =>
        w == w.truncateToDouble() ? '${w.round()}' : '$w';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(PhosphorIcons.chartLineUp(), size: 14, color: ext.textFaint),
            const SizedBox(width: 6),
            Text(
              context.s('workout.weight_dynamics'),
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _bar(values[i], minVal, span),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Текущий рабочий вес (последняя сессия) — итог справа
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${fmt(values.last)} ${context.s('workout.weight_short')}',
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _bar(double value, double minVal, double span) {
    final t = span == 0 ? 1.0 : (value - minVal) / span;
    final factor = 0.3 + 0.7 * t;
    return FractionallySizedBox(
      heightFactor: factor.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
    );
  }
}
