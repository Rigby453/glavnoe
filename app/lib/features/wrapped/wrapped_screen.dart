// Wrapped (SPEC Ф1): сводка за Неделю/Месяц из локальной БД (rule-based,
// числа считает код) + «период одним абзацем» от AI (premium, AI-05/ADR-026).
// Kaname redesign §G: кольцо + streak + Share image + 5 stat tiles (§4) + AI-абзац.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/ai_insight_reveal.dart';
import '../../core/animations/ai_pulse_dot.dart';
import '../../core/animations/ai_skeleton.dart';
import '../../core/animations/constants.dart';
import '../../core/branding.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';

// Внутренний ключ тега → ключ локализации (diary.issue_* в plan_diary.dart).
// Разрешается в контексте виджета, а не в провайдере (нет BuildContext).
const Map<String, String> _issueLabels = {
  'social_media': 'diary.issue_social_media',
  'went_out': 'diary.issue_went_out',
  'was_tired': 'diary.issue_was_tired',
  'sick': 'diary.issue_sick',
  'other': 'diary.issue_other',
};
const String _issuesPrefix = '\n\nIssues: ';

// ---------------------------------------------------------------------------
// Data models (business logic — не трогаем)
// ---------------------------------------------------------------------------

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

  // Настроение: day_logs (дневник) + mood_logs(source='meditation').
  // source='diary' из mood_logs не читаем — дублирует day_logs (двойной счёт).
  final diaryMoods = logs.map((l) => l.mood).whereType<int>().toList();
  final moodLogs = await ref.read(moodLogsDaoProvider).getSince(from);
  final meditationMoods = moodLogs
      .where((m) => m.source == 'meditation')
      .map((m) => m.mood)
      .toList();
  final allMoods = [...diaryMoods, ...meditationMoods];
  final avgMood =
      allMoods.isEmpty ? null : allMoods.reduce((a, b) => a + b) / allMoods.length;

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

/// StreamProvider для streak (autoDispose чтобы не держать подписку открытой).
final _wrappedStreakProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(streakDaoProvider).watchStreak();
});

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

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

  // Ключ RepaintBoundary для генерации share-image
  final _shareKey = GlobalKey();

  // AI recap (premium) — логика не изменена
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

  // Генерирует PNG из RepaintBoundary → сохраняет во временный каталог
  Future<void> _shareImage() async {
    // Захватываем ScaffoldMessenger до async-разрыва
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      // Web — dart:io недоступен, сохранение невозможно
      if (kIsWeb) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.s('wrapped.save_error'))),
        );
        return;
      }

      // Mobile/desktop — сохраняем PNG во временный каталог
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/kaname_wrapped_$ts.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.s('wrapped.saved_image')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.s('wrapped.save_error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(wrappedStatsProvider(_days));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _days == 7
              ? context.s('wrapped.title_week')
              : context.s('wrapped.title_month'),
        ),
      ),
      body: statsAsync.when(
        loading: () =>
            Center(child: KaiLoader(label: context.s('loading.generic'))),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.s('wrapped.err_load').replaceAll('{e}', '$e'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (s) => _buildBody(context, s),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WeeklyStats s) {
    final streakVal =
        ref.watch(_wrappedStreakProvider).valueOrNull?.current ?? 0;

    // Среднее воды в день; БАГ-3: показываем avg/day, не суммарный объём.
    final avgWaterMl = _days > 0 ? (s.waterMl / _days).round() : 0;
    // Локализованная строка с единицей измерения (мл / ml)
    final waterStr =
        context.s('wrapped.water_value').replaceAll('{val}', '$avgWaterMl');

    final moodStr =
        s.avgMood == null ? '—' : s.avgMood!.toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // Переключатель периода
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
                value: 7, label: Text(context.s('wrapped.seg_week'))),
            ButtonSegment(
                value: 30, label: Text(context.s('wrapped.seg_month'))),
          ],
          selected: {_days},
          onSelectionChanged: (sel) => setState(() {
            _days = sel.first;
            _summary = null; // абзац относится к старому периоду
          }),
        ),
        const SizedBox(height: 20),

        // ── ShareCard (RepaintBoundary → PNG) ───────────────────────────────
        RepaintBoundary(
          key: _shareKey,
          child: _ShareCard(
            stats: s,
            days: _days,
            streakVal: streakVal,
            waterStr: waterStr,
            moodStr: moodStr,
          ),
        ),

        const SizedBox(height: 16),

        // Кнопка «Share image» — единственная primary на экране
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(PhosphorIcons.shareNetwork(), size: 20),
            label: Text(context.s('wrapped.share_image')),
            onPressed: _shareImage,
          ),
        ),

        const SizedBox(height: 24),

        // ── AI-секция ────────────────────────────────────────────────────────
        if (_summary != null)
          // Готовый абзац от AI — fade-in + slide (ANIMATIONS.md §7.3)
          AiInsightReveal(
            child: _AiCard(summary: _summary!),
          )
        else if (_summaryLoading)
          // Пульс + скелетон пока AI пишет (§7.1 + §7.2)
          const _AiLoadingCard()
        else
          // Кнопка запроса AI-итогов (только для premium)
          OutlinedButton.icon(
            icon: Icon(PhosphorIcons.sparkle(), size: 18),
            label: Text(context.s('wrapped.btn_ai_recap')),
            onPressed: () => _aiRecap(s),
          ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Share card — весь визуальный контент внутри RepaintBoundary
// ---------------------------------------------------------------------------

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.stats,
    required this.days,
    required this.streakVal,
    required this.waterStr,
    required this.moodStr,
  });

  final WeeklyStats stats;
  final int days;
  final int streakVal;
  final String waterStr;
  final String moodStr;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        // surface1 = colorScheme.surface; отдельный фон для читаемости в share-image
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок: подпись периода слева, логотип справа
          Row(
            children: [
              Expanded(
                child: Text(
                  context
                      .s('wrapped.period_label')
                      .replaceAll('{n}', '$days'),
                  style:
                      t.labelMedium?.copyWith(color: ext.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                kAppWordmark,
                style: t.labelSmall?.copyWith(color: ext.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Кольцо прогресса + streak (рядом)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Кольцо: mainDone/mainTotal за период
              _WrappedRing(done: stats.mainDone, total: stats.mainTotal),
              const SizedBox(width: 20),
              // Streak: огонь + счётчик + 7 точек
              Expanded(
                child: _StreakColumn(streakVal: streakVal),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5 stat-строк с разделителями (§4.2 dense list)
          _buildStatRows(context, ext),
        ],
      ),
    );
  }

  Widget _buildStatRows(
    BuildContext context,
    FocusThemeExtension ext,
  ) {
    // Данные для 5 плиток; topIssue — ключ локализации или null
    final rows = <(IconData, String, String)>[
      (
        PhosphorIcons.checkCircle(),
        context.s('wrapped.stat_tasks_done'),
        '${stats.tasksDone} / ${stats.tasksTotal}',
      ),
      (
        PhosphorIcons.shield(),
        context.s('wrapped.stat_main_done'),
        '${stats.mainDone} / ${stats.mainTotal}',
      ),
      (
        PhosphorIcons.star(),
        context.s('wrapped.stat_avg_mood'),
        '$moodStr / 5',
      ),
      (
        PhosphorIcons.drop(),
        context.s('wrapped.stat_water_avg'),
        waterStr,
      ),
      (
        PhosphorIcons.warningCircle(),
        context.s('wrapped.stat_top_setback'),
        stats.topIssue != null ? context.s(stats.topIssue!) : '—',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _StatRow(
            icon: rows[i].$1,
            label: rows[i].$2,
            value: rows[i].$3,
          ),
          if (i < rows.length - 1)
            Divider(height: 1, thickness: 0.5, color: ext.border),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Кольцо прогресса (анимированное, 100×100)
// ---------------------------------------------------------------------------

class _WrappedRing extends StatefulWidget {
  const _WrappedRing({required this.done, required this.total});

  final int done;
  final int total;

  @override
  State<_WrappedRing> createState() => _WrappedRingState();
}

class _WrappedRingState extends State<_WrappedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _prog;
  bool _launched = false;

  double _target() =>
      widget.total == 0 ? 0.0 : widget.done / widget.total;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: kDurationSlow, vsync: this);
    _prog = Tween<double>(begin: 0, end: _target())
        .animate(CurvedAnimation(parent: _ctrl, curve: kCurveLift));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl.duration = effectiveDuration(context, kDurationSlow);
    if (!_launched) {
      _launched = true;
      if (reduceMotionOf(context)) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void didUpdateWidget(_WrappedRing old) {
    super.didUpdateWidget(old);
    if (old.done != widget.done || old.total != widget.total) {
      final from = _prog.value;
      _prog = Tween<double>(begin: from, end: _target())
          .animate(CurvedAnimation(parent: _ctrl, curve: kCurveLift));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final t = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _prog,
      builder: (_, __) => SizedBox(
        width: 100,
        height: 100,
        child: CustomPaint(
          painter: _RingPainter(
            progress: _prog.value.clamp(0.0, 1.0),
            accentColor: cs.primary,
            trackColor: ext?.border ?? cs.outline,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.total == 0
                      ? '—'
                      : '${widget.done}/${widget.total}',
                  style: t.titleLarge,
                ),
                if (widget.total > 0)
                  Text(
                    context.s('today.ring_main'),
                    style: t.labelSmall?.copyWith(
                      color: ext?.textMuted ??
                          cs.onSurface.withAlpha(140),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 8;
    const strokeW = 8.0;
    const startAngle = -math.pi / 2; // начало сверху (12 часов)

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.accentColor != accentColor ||
      old.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// Streak: огонь + счётчик + 7 точек
// ---------------------------------------------------------------------------

class _StreakColumn extends StatelessWidget {
  const _StreakColumn({required this.streakVal});

  final int streakVal;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final filled = streakVal.clamp(0, 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Строка: огонь + число + «день/дней»
        Row(
          children: [
            Icon(
              PhosphorIcons.fire(PhosphorIconsStyle.fill),
              color: ext.ember,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text('$streakVal', style: t.titleLarge),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                streakVal == 1
                    ? context.s('today.streak_day')
                    : context.s('today.streak_days'),
                style: t.bodySmall?.copyWith(color: ext.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 7 точек (заполненные = success, пустые = border)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) {
            final isFilled = i >= (7 - filled);
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? ext.success : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? ext.success : ext.border,
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Строка статистики (dense list §4.2 — разделители, не отдельные карточки)
// ---------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ext.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: t.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: t.titleSmall,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI-карточка: готовый абзац (появляется через AiInsightReveal)
// ---------------------------------------------------------------------------

class _AiCard extends StatelessWidget {
  const _AiCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: ext.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.primary.withAlpha(51), // ~20% opacity
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.s('wrapped.ai_paragraph_title'),
                  style: t.labelLarge?.copyWith(color: ext.accentInk),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(summary, style: t.bodyMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI-карточка: загрузка (пульс + скелетон, §7.1 + §7.2)
// ---------------------------------------------------------------------------

class _AiLoadingCard extends StatelessWidget {
  const _AiLoadingCard();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AiPulseDot(color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.s('wrapped.ai_writing'),
                  style: t.bodyMedium?.copyWith(color: ext.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AiSkeleton(lines: 3),
        ],
      ),
    );
  }
}
