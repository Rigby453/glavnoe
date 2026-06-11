// Экран Health — хаб здоровья.
// Рабочие модули: трекер воды (Phase 1) + трекер сна (Phase 2).
// Остальное (тренировки/дыхание/осанка) — Phase 2/3, плитки «скоро».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/animations/app_toast.dart';
import '../../core/animations/constants.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/water_goal_provider.dart';
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
final openNightProvider = StreamProvider.autoDispose<SleepLogsTableData?>((ref) {
  return ref.watch(sleepDaoProvider).watchOpenNight();
});

/// Завершённые ночи за последние 7 дней, реактивно.
final recentNightsProvider =
    StreamProvider.autoDispose<List<SleepLogsTableData>>((ref) {
  return ref.watch(sleepDaoProvider).watchRecentNights(7);
});

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  // Sleep, Breathing и Posture убраны из «скоро» — теперь живые разделы ниже
  static const _comingSoon = [
    (Icons.fitness_center, 'Workouts'),
  ];

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
                    Text('$total / $waterGoalMl ml', style: textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                _AnimatedWaterBar(progress: progress),
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
                const SizedBox(height: 16),
                // График: последние 7 дней относительно нормы
                _WeekWaterChart(goalMl: waterGoalMl),
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
            leading: Icon(Icons.restaurant_outlined, color: colorScheme.primary),
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
        const SizedBox(height: 24),

        // --- Скоро ---
        Text('More coming soon', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._comingSoon.map((e) {
          final (icon, label) = e;
          return Card(
            child: ListTile(
              leading: Icon(
                icon,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              title: Text(label),
              trailing: Text('soon', style: textTheme.bodySmall),
              enabled: false,
            ),
          );
        }),
      ],
    );
  }
}

/// Прогресс-бар воды — ANIMATIONS.md §4.2: полоса плавно растёт до нового %
/// за 500 мс (easeOutCubic); при достижении 100% через 600 мс — тост.
class _AnimatedWaterBar extends StatefulWidget {
  const _AnimatedWaterBar({required this.progress});

  final double progress;

  @override
  State<_AnimatedWaterBar> createState() => _AnimatedWaterBarState();
}

class _AnimatedWaterBarState extends State<_AnimatedWaterBar> {
  double _prev = 0;

  @override
  void didUpdateWidget(_AnimatedWaterBar old) {
    super.didUpdateWidget(old);
    if (old.progress == widget.progress) return;
    _prev = old.progress;
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
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 500 мс — точное значение §4.2 (между kDurationSlow и kDurationNormal)
    final duration =
        effectiveDuration(context, const Duration(milliseconds: 500));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _prev, end: widget.progress),
      duration: duration,
      curve: kCurveLift,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
    );
  }
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
        final frac =
            goalMl <= 0 ? 0.0 : (totals[i] / goalMl).clamp(0.0, 1.0);
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
                  final timeStr =
                      TimeOfDay.fromDateTime(open.startAt).format(context);
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
                          final dur =
                              DateTime.now().difference(open.startAt);
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
        final frac =
            goalHours <= 0 ? 0.0 : (slot.hours / goalHours).clamp(0.0, 1.0);
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
