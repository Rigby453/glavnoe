// Вычисление эмоции Kai для домашнего виджета (§4 WIDGET.md).
// Чистая функция без побочных эффектов — удобно для юнит-тестирования.
// Порядок проверок строго по спецификации: away → anxious → success → neutral.

/// Вычисляет строку эмоции Kai для отображения в домашнем виджете.
///
/// Параметры:
/// - [mainDone] — сколько главных задач завершено сегодня.
/// - [mainTotal] — сколько всего главных задач на сегодня.
/// - [hasOverdue] — есть ли незавершённые просроченные пункты.
/// - [lastOpenedAt] — timestamp последнего открытия приложения (null = считать
///   как «заходил недавно», не away).
/// - [now] — текущий момент (передаётся явно для тестируемости).
///
/// Возвращает одну из строк: 'away' | 'anxious' | 'success' | 'neutral'.
String computeKaiWidgetEmotion({
  required int mainDone,
  required int mainTotal,
  required bool hasOverdue,
  required DateTime? lastOpenedAt,
  required DateTime now,
}) {
  // 1. Не заходил >= 2 дней → away (грустно выглядывает)
  if (lastOpenedAt != null) {
    final daysSince = now.difference(lastOpenedAt).inDays;
    if (daysSince >= 2) return 'away';
  }

  // 2. Есть просрочка → anxious
  if (hasOverdue) return 'anxious';

  // 3. Все главные закрыты → success (гордится)
  if (mainTotal > 0 && mainDone >= mainTotal) return 'success';

  // 4. По умолчанию — нейтральный
  return 'neutral';
}
