// Компактный сигнал «Экранное время» для вечернего разбора (inline-строка).
// Данные — только Android, PACKAGE_USAGE_STATS через screenTimeUsageProvider.
//
// Мягкая деградация (SizedBox.shrink() без ошибок):
//   - не Android / разрешение не выдано
//   - произошла ошибка плагина
//   - суммарное использование за день == 0 (нет данных)
//
// Также экспортирует 3 чистые хелпера, используемые в diary_screen.dart:
//   screenTimeTotal / screenTimeTopCategory / screenTimeFmt.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'screen_time_usage_provider.dart';

// ---------------------------------------------------------------------------
// Чистые хелперы (без BuildContext / I/O) — легко тестировать
// ---------------------------------------------------------------------------

/// Суммарные минуты по всем категориям из [usedMinutes].
int screenTimeTotal(Map<String, int> used) =>
    used.values.fold(0, (a, b) => a + b);

/// Самая затратная категория (максимум по минутам).
/// Возвращает null если все значения == 0.
MapEntry<String, int>? screenTimeTopCategory(Map<String, int> used) {
  final nonEmpty = used.entries.where((e) => e.value > 0).toList();
  if (nonEmpty.isEmpty) return null;
  return nonEmpty.reduce((a, b) => a.value >= b.value ? a : b);
}

/// Форматирует минуты → локализованная строка вида «1h 30min» (≥60) или «45min» (<60).
/// Использует l10n-ключи screentime.fmt_h_min / screentime.fmt_min.
String screenTimeFmt(BuildContext context, int minutes) {
  if (minutes >= 60) {
    return context
        .s('screentime.fmt_h_min')
        .replaceAll('{h}', '${minutes ~/ 60}')
        .replaceAll('{m}', '${minutes % 60}');
  }
  return context.s('screentime.fmt_min').replaceAll('{m}', '$minutes');
}

// ---------------------------------------------------------------------------
// Виджет
// ---------------------------------------------------------------------------

/// Compact inline signal: «Screen time: 1h 30min · Social media 45min [Details]».
///
/// Встраивается в [EveningReviewCard] между tone-текстом и кнопкой «Plan».
/// Нейтральный контекст — не обвинение, а информация для самоанализа.
///
/// Деградирует в [SizedBox.shrink()] когда:
///   • разрешение PACKAGE_USAGE_STATS не выдано
///   • произошла ошибка плагина
///   • суммарное использование == 0 (не-Android / нет данных за сегодня)
class ScreenTimeSignalWidget extends ConsumerWidget {
  const ScreenTimeSignalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(screenTimeUsageProvider);

    // Мягкая деградация — возвращаем пустой виджет без видимых следов
    if (!state.isGranted) return const SizedBox.shrink();
    if (state.hasError) return const SizedBox.shrink();

    final total = screenTimeTotal(state.usedMinutes);
    if (total == 0) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ?? Theme.of(context).colorScheme.secondary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final totalStr = screenTimeFmt(context, total);
    final top = screenTimeTopCategory(state.usedMinutes);
    final topPart = top != null
        ? ' · ${context.s('screentime.cat_${top.key}')} ${screenTimeFmt(context, top.value)}'
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Иконка — textMuted, не accent (информационная, не CTA) — Phosphor deviceMobile
        Icon(PhosphorIcons.deviceMobile(), size: 14, color: mutedColor),
        const SizedBox(width: 6),
        // Expanded + ellipsis предотвращают RenderFlex overflow на 320px
        Expanded(
          child: Text(
            '${context.s('screentime.signal_label')}: $totalStr$topPart',
            style: textTheme.bodySmall?.copyWith(color: mutedColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        // Ссылка «Подробнее» → /screen-time
        InkWell(
          onTap: () => context.push('/screen-time'),
          child: Text(
            context.s('screentime.signal_details'),
            style: textTheme.bodySmall?.copyWith(
              color: primaryColor,
              decoration: TextDecoration.underline,
              decorationColor: primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
