// FL-DIARY-01: Форма дневника за сегодня.
// - Настроение 1-5 (эмодзи), свободная заметка, мульти-выбор "What went wrong?".
// - Сохранение — upsert в Drift через DayLogsDao (один ряд на день).
// - Теги "What went wrong" кодируются в note (отдельной колонки в схеме нет).
// Локальное эфемерное состояние формы → StatefulWidget; данные идут через Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/kai_loader.dart';
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
    // Показываем KaiLoader пока грузятся данные из Drift
    if (!_loaded) {
      return Center(
        child: KaiLoader(label: context.s('loading.generic')),
      );
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
      // 24dp горизонтальные поля (02-type-space.md §4.1)
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
        // Тонкий разделитель (используем border из темы, не тяжёлый divider)
        VerticalDivider(
          width: 1,
          thickness: 0.5,
          color: Theme.of(context).colorScheme.outline,
        ),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final reduce = reduceMotionOf(context);

    return [
      // Заголовок экрана: headlineMedium — крупный serif (02-type-space.md §1)
      Text(context.s('diary.title'), style: textTheme.headlineMedium),
      const SizedBox(height: 8),

      // История — TextButton (лёгкое навигационное действие, 03-components.md §6)
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.history, size: 16),
          label: Text(context.s('diary.history')),
          onPressed: () => context.push('/diary-history'),
        ),
      ),
      const SizedBox(height: 16),

      // Настроение 1..5
      // titleSmall для меток секций (более сдержанно чем headlineSmall)
      Text(
        context.s('diary.mood'),
        style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          final value = i + 1;
          final selected = _mood == value;
          return GestureDetector(
            onTap: () => setState(() => _mood = value),
            child: AnimatedContainer(
              // snap=120ms (constants.dart kDurationSnap)
              duration: reduce ? Duration.zero : kDurationSnap,
              curve: kCurveSnap,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Выбранное настроение: accentMuted фон + accent бордер (accent discipline §1)
                // Невыбранное: прозрачный фон + border бордер (нейтральный)
                color: selected ? ext.accentMuted : Colors.transparent,
                border: Border.all(
                  color: selected ? colorScheme.primary : ext.border,
                  width: selected ? 1.5 : 1.0,
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
      Text(
        context.s('diary.note_prompt'),
        style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _noteController,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: context.s('diary.note_hint'),
        ),
      ),
      const SizedBox(height: 24),

      // What went wrong — мульти-выбор FilterChip
      // Тема чипов уже обеспечивает: selected=accent, unselected=surface+border
      Text(
        context.s('diary.what_went_wrong'),
        style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
      ),
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

      // Сохранить день — FilledButton (единственное primary action, 03-components.md §2)
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _save,
          child: Text(context.s('diary.save_day_button')),
        ),
      ),
      const SizedBox(height: 12),

      // AI-инсайт — OutlinedButton (secondary, 03-components.md §5)
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          // KaiLoader вместо спиннера/пульса (06-loading spec)
          icon: _insightLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: KaiLoader(size: 16),
                )
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(context.s('diary.get_insight_button')),
          onPressed: _insightLoading ? null : _getInsight,
        ),
      ),
      const SizedBox(height: 8),

      // This Week / Wrapped — TextButton (лёгкое навигационное действие)
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
      SizedBox(height: 16),
      _QuickInsightCard(),
      SizedBox(height: 16),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      child: Padding(
        // 16dp внутренний отступ карточки (02-type-space.md §4.1)
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Иконка: textMuted (не accent — не primary action, 03-components §1)
                Icon(Icons.fact_check_outlined, color: ext.textMuted, size: 18),
                const SizedBox(width: 8),
                // Expanded предотвращает overflow при крупном тексте (scale 1.5+)
                Expanded(
                  child: Text(
                    context.s('diary.pvf_title'),
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Column(
      children: [
        // Цифра: headlineSmall (serif, крупная)
        Text('$value', style: textTheme.headlineSmall),
        const SizedBox(height: 2),
        // Метка: bodySmall (textMuted — вторичная метаинформация)
        Text(label, style: textTheme.bodySmall?.copyWith(color: ext.textMuted)),
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
    final data = async.valueOrNull;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    // Строки резолвятся здесь, где есть BuildContext и локаль
    final lines = data.resolve(context);
    if (lines.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Иконка insights: textMuted (информационная, не CTA)
                Icon(Icons.insights, color: ext.textMuted, size: 18),
                const SizedBox(width: 8),
                // Expanded предотвращает overflow при крупном тексте (scale 1.5+)
                Expanded(
                  child: Text(
                    context.s('diary.this_week_card_title'),
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lines.map(
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

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
            context
                .s('diary.insight_sleep_low')
                .replaceAll('{avg}', avgSleep.toStringAsFixed(1)),
          );
        } else if (avgSleep >= 7.5) {
          insights.add(
            context
                .s('diary.insight_sleep_good')
                .replaceAll('{avg}', avgSleep.toStringAsFixed(1)),
          );
        }
      }
    }

    // Анализ воды
    if (waterTotals.isNotEmpty) {
      // Среднее за день, а не суммарный объём (запрос пользователя).
      final avgWater =
          (waterTotals.fold<int>(0, (a, b) => a + b) / waterTotals.length)
              .round();
      insights.add(
        context
            .s('diary.insight_water_avg')
            .replaceAll('{avg}', '$avgWater'),
      );
    }
    if (waterTotals.length == 7 && waterGoal > 0) {
      final metGoal = waterTotals.where((t) => t >= waterGoal).length;
      if (metGoal == 7) {
        insights.add(context.s('diary.insight_water_perfect'));
      } else if (metGoal < 3) {
        insights.add(
          context
              .s('diary.insight_water_low')
              .replaceAll('{n}', '$metGoal'),
        );
      }
    }

    // Дефолтное сообщение если нет данных
    if (insights.isEmpty) {
      insights.add(context.s('diary.insight_no_data'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Иконка: textMuted (информационная карточка, не CTA)
                Icon(Icons.insights, color: ext.textMuted, size: 20),
                const SizedBox(width: 8),
                // Expanded предотвращает overflow при крупном тексте (scale 1.5+)
                Expanded(
                  child: Text(
                    context.s('diary.life_insights_title'),
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
