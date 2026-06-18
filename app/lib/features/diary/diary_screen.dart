// FL-DIARY-01: Форма дневника за сегодня.
// - Настроение 1-5 (эмодзи), свободная заметка, мульти-выбор "What went wrong?".
// - Сохранение — upsert в Drift через DayLogsDao (один ряд на день).
// - Теги "What went wrong" кодируются в note (отдельной колонки в схеме нет).
// Локальное эфемерное состояние формы → StatefulWidget; данные идут через Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/ai_pulse_dot.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/utils/breakpoints.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import '../health/health_screen.dart';
import '../paywall/paywall_screen.dart';
import 'diary_insight.dart';

/// Ключи тегов "What went wrong?" — внутренний ключ → ключ локализации.
const Map<String, String> _issueL10nKeys = {
  'social_media': 'diary.issue_social_media',
  'went_out': 'diary.issue_went_out',
  'was_tired': 'diary.issue_was_tired',
  'sick': 'diary.issue_sick',
  'other': 'diary.issue_other',
};

const List<String> _moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const String _issuesPrefix = '\n\nIssues: ';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final TextEditingController _noteController = TextEditingController();
  int? _mood; // 1..5
  final Set<String> _issues = {};
  bool _loaded = false;
  bool _insightLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  /// Загружаем запись за сегодня (если есть) и заполняем форму.
  Future<void> _loadExisting() async {
    final dao = ref.read(dayLogsDaoProvider);
    final existing = await dao.getForDate(DateTime.now());
    if (existing != null) {
      _mood = existing.mood;
      _parseNote(existing.note);
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// Разбираем note на свободный текст и закодированные теги Issues.
  void _parseNote(String? note) {
    if (note == null) return;
    final idx = note.indexOf(_issuesPrefix);
    if (idx == -1) {
      _noteController.text = note;
      return;
    }
    _noteController.text = note.substring(0, idx);
    final tagsPart = note.substring(idx + _issuesPrefix.length);
    for (final raw in tagsPart.split(',')) {
      final key = raw.trim();
      if (_issueL10nKeys.containsKey(key)) _issues.add(key);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dao = ref.read(dayLogsDaoProvider);
    final freeText = _noteController.text.trim();
    final issuesSuffix =
        _issues.isEmpty ? '' : '$_issuesPrefix${_issues.join(', ')}';
    final combined = '$freeText$issuesSuffix';

    await dao.saveForDate(
      date: DateTime.now(),
      mood: _mood,
      note: combined.isEmpty ? null : combined,
    );

    // Пересчитать бесплатный инсайт с учётом только что сохранённого дня.
    ref.invalidate(weeklyDiaryInsightProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('diary.day_saved'))),
      );
    }
  }

  /// AI-инсайт по дневнику (premium). Результат показываем в диалоге.
  Future<void> _getInsight() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      showPremiumUpsell(context, 'AI insights');
      return;
    }
    setState(() => _insightLoading = true);
    try {
      final insight =
          await ref.read(apiClientProvider).aiDiaryInsight('gentle');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.s('diary.insight_dialog_title')),
          content: Text(insight),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.s('btn.close')),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _insightLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return _buildTabletLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  /// Mobile single-column layout (< 600px): форма + карточки подряд.
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildFormWidgets(context),
          const SizedBox(height: 24),
          ..._buildInsightWidgets(),
        ],
      ),
    );
  }

  /// Tablet 2-column layout (≥ 600px).
  /// Left column (flex 1): diary form.
  /// Right column (flex 1): plan-vs-fact + weekly insight + life insights.
  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Левая колонка: форма дневника ---
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildFormWidgets(context),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // --- Правая колонка: карточки инсайтов ---
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildInsightWidgets(),
            ),
          ),
        ),
      ],
    );
  }

  /// Виджеты формы дневника (настроение, заметка, теги, кнопки).
  List<Widget> _buildFormWidgets(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return [
      Text(context.s('diary.title'), style: textTheme.headlineSmall),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.history),
          label: Text(context.s('diary.history')),
          onPressed: () => context.push('/diary-history'),
        ),
      ),
      const SizedBox(height: 8),

      // Настроение 1..5
      Text(context.s('diary.mood'), style: textTheme.labelMedium),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          final value = i + 1;
          final selected = _mood == value;
          return GestureDetector(
            onTap: () => setState(() => _mood = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120), // fast
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? colorScheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
              ),
              child: Text(
                _moodEmojis[i],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),

      // Свободная заметка
      Text(context.s('diary.note_prompt'), style: textTheme.labelMedium),
      const SizedBox(height: 8),
      TextField(
        controller: _noteController,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: context.s('diary.note_hint'),
        ),
      ),
      const SizedBox(height: 24),

      // What went wrong — мульти-выбор
      Text(context.s('diary.what_went_wrong'), style: textTheme.labelMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _issueL10nKeys.entries.map((e) {
          final selected = _issues.contains(e.key);
          return FilterChip(
            label: Text(context.s(e.value)),
            selected: selected,
            onSelected: (on) => setState(() {
              if (on) {
                _issues.add(e.key);
              } else {
                _issues.remove(e.key);
              }
            }),
          );
        }).toList(),
      ),
      const SizedBox(height: 32),

      // Сохранить день
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _save,
          child: Text(context.s('diary.save_day_button')),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          // Во время запроса AI — пульс вместо спиннера (§7.1)
          icon: _insightLoading
              ? const AiPulseDot(size: 10)
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(context.s('diary.get_insight_button')),
          onPressed: _insightLoading ? null : _getInsight,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.calendar_view_week, size: 18),
          label: Text(context.s('diary.this_week_button')),
          onPressed: () => context.push('/wrapped'),
        ),
      ),
    ];
  }

  /// Карточки инсайтов (план vs факт, недельный инсайт, жизненные инсайты).
  List<Widget> _buildInsightWidgets() {
    return const [
      _PlanVsFactCard(),
      SizedBox(height: 12),
      _QuickInsightCard(),
      SizedBox(height: 12),
      _LifeInsightsCard(),
    ];
  }
}

/// «План vs факт» за сегодня: сколько запланировано / сделано / пропущено.
class _PlanVsFactCard extends ConsumerWidget {
  const _PlanVsFactCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pvf = ref.watch(todayPlanVsFactProvider).valueOrNull;
    if (pvf == null || pvf.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined,
                    color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(context.s('diary.pvf_title'), style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: context.s('diary.pvf_planned'), value: pvf.planned),
                _Stat(label: context.s('diary.pvf_done'), value: pvf.done),
                _Stat(label: context.s('diary.pvf_skipped'), value: pvf.skipped),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('$value', style: textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

/// Бесплатный (rule-based) инсайт за неделю — считается локально из Drift.
/// Премиум-AI-инсайт глубже и живёт в отдельной кнопке выше.
class _QuickInsightCard extends ConsumerWidget {
  const _QuickInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyDiaryInsightProvider);
    final insight = async.valueOrNull;
    if (insight == null || insight.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(context.s('diary.this_week_card_title'), style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...insight.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $line', style: textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Аналитика образа жизни — rule-based наблюдения по сну и воде за последние 7 дней.
class _LifeInsightsCard extends ConsumerWidget {
  const _LifeInsightsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Берём данные за последние 7 дней
    final nights = ref.watch(recentNightsProvider).valueOrNull ?? [];
    final waterTotals = ref.watch(weekWaterProvider).valueOrNull ?? [];
    final waterGoal = ref.watch(waterGoalProvider);

    final insights = <String>[];

    // Анализ сна
    if (nights.isNotEmpty) {
      final completedNights =
          nights.where((n) => n.endAt != null).toList();
      if (completedNights.isNotEmpty) {
        final avgSleep = completedNights
                .map((n) => n.endAt!.difference(n.startAt).inMinutes / 60.0)
                .fold(0.0, (a, b) => a + b) /
            completedNights.length;
        if (avgSleep < 6) {
          insights.add(
            '😴 You averaged ${avgSleep.toStringAsFixed(1)}h sleep — try going to bed 30 min earlier.',
          );
        } else if (avgSleep >= 7.5) {
          insights.add(
            '✅ Great sleep this week — ${avgSleep.toStringAsFixed(1)}h avg!',
          );
        }
      }
    }

    // Анализ воды
    if (waterTotals.length == 7 && waterGoal > 0) {
      final metGoal = waterTotals.where((t) => t >= waterGoal).length;
      if (metGoal == 7) {
        insights.add('💧 Perfect hydration week — goal met every day!');
      } else if (metGoal < 3) {
        insights.add(
          '💧 Only $metGoal/7 days met your water goal this week. Try keeping a bottle nearby.',
        );
      }
    }

    // Дефолтное сообщение если нет данных
    if (insights.isEmpty) {
      insights.add(
        '📊 Track sleep and water consistently to see personal insights here.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(context.s('diary.life_insights_title'), style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(insight, style: textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
