// Вспомогательная функция автоматического определения moduleLink по заголовку задачи.
//
// Значения, совпадающие с картой роутинга в task_list.dart, day_timeline.dart,
// week_agenda.dart:
//   'workout'        → /workouts
//   'meal:breakfast' → /food?meal=breakfast
//   'meal:lunch'     → /food?meal=lunch
//   'meal:dinner'    → /food?meal=dinner
//   'sleep'          → /sleep-report
//   null             → нет привязки
//
// Ключевые слова намеренно дублируют _moduleKeywords из nl_datetime.dart —
// обе функции остаются независимыми (nl_datetime — сложный парсер; эта функция
// является единственной точкой истины для сохранения moduleLink при save).
// Расширение: добавить кортеж в _kInferenceKeywords и соответствующий тест.

// Описание одного ключевого слова.
class _IKey {
  const _IKey(this.text, {this.wholeWord = false});
  final String text;
  // Если true — ищем точное слово (окружённое границами), иначе — стем (prefix).
  final bool wholeWord;
}

// Проверяем, является ли символ границей слова (пробел, пунктуация, начало строки).
bool _isBoundary(String ch) {
  final code = ch.codeUnitAt(0);
  // ASCII: не буква и не цифра → граница.
  if (code < 128) return !((code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57));
  // Кириллица: буквы «А»–«я» + «Ё»/«ё».
  final isCyr = (code >= 0x0410 && code <= 0x044F) || code == 0x0401 || code == 0x0451;
  return !isCyr;
}

// Стем: ищем вхождение, у которого перед ним — граница слова (начало строки или _isBoundary).
bool _hasStem(String lower, String stem) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(stem, from);
    if (idx < 0) return false;
    final leftOk = idx == 0 || _isBoundary(lower[idx - 1]);
    if (leftOk) return true;
    from = idx + 1;
  }
}

// Целое слово: стем + граница СПРАВА.
bool _hasWord(String lower, String word) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(word, from);
    if (idx < 0) return false;
    final leftOk = idx == 0 || _isBoundary(lower[idx - 1]);
    final end = idx + word.length;
    final rightOk = end >= lower.length || _isBoundary(lower[end]);
    if (leftOk && rightOk) return true;
    from = idx + 1;
  }
}

bool _matchKey(String lower, _IKey k) =>
    k.wholeWord ? _hasWord(lower, k.text) : _hasStem(lower, k.text);

// Карта ключевые-слова → moduleLink. Проверяются по порядку; возвращается первое совпадение.
// Значения должны ТОЧНО совпадать с тем, что ожидает _openModule в картах задач.
final List<(List<_IKey>, String)> _kInferenceKeywords = [
  // workout
  (
    [
      _IKey('тренировк'),       // тренировка / тренировки / тренировку
      _IKey('трен', wholeWord: true), // «трен» как отдельное сокращение
      _IKey('качал'),           // качалка
      _IKey('спортзал'),        // спортзал
      _IKey('отжим'),           // отжимания
      _IKey('присед'),          // приседания
      _IKey('пробежк'),         // пробежка
      _IKey('бег', wholeWord: true), // бег (не «победа», не «берег»)
      _IKey('йога'),            // йога / йогой
      _IKey('workout'),         // EN
      _IKey('gym', wholeWord: true), // EN
      _IKey('run', wholeWord: true), // EN: run (не «runner» — wholewWord)
      _IKey('exercise'),        // EN
      _IKey('yoga'),            // EN
    ],
    'workout',
  ),
  // завтрак / breakfast
  (
    [
      _IKey('завтрак'),
      _IKey('breakfast'),
    ],
    'meal:breakfast',
  ),
  // обед / lunch
  (
    [
      _IKey('пообед'),          // пообедать / пообедаю
      _IKey('обед'),            // обед / обедать
      _IKey('lunch'),
    ],
    'meal:lunch',
  ),
  // ужин / dinner
  (
    [
      _IKey('ужин'),
      _IKey('dinner'),
      _IKey('supper'),
    ],
    'meal:dinner',
  ),
  // перекус / meal / eat — общая еда без конкретного приёма → нет moduleLink
  // (карточка не знает, в какой meal-слот маршрутизировать).
  // Намеренно НЕ добавляем 'food', 'еда', 'поесть' без слота — они идут без модуля.

  // sleep
  (
    [
      _IKey('поспат'),          // поспать
      _IKey('выспат'),          // выспаться
      _IKey('спать', wholeWord: true),
      _IKey('сон', wholeWord: true),
      _IKey('лечь', wholeWord: true), // лечь (спать)
      _IKey('nap', wholeWord: true),  // EN
      _IKey('sleep'),           // EN: sleep / sleeping
      _IKey('bedtime'),         // EN
    ],
    'sleep',
  ),
];

/// Определяет ссылку на модуль по заголовку задачи [title] (и необязательному
/// типу [type]) путём поиска ключевых слов.
///
/// Возвращает одно из:
///   'workout' | 'meal:breakfast' | 'meal:lunch' | 'meal:dinner' | 'sleep' | null
///
/// Возвращаемые значения точно совпадают с тем, что ожидает _openModule()
/// в task_list.dart / day_timeline.dart / week_agenda.dart.
///
/// Пример:
///   inferModuleLink('Утренняя тренировка') → 'workout'
///   inferModuleLink('завтрак') → 'meal:breakfast'
///   inferModuleLink('Купить молоко') → null
String? inferModuleLink(String title, {String? type}) {
  final lower = title.toLowerCase();
  for (final (keys, value) in _kInferenceKeywords) {
    for (final k in keys) {
      if (_matchKey(lower, k)) return value;
    }
  }
  return null;
}
