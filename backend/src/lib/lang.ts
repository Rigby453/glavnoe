// Разбор заголовка Accept-Language в простой 2-буквенный код.
//
// Намеренно вынесено в отдельный файл (а не в src/food/openFoodFacts.ts): код
// языка нужен и для food-роутов, и для AI food-recognize (routes/ai.ts), а
// openFoodFacts.ts в тестах полностью мокается через jest.mock(factory) —
// если бы parseLangCode жил там, его export стал бы undefined под моком.

/**
 * Извлекает 2-буквенный код языка из заголовка Accept-Language (тот же источник,
 * что и для ИИ-промптов — см. routes/ai.ts langName()). НЕ привязан к узкому списку
 * языков ИИ-переводов: Open Food Facts хранит названия продуктов на гораздо большем
 * числе языков, так что любой валидный 2-буквенный тег пробрасываем как есть.
 * Невалидный/отсутствующий заголовок → "en" (безопасный дефолт).
 */
export function parseLangCode(header: string | string[] | undefined): string {
  const raw = (Array.isArray(header) ? header[0] : header) ?? "";
  const tag = raw.toString().trim().slice(0, 2).toLowerCase();
  return /^[a-z]{2}$/.test(tag) ? tag : "en";
}
