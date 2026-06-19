// DAO для рецептов (SPEC C5, Phase 1).
// Пользователь собирает блюдо из ингредиентов; числа КБЖУ считаются локально.
// Готовый рецепт логируется как обычная строка food_logs.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';
import '../../../features/food/food_nutrition.dart';

part 'recipes_dao.g.dart';

@DriftAccessor(tables: [RecipesTable, RecipeIngredientsTable])
class RecipesDao extends DatabaseAccessor<AppDatabase>
    with _$RecipesDaoMixin {
  RecipesDao(super.db);

  // ---------------------------------------------------------------------------
  // Рецепты
  // ---------------------------------------------------------------------------

  /// Реактивный список всех рецептов, сортировка: самые свежие первыми.
  Stream<List<RecipesTableData>> watchRecipes() {
    return (select(recipesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Реактивно: один рецепт по id (null, если удалён).
  Stream<RecipesTableData?> watchRecipe(String id) {
    return (select(recipesTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Создать новый рецепт; возвращает id созданной записи.
  Future<String> createRecipe(String name) async {
    final id = uuidV4();
    final now = DateTime.now();
    await into(recipesTable).insert(
      RecipesTableCompanion(
        id: Value(id),
        name: Value(name),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  /// Переименовать рецепт; сдвигает updatedAt.
  Future<void> renameRecipe(String id, String name) async {
    await (update(recipesTable)..where((t) => t.id.equals(id))).write(
      RecipesTableCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить рецепт и все его ингредиенты (каскад в транзакции).
  Future<void> deleteRecipe(String id) async {
    await transaction(() async {
      await (delete(recipeIngredientsTable)
            ..where((t) => t.recipeId.equals(id)))
          .go();
      await (delete(recipesTable)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Ингредиенты
  // ---------------------------------------------------------------------------

  /// Реактивный список ингредиентов рецепта, сортировка: по sortOrder.
  Stream<List<RecipeIngredientsTableData>> watchIngredients(String recipeId) {
    return (select(recipeIngredientsTable)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Добавить ингредиент. [per100g] — значения «на 100 г» из базы продуктов;
  /// копируются в строку ингредиента (snapshot).
  Future<void> addIngredient({
    required String recipeId,
    required String name,
    required double grams,
    Nutrition? per100g,
  }) async {
    // sortOrder = текущее кол-во ингредиентов
    final existing = await (select(recipeIngredientsTable)
          ..where((t) => t.recipeId.equals(recipeId)))
        .get();
    final sortOrder = existing.length;

    await into(recipeIngredientsTable).insert(
      RecipeIngredientsTableCompanion(
        id: Value(uuidV4()),
        recipeId: Value(recipeId),
        name: Value(name),
        grams: Value(grams),
        calories: Value(per100g?.calories),
        protein: Value(per100g?.protein),
        fat: Value(per100g?.fat),
        carbs: Value(per100g?.carbs),
        sugar: Value(per100g?.sugar),
        fiber: Value(per100g?.fiber),
        sortOrder: Value(sortOrder),
      ),
    );

    // Обновляем updatedAt у родительского рецепта
    await (update(recipesTable)..where((t) => t.id.equals(recipeId))).write(
      RecipesTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Удалить ингредиент по id.
  Future<void> removeIngredient(String id) async {
    // Читаем recipeId до удаления, чтобы обновить updatedAt рецепта
    final row = await (select(recipeIngredientsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (delete(recipeIngredientsTable)..where((t) => t.id.equals(id))).go();
    if (row != null) {
      await (update(recipesTable)
            ..where((t) => t.id.equals(row.recipeId)))
          .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  /// Восстановить удалённый ингредиент по снапшоту (Undo-паттерн).
  /// Сохраняет оригинальный id и все поля — без изменений схемы БД.
  Future<void> restoreIngredient(RecipeIngredientsTableData snapshot) async {
    // insertOnConflictUpdate: если ингредиент вдруг ещё не удалён — обновляем.
    await into(recipeIngredientsTable).insertOnConflictUpdate(
      RecipeIngredientsTableCompanion(
        id: Value(snapshot.id),
        recipeId: Value(snapshot.recipeId),
        name: Value(snapshot.name),
        grams: Value(snapshot.grams),
        calories: Value(snapshot.calories),
        protein: Value(snapshot.protein),
        fat: Value(snapshot.fat),
        carbs: Value(snapshot.carbs),
        sugar: Value(snapshot.sugar),
        fiber: Value(snapshot.fiber),
        sortOrder: Value(snapshot.sortOrder),
      ),
    );
    // Обновляем updatedAt рецепта
    await (update(recipesTable)
          ..where((t) => t.id.equals(snapshot.recipeId)))
        .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
  }

  /// Обновить граммы ингредиента.
  Future<void> updateIngredientGrams(String id, double grams) async {
    final row = await (select(recipeIngredientsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (update(recipeIngredientsTable)..where((t) => t.id.equals(id))).write(
      RecipeIngredientsTableCompanion(grams: Value(grams)),
    );
    if (row != null) {
      await (update(recipesTable)
            ..where((t) => t.id.equals(row.recipeId)))
          .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }
}
