// Wrapped (SPEC Ф1): сводка за Неделю/Месяц из локальной БД (rule-based,
// числа считает код) + «период одним абзацем» от AI (premium, AI-05/ADR-026).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/ai_insight_reveal.dart';
import '../../core/animations/ai_pulse_dot.dart';
import '../../core/animations/ai_skeleton.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';

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

/// Статистика за последние [days] дней (7 — неделя, 30 — месяц).
final wrappedStatsProvider =
    FutureProvider.autoDispose.family<WeeklyStats, int>((ref, days) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: days - 1));
  final to =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

  final items = await ref.read(itemsDaoProvider).itemsInRange(from, to);
  final logs = await ref.read(dayLogsDaoProvider).since(from);
  final waterMl = await ref.read(waterDaoProvider).totalInRange(from, to);

  bool done(String s) => s == 'done';
  final main = items.where((i) => i.priority == 'main').toList();

  final moods = logs.map((l) => l.mood).whereType<int>().toList();
  final avgMood =
      moods.isEmpty ? null : moods.reduce((a, b) => a + b) / moods.length;

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

class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  int _days = 7;

  // AI-абзац за выбранный период (premium)
  String? _summary;
  bool _summaryLoading = false;

  Future<void> _aiRecap(WeeklyStats s) async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.s('wrapped.ai_premium_snack')),
          action: SnackBarAction(
            label: context.s('wrapped.btn_upgrade'),
            onPressed: () => context.push('/paywall'),
          ),
        ),
      );
      return;
    }

    setState(() => _summaryLoading = true);
    try {
      final tone = ref.read(toneProvider) == AppTone.harsh ? 'harsh' : 'gentle';
      final summary = await ref.read(apiClientProvider).aiWrappedSummary(
            periodDays: _days,
            tasksDone: s.tasksDone,
            tasksTotal: s.tasksTotal,
            mainDone: s.mainDone,
            mainTotal: s.mainTotal,
            avgMood: s.avgMood,
            waterMl: s.waterMl,
            topIssue: s.topIssue,
            tone: tone,
          );
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(wrappedStatsProvider(_days));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _days == 7
              ? context.s('wrapped.title_week')
              : context.s('wrapped.title_month'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            context.s('wrapped.err_load').replaceAll('{e}', '$e'),
          ),
        ),
        data: (s) => _buildStats(context, s),
      ),
    );
  }

  Widget _buildStats(BuildContext context, WeeklyStats s) {
    final textTheme = Theme.of(context).textTheme;
    final moodStr = s.avgMood == null ? '—' : s.avgMood!.toStringAsFixed(1);

    // Статические метки тайлов — через контекст
    final tiles = <(IconData, String, String)>[
      (
        Icons.check_circle_outline,
        context.s('wrapped.stat_tasks_done'),
        '${s.tasksDone} / ${s.tasksTotal}'
      ),
      (
        Icons.shield_outlined,
        context.s('wrapped.stat_main_done'),
        '${s.mainDone} / ${s.mainTotal}'
      ),
      (
        Icons.sentiment_satisfied_alt,
        context.s('wrapped.stat_avg_mood'),
        '$moodStr / 5'
      ),
      (Icons.water_drop, context.s('wrapped.stat_water'), '${s.waterMl} ml'),
      (
        Icons.error_outline,
        context.s('wrapped.stat_top_setback'),
        s.topIssue ?? '—'
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(context.s('wrapped.seg_week'))),
            ButtonSegment(value: 30, label: Text(context.s('wrapped.seg_month'))),
          ],
          selected: {_days},
          onSelectionChanged: (sel) => setState(() {
            _days = sel.first;
            _summary = null; // абзац относится к старому периоду
          }),
        ),
        const SizedBox(height: 16),
        Text(
          context.s('wrapped.period_label').replaceAll('{n}', '$_days'),
          style: textTheme.headlineMedium,
        ),
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
        const SizedBox(height: 16),
        if (_summary != null)
          // Готовый абзац от AI — появляется с fade-in + slide (§7.3)
          AiInsightReveal(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          context.s('wrapped.ai_paragraph_title'),
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_summary!, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          )
        else if (_summaryLoading)
          // Скелетон пока AI пишет (§7.2) — карточка с shimmer + подпись
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AiPulseDot(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.s('wrapped.ai_writing'),
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AiSkeleton(lines: 3),
                ],
              ),
            ),
          )
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(context.s('wrapped.btn_ai_recap')),
            onPressed: () => _aiRecap(s),
          ),
      ],
    );
  }
}
