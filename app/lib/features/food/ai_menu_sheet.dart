// «Собрать ИИ» (SPEC C5, Ф1, premium): AI компонует дневное меню из рецептов
// пользователя и недавних продуктов; ВСЕ числа КБЖУ пересчитывает код
// (ai_menu.dart) из локальных данных. Пользователь подтверждает перед записью.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/animations/ai_insight_reveal.dart';
import '../../core/animations/ai_pulse_dot.dart';
import '../../core/animations/ai_skeleton.dart';
import '../../core/animations/app_sheet.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/health_profile_provider.dart';
import '../../core/settings/nutrition_targets.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import '../paywall/paywall_screen.dart';
import 'ai_menu.dart';
import 'food_nutrition.dart';
import 'recipe_nutrition.dart';

/// Точка входа с Food-экрана. Сама проверяет premium и наличие кандидатов.
Future<void> showAiMenuSheet(BuildContext context, WidgetRef ref) async {
  final premium = await ref.read(isPremiumProvider.future);
  if (!context.mounted) return;
  if (!premium) {
    showPremiumUpsell(context, 'AI menu builder');
    return;
  }

  // Кандидаты: рецепты пользователя + недавние продукты из дневника.
  final recipesDao = ref.read(recipesDaoProvider);
  final recipes = await recipesDao.watchRecipes().first;
  final recipeEntries = <({String name, Nutrition per100g})>[];
  for (final r in recipes) {
    final ings = await recipesDao.watchIngredients(r.id).first;
    final totals = recipeTotals(ings);
    final per100 = recipePer100g(totals.total, totals.totalGrams);
    if (per100 != null) recipeEntries.add((name: r.name, per100g: per100));
  }

  final recentLogs = await ref.read(foodLogsDaoProvider).recentLogs(30);
  final candidates = buildMenuCandidates(
    recipes: recipeEntries,
    recentLogs: recentLogs,
  );

  if (!context.mounted) return;
  if (candidates.length < kMenuCandidatesMin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.s('food.ai_menu_need_more')
              .replaceAll('{n}', '$kMenuCandidatesMin'),
        ),
      ),
    );
    return;
  }

  await showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => _AiMenuSheet(candidates: candidates),
  );
}

class _AiMenuSheet extends ConsumerStatefulWidget {
  const _AiMenuSheet({required this.candidates});

  final List<MenuCandidate> candidates;

  @override
  ConsumerState<_AiMenuSheet> createState() => _AiMenuSheetState();
}

class _AiMenuSheetState extends ConsumerState<_AiMenuSheet> {
  bool _loading = true;
  String? _error;
  List<ProposedMeal> _meals = const [];
  String _note = '';
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tone =
          ref.read(toneProvider) == AppTone.harsh ? 'harsh' : 'gentle';
      // Профиль здоровья: передаётся бэкенду только если непустой.
      final hp = ref.read(healthProfileProvider);
      final response = await ref.read(apiClientProvider).aiMenuBuild(
            candidates: widget.candidates
                .map((c) => {
                      'name': c.name,
                      'per_100g': {
                        'calories': c.per100g.calories,
                        'protein': c.per100g.protein,
                        'fat': c.per100g.fat,
                        'carbs': c.per100g.carbs,
                        'sugar': c.per100g.sugar,
                        'fiber': c.per100g.fiber,
                      },
                    })
                .toList(),
            calorieGoal: ref.read(nutritionTargetsProvider).kcal,
            proteinGoalG: ref.read(nutritionTargetsProvider).proteinG,
            tone: tone,
            healthProfile: hp.isEmpty ? null : hp.toApiMap(),
          );
      final meals = parseProposedMenu(response, widget.candidates);
      if (!mounted) return;
      setState(() {
        _meals = meals;
        _note = (response['note'] as String?) ?? '';
        _loading = false;
        // Ключ локализации; резолвится в build через context.s()
        if (meals.isEmpty) _error = 'food.ai_empty_menu';
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  /// Записывает все позиции меню в дневник еды (подтверждение пользователя —
  /// сама кнопка). Каждая позиция — обычная строка food_logs.
  Future<void> _applyAll() async {
    setState(() => _applying = true);
    final dao = ref.read(foodLogsDaoProvider);
    for (final meal in _meals) {
      for (final item in meal.items) {
        await dao.addLog(
          date: DateTime.now(),
          meal: meal.meal,
          name: item.name,
          grams: item.grams,
          calories: item.nutrition.calories,
          protein: item.nutrition.protein,
          fat: item.nutrition.fat,
          carbs: item.nutrition.carbs,
          sugar: item.nutrition.sugar,
          fiber: item.nutrition.fiber,
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('food.menu_logged'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);
    final total = proposedMenuTotal(_meals);

    return Padding(
      padding: EdgeInsets.only(
        // 24dp горизонтальный отступ
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
            // Заголовок листа — headlineSmall (22sp, display font) с иконкой
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: mutedColor,
                ),
                const SizedBox(width: 8),
                Text(context.s('food.ai_menu_title'), style: textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) ...[
              // KaiLoader вместо спиннера + AiSkeleton для каркаса контента
              Center(
                child: KaiLoader(label: context.s('loading.kai_menu')),
              ),
              const SizedBox(height: 16),
              const AiSkeleton(lines: 4),
            ] else if (_error != null) ...[
              // _error может быть ключом локализации или сырым сообщением API
              Text(
                context.s(_error!),
                style: textTheme.bodyMedium?.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 12),
              // Попробовать снова — OutlinedButton (вторичное, повторяемое действие)
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.s('food.try_again')),
                onPressed: _build,
              ),
            ] else ...[
              AiInsightReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_note.isNotEmpty) ...[
                      Text(_note, style: textTheme.bodyMedium),
                      const SizedBox(height: 12),
                    ],
                    ..._meals.map((m) => _MealBlock(meal: m)),
                    const SizedBox(height: 8),
                    // Итоги дня — titleSmall, калории accent
                    Row(
                      children: [
                        Text(
                          '${total.calories?.round() ?? 0}',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          ' kcal · P ${total.protein?.round() ?? 0} g',
                          style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Пересобрать — OutlinedButton (вторичное)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _applying ? null : _build,
                            child: Text(context.s('food.rebuild_btn')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Записать всё — FilledButton (первичное, 03-components §2)
                        Expanded(
                          child: FilledButton.icon(
                            icon: _applying
                                ? const AiPulseDot(size: 10)
                                : const Icon(Icons.check, size: 18),
                            label: Text(context.s('food.log_all_btn')),
                            onPressed: _applying ? null : _applyAll,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Маппинг ключа приёма пищи (backend) → ключ локализации для ОТОБРАЖЕНИЯ.
/// Бэкенду всегда отправляем оригинальный английский ключ (breakfast/lunch/...).
String _mealL10nKey(String meal) {
  switch (meal) {
    case 'breakfast':
      return 'food.meal_breakfast';
    case 'lunch':
      return 'food.meal_lunch';
    case 'dinner':
      return 'food.meal_dinner';
    case 'snack':
      return 'food.meal_snack';
    default:
      // Неизвестный приём — показываем ключ через S (откат на en → на сам ключ)
      return meal;
  }
}

class _MealBlock extends StatelessWidget {
  const _MealBlock({required this.meal});

  final ProposedMeal meal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // Строки блюд — textMuted (не конкурируют с заголовком)
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(140);

    // Локализованное название приёма пищи; первая буква в верхнем регистре
    final mealLabel = context.s(_mealL10nKey(meal.meal));
    final mealDisplayName = mealLabel.isNotEmpty
        ? mealLabel[0].toUpperCase() + mealLabel.substring(1)
        : meal.meal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название приёма пищи — titleSmall (14sp w600)
          Text(
            mealDisplayName,
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          ...meal.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${i.name} — ${i.grams.round()} g · '
                '${i.nutrition.calories?.round() ?? 0} kcal',
                style: textTheme.bodyMedium?.copyWith(color: mutedColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
