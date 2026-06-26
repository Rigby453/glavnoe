// Редактор рецепта (SPEC C5, Phase 1): ингредиенты из поиска Open Food Facts,
// итоги КБЖУ считает код (recipe_nutrition.dart), готовый рецепт логируется
// в food_logs как обычная порция (синхронизация еды уже работает, ADR-024).
//
// Паттерн безопасного удаления ингредиентов (ADR-delete-safe):
//   - Свайп влево (SwipeToDelete) ИЛИ кнопка-корзина trailing IconButton
//   - Оба пути идут через _deleteIngredient(), который:
//     1. Сохраняет снапшот ингредиента ДО удаления
//     2. Удаляет через DAO
//     3. Показывает Undo-snackbar через showUndoSnackBar
//     4. По нажатию Undo: вызывает dao.restoreIngredient(snapshot)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/database/database_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../services/api/api_client.dart';
import 'food_nutrition.dart';
import 'recipe_nutrition.dart';
import 'recipes_screen.dart' show
    promptRecipeName,
    recipeIngredientsProvider,
    recipeProvider;

const List<String> _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

// ConsumerStatefulWidget (не ConsumerWidget) — нужен mounted-check
// после асинхронных операций удаления в SwipeToDelete.onDismissed.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {

  // --- Действия -------------------------------------------------------------

  Future<void> _rename(RecipesTableData recipe) async {
    final name = await promptRecipeName(
      context,
      title: context.s('food.rename_recipe'),
      initial: recipe.name,
    );
    if (name != null && name.isNotEmpty && name != recipe.name) {
      await ref.read(recipesDaoProvider).renameRecipe(recipe.id, name);
    }
  }

  Future<void> _editGrams(RecipeIngredientsTableData ing) async {
    final grams = await _promptGrams(
      context,
      title: ing.name,
      initial: ing.grams,
    );
    if (grams != null && grams > 0) {
      await ref.read(recipesDaoProvider).updateIngredientGrams(ing.id, grams);
    }
  }

  Future<void> _addIngredient() async {
    await showAppSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _IngredientSearchSheet(recipeId: widget.recipeId),
    );
  }

  /// Записать порцию рецепта в дневник еды.
  Future<void> _logRecipe(
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
    if (mounted) {
      // Локализуем название приёма пищи через food.meal_* ключ
      final mealLabel = context.s('food.meal_${result.meal}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('food.recipe_logged_snack')
                .replaceAll('{name}', recipe.name)
                .replaceAll('{meal}', mealLabel),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // --- Единый путь удаления ингредиента + Undo --------------------------------

  /// Удалить ингредиент и показать Undo-snackbar.
  /// Вызывается как из SwipeToDelete.onDelete, так и из кнопки-корзины.
  Future<void> _deleteIngredient(RecipeIngredientsTableData ing) async {
    // Снапшот ДО удаления — для восстановления по Undo
    final snapshot = ing;
    final dao = ref.read(recipesDaoProvider);

    await dao.removeIngredient(snapshot.id);

    if (!mounted) return;

    // Сообщение: имя ингредиента + ключ 'food.ingredient_removed'
    final message = '"${snapshot.name}" — ${context.s('food.ingredient_removed')}';
    showUndoSnackBar(
      context,
      message: message,
      onUndo: () async {
        await dao.restoreIngredient(snapshot);
      },
    );
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    final recipe = ref.watch(recipeProvider(widget.recipeId)).valueOrNull;
    final ingredients =
        ref.watch(recipeIngredientsProvider(widget.recipeId)).valueOrNull ??
            const <RecipeIngredientsTableData>[];

    if (recipe == null) {
      // Рецепт удалён или ещё грузится первая выборка.
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: KaiLoader(label: context.s('loading.recipe')),
        ),
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
            onPressed: () => _rename(recipe),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ingredients.isEmpty
                ? _emptyIngredients(context, ext)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: ingredients.length,
                    itemBuilder: (context, i) {
                      final ing = ingredients[i];
                      // SwipeToDelete: свайп влево → _deleteIngredient
                      return SwipeToDelete(
                        key: ValueKey(ing.id),
                        onDelete: () => _deleteIngredient(ing),
                        child: ListTile(
                          title: Text(ing.name),
                          subtitle: ing.calories == null
                              ? null
                              : Text(
                                  '${(ing.calories! * ing.grams / 100).round()} kcal',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: mutedColor,
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Кнопка граммов (как раньше)
                              TextButton(
                                child: Text(
                                  '${ing.grams.round()} g',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: mutedColor,
                                  ),
                                ),
                                onPressed: () => _editGrams(ing),
                              ),
                              // Кнопка-корзина — второй способ удаления (03-components)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  // textFaint — мягкий, не агрессивный цвет для корзины
                                  color: ext?.textFaint ??
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(100),
                                ),
                                tooltip: context.s('btn.delete'),
                                onPressed: () => _deleteIngredient(ing),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Нижняя панель: итоги + кнопки действий
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (per100 != null) _TotalsCard(totals: totals, per100: per100),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Вторичное действие — OutlinedButton
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(context.s('food.add_ingredient')),
                          onPressed: _addIngredient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Первичное действие — FilledButton (03-components §2)
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.restaurant, size: 18),
                          label: Text(context.s('food.log_recipe_btn')),
                          onPressed: ingredients.isEmpty
                              ? null
                              : () => _logRecipe(recipe, ingredients),
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

  Widget _emptyIngredients(BuildContext context, FocusThemeExtension? ext) {
    // textFaint — третичный уровень для пустых состояний
    final faintColor = ext?.textFaint ?? Theme.of(context).colorScheme.onSurface.withAlpha(80);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.egg_alt_outlined, size: 56, color: faintColor),
            const SizedBox(height: 16),
            Text(
              context.s('food.ingredients_empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: faintColor,
              ),
            ),
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);
    final t = totals.total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // «Весь рецепт · N г» — локализованный заголовок карточки итогов
            Text(
              '${context.s('food.recipe_whole_title')} · ${totals.totalGrams.round()} g',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            // Калории рецепта — accent (единственная подчёркнутая метрика)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmt(t.calories),
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'kcal',
                  style: textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Макросы Б/Ж/У (EN: P/F/C) — локализованные аббревиатуры
            Text(
              context.s('food.recipe_macros_line')
                  .replaceFirst('{p}', _fmt(t.protein))
                  .replaceFirst('{f}', _fmt(t.fat))
                  .replaceFirst('{c}', _fmt(t.carbs)),
              style: textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 8),
            // На 100 г — локализованная строка с аббревиатурами Б/Ж/У
            Text(
              context.s('food.recipe_per100_line')
                  .replaceFirst('{cal}', _fmt(per100.calories))
                  .replaceFirst('{p}', _fmt(per100.protein))
                  .replaceFirst('{f}', _fmt(per100.fat))
                  .replaceFirst('{c}', _fmt(per100.carbs)),
              style: textTheme.bodySmall?.copyWith(color: mutedColor),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    return Padding(
      padding: EdgeInsets.only(
        // 24dp отступ по spec
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + крестик закрытия (видимый аффорданс)
            Row(
              children: [
                Expanded(
                  child: Text(context.s('food.add_ingredient'), style: textTheme.headlineSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            // Загрузка ингредиентов — KaiLoader
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: KaiLoader(label: context.s('loading.kai_food')),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              )
            else
              ..._results.whereType<Map<String, dynamic>>().map((p) {
                final per = p['per_100g'] as Map<String, dynamic>?;
                final kcal = (per?['calories'] as num?)?.round();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (p['name'] as String?) ?? context.s('food.unknown_product'),
                  ),
                  subtitle: Text(
                    [
                      if (p['brand'] != null) p['brand'] as String,
                      if (kcal != null) '$kcal kcal / 100g',
                    ].join(' · '),
                    style: textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
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
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ctx.textTheme.titleMedium,
      ),
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
      title: Text(
        widget.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.s('food.grams_eaten_label')),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
        // Первичное действие
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

// Расширение для удобного доступа к textTheme (локальный хелпер)
extension _ContextTextTheme on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}
