// Чистая логика AI-сборки меню («Собрать ИИ», SPEC C5, Ф1, premium).
// Здесь только подготовка кандидатов и пересчёт чисел готового меню КОДОМ —
// модель (бэкенд /ai/menu-build) лишь выбирает позиции и граммы.

import '../../core/database/database.dart';
import 'food_nutrition.dart';
import 'whole_food_staples.dart';

/// Кандидат для меню: имя + КБЖУ на 100 г. Источники: рецепты пользователя
/// и недавние продукты из дневника еды.
class MenuCandidate {
  const MenuCandidate({required this.name, required this.per100g});

  final String name;
  final Nutrition per100g;
}

/// Минимум кандидатов, который требует бэкенд (/ai/menu-build).
const int kMenuCandidatesMin = 5;

/// Максимум кандидатов в запросе.
const int kMenuCandidatesMax = 40;

/// Выводит «на 100 г» из строки дневника (там абсолютные значения порции).
/// null, если порция нулевая или калории неизвестны (бесполезный кандидат).
Nutrition? per100gFromLog(FoodLogsTableData log) {
  if (log.grams <= 0 || log.calories == null) return null;
  final k = 100.0 / log.grams;
  double? mul(double? v) => v == null ? null : v * k;
  return Nutrition(
    calories: mul(log.calories),
    protein: mul(log.protein),
    fat: mul(log.fat),
    carbs: mul(log.carbs),
    sugar: mul(log.sugar),
    fiber: mul(log.fiber),
  );
}

/// Собирает список кандидатов: сначала рецепты, затем недавние продукты,
/// затем курируемая база цельных продуктов (kWholeFoodStaples).
/// Дедупликация по имени (регистронезависимо): продукты пользователя (рецепты
/// и логи) добавляются ПЕРВЫМИ, поэтому при совпадении имени они побеждают —
/// «основы» только дополняют список реальной едой, чтобы ИИ мог собрать
/// сбалансированное меню (cap [kMenuCandidatesMax]).
List<MenuCandidate> buildMenuCandidates({
  required List<({String name, Nutrition per100g})> recipes,
  required List<FoodLogsTableData> recentLogs,
}) {
  final result = <MenuCandidate>[];
  final seen = <String>{};

  void add(String name, Nutrition per100g) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty || seen.contains(key)) return;
    if (result.length >= kMenuCandidatesMax) return;
    seen.add(key);
    result.add(MenuCandidate(name: name.trim(), per100g: per100g));
  }

  for (final r in recipes) {
    add(r.name, r.per100g);
  }
  for (final log in recentLogs) {
    final per = per100gFromLog(log);
    if (per != null) add(log.name, per);
  }
  // Мерджим цельные продукты ПОСЛЕ продуктов пользователя: дедуп по имени
  // оставляет пользовательские записи (они уже в seen), а «основы» лишь
  // добавляют недостающую здоровую еду для баланса меню.
  for (final staple in kWholeFoodStaples) {
    add(staple.name, staple.per100g);
  }
  return result;
}

/// Позиция предложенного меню с пересчитанными КОДОМ числами.
class ProposedItem {
  const ProposedItem({
    required this.name,
    required this.grams,
    required this.nutrition,
  });

  final String name;
  final double grams;

  /// Абсолютные значения на эту порцию (посчитаны кодом из кандидата).
  final Nutrition nutrition;
}

/// Приём пищи предложенного меню.
class ProposedMeal {
  const ProposedMeal({required this.meal, required this.items});

  final String meal;
  final List<ProposedItem> items;
}

/// Разбирает ответ /ai/menu-build и пересчитывает числа из [candidates].
/// Позиции, которых нет среди кандидатов, отбрасываются (страховка).
List<ProposedMeal> parseProposedMenu(
  Map<String, dynamic> response,
  List<MenuCandidate> candidates,
) {
  final byName = {
    for (final c in candidates) c.name.trim().toLowerCase(): c,
  };
  final meals = (response['meals'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>();

  final result = <ProposedMeal>[];
  for (final m in meals) {
    final items = <ProposedItem>[];
    for (final raw in (m['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final name = (raw['name'] as String?) ?? '';
      final grams = (raw['grams'] as num?)?.toDouble() ?? 0;
      final candidate = byName[name.trim().toLowerCase()];
      if (candidate == null || grams <= 0) continue;
      items.add(ProposedItem(
        name: candidate.name,
        grams: grams,
        nutrition: scaleNutrition(candidate.per100g, grams),
      ));
    }
    if (items.isNotEmpty) {
      result.add(ProposedMeal(meal: (m['meal'] as String?) ?? 'meal', items: items));
    }
  }
  return result;
}

/// Итог предложенного меню за день (сумма по всем приёмам) — считает код.
Nutrition proposedMenuTotal(List<ProposedMeal> meals) {
  return sumNutrition(
    meals.expand((m) => m.items).map((i) => i.nutrition),
  );
}

/// Разобранный ответ /ai/menu-build: меню + флаг off_target.
/// off_target == true означает, что меню не уложилось в заданные БЖУ после
/// ограниченного цикла валидации на бэкенде — клиент должен предупредить
/// пользователя (числа всё равно считает код, не модель).
class ParsedMenuResponse {
  const ParsedMenuResponse({
    required this.meals,
    required this.note,
    required this.offTarget,
  });

  final List<ProposedMeal> meals;
  final String note;
  final bool offTarget;
}

/// Разбирает полный ответ /ai/menu-build: меню (через [parseProposedMenu]),
/// заметку и флаг off_target. Поле totals из ответа НЕ используется для
/// отображения — клиент пересчитывает итоги локально (proposedMenuTotal),
/// чтобы числа всегда были кодом, а не от модели.
ParsedMenuResponse parseMenuResponse(
  Map<String, dynamic> response,
  List<MenuCandidate> candidates,
) {
  return ParsedMenuResponse(
    meals: parseProposedMenu(response, candidates),
    note: (response['note'] as String?) ?? '',
    offTarget: (response['off_target'] as bool?) ?? false,
  );
}
