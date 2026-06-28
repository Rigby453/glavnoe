// Полный отчёт сна — история ночей, статистика, графики
// Kaname redesign §B + §4.2:
//   • три мини-статкарточки (success-цвет если ≥7 часов)
//   • DateNavigator — единый паттерн навигации по датам
//   • история ночей = hairline-divided rows (не карточки-тайлы)
//   • пустое состояние = KaiMascot(neutral, 64) + подсказка + CTA
//   • Phosphor-иконки; без хардкода строк.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/date_navigator.dart';
import '../../core/widgets/kai_loader.dart';
import '../mascot/kai_mascot.dart';

// ---------------------------------------------------------------------------
// Провайдеры (логика не изменена)
// ---------------------------------------------------------------------------

/// Выбранная дата в sleep report.
final sleepSelectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

/// Ночи, попадающие в выбранный день.
final sleepFilteredNightsProvider =
    StreamProvider.autoDispose<List<SleepLogsTableData>>((ref) {
  final selectedDate = ref.watch(sleepSelectedDateProvider);
  final dao = ref.watch(sleepDaoProvider);

  final startOfDay = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return dao.watchNightsByDateRange(startOfDay, endOfDay);
});

/// Статистика за выбранный период.
final sleepStatsForDateProvider = Provider.autoDispose<SleepStats>((ref) {
  final nights = ref.watch(sleepFilteredNightsProvider).value ?? [];
  return _calculateStats(nights);
});

// ---------------------------------------------------------------------------
// Модель статистики (не изменена)
// ---------------------------------------------------------------------------

class SleepStats {
  const SleepStats({
    required this.avgHours,
    required this.maxHours,
    required this.minHours,
    required this.totalNights,
  });

  final double avgHours;
  final double maxHours;
  final double minHours;
  final int totalNights;
}

SleepStats _calculateStats(List<SleepLogsTableData> nights) {
  if (nights.isEmpty) {
    return const SleepStats(
      avgHours: 0,
      maxHours: 0,
      minHours: 0,
      totalNights: 0,
    );
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

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------

class SleepReportScreen extends ConsumerWidget {
  const SleepReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final selectedDate = ref.watch(sleepSelectedDateProvider);
    final nights = ref.watch(sleepFilteredNightsProvider);
    final stats = ref.watch(sleepStatsForDateProvider);

    return Scaffold(
      appBar: AppBar(
        // Phosphor arrowLeft заменяет Material arrow_back (§icon-map)
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.arrowLeft(PhosphorIconsStyle.regular),
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(context.s('sleep.report_title')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── DateNavigator ─────────────────────────────────────────────────
          // surface1 + 0.5dp hairline + R14, отступы 24 по бокам, 12 сверху
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ext.border, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: DateNavigator(
                date: selectedDate,
                onChanged: (d) =>
                    ref.read(sleepSelectedDateProvider.notifier).state = d,
              ),
            ),
          ),

          // ── Скролл-область ────────────────────────────────────────────────
          Expanded(
            child: nights.when(
              data: (nightList) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Три мини-статкарточки ────────────────────────────
                    // Единица «h» локализована через sleep.h_unit (en=h, ru=ч, …)
                    Builder(
                      builder: (ctx) {
                        final hUnit = ctx.s('sleep.h_unit');
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: ctx.s('sleep.avg'),
                                  // success-цвет если среднее ≥ 7 часов
                                  value: stats.avgHours > 0
                                      ? '${stats.avgHours.toStringAsFixed(1)}$hUnit'
                                      : '—',
                                  isSuccess: stats.avgHours > 0 &&
                                      stats.avgHours >= 7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: ctx.s('sleep.best_night'),
                                  // success-цвет если лучшая ночь ≥ 7 часов
                                  value: stats.maxHours > 0
                                      ? '${stats.maxHours.toStringAsFixed(1)}$hUnit'
                                      : '—',
                                  isSuccess: stats.maxHours > 0 &&
                                      stats.maxHours >= 7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: ctx.s('sleep.total_nights'),
                                  value: '${stats.totalNights}',
                                  // Для общего числа ночей нет цветового порога
                                  isSuccess: null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── История ночей ────────────────────────────────────
                    Text(
                      context.s('sleep.history'),
                      style: textTheme.titleSmall?.copyWith(
                        color: ext.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (nightList.isEmpty)
                      _EmptyState()
                    else
                      _NightList(nights: nightList),
                  ],
                ),
              ),
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: KaiLoader(label: context.s('loading.sleep')),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context
                        .s('error.generic')
                        .replaceFirst('{err}', '$err'),
                    style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Мини-карточка статистики (§4.2: surface1 + hairline + R14)
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    // null = нет порога (нейтральный цвет); true/false = выше/ниже 7ч
    required this.isSuccess,
  });

  final String label;
  final String value;
  final bool? isSuccess;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Цвет hero-числа: success если порог достигнут, иначе основной ink
    final valueColor = switch (isSuccess) {
      true => ext.success,
      false => ext.textMuted,
      null => colorScheme.onSurface,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Метка — bodySmall + textMuted
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: ext.textMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          // Hero-число — displaySmall (28sp, w500, tabular)
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.displaySmall?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Список ночей — hairline-divided rows (§4.2 «dense lists»)
// ---------------------------------------------------------------------------

class _NightList extends StatelessWidget {
  const _NightList({required this.nights});

  final List<SleepLogsTableData> nights;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      // Clip нужен чтобы скруглённые углы не «вылезали» за content rows
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < nights.length; i++) ...[
            _NightRow(night: nights[i]),
            if (i < nights.length - 1)
              Divider(height: 1, thickness: 0.5, color: ext.border),
          ],
        ],
      ),
    );
  }
}

class _NightRow extends StatelessWidget {
  const _NightRow({required this.night});

  final SleepLogsTableData night;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final duration = night.endAt != null
        ? night.endAt!.difference(night.startAt).inMinutes / 60.0
        : null;

    // success-цвет если ≥ 7 часов, иначе textMuted
    final durationColor =
        duration != null && duration >= 7 ? ext.success : ext.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Phosphor moon — иконка-домен «сон» (§icon-map: sleep=moon/bed)
          PhosphorIcon(
            PhosphorIcons.moon(PhosphorIconsStyle.regular),
            size: 16,
            color: ext.textFaint,
          ),
          const SizedBox(width: 12),

          // Дата + время начала — Expanded чтобы не было overflow на 320px
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Locale-aware короткая дата: «Jun 24» / «24 июн.»
                Text(
                  DateFormat.MMMd().format(night.startAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                // Время отбоя — bodySmall + textMuted
                Text(
                  _formatTime(night.startAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Длительность или «In progress» (единица «h» через sleep.h_unit)
          if (duration != null)
            Text(
              '${duration.toStringAsFixed(1)}${context.s('sleep.h_unit')}',
              style: textTheme.headlineSmall?.copyWith(color: durationColor),
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

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Пустое состояние (§4.2: Kai neutral 64 + подсказка + verb-кнопка)
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KaiMascot(size: 64, emotion: KaiEmotion.neutral),
            const SizedBox(height: 16),
            Text(
              context.s('sleep.empty_hint'),
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Outlined — этот экран только для просмотра, FilledButton не нужен
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: PhosphorIcon(
                PhosphorIcons.moon(PhosphorIconsStyle.regular),
                size: 16,
              ),
              label: Text(context.s('sleep.log_sleep')),
            ),
          ],
        ),
      ),
    );
  }
}
