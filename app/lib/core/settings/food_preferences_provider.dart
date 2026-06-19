// Пищевые предпочтения пользователя — диета, цель, любимые/нелюбимые продукты,
// количество приёмов пищи. Хранятся в SharedPreferences.
// Используются для персонализации AI-конструктора меню (POST /ai/menu-build).
// Цель (goal) также влияет на расчёт дневных норм питания (nutritionTargetsProvider):
//   lose    → TDEE × 0.85
//   maintain→ TDEE × 1.00
//   gain    → TDEE × 1.15

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Ключи SharedPreferences
// ---------------------------------------------------------------------------
const kFoodDietKey = 'food_diet';
const kFoodGoalKey = 'food_goal';
const kFoodDislikesKey = 'food_dislikes';
const kFoodLikesKey = 'food_likes';
const kFoodMealsPerDayKey = 'food_meals_per_day';

// ---------------------------------------------------------------------------
// Модель
// ---------------------------------------------------------------------------

/// Пищевые предпочтения пользователя.
///
/// [diet]       — тип питания: 'none'|'vegetarian'|'vegan'|'pescatarian'|
///                'halal'|'kosher'|'keto'|'other'
/// [goal]       — цель по весу: 'maintain'|'lose'|'gain'
/// [dislikes]   — нелюбимые продукты (свободный текст)
/// [likes]      — любимые продукты (свободный текст)
/// [mealsPerDay]— количество приёмов пищи в день (3..5)
class FoodPreferences {
  const FoodPreferences({
    this.diet = 'none',
    this.goal = 'maintain',
    this.dislikes = '',
    this.likes = '',
    this.mealsPerDay = 3,
  });

  final String diet;
  final String goal;
  final String dislikes;
  final String likes;
  final int mealsPerDay;

  /// true, если предпочтения не менялись от дефолта (ничего значимого не указано).
  bool get isEmpty =>
      diet == 'none' &&
      goal == 'maintain' &&
      dislikes.trim().isEmpty &&
      likes.trim().isEmpty &&
      mealsPerDay == 3;

  FoodPreferences copyWith({
    String? diet,
    String? goal,
    String? dislikes,
    String? likes,
    int? mealsPerDay,
  }) =>
      FoodPreferences(
        diet: diet ?? this.diet,
        goal: goal ?? this.goal,
        dislikes: dislikes ?? this.dislikes,
        likes: likes ?? this.likes,
        mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      );

  /// Сериализация в snake_case для API. Пустые/дефолтные поля опускаются.
  Map<String, dynamic> toApiMap() {
    final m = <String, dynamic>{};
    if (diet != 'none') m['diet'] = diet;
    if (goal != 'maintain') m['goal'] = goal;
    if (dislikes.trim().isNotEmpty) m['dislikes'] = dislikes.trim();
    if (likes.trim().isNotEmpty) m['likes'] = likes.trim();
    if (mealsPerDay != 3) m['meals_per_day'] = mealsPerDay;
    return m;
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Читает/пишет пищевые предпочтения в SharedPreferences.
class FoodPreferencesNotifier extends Notifier<FoodPreferences> {
  @override
  FoodPreferences build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return FoodPreferences(
      diet: prefs.getString(kFoodDietKey) ?? 'none',
      goal: prefs.getString(kFoodGoalKey) ?? 'maintain',
      dislikes: prefs.getString(kFoodDislikesKey) ?? '',
      likes: prefs.getString(kFoodLikesKey) ?? '',
      mealsPerDay: prefs.getInt(kFoodMealsPerDayKey) ?? 3,
    );
  }

  /// Сохраняет новые предпочтения в prefs и обновляет состояние.
  Future<void> save(FoodPreferences prefs) async {
    final sp = ref.read(sharedPreferencesProvider);
    await sp.setString(kFoodDietKey, prefs.diet);
    await sp.setString(kFoodGoalKey, prefs.goal);
    await sp.setString(kFoodDislikesKey, prefs.dislikes.trim());
    await sp.setString(kFoodLikesKey, prefs.likes.trim());
    await sp.setInt(kFoodMealsPerDayKey, prefs.mealsPerDay);
    state = prefs;
  }
}

final foodPreferencesProvider =
    NotifierProvider<FoodPreferencesNotifier, FoodPreferences>(
  FoodPreferencesNotifier.new,
);
