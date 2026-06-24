// Экран истории упражнения (Feature B, set-by-set дневник).
// Показывает прошлые подходы упражнения, сгруппированные по дням,
// и лёгкую динамику рабочего веса (макс. вес за сессию) в виде столбиков.
// Офлайн-первый: данные только из Drift через WorkoutsDao.
//
// Заголовок = имя упражнения: берётся из watchExercise(id); если упражнение
// уже удалено (null) — fallback на переданный exerciseName, затем на общий
// заголовок «Exercise history».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

class ExerciseHistoryScreen extends ConsumerWidget {
  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseId,
    this.exerciseName,
  });

  final String exerciseId;

  /// Опциональное имя упражнения от вызывающей стороны — fallback, если
  /// упражнение уже удалено и watchExercise вернёт null.
  final String? exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Заголовок: имя упражнения из БД → переданное имя → общий заголовок.
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
  // Пустое состояние
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
            // Иконка пустого состояния — textFaint (тихая, не акцентная)
            Icon(Icons.show_chart, size: 56, color: ext.textFaint),
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
  // История: динамика веса + подходы по дням
  // ---------------------------------------------------------------------------

  Widget _buildHistory(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme textTheme,
    List<WorkoutSetLogsTableData> logs,
  ) {
    // logs приходят свежими первыми (completedAt desc). Группируем по дню.
    final groups = _groupByDay(logs);

    // Динамика: рабочий вес (макс. за сессию) по времени, старые → новые.
    final sessionWeights = _topWeightPerSession(logs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        // Лёгкий спарклайн динамики рабочего веса (если есть числовой вес)
        if (sessionWeights.isNotEmpty) ...[
          _WeightDynamics(
            values: sessionWeights,
            ext: ext,
            textTheme: textTheme,
            accent: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
        ],
        // Подходы, сгруппированные по дням (свежие дни сверху)
        for (final group in groups) ...[
          _DayHeader(date: group.date, ext: ext, textTheme: textTheme),
          const SizedBox(height: 8),
          for (final log in group.sets)
            _SetRow(log: log, ext: ext, textTheme: textTheme),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Группировка/агрегация
  // ---------------------------------------------------------------------------

  /// Сгруппировать подходы по календарному дню (свежие дни первыми,
  /// внутри дня — по времени, старые первыми).
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

  /// Топовый рабочий вес (макс. weightKg) на каждую сессию, по времени
  /// (старые → новые) — для столбиковой динамики. Сессии без числового веса
  /// (только bodyweight) пропускаются.
  List<double> _topWeightPerSession(List<WorkoutSetLogsTableData> logs) {
    // Время сессии = минимальный completedAt её подходов (для сортировки).
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
// Провайдеры экрана (family по exerciseId)
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
// Модель группы подходов одного дня
// ---------------------------------------------------------------------------

class _DayGroup {
  _DayGroup({required this.date, required this.sets});

  final DateTime date;
  final List<WorkoutSetLogsTableData> sets;
}

// ---------------------------------------------------------------------------
// Заголовок дня
// ---------------------------------------------------------------------------

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.ext,
    required this.textTheme,
  });

  final DateTime date;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // «Mon, Jun 23» — короткая дата (как в week_agenda). DateFormat без явной
    // локали следует Intl.defaultLocale (выставляется applyIntlLocale), поэтому
    // дата локализуется вместе с языком приложения.
    final label = DateFormat('EEE, MMM d').format(date);
    return Text(
      label,
      style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Строка подхода: «12 × 40 kg» / «15 × Bodyweight»
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Номер подхода — тихая подпись (setIndex 0-based → +1)
          SizedBox(
            width: 28,
            child: Text(
              '${log.setIndex + 1}',
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
            ),
          ),
          // «reps × weight» — основная метрика подхода
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

  /// Форматирование веса: «40 kg» / «42.5 kg» / «Bodyweight» (null) —
  /// та же идея, что в тренажёре.
  String _formatWeight(BuildContext context, double? w) {
    if (w == null) return context.s('workout.bodyweight');
    final v = w == w.truncateToDouble() ? '${w.round()}' : '$w';
    return '$v ${context.s('workout.weight_short')}';
  }
}

// ---------------------------------------------------------------------------
// Лёгкая динамика рабочего веса — ряд столбиков (без новых зависимостей).
// Overflow-safe: столбики во Flexible, текст с ellipsis.
// ---------------------------------------------------------------------------

class _WeightDynamics extends StatelessWidget {
  const _WeightDynamics({
    required this.values,
    required this.ext,
    required this.textTheme,
    required this.accent,
  });

  /// Топовый рабочий вес по сессиям, старые → новые.
  final List<double> values;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    // Диапазон для нормализации высоты: если все равны — все полной высоты.
    final span = (maxVal - minVal).abs();

    String fmt(double w) =>
        w == w.truncateToDouble() ? '${w.round()}' : '$w';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Подпись блока — тихая (textFaint)
        Text(
          context.s('workout.weight_dynamics'),
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
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
    // Высота столбика 0.35..1.0 от доступной — чтобы даже минимум был виден.
    final t = span == 0 ? 1.0 : (value - minVal) / span;
    final factor = 0.35 + 0.65 * t;
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
