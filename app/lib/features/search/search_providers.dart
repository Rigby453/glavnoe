// Провайдеры глобального поиска (#17) — данные, без UI.
// Ищем по 4 сущностям локальной Drift-БД (offline-first, без бэкенда):
// задачи (items.title), дневник (day_logs.note), рецепты (recipes.name +
// description), покупки (shopping_items.name). Регистронезависимое
// совпадение подстроки, фильтрация в памяти (Drift не даёт надёжный
// LIKE-ci на всех платформах, а датасет пользователя — не мегабайты).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/day_logs_dao.dart';
import '../../core/database/daos/items_dao.dart';
import '../../core/database/daos/recipes_dao.dart';
import '../../core/database/daos/shopping_dao.dart';
import '../../core/database/database_providers.dart';
import 'search_results_model.dart';

/// Текущий поисковый запрос (сырой, как ввёл пользователь — не нормализован).
/// UI пишет сюда через ref.read(...).state = text; провайдер результатов сам
/// триммит/лоуэркейсит перед сравнением.
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

/// Лимит хитов на секцию — чтобы не тормозить и не заваливать список при
/// большом совпадении (например, общее слово встречается в сотне задач).
/// TODO(#17): пагинация/подгрузка по скроллу, если лимита не хватит в проде.
const int kGlobalSearchSectionLimit = 30;

/// Результаты глобального поиска по нормализованному запросу.
/// Ключ family — сырая строка запроса (нормализация — внутри); пустой или
/// состоящий из пробелов запрос возвращает [GlobalSearchResults.empty] без
/// единого обращения к БД.
///
/// autoDispose: подписка живёт только пока экран поиска слушает провайдер —
/// закрыли поиск → провайдер и его результаты освобождаются.
final globalSearchResultsProvider = FutureProvider.autoDispose
    .family<GlobalSearchResults, String>((ref, rawQuery) async {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return const GlobalSearchResults.empty();

  final itemsDao = ref.watch(itemsDaoProvider);
  final dayLogsDao = ref.watch(dayLogsDaoProvider);
  final recipesDao = ref.watch(recipesDaoProvider);
  final shoppingDao = ref.watch(shoppingDaoProvider);

  final tasks = await _searchTasks(itemsDao: itemsDao, query: query);
  final diary = await _searchDiary(dayLogsDao: dayLogsDao, query: query);
  final recipes = await _searchRecipes(recipesDao: recipesDao, query: query);
  final shopping =
      await _searchShopping(shoppingDao: shoppingDao, query: query);

  return GlobalSearchResults(
    tasks: tasks,
    diary: diary,
    recipes: recipes,
    shopping: shopping,
  );
});

// ---------------------------------------------------------------------------
// Задачи (ItemsTable)
// ---------------------------------------------------------------------------

/// Ищет по title всех задач.
///
/// ItemsDao не имеет метода "все задачи без ограничений", только диапазонные
/// запросы (itemsInRange нужен [from, to)) — читаем очень широкий диапазон
/// как практический эквивалент "все задачи". itemsInRange уже исключает
/// якоря серий (recurrenceRule != null), поэтому отдельно добираем их через
/// watchSeriesAnchors(), чтобы поиск находил и сами повторяющиеся серии, а
/// не только их материализованные конкретные дни.
/// TODO(#17): добавить в ItemsDao выделенный метод searchTitles(query) с
/// SQL-фильтром (LIKE) и пагинацией, когда объём данных перестанет быть
/// тривиальным для полного сканирования в памяти.
Future<List<GlobalSearchHit>> _searchTasks({
  required ItemsDao itemsDao,
  required String query,
}) async {
  final concreteItems = await itemsDao.itemsInRange(
    DateTime(1970),
    DateTime(2100),
  );
  final seriesAnchors = await itemsDao.watchSeriesAnchors().first;

  final hits = <GlobalSearchHit>[];
  for (final item in [...concreteItems, ...seriesAnchors]) {
    if (!item.title.toLowerCase().contains(query)) continue;
    hits.add(
      GlobalSearchHit(
        id: item.id,
        title: item.title,
        kind: SearchHitKind.task,
        date: item.scheduledAt,
      ),
    );
  }
  // Свежие сверху: сортируем по дате убыв. и лишь ПОТОМ режем лимитом — иначе
  // лимит отрезал бы недавние и наверх всплывали самые старые задачи (баг).
  hits.sort((a, b) =>
      (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
  return hits.take(kGlobalSearchSectionLimit).toList();
}

// ---------------------------------------------------------------------------
// Дневник (DayLogsTable)
// ---------------------------------------------------------------------------

/// Ищет по note всех дневниковых записей. DayLogsDao.since(from) с очень
/// ранней датой — практический эквивалент "все записи" (нет отдельного
/// метода getAll, а диапазон не нужен для этой фичи).
Future<List<GlobalSearchHit>> _searchDiary({
  required DayLogsDao dayLogsDao,
  required String query,
}) async {
  final allLogs = await dayLogsDao.since(DateTime(1970));

  final hits = <GlobalSearchHit>[];
  for (final log in allLogs) {
    final note = log.note;
    if (note == null || note.isEmpty) continue;
    if (!note.toLowerCase().contains(query)) continue;
    hits.add(
      GlobalSearchHit(
        id: log.id,
        title: _excerpt(note, query),
        kind: SearchHitKind.diary,
        date: log.date,
      ),
    );
  }
  // Свежие записи сверху (см. _searchTasks): сортировка по дате убыв. → лимит.
  hits.sort((a, b) =>
      (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
  return hits.take(kGlobalSearchSectionLimit).toList();
}

// ---------------------------------------------------------------------------
// Рецепты (RecipesTable)
// ---------------------------------------------------------------------------

/// Ищет по name + description рецептов. RecipesDao не даёт Future-метод для
/// всего списка — только watchRecipes() (Stream); берём один снапшот через
/// .first (стрим сам себя закрывает после первого события).
Future<List<GlobalSearchHit>> _searchRecipes({
  required RecipesDao recipesDao,
  required String query,
}) async {
  final allRecipes = await recipesDao.watchRecipes().first;

  final hits = <GlobalSearchHit>[];
  for (final recipe in allRecipes) {
    final name = recipe.name;
    final description = recipe.description;
    final nameMatches = name.toLowerCase().contains(query);
    // Фрагмент описания вычисляем только когда совпадение реально в
    // description — иначе вторая строка была бы избыточным дублем title.
    final descriptionExcerpt =
        (description != null && description.toLowerCase().contains(query))
            ? _excerpt(description, query)
            : null;
    if (!nameMatches && descriptionExcerpt == null) continue;
    hits.add(
      GlobalSearchHit(
        id: recipe.id,
        title: name,
        snippet: descriptionExcerpt,
        kind: SearchHitKind.recipe,
      ),
    );
    if (hits.length >= kGlobalSearchSectionLimit) break;
  }
  return hits;
}

// ---------------------------------------------------------------------------
// Покупки (ShoppingItemsTable)
// ---------------------------------------------------------------------------

/// Ищет по name покупок. ShoppingDao тоже отдаёт только Stream (watchAll()) —
/// берём первый снапшот аналогично рецептам.
Future<List<GlobalSearchHit>> _searchShopping({
  required ShoppingDao shoppingDao,
  required String query,
}) async {
  final allShopping = await shoppingDao.watchAll().first;

  final hits = <GlobalSearchHit>[];
  for (final item in allShopping) {
    final name = item.name;
    if (!name.toLowerCase().contains(query)) continue;
    hits.add(
      GlobalSearchHit(
        id: item.id,
        title: name,
        // quantity — сырой пользовательский текст («2 шт», «500 г»), не
        // сгенерированная копия приложения, поэтому пропускать через l10n не
        // нужно (правило про no-hardcoded-strings касается АВТОРСКИХ строк
        // приложения, а не пользовательских данных).
        snippet: item.quantity,
        kind: SearchHitKind.shopping,
      ),
    );
    if (hits.length >= kGlobalSearchSectionLimit) break;
  }
  return hits;
}

// ---------------------------------------------------------------------------
// Общий хелпер: короткий фрагмент вокруг совпадения
// ---------------------------------------------------------------------------

/// Вырезает фрагмент [text] длиной до [maxLength] символов вокруг первого
/// (регистронезависимого) совпадения [query]. Если совпадения не нашлось
/// (вызывающий код обычно уже проверил contains — это запасной путь),
/// возвращает первые [maxLength] символов текста. Добавляет «…» на срезанных
/// краях, чтобы было видно, что текст обрублен.
String _excerpt(String text, String query, {int maxLength = 80}) {
  final lower = text.toLowerCase();
  final matchIndex = lower.indexOf(query);

  if (matchIndex < 0) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  final matchEnd = matchIndex + query.length;
  final radius = ((maxLength - query.length) / 2).floor();
  var start = matchIndex - radius;
  var end = matchEnd + radius;

  if (start < 0) {
    end -= start; // добавляем неиспользованный левый запас к правому краю
    start = 0;
  }
  if (end > text.length) {
    start -= (end - text.length); // и наоборот
    end = text.length;
  }
  start = start.clamp(0, text.length);
  end = end.clamp(start, text.length);

  final prefix = start > 0 ? '…' : '';
  final suffix = end < text.length ? '…' : '';
  return '$prefix${text.substring(start, end)}$suffix';
}
