// Weekly wrapped (SPEC Ф1, rule-based): сводка за 7 дней из локальной БД.
// Без AI — все числа считаются кодом. «Неделя одним абзацем» (AI) — позже.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';

const Map<String, String> _issueLabels = {
  'social_media': 'Social media',
  'went_out': 'Went out',
  'was_tired': 'Was tired',
  'sick': 'Sick',
  'other': 'Other',
};
const String _issuesPrefix = '\n\nIssues: ';

class WeeklyStats {
  const WeeklyStats({
    required this.tasksDone,
    required this.tasksTotal,
    required this.mainDone,
    required this.mainTotal,
    required this.avgMood,
    required this.waterMl,
    required this.topIssue,
  });

  final int tasksDone;
  final int tasksTotal;
  final int mainDone;
  final int mainTotal;
  final double? avgMood;
  final int waterMl;
  final String? topIssue;
}

final weeklyStatsProvider = FutureProvider.autoDispose<WeeklyStats>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  final to = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1));

  final items = await ref.read(itemsDaoProvider).itemsInRange(from, to);
  final logs = await ref.read(dayLogsDaoProvider).since(from);
  final waterMl = await ref.read(waterDaoProvider).totalInRange(from, to);

  bool done(String s) => s == 'done';
  final main = items.where((i) => i.priority == 'main').toList();

  final moods = logs.map((l) => l.mood).whereType<int>().toList();
  final avgMood = moods.isEmpty
      ? null
      : moods.reduce((a, b) => a + b) / moods.length;

  // Топ-причина срывов из закодированных в note тегов "Issues: ..."
  final counts = <String, int>{};
  for (final l in logs) {
    final note = l.note;
    if (note == null) continue;
    final idx = note.indexOf(_issuesPrefix);
    if (idx == -1) continue;
    for (final raw in note.substring(idx + _issuesPrefix.length).split(',')) {
      final key = raw.trim();
      if (_issueLabels.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }
  String? topIssue;
  if (counts.isNotEmpty) {
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    topIssue = _issueLabels[best.key];
  }

  return WeeklyStats(
    tasksDone: items.where((i) => done(i.status)).length,
    tasksTotal: items.length,
    mainDone: main.where((i) => done(i.status)).length,
    mainTotal: main.length,
    avgMood: avgMood,
    waterMl: waterMl,
    topIssue: topIssue,
  );
});

class WrappedScreen extends ConsumerWidget {
  const WrappedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('This week')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (s) => _StatsView(s: s),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.s});
  final WeeklyStats s;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final moodStr = s.avgMood == null ? '—' : s.avgMood!.toStringAsFixed(1);
    final tiles = <(IconData, String, String)>[
      (Icons.check_circle_outline, 'Tasks done', '${s.tasksDone} / ${s.tasksTotal}'),
      (Icons.shield_outlined, 'Main done', '${s.mainDone} / ${s.mainTotal}'),
      (Icons.sentiment_satisfied_alt, 'Avg mood', '$moodStr / 5'),
      (Icons.water_drop, 'Water', '${s.waterMl} ml'),
      (Icons.error_outline, 'Top setback', s.topIssue ?? '—'),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Your last 7 days', style: textTheme.headlineMedium),
        const SizedBox(height: 16),
        ...tiles.map((t) {
          final (icon, label, value) = t;
          return Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: Text(value, style: textTheme.titleMedium),
            ),
          );
        }),
      ],
    );
  }
}
