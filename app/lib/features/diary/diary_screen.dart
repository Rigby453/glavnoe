// FL-DIARY-01: Форма дневника за сегодня — Kaname restyle.
// - Настроение 1-5 (эмодзи), свободная заметка, мульти-выбор "What went wrong?".
// - Сохранение — upsert в Drift через DayLogsDao (один ряд на день).
// - Теги "What went wrong" кодируются в note (отдельной колонки в схеме нет).
// Локальное эфемерное состояние формы → StatefulWidget; данные идут через Riverpod.
// Иконки: Phosphor (phosphor_flutter ≥2.1); карточки — surface1 + hairline + R14.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
import '../health/screen_time_signal_widget.dart';
import '../health/screen_time_usage_provider.dart';
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
    final now = DateTime.now();
    final dao = ref.read(dayLogsDaoProvider);
    final freeText = _noteController.text.trim();
    final issuesSuffix =
        _issues.isEmpty ? '' : '$_issuesPrefix${_issues.join(', ')}';
    final combined = '$freeText$issuesSuffix';

    // Основная запись дневника (UI опирается на day_logs.mood).
    await dao.saveForDate(
      date: now,
      mood: _mood,
      note: combined.isEmpty ? null : combined,
    );

    // Дополнительно пишем настроение в mood_logs — единый агрегат аналитики.
    // Дубли предотвращаем через «первая запись за день» (first-save-wins):
    // если mood_logs уже содержит diary-запись за сегодня, пропускаем.
    if (_mood != null) {
      final moodDao = ref.read(moodLogsDaoProvider);
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayDiary =
          await moodDao.getSinceBySource(todayStart, 'diary');
      if (todayDiary.isEmpty) {
        await moodDao.insertMood(
          mood: _mood!,
          loggedAt: now,
          source: 'diary',
          note: freeText.isEmpty ? null : freeText,
        );
      }
    }

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
      // 24dp горизонтальные поля (design-tokens §spacing)
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
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
        // Тонкий разделитель — ext.border (hairline 0.5dp, Kaname spec)
        VerticalDivider(
          width: 1,
          thickness: 0.5,
          color: ext.border,
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
      // Заголовок экрана: headlineMedium (calm, sentence case)
      Text(context.s('diary.title'), style: textTheme.headlineMedium),
      const SizedBox(height: 8),

      // История — TextButton с иконкой clockCounterClockwise (Phosphor)
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: Icon(PhosphorIcons.clockCounterClockwise(), size: 16),
          label: Text(context.s('diary.history')),
          onPressed: () => context.push('/diary-history'),
        ),
      ),
      const SizedBox(height: 16),

      // --- Настроение 1..5 ---
      // titleSmall для меток секций (сдержанно, textMuted)
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
              // snap=120ms (kDurationSnap)
              duration: reduce ? Duration.zero : kDurationSnap,
              curve: kCurveSnap,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Выбранное: accentMuted фон + accent бордер (accent discipline)
                // Невыбранное: прозрачный фон + border (нейтральный)
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

      // --- Свободная заметка ---
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

      // --- What went wrong — мульти-выбор FilterChip ---
      // Тема чипов: selected = accentTint + accent border; unselected = surface + border
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

      // --- Сохранить день — FilledButton (единственное primary action) ---
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _save,
          child: Text(context.s('diary.save_day_button')),
        ),
      ),
      const SizedBox(height: 12),

      // --- AI-инсайт — OutlinedButton (secondary, premium-gated) ---
      // KaiLoader вместо иконки во время загрузки (spec: KaiLoader on AI)
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: _insightLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: KaiLoader(size: 16),
                )
              : Icon(PhosphorIcons.sparkle(), size: 18),
          label: Text(context.s('diary.get_insight_button')),
          onPressed: _insightLoading ? null : _getInsight,
        ),
      ),
      const SizedBox(height: 8),

      // --- This Week / Wrapped — OutlinedButton (лёгкое навигационное действие) ---
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(PhosphorIcons.calendarCheck(), size: 18),
          label: Text(context.s('diary.this_week_button')),
          onPressed: () => context.push('/wrapped'),
        ),
      ),
    ];
  }

  /// Карточки инсайтов (план vs факт, экранное время, недельный инсайт, жизненные).
  List<Widget> _buildInsightWidgets() {
    return const [
      _PlanVsFactCard(),
      SizedBox(height: 16),
      _ScreenTimeSignalCard(),
      SizedBox(height: 16),
      _QuickInsightCard(),
      SizedBox(height: 16),
      _LifeInsightsCard(),
    ];
  }
}

/// Карточка-сигнал «Экранное время» в дневнике.
/// Нейтральный контекст: суммарное время + самая затратная категория.
/// Мягкая деградация: нет разрешения / нет Android / нет данных → SizedBox.shrink().
class _ScreenTimeSignalCard extends ConsumerWidget {
  const _ScreenTimeSignalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(screenTimeUsageProvider);

    // Мягкая деградация — не показываем пустую карточку
    if (!state.isGranted) return const SizedBox.shrink();
    if (state.hasError) return const SizedBox.shrink();

    final total = screenTimeTotal(state.usedMinutes);
    if (total == 0) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final totalStr = screenTimeFmt(context, total);
    final top = screenTimeTopCategory(state.usedMinutes);
    final topPart = top != null
        ? ' · ${context.s('screentime.cat_${top.key}')} ${screenTimeFmt(context, top.value)}'
        : '';

    return _InsightCard(
      icon: PhosphorIcons.deviceMobile(),
      title: context.s('screentime.signal_card_title'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalStr$topPart',
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Ссылка «Подробнее» → /screen-time
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context.push('/screen-time'),
            child: Text(
              context.s('screentime.signal_details'),
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// «План vs факт» за сегодня: сколько запланировано / сделано / пропущено.
class _PlanVsFactCard extends ConsumerWidget {
  const _PlanVsFactCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pvf = ref.watch(todayPlanVsFactProvider).valueOrNull;
    if (pvf == null || pvf.isEmpty) return const SizedBox.shrink();

    return _InsightCard(
      icon: PhosphorIcons.listChecks(),
      title: context.s('diary.pvf_title'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: context.s('diary.pvf_planned'), value: pvf.planned),
          _Stat(label: context.s('diary.pvf_done'), value: pvf.done),
          _Stat(label: context.s('diary.pvf_skipped'), value: pvf.skipped),
        ],
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
        // Цифра: headlineSmall (табличные цифры, крупная)
        Text('$value', style: textTheme.headlineSmall),
        const SizedBox(height: 2),
        // Метка: bodySmall (textMuted — вторичная метаинформация)
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
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

    return _InsightCard(
      icon: PhosphorIcons.chartLineUp(),
      title: context.s('diary.this_week_card_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $line',
                  style: textTheme.bodyMedium,
                ),
              ),
            )
            .toList(),
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
      // Среднее за день, а не суммарный объём
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

    return _InsightCard(
      icon: PhosphorIcons.chartLine(),
      title: context.s('diary.life_insights_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: insights
            .map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(insight, style: textTheme.bodyMedium),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Базовая карточка инсайта: surface1 + hairline (ext.border) + R14.
/// Общий шаблон для всех insight-карточек — заголовок с иконкой + body-слот.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        // surface1 = colorScheme.surface (Kaname token mapping)
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Иконка: textMuted (информационная, не CTA)
              Icon(icon, color: ext.textMuted, size: 18),
              const SizedBox(width: 8),
              // Expanded предотвращает overflow при крупном тексте
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
