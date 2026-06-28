// Редактор рецепта (SPEC C5, Phase 1): ингредиенты из поиска Open Food Facts,
// итоги КБЖУ считает код (recipe_nutrition.dart), готовый рецепт логируется
// в food_logs как обычная порция.
//
// Kaname redesign §4.2: hairline-divided ингредиент-строки, object card (_TotalsCard),
// Phosphor icons, KaiMascot empty state. §4.3: ONE primary (FilledButton «log»),
// второстепенное — OutlinedButton «add ingredient».
//
// Паттерн безопасного удаления ингредиентов (ADR-delete-safe):
//   - Свайп влево (SwipeToDelete) ИЛИ кнопка-корзина trailing IconButton
//   - Оба пути идут через _deleteIngredient(), который показывает Undo-snackbar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/api/api_client.dart';
import 'food_nutrition.dart';
import 'recipe_nutrition.dart';
import 'recipes_screen.dart' show
    promptRecipeName,
    recipeIngredientsProvider,
    recipeProvider;

const List<String> _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

// ConsumerStatefulWidget — нужен mounted-check после async операций.
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
    if (per100 == null) return;

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

  Future<void> _deleteIngredient(RecipeIngredientsTableData ing) async {
    final snapshot = ing;
    final dao = ref.read(recipesDaoProvider);

    await dao.removeIngredient(snapshot.id);

    if (!mounted) return;

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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? cs.onSurface.withAlpha(153);
    final faintColor = ext?.textFaint ?? cs.onSurface.withAlpha(100);
    final borderColor = ext?.border ?? cs.outline.withAlpha(50);
    final emberColor = ext?.ember ?? cs.error;
    final tone = ref.watch(toneProvider);

    final recipe = ref.watch(recipeProvider(widget.recipeId)).valueOrNull;
    final ingredients =
        ref.watch(recipeIngredientsProvider(widget.recipeId)).valueOrNull ??
            const <RecipeIngredientsTableData>[];

    if (recipe == null) {
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
            icon: Icon(PhosphorIcons.pencilSimple()),
            onPressed: () => _rename(recipe),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ingredients.isEmpty
                ? _emptyIngredients(context, ext, tone)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: ingredients.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: borderColor,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, i) {
                      final ing = ingredients[i];
                      // SwipeToDelete: свайп влево → _deleteIngredient
                      return SwipeToDelete(
                        key: ValueKey(ing.id),
                        onDelete: () => _deleteIngredient(ing),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Название + калории
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      ing.name,
                                      style: tt.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (ing.calories != null) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        context
                                            .s('food.kcal_val')
                                            .replaceFirst(
                                              '{val}',
                                              (ing.calories! * ing.grams / 100)
                                                  .round()
                                                  .toString(),
                                            ),
                                        style: tt.bodySmall?.copyWith(
                                          color: mutedColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Кнопка граммов — ghost (вторичное действие)
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => _editGrams(ing),
                                child: Text(
                                  context
                                      .s('food.grams_val')
                                      .replaceFirst(
                                        '{val}',
                                        ing.grams.round().toString(),
                                      ),
                                  style: tt.labelMedium?.copyWith(
                                    color: mutedColor,
                                  ),
                                ),
                              ),
                              // Корзина — textFaint (мягко, не агрессивно)
                              IconButton(
                                icon: Icon(
                                  PhosphorIcons.trash(),
                                  size: 20,
                                  color: faintColor,
                                ),
                                tooltip: context.s('btn.delete'),
                                onPressed: () => _deleteIngredient(ing),
                                visualDensity: VisualDensity.compact,
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
                  if (per100 != null)
                    _TotalsCard(totals: totals, per100: per100),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Добавить ингредиент — OutlinedButton (вторичное)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(PhosphorIcons.plus(), size: 18),
                          label: Text(context.s('food.add_ingredient')),
                          onPressed: _addIngredient,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Записать рецепт — FilledButton (единственный primary, §4.3)
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(PhosphorIcons.forkKnife(), size: 18),
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

  /// Пустое состояние списка ингредиентов: KaiMascot (neutral 64) + verb button.
  Widget _emptyIngredients(
    BuildContext context,
    FocusThemeExtension? ext,
    AppTone tone,
  ) {
    final tt = Theme.of(context).textTheme;
    final mutedColor = ext?.textMuted ??
        Theme.of(context).colorScheme.onSurface.withAlpha(80);

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
              context.s('food.ingredients_empty'),
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 16),
            // Verb button — OutlinedButton (secondary; primary — кнопка «Log» внизу)
            OutlinedButton.icon(
              icon: Icon(PhosphorIcons.plus(), size: 18),
              label: Text(context.s('food.add_ingredient')),
              onPressed: _addIngredient,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка итогов: §4.2 object card (surface1 + hairline R14)
// ---------------------------------------------------------------------------

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, required this.per100});

  final RecipeTotals totals;
  final Nutrition per100;

  String _fmt(double? v) => v == null ? '—' : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? cs.onSurface.withAlpha(153);
    final borderColor = ext?.border ?? cs.outline.withAlpha(50);
    final t = totals.total;

    // Заголовок «Весь рецепт · N г» — оба куска локализованы
    final heading =
        '${context.s('food.recipe_whole_title')} · '
        '${context.s('food.grams_val').replaceFirst('{val}', totals.totalGrams.round().toString())}';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: tt.titleSmall),
          const SizedBox(height: 6),
          // Калории — accent (единственная выделенная метрика)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(t.calories),
                style: tt.headlineSmall?.copyWith(color: cs.primary),
              ),
              const SizedBox(width: 4),
              Text(
                // «kcal» — часть строки food.kcal_val без числа
                context.s('food.kcal_val').replaceFirst('{val}', '').trim(),
                style: tt.bodySmall?.copyWith(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Макросы Б/Ж/У (локализованные аббревиатуры)
          Text(
            context
                .s('food.recipe_macros_line')
                .replaceFirst('{p}', _fmt(t.protein))
                .replaceFirst('{f}', _fmt(t.fat))
                .replaceFirst('{c}', _fmt(t.carbs)),
            style: tt.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 8),
          // На 100 г — локализованная строка
          Text(
            context
                .s('food.recipe_per100_line')
                .replaceFirst('{cal}', _fmt(per100.calories))
                .replaceFirst('{p}', _fmt(per100.protein))
                .replaceFirst('{f}', _fmt(per100.fat))
                .replaceFirst('{c}', _fmt(per100.carbs)),
            style: tt.bodySmall?.copyWith(color: mutedColor),
          ),
        ],
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
    // Локализованный фолбэк — до await, context.mounted не нужен
    final name = (product['name'] as String?) ?? context.s('food.unknown_product');
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? cs.onSurface.withAlpha(153);
    final borderColor = ext?.border ?? cs.outline.withAlpha(50);

    return Padding(
      padding: EdgeInsets.only(
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
            // Заголовок листа: handle/title + крестик закрытия (§4.3 sheet pattern)
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.s('food.add_ingredient'),
                    style: tt.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.x()),
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
                  icon: Icon(PhosphorIcons.magnifyingGlass()),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                  style: tt.bodyMedium?.copyWith(color: mutedColor),
                ),
              )
            else
              // §4.2 hairline-divided результаты: InkWell+Padding+Column, NOT ListTile
              ..._results.whereType<Map<String, dynamic>>().map((p) {
                final per = p['per_100g'] as Map<String, dynamic>?;
                final kcal = (per?['calories'] as num?)?.round();
                final subtitle = [
                  if (p['brand'] != null) p['brand'] as String,
                  if (kcal != null)
                    context
                        .s('food.kcal_per_100g')
                        .replaceFirst('{kcal}', '$kcal'),
                ].join(' · ');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => _pick(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (p['name'] as String?) ??
                                  context.s('food.unknown_product'),
                              style: tt.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: tt.bodySmall?.copyWith(
                                  color: mutedColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: borderColor,
                    ),
                  ],
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

/// Диалог логирования рецепта: граммы + приём пищи.
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
    _grams = TextEditingController(text: widget.totalGrams.round().toString());
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // accentTint + accentInk для выбранного чипа (§4.3 choice chips)
    final tintColor = ext?.accentTint ?? cs.primaryContainer;
    final inkColor = ext?.accentInk ?? cs.primary;
    final chipBorder = ext?.border ?? cs.outline.withAlpha(80);

    return AlertDialog(
      title: Text(
        widget.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: tt.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.s('food.grams_eaten_label'),
            ),
          ),
          const SizedBox(height: 16),
          // §4.3: accentTint фон + accent border при выборе; ghost иначе
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _meals.map((m) {
              final selected = _meal == m;
              return ChoiceChip(
                label: Text(
                  context.s('food.meal_$m'),
                  style: tt.bodySmall?.copyWith(
                    color: selected ? inkColor : null,
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _meal = m),
                selectedColor: tintColor,
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: selected
                      ? cs.primary.withAlpha(180)
                      : chipBorder,
                  width: selected ? 1.0 : 0.5,
                ),
                showCheckmark: false,
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

// Расширение для удобного доступа к textTheme (локальный хелпер)
extension _ContextTextTheme on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}
