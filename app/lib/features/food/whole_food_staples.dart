// Курируемая база цельных продуктов («food DB» роль) для AI-сборки меню.
// Эти продукты дают модели РЕАЛЬНУЮ еду, чтобы собрать сбалансированное меню —
// без них кандидаты ограничены только тем, что пользователь сам записал
// (часто это «джанк»), и ИИ не из чего строить нормальный рацион.
//
// Все числа — правдоподобные константы на 100 г (как из базы продуктов;
// модель НИКОГДА не выдаёт КБЖУ — числа считает код из этих констант).
// sugar/fiber указаны там, где известны; null — если неприменимо/неизвестно.

import 'ai_menu.dart';
import 'food_nutrition.dart';

/// Цельные продукты-«основы» с КБЖУ на 100 г. Имена на английском (правило
/// кода/имён), мерджатся в кандидаты в buildMenuCandidates.
const List<MenuCandidate> kWholeFoodStaples = [
  // --- Белки животные ---
  MenuCandidate(
    name: 'Chicken breast',
    per100g: Nutrition(calories: 165, protein: 31, fat: 3.6, carbs: 0, sugar: 0, fiber: 0),
  ),
  MenuCandidate(
    name: 'Eggs',
    per100g: Nutrition(calories: 143, protein: 13, fat: 9.5, carbs: 0.7, sugar: 0.4, fiber: 0),
  ),
  MenuCandidate(
    name: 'Lean beef steak',
    per100g: Nutrition(calories: 217, protein: 26, fat: 12, carbs: 0, sugar: 0, fiber: 0),
  ),
  MenuCandidate(
    name: 'Salmon',
    per100g: Nutrition(calories: 208, protein: 20, fat: 13, carbs: 0, sugar: 0, fiber: 0),
  ),
  MenuCandidate(
    name: 'White fish',
    per100g: Nutrition(calories: 96, protein: 21, fat: 1.2, carbs: 0, sugar: 0, fiber: 0),
  ),
  MenuCandidate(
    name: 'Turkey breast',
    per100g: Nutrition(calories: 135, protein: 29, fat: 1.7, carbs: 0, sugar: 0, fiber: 0),
  ),
  // --- Молочные ---
  MenuCandidate(
    name: 'Cottage cheese',
    per100g: Nutrition(calories: 98, protein: 11, fat: 4.3, carbs: 3.4, sugar: 2.7, fiber: 0),
  ),
  MenuCandidate(
    name: 'Greek yogurt',
    per100g: Nutrition(calories: 59, protein: 10, fat: 0.4, carbs: 3.6, sugar: 3.2, fiber: 0),
  ),
  MenuCandidate(
    name: 'Milk',
    per100g: Nutrition(calories: 61, protein: 3.2, fat: 3.3, carbs: 4.8, sugar: 4.8, fiber: 0),
  ),
  // --- Крупы / гарниры (на 100 г варёного, кроме овса — сухой) ---
  MenuCandidate(
    name: 'White rice',
    per100g: Nutrition(calories: 130, protein: 2.7, fat: 0.3, carbs: 28, sugar: 0.1, fiber: 0.4),
  ),
  MenuCandidate(
    name: 'Buckwheat',
    per100g: Nutrition(calories: 110, protein: 3.8, fat: 1.1, carbs: 20, sugar: 0.9, fiber: 2.7),
  ),
  MenuCandidate(
    name: 'Oats',
    per100g: Nutrition(calories: 379, protein: 13, fat: 6.5, carbs: 67, sugar: 1, fiber: 10),
  ),
  MenuCandidate(
    name: 'Pasta',
    per100g: Nutrition(calories: 158, protein: 5.8, fat: 0.9, carbs: 31, sugar: 0.6, fiber: 1.8),
  ),
  MenuCandidate(
    name: 'Potato',
    per100g: Nutrition(calories: 87, protein: 1.9, fat: 0.1, carbs: 20, sugar: 0.9, fiber: 1.8),
  ),
  MenuCandidate(
    name: 'Sweet potato',
    per100g: Nutrition(calories: 90, protein: 2, fat: 0.2, carbs: 21, sugar: 6.5, fiber: 3.3),
  ),
  MenuCandidate(
    name: 'Whole-grain bread',
    per100g: Nutrition(calories: 247, protein: 13, fat: 3.5, carbs: 41, sugar: 6, fiber: 7),
  ),
  // --- Бобовые ---
  MenuCandidate(
    name: 'Lentils',
    per100g: Nutrition(calories: 116, protein: 9, fat: 0.4, carbs: 20, sugar: 1.8, fiber: 7.9),
  ),
  MenuCandidate(
    name: 'Beans',
    per100g: Nutrition(calories: 127, protein: 8.7, fat: 0.5, carbs: 23, sugar: 0.3, fiber: 6.4),
  ),
  // --- Овощи ---
  MenuCandidate(
    name: 'Broccoli',
    per100g: Nutrition(calories: 34, protein: 2.8, fat: 0.4, carbs: 7, sugar: 1.7, fiber: 2.6),
  ),
  MenuCandidate(
    name: 'Mixed vegetables',
    per100g: Nutrition(calories: 65, protein: 2.6, fat: 0.5, carbs: 13, sugar: 4, fiber: 4),
  ),
  // --- Фрукты ---
  MenuCandidate(
    name: 'Banana',
    per100g: Nutrition(calories: 89, protein: 1.1, fat: 0.3, carbs: 23, sugar: 12, fiber: 2.6),
  ),
  MenuCandidate(
    name: 'Apple',
    per100g: Nutrition(calories: 52, protein: 0.3, fat: 0.2, carbs: 14, sugar: 10, fiber: 2.4),
  ),
  // --- Жиры / орехи ---
  MenuCandidate(
    name: 'Olive oil',
    per100g: Nutrition(calories: 884, protein: 0, fat: 100, carbs: 0, sugar: 0, fiber: 0),
  ),
  MenuCandidate(
    name: 'Butter',
    per100g: Nutrition(calories: 717, protein: 0.9, fat: 81, carbs: 0.1, sugar: 0.1, fiber: 0),
  ),
  MenuCandidate(
    name: 'Almonds',
    per100g: Nutrition(calories: 579, protein: 21, fat: 50, carbs: 22, sugar: 4.4, fiber: 12),
  ),
];
