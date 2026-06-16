// Полный отчёт воды — история, графики, статистика
// Открывается из Health → мини-карточка воды

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/water_goal_provider.dart';

/// Провайдер для выбранной даты (water report)
final waterSelectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

/// Все записи воды за выбранный день
final waterLogsForDateProvider =
    StreamProvider.autoDispose<List<WaterLogsTableData>>((ref) {
      final date = ref.watch(waterSelectedDateProvider);
      return ref.watch(waterDaoProvider).watchWaterForDate(date);
    });

/// Сумма выпитого за выбранный день
final waterTotalForDateProvider = StreamProvider.autoDispose<int>((ref) {
  final date = ref.watch(waterSelectedDateProvider);
  return ref.watch(waterDaoProvider).watchTotalForDate(date);
});

class WaterReportScreen extends ConsumerWidget {
  const WaterReportScreen({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Устанавливаем начальную дату
    ref.listen(waterSelectedDateProvider, (_, next) {});
    if (date != null) {
      ref.read(waterSelectedDateProvider.notifier).state = date!;
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final waterLogs = ref.watch(waterLogsForDateProvider);
    final waterTotal = ref.watch(waterTotalForDateProvider);
    final waterGoal = ref.watch(waterGoalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Water Report', style: textTheme.headlineSmall),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Выбор даты
          _buildDatePicker(context, ref, textTheme),

          Expanded(
            child: waterLogs.when(
              data: (logs) => SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Статистика
                      waterTotal.when(
                        data: (total) => _buildStatsSection(
                          context,
                          total,
                          waterGoal,
                          textTheme,
                        ),
                        loading: () => const SizedBox(height: 100),
                        error: (err, st) => Text('Error: $err'),
                      ),
                      const SizedBox(height: 24),

                      // История записей
                      Text('Water Logs', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (logs.isEmpty)
                        Center(
                          child: Text(
                            'No water logs for this day',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        )
                      else
                        ...logs.map(
                          (log) => _buildWaterLogCard(
                            context,
                            log,
                            textTheme,
                            colorScheme,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    int total,
    int waterGoal,
    TextTheme textTheme,
  ) {
    final percentage = waterGoal > 0 ? (total / waterGoal * 100).round() : 0;
    final status = percentage >= 100 ? 'Goal Met!' : '$percentage%';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total',
                value: '${(total / 1000).toStringAsFixed(1)}L',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Goal',
                value: '${(waterGoal / 1000).toStringAsFixed(1)}L',
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Status',
                value: status,
                textTheme: textTheme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    WidgetRef ref,
    TextTheme textTheme,
  ) {
    final selectedDate = ref.watch(waterSelectedDateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            _formatFullDate(selectedDate),
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(waterSelectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(waterSelectedDateProvider.notifier).state = picked;
    }
  }

  String _formatFullDate(DateTime dt) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _buildWaterLogCard(
    BuildContext context,
    WaterLogsTableData log,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
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
                _formatDate(log.loggedAt),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(log.loggedAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
          Text(
            '${log.amountMl} ml',
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
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
