// Редактор рецепта (SPEC C5, Phase 1): ингредиенты из поиска Open Food Facts,
// итоги КБЖУ считает код (recipe_nutrition.dart), готовый рецепт логируется
// в food_logs как обычная порция (синхронизация еды уже работает, ADR-024).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/database/database_providers.dart';
import '../../services/api/api_client.dart';
import 'food_nutrition.dart';
import 'recipe_nutrition.dart';
import 'recipes_screen.dart' show
    promptRecipeName,
    recipeIngredientsProvider,
    recipeProvider;

const List<String> _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

class RecipeEditorScreen extends ConsumerWidget {
  const RecipeEditorScreen({super.key, required this.recipeId});

  final String recipeId;

  // --- Действия -------------------------------------------------------------

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    RecipesTableData recipe,
  ) async {
    final name = await promptRecipeName(
      context,
      title: context.s('food.rename_recipe'),
      initial: recipe.name,
    );
    if (name != null && name.isNotEmpty && name != recipe.name) {
      await ref.read(recipesDaoProvider).renameRecipe(recipe.id, name);
    }
  }

  Future<void> _editGrams(
    BuildContext context,
    WidgetRef ref,
    RecipeIngredientsTableData ing,
  ) async {
    final grams = await _promptGrams(
      context,
      title: ing.name,
      initial: ing.grams,
    );
    if (grams != null && grams > 0) {
      await ref.read(recipesDaoProvider).updateIngredientGrams(ing.id, grams);
    }
  }

  Future<void> _addIngredient(BuildContext context, WidgetRef ref) async {
    await showAppSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _IngredientSearchSheet(recipeId: recipeId),
    );
  }

  /// Записать порцию рецепта в дневник еды.
  Future<void> _logRecipe(
    BuildContext context,
    WidgetRef ref,
    RecipesTableData recipe,
    List<RecipeIngredientsTableData> ingredients,
  ) async {
    final totals = recipeTotals(ingredients);
    final per100 = recipePer100g(totals.total, totals.totalGrams);
    if (per100 == null) return; // пустой рецепт — кнопка и так выключена

    final result = await showDialog<({double grams, String meal})>(
      context: context,
      builder: (_) => _LogRecipeDialog(
        name: recipe.name,
        totalGrams: totals.totalGrams,
      ),
    );
    if (result == null) return;

    final scaled = scaleNutrition(per100, result.grams);
    await ref.read(foodLogsDaoProvider).addLog(
          date: DateTime.now(),
          meal: result.meal,
          name: recipe.name,
          grams: result.grams,
          calories: scaled.calories,
          protein: scaled.protein,
          fat: scaled.fat,
          carbs: scaled.carbs,
          sugar: scaled.sugar,
          fiber: scaled.fiber,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        // Строка интерполирована — оставляем как есть (имя + приём пищи динамические)
        SnackBar(content: Text('"${recipe.name}" logged as ${result.meal}')),
      );
      Navigator.of(context).pop();
    }
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeProvider(recipeId)).valueOrNull;
    final ingredients =
        ref.watch(recipeIngredientsProvider(recipeId)).valueOrNull ??
            const <RecipeIngredientsTableData>[];

    if (recipe == null) {
      // Рецепт удалён или ещё грузится первая выборка.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totals = recipeTotals(ingredients);
    final per100 = recipePer100g(totals.total, totals.totalGrams);

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            tooltip: context.s('food.rename_tooltip'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(context, ref, recipe),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ingredients.isEmpty
                ? _emptyIngredients(context)
                : ListView.builder(
                    itemCount: ingredients.length,
                    itemBuilder: (context, i) {
                      final ing = ingredients[i];
                      return Dismissible(
                        key: ValueKey(ing.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Theme.of(context).colorScheme.error,
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        onDismissed: (_) => ref
                            .read(recipesDaoProvider)
                            .removeIngredient(ing.id),
                        child: ListTile(
                          title: Text(ing.name),
                          subtitle: ing.calories == null
                              ? null
                              : Text(
                                  '${(ing.calories! * ing.grams / 100).round()} kcal',
                                ),
                          trailing: TextButton(
                            child: Text('${ing.grams.round()} g'),
                            onPressed: () => _editGrams(context, ref, ing),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (per100 != null) _TotalsCard(totals: totals, per100: per100),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(context.s('food.add_ingredient')),
                          onPressed: () => _addIngredient(context, ref),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.restaurant, size: 18),
                          label: Text(context.s('food.log_recipe_btn')),
                          onPressed: ingredients.isEmpty
                              ? null
                              : () => _logRecipe(
                                  context, ref, recipe, ingredients),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyIngredients(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withAlpha(80);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.egg_alt_outlined, size: 56, color: muted),
          const SizedBox(height: 16),
          Text(
            context.s('food.ingredients_empty'),
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка итогов: total + per 100 g
// ---------------------------------------------------------------------------

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, required this.per100});

  final RecipeTotals totals;
  final Nutrition per100;

  String _fmt(double? v) => v == null ? '—' : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = totals.total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Whole recipe · ${totals.totalGrams.round()} g',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${_fmt(t.calories)} kcal · P ${_fmt(t.protein)} · '
              'F ${_fmt(t.fat)} · C ${_fmt(t.carbs)}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Per 100 g: ${_fmt(per100.calories)} kcal · '
              'P ${_fmt(per100.protein)} · F ${_fmt(per100.fat)} · '
              'C ${_fmt(per100.carbs)}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Шит поиска ингредиента (Open Food Facts через бэкенд)
// ---------------------------------------------------------------------------

class _IngredientSearchSheet extends ConsumerStatefulWidget {
  const _IngredientSearchSheet({required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<_IngredientSearchSheet> createState() =>
      _IngredientSearchSheetState();
}

class _IngredientSearchSheetState
    extends ConsumerState<_IngredientSearchSheet> {
  final _controller = TextEditingController();
  List<dynamic> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ref.read(apiClientProvider).foodSearch(q);
      if (mounted) setState(() => _results = products);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(Map<String, dynamic> product) async {
    final name = (product['name'] as String?) ?? 'Ingredient';
    final grams = await _promptGrams(context, title: name, initial: 100);
    if (grams == null || grams <= 0) return;

    final per = product['per_100g'] as Map<String, dynamic>?;
    double? d(String k) => (per?[k] as num?)?.toDouble();

    await ref.read(recipesDaoProvider).addIngredient(
          recipeId: widget.recipeId,
          name: name,
          grams: grams,
          per100g: Nutrition(
            calories: d('calories'),
            protein: d('protein'),
            fat: d('fat'),
            carbs: d('carbs'),
            sugar: d('sugar'),
            fiber: d('fiber'),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.s('food.add_ingredient'), style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: context.s('food.search_hint'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: textTheme.bodyMedium),
              )
            else
              ..._results.whereType<Map<String, dynamic>>().map((p) {
                final per = p['per_100g'] as Map<String, dynamic>?;
                final kcal = (per?['calories'] as num?)?.round();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((p['name'] as String?) ?? context.s('food.unknown_product')),
                  subtitle: Text([
                    if (p['brand'] != null) p['brand'] as String,
                    if (kcal != null) '$kcal kcal / 100g',
                  ].join(' · ')),
                  onTap: () => _pick(p),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Диалоги
// ---------------------------------------------------------------------------

/// Диалог ввода граммов (добавление ингредиента / правка).
Future<double?> _promptGrams(
  BuildContext context, {
  required String title,
  required double initial,
}) {
  final controller =
      TextEditingController(text: initial.round().toString());
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: ctx.s('food.grams_label')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final grams = double.tryParse(controller.text.trim());
            if (grams == null || grams <= 0) return;
            Navigator.of(ctx).pop(grams);
          },
          child: Text(ctx.s('food.ok_btn')),
        ),
      ],
    ),
  );
}

/// Диалог логирования рецепта: граммы съеденного + приём пищи.
class _LogRecipeDialog extends StatefulWidget {
  const _LogRecipeDialog({required this.name, required this.totalGrams});

  final String name;
  final double totalGrams;

  @override
  State<_LogRecipeDialog> createState() => _LogRecipeDialogState();
}

class _LogRecipeDialogState extends State<_LogRecipeDialog> {
  late final TextEditingController _grams;
  String _meal = 'lunch';

  @override
  void initState() {
    super.initState();
    // По умолчанию — вся готовая порция рецепта.
    _grams = TextEditingController(text: widget.totalGrams.round().toString());
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.s('food.grams_eaten_label')),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _meals.map((m) {
              // Локализуем название приёма пищи через ключ food.meal_*
              return ChoiceChip(
                label: Text(context.s('food.meal_$m')),
                selected: _meal == m,
                onSelected: (_) => setState(() => _meal = m),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final grams = double.tryParse(_grams.text.trim());
            if (grams == null || grams <= 0) return;
            Navigator.of(context).pop((grams: grams, meal: _meal));
          },
          child: Text(context.s('food.log_btn')),
        ),
      ],
    );
  }
}
