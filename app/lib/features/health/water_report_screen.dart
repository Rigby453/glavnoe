// Отчёт о воде — история, статистика.
// Redesign «Kaname» §4.2: Phosphor, hairline-divided rows (вместо card-per-entry),
// пустое состояние с KaiMascot, FittedBox для stat-значений на 320px.
// Открывается из WaterFullscreenScreen или из кнопки отчёта в карточке Health.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/date_navigator.dart';
import '../../core/widgets/kai_loader.dart';
import '../mascot/kai_mascot.dart';

/// Провайдер выбранной даты (water report).
final waterSelectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

/// Все записи воды за выбранный день, реактивно.
final waterLogsForDateProvider =
    StreamProvider.autoDispose<List<WaterLogsTableData>>((ref) {
      final date = ref.watch(waterSelectedDateProvider);
      return ref.watch(waterDaoProvider).watchWaterForDate(date);
    });

/// Сумма выпитого за выбранный день, реактивно.
final waterTotalForDateProvider = StreamProvider.autoDispose<int>((ref) {
  final date = ref.watch(waterSelectedDateProvider);
  return ref.watch(waterDaoProvider).watchTotalForDate(date);
});

class WaterReportScreen extends ConsumerWidget {
  const WaterReportScreen({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Устанавливаем начальную дату, если передана
    ref.listen(waterSelectedDateProvider, (_, next) {});
    if (date != null) {
      ref.read(waterSelectedDateProvider.notifier).state = date!;
    }

    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedDate = ref.watch(waterSelectedDateProvider);
    final waterLogs = ref.watch(waterLogsForDateProvider);
    final waterTotal = ref.watch(waterTotalForDateProvider);
    final waterGoal = ref.watch(waterGoalProvider);

    return Scaffold(
      appBar: AppBar(
        // Phosphor: arrowLeft вместо Material arrow_back
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
        ),
        title: Text(context.s('water.report_title')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // DateNavigator уже реализован с Phosphor (caretLeft/caretRight)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ext.border, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DateNavigator(
                date: selectedDate,
                onChanged: (d) =>
                    ref.read(waterSelectedDateProvider.notifier).state = d,
              ),
            ),
          ),

          Expanded(
            child: waterLogs.when(
              data: (logs) => SingleChildScrollView(
                // 24dp горизонтальные поля — spec §1
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Три мини-карточки статистики
                    waterTotal.when(
                      data: (total) => _buildStatsSection(
                        context,
                        total,
                        waterGoal,
                        textTheme,
                        ext,
                        colorScheme,
                      ),
                      loading: () => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: KaiLoader(
                            label: context.s('loading.generic'),
                          ),
                        ),
                      ),
                      error: (err, _) => Text(
                        context
                            .s('error.generic')
                            .replaceFirst('{err}', '$err'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Заголовок секции записей — titleMedium
                    Text(
                      context.s('water.logs_section'),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    // Пустое состояние — §4.2: Kai (neutral 64) + подпись + verb button
                    if (logs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              const KaiMascot(
                                size: 64,
                                emotion: KaiEmotion.neutral,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.s('water.no_logs'),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: ext.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              // Verb button — возврат для записи воды
                              OutlinedButton(
                                onPressed: () => context.pop(),
                                child: Text(context.s('water.log_water_btn')),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // §4.2 hairline-divided rows — один контейнер вместо card-per-row
                      _buildLogsList(context, logs, colorScheme, ext),
                  ],
                ),
              ),
              // KaiLoader вместо CircularProgressIndicator
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: KaiLoader(label: context.s('loading.water')),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  context.s('error.generic').replaceFirst('{err}', '$err'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Три мини-карточки: всего / цель / статус. §4.2 stat cards с FittedBox.
  Widget _buildStatsSection(
    BuildContext context,
    int total,
    int waterGoal,
    TextTheme textTheme,
    FocusThemeExtension ext,
    ColorScheme colorScheme,
  ) {
    final percentage = waterGoal > 0 ? (total / waterGoal * 100).round() : 0;
    final status =
        percentage >= 100 ? context.s('water.goal_met') : '$percentage%';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_total'),
            value: '${(total / 1000).toStringAsFixed(1)}L',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_goal'),
            value: '${(waterGoal / 1000).toStringAsFixed(1)}L',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_status'),
            value: status,
          ),
        ),
      ],
    );
  }

  /// §4.2 hairline-divided rows — единый контейнер вместо card-per-row.
  Widget _buildLogsList(
    BuildContext context,
    List<WaterLogsTableData> logs,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < logs.length; i++) ...[
            _WaterLogRow(log: logs[i]),
            if (i < logs.length - 1)
              Divider(height: 1, thickness: 0.5, color: ext.border),
          ],
        ],
      ),
    );
  }
}

/// Одна строка записи воды в §4.2 стиле: время слева, объём справа.
/// Дата не показывается — день уже выбран в DateNavigator.
class _WaterLogRow extends StatelessWidget {
  const _WaterLogRow({required this.log});

  final WaterLogsTableData log;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Время в формате HH:mm
    final time =
        '${log.loggedAt.hour.toString().padLeft(2, '0')}:${log.loggedAt.minute.toString().padLeft(2, '0')}';
    // Объём — локаль-aware через шаблон (не хардкод 'ml')
    final amount = context
        .s('water.amt_ml_fmt')
        .replaceFirst('{ml}', '${log.amountMl}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Phosphor drop — доменная иконка воды
          Icon(PhosphorIcons.drop(), size: 16, color: ext.textMuted),
          const SizedBox(width: 10),
          // Время — bodyMedium
          Text(time, style: textTheme.bodyMedium),
          const Spacer(),
          // Объём — titleSmall (w500, числа читаются чётче)
          Text(amount, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Мини-карточка статистики (total / goal / status). §4.2 flat card.
/// FittedBox на значении защищает от overflow на 320px + textScale 1.5.
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Метка — bodySmall + textMuted
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Значение — headlineMedium; FittedBox защищает от overflow
          // на 320px + textScale 1.5 (особенно «Goal Met!» длиннее «1.8L»)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: textTheme.headlineMedium),
          ),
        ],
      ),
    );
  }
}
