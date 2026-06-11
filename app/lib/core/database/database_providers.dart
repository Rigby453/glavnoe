// Riverpod-провайдеры для Drift БД и DAO
// Единственный экземпляр AppDatabase на приложение
// Экраны читают itemsDaoProvider / streakDaoProvider через ref.watch/read

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'daos/items_dao.dart';
import 'daos/streak_dao.dart';
import 'daos/day_logs_dao.dart';
import 'daos/water_dao.dart';
import 'daos/food_logs_dao.dart';
import 'daos/shopping_dao.dart';
import 'daos/recipes_dao.dart';

/// Единственный экземпляр базы данных
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Закрываем БД при уничтожении провайдера (горячая перезагрузка / тесты)
  ref.onDispose(db.close);
  return db;
});

/// DAO для задач
final itemsDaoProvider = Provider<ItemsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ItemsDao(db);
});

/// DAO для streak
final streakDaoProvider = Provider<StreakDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StreakDao(db);
});

/// DAO для дневных записей (настроение, заметки)
final dayLogsDaoProvider = Provider<DayLogsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DayLogsDao(db);
});

/// DAO для трекера воды (раздел Health)
final waterDaoProvider = Provider<WaterDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WaterDao(db);
});

/// DAO для журнала еды (раздел Health → Food)
final foodLogsDaoProvider = Provider<FoodLogsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FoodLogsDao(db);
});

/// DAO для списка покупок (SPEC C5, Phase 1)
final shoppingDaoProvider = Provider<ShoppingDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ShoppingDao(db);
});

/// DAO для рецептов (SPEC C5, Phase 1)
final recipesDaoProvider = Provider<RecipesDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RecipesDao(db);
});
