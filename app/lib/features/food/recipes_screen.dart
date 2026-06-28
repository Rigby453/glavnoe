// Экран «Мои рецепты» (SPEC C5, Phase 1).
// Kaname redesign §4.2: object cards (surface1 + hairline R14), Phosphor icons,
// KaiMascot empty state + verb button. ONE primary FilledButton per screen (FAB).
// Пользователь собирает блюда из ингредиентов; КБЖУ считает код (recipe_nutrition.dart).
// Рецепты локальные (Drift, ADR: без синка до Ф3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../features/mascot/kai_mascot.dart';
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

  /// Удалить рецепт с возможностью Undo. Снапшот ДО удаления → восстановление.
  Future<void> _deleteRecipe(
    BuildContext context,
    WidgetRef ref,
    RecipesTableData recipe,
  ) async {
    final dao = ref.read(recipesDaoProvider);
    final ingredientSnapshot =
        ref.read(recipeIngredientsProvider(recipe.id)).valueOrNull ??
            const <RecipeIngredientsTableData>[];

    await dao.deleteRecipe(recipe.id);

    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${recipe.name}" — ${context.s('food.recipe_removed')}',
      onUndo: () async {
        await dao.restoreRecipe(recipe, ingredientSnapshot);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(context.s('food.my_recipes_title'))),
      // FAB = единственная primary-кнопка экрана (§4.3), позиция endFloat
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipes_add_fab',
        tooltip: context.s('food.new_recipe'),
        onPressed: () => _newRecipe(context, ref),
        child: Icon(PhosphorIcons.plus()),
      ),
      body: recipes.isEmpty
          ? _EmptyState(onAdd: () => _newRecipe(context, ref))
          : ListView.builder(
              // 24dp экранный отступ + 88dp снизу для FAB
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 88),
              itemCount: recipes.length,
              itemBuilder: (context, i) {
                final r = recipes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  // SwipeToDelete: свайп влево → удаление + Undo-snackbar
                  child: SwipeToDelete(
                    key: ValueKey('recipe_${r.id}'),
                    onDelete: () => _deleteRecipe(context, ref, r),
                    child: _RecipeTile(
                      recipe: r,
                      onDelete: () => _deleteRecipe(context, ref, r),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка рецепта — §4.2 object card
// surface1 + 0.5dp hairline (ext.border) + R14, pad 11×12
// Leading neutral icon, title+subtitle, trailing trash(ember) + caretRight
// ---------------------------------------------------------------------------

class _RecipeTile extends ConsumerWidget {
  const _RecipeTile({required this.recipe, required this.onDelete});

  final RecipesTableData recipe;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? cs.onSurface.withAlpha(153);
    final faintColor = ext?.textFaint ?? cs.onSurface.withAlpha(80);
    final emberColor = ext?.ember ?? cs.error;
    final borderColor = ext?.border ?? cs.outline.withAlpha(50);

    final ingredients =
        ref.watch(recipeIngredientsProvider(recipe.id)).valueOrNull ??
            const <RecipeIngredientsTableData>[];
    final totals = recipeTotals(ingredients);
    final per100 = recipePer100g(totals.total, totals.totalGrams);
    final kcal100 = per100?.calories?.round();

    final subtitle = [
      plIngredients(context, ingredients.length),
      if (kcal100 != null)
        context
            .s('food.kcal_per_100g')
            .replaceFirst('{kcal}', '$kcal100'),
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          padding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
          child: Row(
            children: [
              // Ведущая нейтральная иконка (textMuted, не акцент)
              Icon(PhosphorIcons.cookingPot(), size: 20, color: mutedColor),
              const SizedBox(width: 12),
              // Название + подзаголовок (занимают всё доступное место)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.name,
                      style: tt.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(color: mutedColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Удалить — ember (§4.2 «trash(ember)»)
              IconButton(
                icon: Icon(PhosphorIcons.trash(), size: 20, color: emberColor),
                tooltip: context.s('btn.delete'),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
              // Стрелка навигации — textFaint
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  PhosphorIcons.caretRight(),
                  size: 16,
                  color: faintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Пустое состояние — KaiMascot (neutral, 64) + текст + verb button (§4.2)
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final tt = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KaiMascot(
              size: 64,
              emotion: KaiEmotion.neutral,
              isHarsh: tone == AppTone.harsh,
            ),
            const SizedBox(height: 16),
            Text(
              context.s('food.recipes_empty'),
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 16),
            // Verb button — единственный primary на экране (§4.3)
            FilledButton.icon(
              icon: Icon(PhosphorIcons.plus(), size: 18),
              label: Text(context.s('food.new_recipe')),
              onPressed: onAdd,
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
