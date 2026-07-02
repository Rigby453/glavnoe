// Общие провайдеры для модуля «История дневника» (diary_history_screen.dart +
// diary_day_detail_screen.dart). Вынесены в отдельный файл, чтобы оба экрана
// могли их использовать без циклического импорта друг друга.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

/// Запись дневника за конкретный календарный день (может отсутствовать).
final dayLogProvider = FutureProvider.family
    .autoDispose<DayLogsTableData?, DateTime>((ref, date) async {
  final start = DateTime.utc(date.year, date.month, date.day);
  return ref.watch(dayLogsDaoProvider).getForDate(start);
});

/// Настроение по дням ВЫБРАННОГО года: ключ — '$year-$month-$day', значение —
/// mood (1..5). Дни без записи/без mood отсутствуют в карте. Используется для
/// раскраски год-календаря в DiaryHistoryScreen.
final dayLogsInYearProvider =
    FutureProvider.family.autoDispose<Map<String, int>, int>((ref, year) async {
  final dao = ref.watch(dayLogsDaoProvider);
  final rows = await dao.getBetween(
    DateTime.utc(year, 1, 1),
    DateTime.utc(year + 1, 1, 1),
  );
  final map = <String, int>{};
  for (final row in rows) {
    final mood = row.mood;
    if (mood == null) continue;
    // .toUtc() восстанавливает исходные Y/M/D, с которыми день был записан
    // (saveForDate пишет DateTime.utc(y,m,d); Drift отдаёт обратно ЛОКАЛЬНОЕ
    // представление того же момента — toUtc() убирает сдвиг часового пояса,
    // который иначе мог бы «съехать» день на западных часовых поясах).
    final d = row.date.toUtc();
    map['${d.year}-${d.month}-${d.day}'] = mood;
  }
  return map;
});

/// Цвет ячейки/легенды по настроению — тональный ramp АКЦЕНТА темы, НЕ
/// светофор danger→success (решение владельца продукта, 2026-07-02): плохое
/// настроение — не «красный сигнал опасности», а просто менее насыщенный
/// акцент. [surface]/[primary] — берутся из Theme.of(context).colorScheme
/// (surface + primary), никаких хардкод-хексов мимо темы.
///
/// [mood] 1..5 → moodT растёт от ~0.25 (mood 1, едва заметный акцент) до 1.0
/// (mood 5, полный акцент), шаг 0.75/4 на единицу mood. Итоговая заливка —
/// Color.lerp(surface, primary, moodT): чем лучше настроение, тем насыщеннее.
Color moodColor(Color surface, Color primary, int mood) {
  final step = (mood - 1).clamp(0, 4) / 4; // 0.0 (mood 1) .. 1.0 (mood 5)
  final moodT = 0.25 + step * 0.75; // 0.25 .. 1.0
  return Color.lerp(surface, primary, moodT)!;
}
