// Классическая схема приёмов пищи (slots) для модуля Food.
//
// Пользователь выбирает число приёмов в день (foodPrefs.mealsPerDay, 1..6+ —
// минимум 1 приём поддерживает интервальное голодание/OMAD, см. ITEM A).
// В зависимости от этого числа day делится на классические слоты:
//   3 → завтрак, обед, ужин
//   4 → завтрак, обед, полдник, ужин
//   5 → завтрак, второй завтрак, обед, полдник, ужин
//
// ID слотов — стабильные английские строки; именно они пишутся в БД
// (FoodLogsTable.meal) и отправляются бэкенду в запросе /ai/menu-build.
// Для отображения название слота локализуется через ключ 'food.meal_<slot>'.
//
// 'snack' — общий/легаси-слот: в него попадают старые записи и всё, что
// не вписалось в классические слоты. Группировка в UI показывает его последним.

/// Канонический порядок слотов для отображения (группировка дневного лога).
/// Любой meal, которого здесь нет, считается «прочим» и идёт в конец под 'snack'.
const List<String> kMealSlotOrder = [
  'breakfast',
  'second_breakfast',
  'lunch',
  'afternoon_snack',
  'dinner',
  'snack',
];

/// Возвращает список слотов нужной длины по КЛАССИЧЕСКОЙ схеме.
///
/// [mealsPerDay] поддерживает минимум 1 (OMAD/интервальное голодание) и
/// не ограничен сверху. Маппинг:
///   n == 1 → [breakfast]                                    (OMAD)
///   n == 2 → [breakfast, lunch]                             (зажим базовой тройки)
///   n == 3 → [breakfast, lunch, dinner]
///   n == 4 → [breakfast, lunch, afternoon_snack, dinner]
///   n == 5 → [breakfast, second_breakfast, lunch, afternoon_snack, dinner]
///   n >= 6 → список для n==5 плюс завершающий 'snack'
List<String> mealsForCount(int mealsPerDay) {
  switch (mealsPerDay) {
    case 3:
      return const ['breakfast', 'lunch', 'dinner'];
    case 4:
      return const ['breakfast', 'lunch', 'afternoon_snack', 'dinner'];
    case 5:
      return const [
        'breakfast',
        'second_breakfast',
        'lunch',
        'afternoon_snack',
        'dinner',
      ];
  }
  // n <= 2 — зажим: первые n из базовой тройки.
  if (mealsPerDay <= 2) {
    const base = ['breakfast', 'lunch', 'dinner'];
    final n = mealsPerDay.clamp(1, base.length);
    return base.sublist(0, n);
  }
  // n >= 6 — пятёрка + общий перекус в конце (держим просто).
  return const [
    'breakfast',
    'second_breakfast',
    'lunch',
    'afternoon_snack',
    'dinner',
    'snack',
  ];
}
