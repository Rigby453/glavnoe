// DAO для food_logs (модуль «Еда»). Хранит съеденное за день с уже
// посчитанными КБЖУ на порцию. Числа берутся из Open Food Facts (на 100 г) и
// масштабируются под граммы при добавлении.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'food_logs_dao.g.dart';

@DriftAccessor(tables: [FoodLogsTable])
class FoodLogsDao extends DatabaseAccessor<AppDatabase>
    with _$FoodLogsDaoMixin {
  FoodLogsDao(super.db);

  /// Реактивно: все записи о еде за день, по времени добавления.
  Stream<List<FoodLogsTableData>> watchForDay(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(foodLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(dayEnd),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Добавить запись о съеденном. Абсолютные значения КБЖУ уже посчитаны.
  Future<void> addLog({
    required DateTime date,
    required String meal,
    required String name,
    required double grams,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? sugar,
    double? fiber,
  }) async {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    await into(foodLogsTable).insert(
      FoodLogsTableCompanion(
        id: Value(uuidV4()),
        date: Value(dayStart),
        meal: Value(meal),
        name: Value(name),
        grams: Value(grams),
        calories: Value(calories),
        protein: Value(protein),
        fat: Value(fat),
        carbs: Value(carbs),
        sugar: Value(sugar),
        fiber: Value(fiber),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить запись о еде по id.
  Future<void> deleteLog(String id) async {
    await (delete(foodLogsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Записи за последние [days] дней, свежие первыми.
  /// Используется как источник «недавних продуктов» для AI-сборки меню.
  Future<List<FoodLogsTableData>> recentLogs(int days) {
    final now = DateTime.now();
    final cutoff = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: days));
    return (select(foodLogsTable)
          ..where((t) => t.date.isBiggerOrEqualValue(cutoff))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }
}
