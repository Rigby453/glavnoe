// Экран «Мои рецепты» (SPEC C5, Phase 1).
// Пользователь собирает блюда из ингредиентов; КБЖУ считает код
// (recipe_nutrition.dart). Рецепты локальные (Drift, ADR: без синка до Ф3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import 'recipe_nutrition.dart';

// ---------------------------------------------------------------------------
// Провайдеры (используются и редактором рецепта)
// ---------------------------------------------------------------------------

/// Все рецепты, свежие сверху.
final recipesListProvider =
    StreamProvider.autoDispose<List<RecipesTableData>>((ref) {
  return ref.watch(recipesDaoProvider).watchRecipes();
});

/// Ингредиенты одного рецепта (family по id).
final recipeIngredientsProvider = StreamProvider.autoDispose
    .family<List<RecipeIngredientsTableData>, String>((ref, recipeId) {
  return ref.watch(recipesDaoProvider).watchIngredients(recipeId);
});

/// Один рецепт по id (null после удаления).
final recipeProvider = StreamProvider.autoDispose
    .family<RecipesTableData?, String>((ref, id) {
  return ref.watch(recipesDaoProvider).watchRecipe(id);
});

// ---------------------------------------------------------------------------
// Экран списка
// ---------------------------------------------------------------------------

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  Future<void> _newRecipe(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, title: context.s('food.new_recipe'));
    if (name == null || name.isEmpty) return;
    final id = await ref.read(recipesDaoProvider).createRecipe(name);
    if (context.mounted) context.push('/recipes/$id');
  }

  Future<void> _deleteRecipe(
    BuildContext context,
    WidgetRef ref,
    RecipesTableData recipe,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${recipe.name}"?'),
        content: Text(ctx.s('food.delete_recipe_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.s('btn.delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(recipesDaoProvider).deleteRecipe(recipe.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(context.s('food.my_recipes_title'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.s('food.new_recipe')),
        onPressed: () => _newRecipe(context, ref),
      ),
      body: recipes.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: recipes.length,
              itemBuilder: (context, i) {
                final r = recipes[i];
                return _RecipeTile(
                  key: ValueKey(r.id),
                  recipe: r,
                  onDelete: () => _deleteRecipe(context, ref, r),
                );
              },
            ),
    );
  }
}

class _RecipeTile extends ConsumerWidget {
  const _RecipeTile({required this.recipe, required this.onDelete, super.key});

  final RecipesTableData recipe;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients =
        ref.watch(recipeIngredientsProvider(recipe.id)).valueOrNull ??
            const <RecipeIngredientsTableData>[];
    final totals = recipeTotals(ingredients);
    final per100 = recipePer100g(totals.total, totals.totalGrams);
    final kcal100 = per100?.calories?.round();

    final subtitle = [
      '${ingredients.length} ingredient${ingredients.length == 1 ? '' : 's'}',
      if (kcal100 != null) '$kcal100 kcal / 100 g',
    ].join(' · ');

    return ListTile(
      leading: const Icon(Icons.restaurant_menu),
      title: Text(recipe.name),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: context.s('btn.delete'),
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: () => context.push('/recipes/${recipe.id}'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withAlpha(80);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu, size: 56, color: muted),
          const SizedBox(height: 16),
          Text(
            context.s('food.recipes_empty'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Общий диалог ввода имени (новый рецепт / переименование)
// ---------------------------------------------------------------------------

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: ctx.s('food.recipe_name_hint')),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(ctx.s('btn.save')),
        ),
      ],
    ),
  );
}

/// Публичная обёртка для редактора (живёт здесь, чтобы не дублировать диалог).
Future<String?> promptRecipeName(
  BuildContext context, {
  required String title,
  String initial = '',
}) =>
    _promptName(context, title: title, initial: initial);
