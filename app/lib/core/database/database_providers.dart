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
import 'daos/sleep_dao.dart';
import 'daos/workouts_dao.dart';
import 'daos/goals_dao.dart';
import 'daos/habits_dao.dart';
import 'daos/item_attachments_dao.dart';
import 'daos/subtasks_dao.dart';
import 'daos/custom_breathing_dao.dart';
import 'daos/custom_meditation_dao.dart';
import 'daos/mood_logs_dao.dart';

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

/// DAO для трекера сна (Phase 2)
final sleepDaoProvider = Provider<SleepDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SleepDao(db);
});

/// DAO для шаблонов тренировок (Phase 2)
final workoutsDaoProvider = Provider<WorkoutsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WorkoutsDao(db);
});

/// DAO для долгосрочных целей (SPEC C4, Phase 3)
final goalsDaoProvider = Provider<GoalsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalsDao(db);
});

/// DAO для трекера привычек (schemaVersion 10)
final habitsDaoProvider = Provider<HabitsDao>((ref) {
  return ref.watch(appDatabaseProvider).habitsDao;
});

/// DAO для вложений задач — фото/видео (schemaVersion 11, локально)
final itemAttachmentsDaoProvider = Provider<ItemAttachmentsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ItemAttachmentsDao(db);
});

/// DAO для подзадач (чеклист задач, schemaVersion 14)
final subtasksDaoProvider = Provider<SubtasksDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SubtasksDao(db);
});

/// DAO для пользовательских дыхательных техник (schemaVersion 20)
final customBreathingDaoProvider = Provider<CustomBreathingDao>((ref) {
  return ref.watch(appDatabaseProvider).customBreathingDao;
});

/// DAO для пользовательских медитативных сессий (schemaVersion 21)
final customMeditationDaoProvider = Provider<CustomMeditationDao>((ref) {
  return ref.watch(appDatabaseProvider).customMeditationDao;
});

/// DAO для логов настроения после медитации (schemaVersion 22, локальный)
final moodLogsDaoProvider = Provider<MoodLogsDao>((ref) {
  return ref.watch(appDatabaseProvider).moodLogsDao;
});

/// Все уникальные теги из истории задач (sorted by usage frequency desc).
/// Используется формой создания задачи — ряд подсказок тегов (B7).
final allUsedTagsProvider = FutureProvider<List<String>>((ref) {
  // ref.watch, а не ref.read: Riverpod требует watch внутри провайдера, чтобы
  // граф зависимостей строился корректно (itemsDaoProvider стабилен, но явная
  // зависимость необходима для lint и будущих перезагрузок).
  return ref.watch(itemsDaoProvider).allUsedTags();
});
