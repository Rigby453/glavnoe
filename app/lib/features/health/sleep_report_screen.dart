// Полный отчёт сна — история ночей, статистика, графики
// Открывается из Health → мини-карточка сна

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';

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
    // ThemeExtension для textMuted / textFaint / success / border
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final selectedDate = ref.watch(sleepSelectedDateProvider);
    final nights = ref.watch(sleepFilteredNightsProvider);
    final stats = ref.watch(sleepStatsForDateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        // Заголовок экрана — headlineSmall (display font, 22sp)
        title: Text(context.s('sleep.report_title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context, ref),
            tooltip: context.s('sleep.select_date'),
          ),
        ],
      ),
      body: nights.when(
        data: (nightList) => SingleChildScrollView(
          // 24dp горизонтальные поля, 16dp сверху — §4.1
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Блок статистики: три карточки рядом
                _buildStatsCards(context, stats, textTheme, ext),
                const SizedBox(height: 24),

                // Выбор даты — кнопка-нудж, не акцентный элемент
                GestureDetector(
                  onTap: () => _selectDate(context, ref),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatSelectedDate(context, selectedDate),
                        style: textTheme.titleMedium?.copyWith(
                          // Дата — textMuted, не accent
                          color: ext.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        // Иконка тоже нейтральная
                        color: ext.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок секции истории
                Text(
                  context.s('sleep.history'),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Список ночей
                if (nightList.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.s('sleep.no_data'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: ext.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: nightList
                        .map(
                          (night) => _buildNightCard(
                            context,
                            night,
                            textTheme,
                            colorScheme,
                            ext,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
        // KaiLoader заменяет CircularProgressIndicator (п. 6)
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: KaiLoader(label: context.s('loading.sleep')),
          ),
        ),
        error: (err, st) => Center(
          child: Text(context.s('error.generic').replaceFirst('{err}', '$err')),
        ),
      ),
    );
  }

  /// Три мини-карточки статистики: avg / best / total nights.
  Widget _buildStatsCards(
    BuildContext context,
    SleepStats stats,
    TextTheme textTheme,
    FocusThemeExtension ext,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.s('sleep.avg'),
            // Большие hero-числа: displaySmall (32sp, display font) — §1
            value: '${stats.avgHours.toStringAsFixed(1)}h',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('sleep.best_night'),
            value: '${stats.maxHours.toStringAsFixed(1)}h',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('sleep.total_nights'),
            value: '${stats.totalNights}',
          ),
        ),
      ],
    );
  }

  /// Карточка одной ночи: дата + время старта + длительность.
  Widget _buildNightCard(
    BuildContext context,
    SleepLogsTableData night,
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    final duration = night.endAt != null
        ? night.endAt!.difference(night.startAt).inMinutes / 60.0
        : null;

    // Цель достигнута (≥ 7ч) → success color; иначе — textMuted
    final durationColor =
        duration != null && duration >= 7 ? ext.success : ext.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // surface вместо surfaceContainer (нет хардкода)
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.border),
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
              // Метаданные — bodySmall + textMuted (§ TYPOGRAPHY)
              Text(
                _formatTime(night.startAt),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ],
          ),
          if (duration != null)
            // Hero-число длительности — headlineSmall (display font, 22sp)
            Text(
              '${duration.toStringAsFixed(1)}h',
              style: textTheme.headlineSmall?.copyWith(
                color: durationColor,
              ),
            )
          else
            Text(
              context.s('sleep.in_progress'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
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

  String _formatSelectedDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return context.s('sleep.today');
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return context.s('sleep.yesterday');
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

/// Мини-карточка статистики (avg/best/total).
/// Использует Card ThemeData вместо хардкоженного Container + декорации.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Метка — bodySmall + textMuted
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            // Hero-число — displaySmall (32sp, display font, w700)
            Text(
              value,
              style: textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}
