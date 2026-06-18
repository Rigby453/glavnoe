// Иконки продуктов питания — моментальная замена сетевым фото из Open Food Facts.
// Подход: сопоставление ключевых слов (EN + RU) → emoji; если не найдено —
// запасной Material-иконка. Нет сети, нет задержки, нет некрасивых 404-картинок.
//
// Использование: FoodIconTile(name: product['name'], category: product['category'])

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Словарь: keyword → emoji
// Ключи: строчные. Допускается несколько ключей на один emoji (через forEach ниже).
// Охватывает ~50+ ключевых слов на EN и RU.
// ---------------------------------------------------------------------------

const Map<String, String> _kKeywordEmoji = {
  // --- Фрукты / Fruits ---
  'apple': '🍎',
  'яблоко': '🍎',
  'яблок': '🍎',
  'banana': '🍌',
  'банан': '🍌',
  'orange': '🍊',
  'апельсин': '🍊',
  'lemon': '🍋',
  'лимон': '🍋',
  'grape': '🍇',
  'виноград': '🍇',
  'strawberry': '🍓',
  'клубника': '🍓',
  'watermelon': '🍉',
  'арбуз': '🍉',
  'peach': '🍑',
  'персик': '🍑',
  'pear': '🍐',
  'груша': '🍐',
  'cherry': '🍒',
  'вишня': '🍒',
  'черешня': '🍒',
  'mango': '🥭',
  'манго': '🥭',
  'pineapple': '🍍',
  'ананас': '🍍',
  'fruit': '🍑',
  'фрукт': '🍑',

  // --- Овощи / Vegetables ---
  'broccoli': '🥦',
  'брокколи': '🥦',
  'carrot': '🥕',
  'морковь': '🥕',
  'морков': '🥕',
  'tomato': '🍅',
  'томат': '🍅',
  'помидор': '🍅',
  'cucumber': '🥒',
  'огурец': '🥒',
  'огурц': '🥒',
  'potato': '🥔',
  'картофель': '🥔',
  'картошка': '🥔',
  'onion': '🧅',
  'лук': '🧅',
  'garlic': '🧄',
  'чеснок': '🧄',
  'pepper': '🌶️',
  'перец': '🌶️',
  'corn': '🌽',
  'кукуруза': '🌽',
  'spinach': '🥬',
  'шпинат': '🥬',
  'lettuce': '🥬',
  'салат': '🥗',
  'cabbage': '🥬',
  'капуста': '🥬',
  'vegetable': '🥦',
  'овощ': '🥦',

  // --- Злаки, хлеб / Grains & Bread ---
  'bread': '🍞',
  'хлеб': '🍞',
  'toast': '🍞',
  'тост': '🍞',
  'baguette': '🥖',
  'багет': '🥖',
  'croissant': '🥐',
  'круассан': '🥐',
  'rice': '🍚',
  'рис': '🍚',
  'pasta': '🍝',
  'паста': '🍝',
  'макарон': '🍝',
  'noodle': '🍜',
  'лапша': '🍜',
  'oat': '🌾',
  'овёс': '🌾',
  'овсянка': '🌾',
  'porridge': '🌾',
  'каша': '🌾',
  'cereal': '🥣',
  'хлопья': '🥣',
  'granola': '🥣',
  'мюсли': '🥣',
  'wheat': '🌾',
  'пшеница': '🌾',
  'flour': '🌾',
  'мука': '🌾',

  // --- Мясо / Meat ---
  'chicken': '🍗',
  'курица': '🍗',
  'курин': '🍗',
  'poultry': '🍗',
  'птица': '🍗',
  'beef': '🥩',
  'говядина': '🥩',
  'говяд': '🥩',
  'steak': '🥩',
  'стейк': '🥩',
  'pork': '🥩',
  'свинина': '🥩',
  'свин': '🥩',
  'bacon': '🥓',
  'бекон': '🥓',
  'sausage': '🌭',
  'сосиска': '🌭',
  'колбаса': '🌭',
  'колбас': '🌭',
  'meat': '🥩',
  'мясо': '🥩',
  'мяс': '🥩',
  'lamb': '🥩',
  'ягнёнок': '🥩',
  'turkey': '🦃',
  'индейка': '🦃',

  // --- Рыба / Seafood ---
  'fish': '🐟',
  'рыба': '🐟',
  'рыб': '🐟',
  'salmon': '🐟',
  'лосось': '🐟',
  'tuna': '🐟',
  'тунец': '🐟',
  'shrimp': '🍤',
  'креветка': '🍤',
  'seafood': '🦐',
  'морепрод': '🦐',

  // --- Молочное / Dairy ---
  'milk': '🥛',
  'молоко': '🥛',
  'молок': '🥛',
  'cheese': '🧀',
  'сыр': '🧀',
  'yogurt': '🥛',
  'йогурт': '🥛',
  'butter': '🧈',
  'масло': '🧈',
  'cream': '🥛',
  'сметана': '🥛',
  'кефир': '🥛',
  'dairy': '🥛',
  'молочн': '🥛',
  'творог': '🥛',

  // --- Яйца / Eggs ---
  'egg': '🥚',
  'яйцо': '🥚',
  'яйца': '🥚',
  'яиц': '🥚',
  'омлет': '🍳',
  'omelette': '🍳',
  'omelet': '🍳',

  // --- Напитки / Drinks ---
  'coffee': '☕',
  'кофе': '☕',
  'tea': '🍵',
  'чай': '🍵',
  'water': '💧',
  'вода': '💧',
  'воды': '💧',
  'juice': '🧃',
  'сок': '🧃',
  'smoothie': '🥤',
  'смузи': '🥤',
  'beer': '🍺',
  'пиво': '🍺',
  'wine': '🍷',
  'вино': '🍷',
  'drink': '🥤',
  'напиток': '🥤',
  'напитк': '🥤',

  // --- Сладкое / Sweets ---
  'candy': '🍬',
  'конфета': '🍬',
  'конфет': '🍬',
  'chocolate': '🍫',
  'шоколад': '🍫',
  'cake': '🎂',
  'торт': '🎂',
  'cookie': '🍪',
  'печенье': '🍪',
  'печень': '🍪',
  'ice cream': '🍦',
  'мороженое': '🍦',
  'honey': '🍯',
  'мёд': '🍯',
  'мед': '🍯',
  'jam': '🍓',
  'варенье': '🍓',
  'sugar': '🍬',
  'сахар': '🍬',
  'snack': '🍿',
  'снэк': '🍿',
  'chips': '🍿',
  'чипсы': '🍿',
  'popcorn': '🍿',
  'попкорн': '🍿',
  'cracker': '🥨',
  'крекер': '🥨',
  'pretzel': '🥨',
  'sweet': '🍬',
  'сладк': '🍬',

  // --- Орехи / Nuts ---
  'nut': '🥜',
  'орех': '🥜',
  'орехи': '🥜',
  'almond': '🥜',
  'миндаль': '🥜',
  'walnut': '🥜',
  'грецкий': '🥜',
  'peanut': '🥜',
  'арахис': '🥜',
  'seeds': '🌻',
  'семечки': '🌻',
  'семена': '🌻',

  // --- Масла, соусы / Oils & Sauces ---
  'oil': '🫙',
  'масло раст': '🫙',
  'olive oil': '🫙',
  'оливковое': '🫙',
  'sauce': '🫙',
  'соус': '🫙',
  'ketchup': '🍅',
  'кетчуп': '🍅',
  'mayonnaise': '🫙',
  'майонез': '🫙',

  // --- Готовые блюда / Prepared Foods ---
  'pizza': '🍕',
  'пицца': '🍕',
  'burger': '🍔',
  'бургер': '🍔',
  'sandwich': '🥪',
  'сэндвич': '🥪',
  'бутерброд': '🥪',
  'soup': '🍲',
  'суп': '🍲',
  'salad': '🥗',
  'сalad': '🥗',
  'wrap': '🌯',
  'ролл': '🌯',
  'roll': '🌯',
  'sushi': '🍣',
  'суши': '🍣',
  'pancake': '🥞',
  'блин': '🥞',
  'pancakes': '🥞',
  'блины': '🥞',
  'waffle': '🧇',
  'вафля': '🧇',

  // --- Бобовые / Legumes ---
  'bean': '🫘',
  'фасоль': '🫘',
  'lentil': '🫘',
  'чечевица': '🫘',
  'pea': '🫛',
  'горох': '🫛',
  'chickpea': '🫘',
  'нут': '🫘',
  'tofu': '🫘',
  'тофу': '🫘',

  // --- Грибы / Mushrooms ---
  'mushroom': '🍄',
  'гриб': '🍄',
  'грибы': '🍄',
};

// ---------------------------------------------------------------------------
// Категориальные fallback (для поля category из Open Food Facts)
// ---------------------------------------------------------------------------

const Map<String, String> _kCategoryEmoji = {
  'dairies': '🥛',
  'dairy': '🥛',
  'beverages': '🥤',
  'drinks': '🥤',
  'meats': '🥩',
  'meat': '🥩',
  'fish': '🐟',
  'seafood': '🦐',
  'fruits': '🍎',
  'fruit': '🍎',
  'vegetables': '🥦',
  'vegetable': '🥦',
  'breads': '🍞',
  'bread': '🍞',
  'cereals': '🥣',
  'cereal': '🥣',
  'snacks': '🍿',
  'snack': '🍿',
  'sweets': '🍬',
  'sweet': '🍬',
  'sugary': '🍬',
  'nuts': '🥜',
  'nut': '🥜',
  'eggs': '🥚',
  'egg': '🥚',
  'sauces': '🫙',
  'condiments': '🫙',
  'pasta': '🍝',
  'rice': '🍚',
  'oils': '🫙',
};

// ---------------------------------------------------------------------------
// Публичная функция: name + category → emoji или null
// ---------------------------------------------------------------------------

/// Возвращает emoji для продукта по имени и/или категории.
/// Возвращает null, если ни одно ключевое слово не сопоставлено.
String? emojiForFood({String? name, String? category}) {
  // Сначала пробуем по ключевым словам имени (нормализованное)
  if (name != null && name.isNotEmpty) {
    final lower = name.toLowerCase();
    // Перебираем по длине ключа (длиннее = точнее), чтобы «olive oil» бил «oil»
    final sorted = _kKeywordEmoji.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final keyword in sorted) {
      if (lower.contains(keyword)) return _kKeywordEmoji[keyword];
    }
  }

  // Затем — по категории (могут прийти из OFF как «en:dairies» или «dairies»)
  if (category != null && category.isNotEmpty) {
    final cat = category.toLowerCase().replaceAll('en:', '').trim();
    // Прямое совпадение
    if (_kCategoryEmoji.containsKey(cat)) return _kCategoryEmoji[cat];
    // Частичное совпадение
    for (final key in _kCategoryEmoji.keys) {
      if (cat.contains(key)) return _kCategoryEmoji[key];
    }
  }

  return null; // нет совпадения → виджет покажет Material-иконку
}

// ---------------------------------------------------------------------------
// FoodIconTile — виджет
// ---------------------------------------------------------------------------

/// Квадратная плитка с emoji/иконкой продукта.
/// Рендерит мгновенно, без сети. Размер по умолчанию: 40×40 dp.
class FoodIconTile extends StatelessWidget {
  const FoodIconTile({
    super.key,
    this.name,
    this.category,
    this.size = 40.0,
  });

  /// Имя продукта (EN или RU) — используется для подбора emoji.
  final String? name;

  /// Категория продукта (например, «en:dairies») — запасной ключ.
  final String? category;

  /// Размер плитки (ширина = высота).
  final double size;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final borderColor =
        ext?.border ?? Theme.of(context).colorScheme.outline;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    final emoji = emojiForFood(name: name, category: category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? Text(
              emoji,
              style: TextStyle(fontSize: size * 0.55),
            )
          : Icon(
              Icons.restaurant_outlined,
              size: size * 0.55,
              color: ext?.textMuted ??
                  Theme.of(context).colorScheme.onSurface.withAlpha(120),
            ),
    );
  }
}
