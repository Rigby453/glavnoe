// Riverpod-провайдеры для Drift БД и DAO
// Единственный экземпляр AppDatabase на приложение
// Экраны читают itemsDaoProvider / streakDaoProvider через ref.watch/read

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'daos/items_dao.dart';
import 'daos/streak_dao.dart';
import 'daos/day_logs_dao.dart';
import 'daos/water_dao.dart';

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
