// Провайдеры экрана Plan: режим вида (День/Неделя/Месяц) и реактивный
// диапазон задач для месячного календаря.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';

/// Режим отображения плана.
enum PlanView { day, week, month }

/// Текущий выбранный режим вида. По умолчанию — День (текущее поведение).
final planViewProvider = StateProvider<PlanView>((ref) => PlanView.day);

/// Задачи в диапазоне [from, to) реактивно. Ключ — запись (from, to)
/// (записи в Dart 3 имеют value-equality, поэтому годятся как family-ключ).
final rangeItemsProvider = StreamProvider.autoDispose
    .family<List<ItemsTableData>, (DateTime, DateTime)>((ref, range) {
  return ref.watch(itemsDaoProvider).watchItemsInRange(range.$1, range.$2);
});
