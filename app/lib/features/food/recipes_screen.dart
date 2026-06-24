// Экран «Мои рецепты» (SPEC C5, Phase 1).
// Пользователь собирает блюда из ингредиентов; КБЖУ считает код
// (recipe_nutrition.dart). Рецепты локальные (Drift, ADR: без синка до Ф3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/settings/fab_position_provider.dart';
import '../../core/theme/app_theme.dart';
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
        title: Text(
          'Delete "${recipe.name}"?',
          style: ctx.textTheme.titleMedium,
        ),
        content: Text(ctx.s('food.delete_recipe_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('btn.cancel')),
          ),
          // Деструктивное действие — FilledButton с ember стилем (03-components §2)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.secondary,
              foregroundColor: Theme.of(ctx).colorScheme.onSecondary,
            ),
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

    final fabLocation = ref.watch(fabPositionProvider).fabLocation;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('food.my_recipes_title'))),
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipes_add_fab',
        tooltip: context.s('food.new_recipe'),
        onPressed: () => _newRecipe(context, ref),
        child: const Icon(Icons.add),
      ),
      body: recipes.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              // 24dp экранный отступ + 88dp снизу для FAB
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 88),
              itemCount: recipes.length,
              itemBuilder: (context, i) {
                final r = recipes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecipeTile(
                    key: ValueKey(r.id),
                    recipe: r,
                    onDelete: () => _deleteRecipe(context, ref, r),
                  ),
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
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    final ingredients =
        ref.watch(recipeIngredientsProvider(recipe.id)).valueOrNull ??
            const <RecipeIngredientsTableData>[];
    final totals = recipeTotals(ingredients);
    final per100 = recipePer100g(totals.total, totals.totalGrams);
    final kcal100 = per100?.calories?.round();

    final subtitle = [
      plIngredients(context, ingredients.length),
      if (kcal100 != null) '$kcal100 kcal / 100 g',
    ].join(' · ');

    return Card(
      child: ListTile(
        // Иконка рецепта — нейтральный textMuted (не акцент, 03-components §19)
        leading: Icon(
          Icons.restaurant_menu_outlined,
          color: mutedColor,
        ),
        title: Text(recipe.name),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
        trailing: IconButton(
          tooltip: context.s('btn.delete'),
          icon: Icon(
            Icons.delete_outline,
            size: 20,
            color: ext?.textFaint,
          ),
          onPressed: onDelete,
        ),
        onTap: () => context.push('/recipes/${recipe.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // textFaint — третичный уровень для пустых состояний (01-color.md)
    final faintColor = ext?.textFaint ?? Theme.of(context).colorScheme.onSurface.withAlpha(80);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 56, color: faintColor),
            const SizedBox(height: 16),
            Text(
              context.s('food.recipes_empty'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: faintColor),
            ),
          ],
        ),
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
      title: Text(title, style: ctx.textTheme.titleMedium),
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

// Расширение для удобного доступа к textTheme (локальный хелпер)
extension _ContextTextTheme on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}
