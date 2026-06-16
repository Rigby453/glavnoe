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
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/theme_provider.dart';
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
        title: 'Time to drink water 💧',
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    // Норма из настроек (онбординг-шаг «нормы»; по умолчанию 2000 мл)
    final waterGoalMl = ref.watch(waterGoalProvider);
    final progress = (total / waterGoalMl).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Health', style: textTheme.headlineMedium),
        const SizedBox(height: 16),

        // --- Трекер воды ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Water', style: textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '$total / $waterGoalMl ml',
                      style: textTheme.titleMedium,
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
                          Text(
                            '$total ml',
                            style: textTheme.headlineSmall,
                          ),
                          Text(
                            'of $waterGoalMl ml goal',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.local_drink, size: 18),
                        label: const Text('+250 ml'),
                        onPressed: () => dao.addWater(250),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sports_bar, size: 18),
                        label: const Text('+500 ml'),
                        onPressed: () => dao.addWater(500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: () => dao.undoLast(DateTime.now()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.notifications_outlined, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Drink reminders (every 2 h)')),
                    Switch.adaptive(
                      value: ref.watch(waterReminderProvider),
                      onChanged: (v) =>
                          ref.read(waterReminderProvider.notifier).toggle(v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // График: последние 7 дней относительно нормы
                _WeekWaterChart(goalMl: waterGoalMl),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View Report'),
                  onPressed: () => context.push('/water-report'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Трекер сна ---
        const _SleepCard(),
        const SizedBox(height: 16),
        // --- Еда ---
        Card(
          child: ListTile(
            leading: Icon(
              Icons.restaurant_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('Food'),
            subtitle: const Text('Log meals · KБЖУ from Open Food Facts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/food'),
          ),
        ),
        const SizedBox(height: 16),

        // --- Фокус-сессии ---
        Card(
          child: ListTile(
            leading: Icon(Icons.timer_outlined, color: colorScheme.primary),
            title: const Text('Focus session'),
            subtitle: const Text('25/5 · 50/10 · 67/15 and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/focus'),
          ),
        ),
        const SizedBox(height: 16),

        // --- Тренировки (Ф2) ---
        Card(
          child: ListTile(
            leading: Icon(Icons.fitness_center, color: colorScheme.primary),
            title: const Text('Workouts'),
            subtitle: const Text('Your workout plans'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/workouts'),
          ),
        ),
        const SizedBox(height: 16),

        // --- Дыхание (Ф2) ---
        Card(
          child: ListTile(
            leading: Icon(Icons.air, color: colorScheme.primary),
            title: const Text('Breathing'),
            subtitle: const Text('Box 4-4-4-4 · Calm 4-7-8 · Simple 5-5'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/breathing'),
          ),
        ),
        const SizedBox(height: 16),

        // --- Осанка (Ф2) ---
        Card(
          child: ListTile(
            leading: Icon(Icons.self_improvement, color: colorScheme.primary),
            title: const Text('Posture'),
            subtitle: const Text('Exercises · stand-tall reminders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/posture'),
          ),
        ),
        const SizedBox(height: 16),

        // --- Трекер привычек ---
        Card(
          child: ListTile(
            leading: Icon(Icons.track_changes, color: colorScheme.primary),
            title: const Text('Habits'),
            subtitle: const Text('Build good habits · break bad ones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/habits'),
          ),
        ),
        const SizedBox(height: 12),

        // --- Совместная учёба ---
        Card(
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Co-study'),
            subtitle: const Text('Study with friends · leaderboard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/costudy'),
          ),
        ),
      ],
    );
  }
}

/// Анимированный стакан с водой — заменяет плоский прогресс-бар.
/// §4.2: при достижении 100% через 600 мс — тост.
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedWaterGlass old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      // §4.2: норма достигнута → задержка 600 мс → тост
      if (old.progress < 1.0 && widget.progress >= 1.0) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            showAppToast(
              context,
              variant: AppToastVariant.done,
              message: 'Water goal reached 💧',
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
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Water goal reached 💧',
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
                    color: reached
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(
                            alpha: isToday ? 0.8 : 0.35,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _letters[day.weekday - 1],
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.6),
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
    final colorScheme = Theme.of(context).colorScheme;
    // Используем .when для разбора состояния загрузки корректно.
    final openAsync = ref.watch(openNightProvider);
    final dao = ref.read(sleepDaoProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Sleep', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            openAsync.when(
              loading: () => const SizedBox(height: 48),
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
                        'Sleeping since $timeStr',
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.wb_sunny_outlined),
                        label: const Text("I'm awake"),
                        onPressed: () async {
                          await dao.endNight();
                          // Считаем длительность для снэкбара
                          final dur = DateTime.now().difference(open.startAt);
                          final h = dur.inHours;
                          final m = dur.inMinutes % 60;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Night logged: ${h}h ${m}m'),
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
                    FilledButton.icon(
                      icon: const Icon(Icons.bedtime),
                      label: const Text('Going to bed'),
                      onPressed: () => dao.startNight(),
                    ),
                    const SizedBox(height: 16),
                    _WeekSleepChart(goalHours: 7),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('View Report'),
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
/// Цель подсветки — ≥ 7 часов (accent color).
class _WeekSleepChart extends ConsumerWidget {
  const _WeekSleepChart({required this.goalHours});

  final double goalHours;

  static const _chartHeight = 56.0;
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = ref.watch(recentNightsProvider).valueOrNull;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();

    // Если данных нет вообще (null = загружается) или пустой список
    if (nights == null) return const SizedBox.shrink();
    if (nights.isEmpty) {
      return Text(
        'No nights tracked yet',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
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
                    color: reached
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(
                            alpha: isToday ? 0.8 : 0.35,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _letters[slot.day.weekday - 1],
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.6),
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
