// Экран Health — хаб здоровья.
// Рабочий модуль: трекер воды (Phase 1). Остальное (тренировки/сон/дыхание/
// осанка) — Phase 2, показываем плитками «скоро».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';

/// Дневная цель по воде, мл.
const int _waterGoalMl = 2000;

/// Сумма выпитого за сегодня (реактивно).
final todayWaterProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(waterDaoProvider).watchTodayTotalMl(DateTime.now());
});

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  static const _comingSoon = [
    (Icons.fitness_center, 'Workouts'),
    (Icons.bedtime_outlined, 'Sleep'),
    (Icons.air, 'Breathing'),
    (Icons.self_improvement, 'Posture'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    final progress = (total / _waterGoalMl).clamp(0.0, 1.0);
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
                    Text('$total / $_waterGoalMl ml', style: textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
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
              ],
            ),
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
