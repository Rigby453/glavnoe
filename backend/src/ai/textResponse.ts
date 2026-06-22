/**
 * Хелперы для PLAIN-TEXT AI-генераторов (morning/insight/wrapped).
 * Эти фичи возвращают обычный текст, не JSON. Но модель иногда всё равно
 * оборачивает ответ в JSON вида {"summary":"..."}. Чтобы пользователь не видел
 * сырой JSON, defensively разворачиваем такой ответ обратно в текст.
 */

/**
 * Если text (после trim) выглядит как JSON-объект и содержит строковое поле
 * `key`, возвращает значение этого поля. Иначе — возвращает исходный
 * (триммированный) текст. Никогда не бросает исключений.
 *
 * @param text - сырой ответ модели
 * @param key - ожидаемый ключ (напр. "summary" | "insight" | "message")
 */
export function unwrapMaybeJson(text: string, key: string): string {
  const trimmed = text.trim();
  if (!trimmed.startsWith("{")) return trimmed;
  try {
    const parsed: unknown = JSON.parse(trimmed);
    if (
      parsed !== null &&
      typeof parsed === "object" &&
      typeof (parsed as Record<string, unknown>)[key] === "string"
    ) {
      return ((parsed as Record<string, unknown>)[key] as string).trim();
    }
  } catch {
    // не валидный JSON — отдаём как обычный текст
  }
  return trimmed;
}
