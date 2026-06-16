// Полный отчёт сна — история ночей, статистика, графики
// Открывается из Health → мини-карточка сна

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

/// Провайдер для выбранной даты (sleep report)
final sleepSelectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

/// Провайдер для фильтрации ночей по выбранной дате
final sleepFilteredNightsProvider =
    StreamProvider.autoDispose<List<SleepLogsTableData>>((ref) {
      final selectedDate = ref.watch(sleepSelectedDateProvider);
      final dao = ref.watch(sleepDaoProvider);

      // Получаем начало и конец выбранного дня
      final startOfDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Фильтруем ночи, где endAt попадает в выбранный день
      // или startAt в выбранный день (для незаконченных ночей)
      return dao.watchNightsByDateRange(startOfDay, endOfDay);
    });

/// Провайдер для статистики за выбранный период
final sleepStatsForDateProvider = Provider.autoDispose<SleepStats>((ref) {
  final nights = ref.watch(sleepFilteredNightsProvider).value ?? [];
  return _calculateStats(nights);
});

class SleepStats {
  final double avgHours;
  final double maxHours;
  final double minHours;
  final int totalNights;

  SleepStats({
    required this.avgHours,
    required this.maxHours,
    required this.minHours,
    required this.totalNights,
  });
}

SleepStats _calculateStats(List<SleepLogsTableData> nights) {
  if (nights.isEmpty) {
    return SleepStats(avgHours: 0, maxHours: 0, minHours: 0, totalNights: 0);
  }

  final hours = nights
      .where((n) => n.endAt != null)
      .map((n) => n.endAt!.difference(n.startAt).inMinutes / 60.0)
      .toList();

  if (hours.isEmpty) {
    return SleepStats(
      avgHours: 0,
      maxHours: 0,
      minHours: 0,
      totalNights: nights.length,
    );
  }

  final avg = hours.reduce((a, b) => a + b) / hours.length;
  final max = hours.reduce((a, b) => a > b ? a : b);
  final min = hours.reduce((a, b) => a < b ? a : b);

  return SleepStats(
    avgHours: avg,
    maxHours: max,
    minHours: min,
    totalNights: nights.length,
  );
}

class SleepReportScreen extends ConsumerWidget {
  const SleepReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedDate = ref.watch(sleepSelectedDateProvider);
    final nights = ref.watch(sleepFilteredNightsProvider);
    final stats = ref.watch(sleepStatsForDateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Sleep Report', style: textTheme.headlineSmall),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context, ref),
            tooltip: 'Select date',
          ),
        ],
      ),
      body: nights.when(
        data: (nightList) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статистика
                _buildStatsCards(context, stats, textTheme),
                const SizedBox(height: 24),

                // Выбранная дата
                GestureDetector(
                  onTap: () => _selectDate(context, ref),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatSelectedDate(selectedDate),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // История ночей
                Text('Sleep History', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                nights.when(
                  data: (nightList) {
                    if (nightList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No sleep data for this date',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: nightList
                          .map(
                            (night) => _buildNightCard(
                              context,
                              night,
                              textTheme,
                              colorScheme,
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, st) => Text('Error: $err'),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatsCards(
    BuildContext context,
    SleepStats stats,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Avg Sleep',
                value: '${stats.avgHours.toStringAsFixed(1)}h',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Best Night',
                value: '${stats.maxHours.toStringAsFixed(1)}h',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total Nights',
                value: '${stats.totalNights}',
                textTheme: textTheme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNightCard(
    BuildContext context,
    SleepLogsTableData night,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final duration = night.endAt != null
        ? night.endAt!.difference(night.startAt).inMinutes / 60.0
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(night.startAt),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(night.startAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
          if (duration != null)
            Text(
              '${duration.toStringAsFixed(1)}h',
              style: textTheme.bodyLarge?.copyWith(
                color: duration >= 7 ? Colors.green : colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              'In progress',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Today';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(sleepSelectedDateProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'SELECT DATE',
      cancelText: 'CANCEL',
      confirmText: 'OK',
      locale: const Locale('en', 'US'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: Theme.of(context).colorScheme.primary,
              headerForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(sleepSelectedDateProvider.notifier).state = picked;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final TextTheme textTheme;

  const _StatCard({
    required this.label,
    required this.value,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
