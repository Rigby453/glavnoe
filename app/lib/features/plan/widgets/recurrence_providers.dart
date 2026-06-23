// FL-RECUR: слой раскрытия (expansion) повторяющихся серий в виртуальные повторы.
//
// Конкретные строки дня (watchTodayItems/watchItemsInRange уже исключают якоря)
// дополняются ВИРТУАЛЬНЫМИ повторами, порождёнными из якорей серий по правилу
// recurrence.dart. Виртуальный повтор — копия якоря с синтетическим id вида
// `${anchorId}@yyyymmdd`, recurrenceRule=null, status='pending', scheduledAt =
// дата + время-суток якоря.
//
// Ядро (mergeOccurrencesForDay / mergeOccurrencesForRange) — ЧИСТЫЕ функции,
// покрытые test/recurrence_test.dart. Провайдеры лишь склеивают стримы.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../recurrence.dart';

/// Разделитель синтетического id виртуального повтора.
const String kVirtualIdSeparator = '@';

/// `yyyymmdd` для синтетического id повтора.
String virtualDateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}'
    '${day.month.toString().padLeft(2, '0')}'
    '${day.day.toString().padLeft(2, '0')}';

/// true, если [id] — синтетический id виртуального повтора (содержит '@').
bool isVirtualOccurrenceId(String id) => id.contains(kVirtualIdSeparator);

/// Извлекает id якоря из синтетического id повтора. Для обычного id вернёт его же.
String anchorIdFromVirtual(String id) {
  final idx = id.indexOf(kVirtualIdSeparator);
  return idx < 0 ? id : id.substring(0, idx);
}

/// Извлекает дату (полночь) из синтетического id повтора. null если не виртуал
/// или формат даты некорректен.
DateTime? dateFromVirtual(String id) {
  final idx = id.indexOf(kVirtualIdSeparator);
  if (idx < 0) return null;
  final key = id.substring(idx + 1);
  if (key.length != 8) return null;
  final y = int.tryParse(key.substring(0, 4));
  final m = int.tryParse(key.substring(4, 6));
  final d = int.tryParse(key.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Строит один виртуальный повтор якоря [anchor] на дату [day].
ItemsTableData buildVirtualOccurrence(ItemsTableData anchor, DateTime day) {
  final at = DateTime(
    day.year,
    day.month,
    day.day,
    anchor.scheduledAt.hour,
    anchor.scheduledAt.minute,
  );
  return anchor.copyWith(
    id: '${anchor.id}$kVirtualIdSeparator${virtualDateKey(day)}',
    scheduledAt: at,
    status: 'pending',
    // Виртуальный повтор — НЕ серия (иначе UI принял бы его за шаблон).
    recurrenceRule: const Value(null),
  );
}

/// ЧИСТАЯ функция: сливает конкретные строки дня [concrete] с виртуальными
/// повторами всех [anchors], которые порождают повтор на [day].
///
/// Результат отсортирован по scheduledAt (как DAO-запросы). Конкретные строки
/// сохраняются как есть; виртуалы добавляются только для дней, где occursOn
/// истинно (даты в EXDATE/после UNTIL/до старта отсекаются правилом).
List<ItemsTableData> mergeOccurrencesForDay(
  List<ItemsTableData> concrete,
  List<ItemsTableData> anchors,
  DateTime day,
) {
  final result = <ItemsTableData>[...concrete];
  for (final anchor in anchors) {
    final rule = RecurrenceRule.parse(anchor.recurrenceRule);
    if (rule == null) continue;
    if (occursOn(rule, anchor.scheduledAt, day)) {
      result.add(buildVirtualOccurrence(anchor, day));
    }
  }
  result.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return result;
}

/// ЧИСТАЯ функция: то же для диапазона [fromDay, toDay] (по дням, включительно).
/// Конкретные строки [concrete] (могут охватывать несколько дней) сохраняются;
/// для каждого дня окна добавляются виртуалы по occurrenceDatesInRange.
List<ItemsTableData> mergeOccurrencesForRange(
  List<ItemsTableData> concrete,
  List<ItemsTableData> anchors,
  DateTime fromDay,
  DateTime toDay,
) {
  final result = <ItemsTableData>[...concrete];
  for (final anchor in anchors) {
    final rule = RecurrenceRule.parse(anchor.recurrenceRule);
    if (rule == null) continue;
    final dates = occurrenceDatesInRange(
      anchor.scheduledAt,
      rule,
      fromDay,
      toDay,
    );
    for (final d in dates) {
      result.add(buildVirtualOccurrence(anchor, d));
    }
  }
  result.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return result;
}

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Стрим якорей серий (recurrenceRule != null).
final seriesAnchorsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchSeriesAnchors();
});

/// Раскрытые задачи дня = конкретные строки дня + виртуальные повторы серий.
/// Замена watchTodayItems(date) для всех поверхностей отображения.
final expandedDayItemsProvider = StreamProvider.autoDispose
    .family<List<ItemsTableData>, DateTime>((ref, date) {
  final dao = ref.watch(itemsDaoProvider);
  final anchorsAsync = ref.watch(seriesAnchorsProvider);
  final anchors = anchorsAsync.valueOrNull ?? const <ItemsTableData>[];
  return dao
      .watchTodayItems(date)
      .map((concrete) => mergeOccurrencesForDay(concrete, anchors, date));
});

/// Раскрытые задачи диапазона [from, to) = конкретные + виртуалы серий.
/// Замена watchItemsInRange(from, to) для недельной сетки.
/// Ключ — запись (from, to) локальная полночь, как rangeItemsProvider.
final expandedRangeItemsProvider = StreamProvider.autoDispose
    .family<List<ItemsTableData>, (DateTime, DateTime)>((ref, range) {
  final dao = ref.watch(itemsDaoProvider);
  final anchorsAsync = ref.watch(seriesAnchorsProvider);
  final anchors = anchorsAsync.valueOrNull ?? const <ItemsTableData>[];
  // Диапазон полуоткрытый [from, to): последний день — to - 1 день.
  final fromDay = DateTime(range.$1.year, range.$1.month, range.$1.day);
  final lastDay = DateTime(range.$2.year, range.$2.month, range.$2.day)
      .subtract(const Duration(days: 1));
  return dao.watchItemsInRange(range.$1, range.$2).map(
        (concrete) =>
            mergeOccurrencesForRange(concrete, anchors, fromDay, lastDay),
      );
});
