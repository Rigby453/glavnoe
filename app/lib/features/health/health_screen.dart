// Экран Health — хаб здоровья.
// Рабочие модули: трекер воды (Phase 1) + трекер сна (Phase 2).
// Остальное (тренировки/дыхание/осанка) — Phase 2/3, плитки «скоро».

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/animations/app_toast.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/kai_loader.dart';
import 'sleep_stats.dart';

/// Сумма выпитого за сегодня (реактивно).
final todayWaterProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(waterDaoProvider).watchTodayTotalMl(DateTime.now());
});

/// Суммы по дням за последние 7 дней (индекс 6 — сегодня), реактивно.
final weekWaterProvider = StreamProvider.autoDispose<List<int>>((ref) {
  return ref.watch(waterDaoProvider).watchDailyTotals(DateTime.now(), 7);
});

/// Открытая ночь (endAt == null), реактивно.
final openNightProvider = StreamProvider.autoDispose<SleepLogsTableData?>((
  ref,
) {
  return ref.watch(sleepDaoProvider).watchOpenNight();
});

/// Завершённые ночи за последние 7 дней, реактивно.
final recentNightsProvider =
    StreamProvider.autoDispose<List<SleepLogsTableData>>((ref) {
      return ref.watch(sleepDaoProvider).watchRecentNights(7);
    });

/// Провайдер напоминаний о воде — включить/выключить расписание уведомлений.
final waterReminderProvider =
    StateNotifierProvider<WaterReminderNotifier, bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return WaterReminderNotifier(prefs);
});

class WaterReminderNotifier extends StateNotifier<bool> {
  WaterReminderNotifier(this._prefs)
      : super(_prefs.getBool('water_reminders') ?? false);
  final SharedPreferences _prefs;
  // FlutterLocalNotificationsPlugin uses a factory/singleton — not const.
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _baseId = 400;

  Future<void> toggle(bool value) async {
    state = value;
    await _prefs.setBool('water_reminders', value);
    if (value) {
      await _schedule();
    } else {
      await _cancel();
    }
  }

  Future<void> _schedule() async {
    await _cancel();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kaizen_water',
        'Water reminders',
        channelDescription: 'Hydration reminders every 2 hours',
        importance: Importance.low,
        priority: Priority.low,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (var i = 0; i < 8; i++) {
      final hour = 8 + i * 2;
      final scheduled = _nextInstance(hour);
      await _plugin.zonedSchedule(
        id: _baseId + i,
        title: 'Time to drink water',
        body: 'Stay hydrated!',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _cancel() async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(id: _baseId + i);
    }
  }

  tz.TZDateTime _nextInstance(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }
}

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  // Все Phase-2 модули теперь реализованы — секция «скоро» убрана

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return _buildTabletLayout(context, ref);
        }
        return _buildMobileLayout(context, ref);
      },
    );
  }

  /// Mobile single-column layout (< 600px).
  Widget _buildMobileLayout(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    final waterGoalMl = ref.watch(waterGoalProvider);
    final progress = (total / waterGoalMl).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);

    return ListView(
      // 24dp screen margin — spec §4.1
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
        // headlineMedium — display font (серифный), 32sp, w700
        Text(context.s('health.title'), style: textTheme.headlineMedium),
        const SizedBox(height: 24),
        _buildWaterCard(context, ref, textTheme, total, waterGoalMl, progress, dao),
        const SizedBox(height: 16),
        const _SleepCard(),
        const SizedBox(height: 24),
        ..._buildNavTileCards(context),
      ],
    );
  }

  /// Tablet 2-column layout (≥ 600px).
  /// Top row: Water card | Sleep card (each 50%).
  /// Below: GridView crossAxisCount=2 for navigation tiles.
  Widget _buildTabletLayout(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    final waterGoalMl = ref.watch(waterGoalProvider);
    final progress = (total / waterGoalMl).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);
    final navTiles = _buildNavTileCards(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(context.s('health.title'), style: textTheme.headlineMedium),
        const SizedBox(height: 24),
        // Water + Sleep side by side
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildWaterCard(
                  context, ref, textTheme, total, waterGoalMl, progress, dao,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: _SleepCard()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Navigation tiles in a 2-column grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: navTiles,
        ),
      ],
    );
  }

  /// Карточка трекера воды.
  /// ACCENT DISCIPLINE: только кнопки лога — Outlined (повторяемые действия).
  /// Иконка воды — нейтральная (textMuted); акцент только на прогресс-дуге.
  Widget _buildWaterCard(
    BuildContext context,
    WidgetRef ref,
    TextTheme textTheme,
    int total,
    int waterGoalMl,
    double progress,
    dynamic dao,
  ) {
    // Берём ext для доступа к textMuted / success без хардкода hex
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок карточки — иконка нейтральная (textMuted)
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: ext.textMuted),
                const SizedBox(width: 8),
                Text(context.s('health.water'), style: textTheme.titleMedium),
                const Spacer(),
                // Метрика: текст нейтральный (bodyMedium), акцент НЕ применяется.
                // Flexible предотвращает overflow на 320px: длинная строка усекается.
                Flexible(
                  child: Text(
                    '$total / $waterGoalMl ml',
                    style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 18, color: ext.textMuted),
                  tooltip: context.s('health.water_full_view'),
                  onPressed: () => context.push('/water'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _AnimatedWaterGlass(progress: progress),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Первичная метрика — headlineSmall, display font, accent color
                      Text(
                        '$total ml',
                        style: textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        context.s('health.water_goal_of').replaceFirst('{goal}', '$waterGoalMl'),
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      // Прогресс-бар: accent только когда он несёт смысл метрики
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Кнопки лога: Outlined (повторяемые действия — §2 BUTTON HIERARCHY)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_drink, size: 18),
                    label: Text(context.s('health.water_add_250')),
                    onPressed: () => dao.addWater(250),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.sports_bar, size: 18),
                    label: Text(context.s('health.water_add_500')),
                    onPressed: () => dao.addWater(500),
                  ),
                ),
                const SizedBox(width: 8),
                // Undo — IconButton (tertiary, без акцента)
                IconButton(
                  tooltip: context.s('health.water_undo'),
                  icon: Icon(Icons.undo, color: ext.textMuted),
                  onPressed: () => dao.undoLast(DateTime.now()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Тоггл напоминаний — нейтральная иконка
            Row(
              children: [
                Icon(Icons.notifications_outlined, size: 16, color: ext.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.s('health.water_reminders'),
                    style: textTheme.bodySmall,
                  ),
                ),
                Switch.adaptive(
                  value: ref.watch(waterReminderProvider),
                  onChanged: (v) =>
                      ref.read(waterReminderProvider.notifier).toggle(v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // График: последние 7 дней — нажимаемая зона → отчёт о воде.
            // InkWell охватывает только график, не кнопки лога выше.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/water-report'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: _WeekWaterChart(goalMl: waterGoalMl)),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Theme.of(context)
                          .extension<FocusThemeExtension>()!
                          .textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // "View report" — TextButton (навигационный нудж, не основное действие)
            TextButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(context.s('health.view_report')),
              onPressed: () => context.push('/water-report'),
            ),
          ],
        ),
      ),
    );
  }

  /// Навигационные карточки-плитки.
  /// ИСПРАВЛЕНИЕ ГЛАВНОЙ ПРОБЛЕМЫ: иконки нейтральные (textMuted),
  /// НЕ colorScheme.primary — так на всех ~9 плитках не будет «стены лайма».
  /// Accent зарезервирован для одного первичного/активного элемента.
  List<Widget> _buildNavTileCards(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    // Нейтральный цвет для всех иконок навигационных плиток
    final iconColor = ext.textMuted;

    return [
      // --- Еда ---
      Card(
        child: ListTile(
          leading: Icon(Icons.restaurant_outlined, color: iconColor),
          title: Text(context.s('health.food')),
          subtitle: Text(context.s('health.food_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/food'),
        ),
      ),
      // --- Фокус-сессии ---
      Card(
        child: ListTile(
          leading: Icon(Icons.timer_outlined, color: iconColor),
          title: Text(context.s('health.focus_session')),
          subtitle: Text(context.s('health.focus_session_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/focus'),
        ),
      ),
      // --- Тренировки (Ф2) ---
      Card(
        child: ListTile(
          leading: Icon(Icons.fitness_center_outlined, color: iconColor),
          title: Text(context.s('health.workouts')),
          subtitle: Text(context.s('health.workouts_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/workouts'),
        ),
      ),
      // --- Зарядка / растяжка ---
      Card(
        child: ListTile(
          leading: Icon(Icons.accessibility_new_outlined, color: iconColor),
          title: Text(context.s('health.warmup')),
          subtitle: Text(context.s('health.warmup_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/warmup'),
        ),
      ),
      // --- Дыхание (Ф2) ---
      Card(
        child: ListTile(
          leading: Icon(Icons.air, color: iconColor),
          title: Text(context.s('health.breathing')),
          subtitle: Text(context.s('health.breathing_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/breathing'),
        ),
      ),
      // --- Медитация (Ф2) ---
      Card(
        child: ListTile(
          leading: Icon(Icons.spa_outlined, color: iconColor),
          title: Text(context.s('health.meditation')),
          subtitle: Text(context.s('health.meditation_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/meditation'),
        ),
      ),
      // --- Осанка (Ф2) ---
      Card(
        child: ListTile(
          leading: Icon(Icons.self_improvement, color: iconColor),
          title: Text(context.s('health.posture')),
          subtitle: Text(context.s('health.posture_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/posture'),
        ),
      ),
      // --- Экранное время ---
      Card(
        child: ListTile(
          leading: Icon(Icons.phone_android_outlined, color: iconColor),
          title: Text(context.s('health.screen_time')),
          subtitle: Text(context.s('health.screen_time_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/screen-time'),
        ),
      ),
      // --- Трекер привычек ---
      Card(
        child: ListTile(
          leading: Icon(Icons.track_changes_outlined, color: iconColor),
          title: Text(context.s('habits.title')),
          subtitle: Text(context.s('habits.subtitle_hub')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/habits'),
        ),
      ),
      // --- Совместная учёба ---
      Card(
        child: ListTile(
          leading: Icon(Icons.people_outline, color: iconColor),
          title: Text(context.s('costudy.title')),
          subtitle: Text(context.s('costudy.subtitle_hub')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/costudy'),
        ),
      ),
    ];
  }
}

/// Анимированный стакан с водой — заменяет плоский прогресс-бар.
/// При достижении 100% через 600 мс — тост.
class _AnimatedWaterGlass extends StatefulWidget {
  const _AnimatedWaterGlass({required this.progress});
  final double progress;

  @override
  State<_AnimatedWaterGlass> createState() => _AnimatedWaterGlassState();
}

class _AnimatedWaterGlassState extends State<_AnimatedWaterGlass>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // ВАЖНО: MediaQuery.of(context) НЕЛЬЗЯ вызывать в initState — это кидает
    // ассерт «dependOnInheritedWidgetOfExactType before initState completed»
    // и каскадом валит весь экран. reduce-motion читаем в didChangeDependencies.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduce-motion: при отключённой анимации duration=0.
    // didChangeDependencies вызывается после initState и при смене зависимостей.
    final reduce = MediaQuery.of(context).disableAnimations;
    _ctrl.duration =
        reduce ? Duration.zero : const Duration(milliseconds: 600);
    if (!_started) {
      _started = true;
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedWaterGlass old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      // Норма достигнута → задержка 600 мс → тост
      if (old.progress < 1.0 && widget.progress >= 1.0) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            showAppToast(
              context,
              variant: AppToastVariant.done,
              message: context.s('health.water_goal_reached'),
            );
          }
        });
      }
      _anim = Tween<double>(begin: _anim.value, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
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
    // Стакан рисуется акцентным цветом — это первичная метрика прогресса воды
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: context.s('health.water_goal_reached'),
      triggerMode: widget.progress >= 1.0
          ? TooltipTriggerMode.tap
          : TooltipTriggerMode.manual,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (ctx, _) => CustomPaint(
          size: const Size(56, 72),
          painter: _GlassPainter(fill: _anim.value, color: color),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.fill, required this.color});
  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Контур стакана (трапеция: снизу уже)
    final glassPath = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.9, 0)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();

    // Заливка воды (клипируется формой стакана)
    final waterTop = h * (1 - fill.clamp(0.0, 1.0));
    final waterPath = Path()
      ..moveTo(w * 0.1 + (w * 0.12) * (waterTop / h), waterTop)
      ..lineTo(w * 0.9 - (w * 0.12) * (waterTop / h), waterTop)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();

    // Рисуем воду
    canvas.drawPath(
      waterPath,
      Paint()..color = color.withValues(alpha: 0.35),
    );

    // Рисуем контур стакана
    canvas.drawPath(
      glassPath,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Линия на поверхности воды
    if (fill > 0.02) {
      canvas.drawLine(
        Offset(w * 0.1 + (w * 0.12) * (waterTop / h) + 2, waterTop),
        Offset(w * 0.9 - (w * 0.12) * (waterTop / h) - 2, waterTop),
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill || old.color != color;
}

/// Мини-график воды за последние 7 дней (высота столбца — доля от нормы).
/// Столбцы успешных дней — accent; остальные — textMuted c opacity.
class _WeekWaterChart extends ConsumerWidget {
  const _WeekWaterChart({required this.goalMl});

  final int goalMl;

  static const _chartHeight = 56.0;
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(weekWaterProvider).valueOrNull;
    if (totals == null || totals.length != 7) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final frac = goalMl <= 0 ? 0.0 : (totals[i] / goalMl).clamp(0.0, 1.0);
        final isToday = i == 6;
        final reached = totals[i] >= goalMl && goalMl > 0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: (_chartHeight * frac).clamp(3.0, _chartHeight),
                  decoration: BoxDecoration(
                    // Accent только для дней где достигнута цель (success moment)
                    // Остальные — нейтральная textMuted c пониженной opacity
                    color: reached
                        ? colorScheme.primary
                        : ext.textMuted.withValues(
                            alpha: isToday ? 0.55 : 0.30,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _letters[day.weekday - 1],
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? ext.textMuted : ext.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Sleep tracker card
// ---------------------------------------------------------------------------

/// Карточка трекера сна. Два состояния:
/// • нет открытой ночи → кнопка «Going to bed» + недельный график
/// • есть открытая ночь → «Sleeping since HH:MM» + кнопка «I'm awake»
class _SleepCard extends ConsumerWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    // Используем .when для разбора состояния загрузки корректно.
    final openAsync = ref.watch(openNightProvider);
    final dao = ref.read(sleepDaoProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок: иконка нейтральная (textMuted), не primary
            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: ext.textMuted),
                const SizedBox(width: 8),
                Text(context.s('health.sleep'), style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            openAsync.when(
              // Async spinner → KaiLoader (заменяет базовый CircularProgressIndicator)
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: KaiLoader(label: context.s('loading.sleep')),
                ),
              ),
              error: (_, e) => const SizedBox.shrink(),
              data: (open) {
                if (open != null) {
                  // Ночь идёт — показываем время начала и кнопку «проснулся»
                  final timeStr = TimeOfDay.fromDateTime(
                    open.startAt,
                  ).format(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${context.s('health.sleep_sleeping_since')} $timeStr',
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      // FilledButton — единственное первичное действие в карточке
                      FilledButton.icon(
                        icon: const Icon(Icons.wb_sunny_outlined),
                        label: Text(context.s('health.sleep_im_awake')),
                        onPressed: () async {
                          await dao.endNight();
                          // Считаем длительность для снэкбара
                          final dur = DateTime.now().difference(open.startAt);
                          final h = dur.inHours;
                          final m = dur.inMinutes % 60;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.s('health.sleep_night_logged')
                                      .replaceAll('{h}', '$h')
                                      .replaceAll('{m}', '$m'),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  );
                }

                // Ночи нет — кнопка «Ложусь спать» + недельный график
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // FilledButton — единственное первичное действие в карточке
                    FilledButton.icon(
                      icon: const Icon(Icons.bedtime),
                      label: Text(context.s('health.sleep_going_to_bed')),
                      onPressed: () => dao.startNight(),
                    ),
                    const SizedBox(height: 16),
                    // График: последние 7 дней — нажимаемая зона → отчёт о сне.
                    // InkWell охватывает только график, не кнопку «Ложусь спать».
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.push('/sleep-report'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: _WeekSleepChart(goalHours: 7)),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Theme.of(context)
                                  .extension<FocusThemeExtension>()!
                                  .textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // TextButton — навигационный нудж (не основное действие)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(context.s('health.view_report')),
                      onPressed: () => context.push('/sleep-report'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Мини-график сна за последние 7 дней (аналог _WeekWaterChart).
/// Цель подсветки — ≥ 7 часов (accent color); остальные — textMuted.
class _WeekSleepChart extends ConsumerWidget {
  const _WeekSleepChart({required this.goalHours});

  final double goalHours;

  static const _chartHeight = 56.0;
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = ref.watch(recentNightsProvider).valueOrNull;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();

    // Если данных нет вообще (null = загружается) или пустой список
    if (nights == null) return const SizedBox.shrink();
    if (nights.isEmpty) {
      return Text(
        context.s('health.sleep_no_nights'),
        style: textTheme.bodySmall,
      );
    }

    final slots = nightlyHours(nights, today, 7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final slot = slots[i];
        final frac = goalHours <= 0
            ? 0.0
            : (slot.hours / goalHours).clamp(0.0, 1.0);
        final isToday = i == 6;
        final reached = slot.hours >= goalHours && goalHours > 0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: (_chartHeight * frac).clamp(3.0, _chartHeight),
                  decoration: BoxDecoration(
                    // Accent для успешных дней; нейтральная textMuted для остальных
                    color: reached
                        ? colorScheme.primary
                        : ext.textMuted.withValues(
                            alpha: isToday ? 0.55 : 0.30,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _letters[slot.day.weekday - 1],
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? ext.textMuted : ext.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
