// Парсер хэштегов из заголовка задачи.
//
// Контракт:
//   parseTaskTags('Buy milk #shopping #today')
//     → cleanTitle: 'Buy milk'
//       tags:       ['shopping', 'today']
//
// Что считается тегом (#<токен>):
//   • Токен состоит из букв (Latin/Cyrillic, вкл. ё), цифр и «_».
//   • Хотя бы ОДНА буква обязательна — «#123» и «#___» не являются тегами.
//   • Левая граница обязательна: начало строки / пробел / пунктуация.
//     Внутри слова («prefix#tag») не является тегом.
//   • Пунктуация после тега НЕ является частью тега («#math.» → тег «math»).
//
// Регистр:
//   • Теги возвращаются В ОРИГИНАЛЬНОМ РЕГИСТРЕ ввода.
//   • Дедупликация регистрозависимая: «#Math» и «#math» — разные теги.
//
// Хранение:
//   • В Drift сохраняется ИСХОДНЫЙ заголовок (с #-токенами): «купить молоко #shopping».
//     Это позволяет planSearchMatches искать по #tag без изменений.
//   • В UI отображается cleanTitle + чипы тегов.
//   • При сохранении из формы редактирования выбранные чипы снова
//     добавляются в конец заголовка перед записью в Drift.

/// Результат парсинга тегов из заголовка задачи.
class TagParseResult {
  const TagParseResult({required this.cleanTitle, required this.tags});

  /// Заголовок без #-токенов; лишние пробелы схлопнуты; trim.
  final String cleanTitle;

  /// Теги без «#», в порядке первого появления, без дубликатов.
  /// Пример: ['shopping', 'cs101', 'учёба']
  final List<String> tags;
}

// ---------------------------------------------------------------------------
// Регэксп для распознавания тегов.
//
// Объяснение паттерна:
//   (?<![^\s\p{P}])  — левая граница: перед «#» должен стоять
//                       пробельный символ, пунктуация ИЛИ начало строки.
//                       Используем отрицательный lookbehind «НЕ (не-пробел,
//                       не-пунктуация)» = «перед нами пробел/пункт/начало».
//                       Dart поддерживает Unicode-категории в режиме unicode:true.
//   #                — буквальный символ решётки
//   (                — захват: тело тега
//     (?=[\w\p{L}])  — lookahead: после «#» сразу буква или \w (цифра/_)
//                       — защита от «# » и «##»
//     [\w\p{L}]*     — ноль и более символов «\w или буква» (тело тега)
//   )
//
// Упрощённый подход (Dart не поддерживает \p{P} в RegExp без ICU):
// Dart-regexp с unicode:true поддерживает \p{L} (Unicode-буква) и \w (=ASCII
// word chars + _), но НЕ поддерживает \p{P}. Поэтому используем явный список
// «что является НЕ-левой-границей» = буква/цифра/«_» + «#»:
//   Левая граница = НАЧАЛО строки ИЛИ предшествующий символ ∈ (пробел, пунктуация,
//                   любой не-буква-не-цифра-не_-не#).
//
// Реализуем через _isBoundaryChar — та же логика, что в nl_datetime.dart.
// ---------------------------------------------------------------------------

/// Извлекает теги (#-токены) из [rawTitle].
///
/// Возвращает [TagParseResult] с очищенным заголовком и списком тегов.
TagParseResult parseTaskTags(String rawTitle) {
  if (rawTitle.trim().isEmpty) {
    return const TagParseResult(cleanTitle: '', tags: []);
  }

  // Список (start, end) спанов #tag-токенов (включая решётку).
  final spans = <(int, int)>[];
  final tagNames = <String>[];
  final seenTags = <String>{};

  // Итерируем посимвольно для надёжной Dart-Unicode обработки кириллицы.
  // Регэксп с unicode:true в Dart не поддерживает lookbehind над Unicode,
  // поэтому ручной проход безопаснее.
  final runes = rawTitle.runes.toList();
  var i = 0;
  while (i < runes.length) {
    final ch = String.fromCharCode(runes[i]);
    if (ch == '#') {
      // Проверяем левую границу.
      final leftOk = i == 0 || _isBoundaryChar(String.fromCharCode(runes[i - 1]));
      if (leftOk && i + 1 < runes.length) {
        // Читаем тело тега: [a-zA-Zа-яёА-ЯЁ0-9_]+
        var j = i + 1;
        while (j < runes.length && _isTagBodyChar(String.fromCharCode(runes[j]))) {
          j++;
        }
        final tokenLength = j - (i + 1); // длина тела (без #)
        if (tokenLength > 0) {
          final tagBody = rawTitle.substring(i + 1, j);
          // Тег должен содержать хотя бы одну букву (не только цифры/подчёркивания).
          if (_hasLetter(tagBody)) {
            spans.add((i, j));
            if (!seenTags.contains(tagBody)) {
              seenTags.add(tagBody);
              tagNames.add(tagBody);
            }
            i = j; // перепрыгиваем через тег
            continue;
          }
        }
      }
    }
    i++;
  }

  // Нет тегов → возвращаем trim без изменений.
  if (spans.isEmpty) {
    return TagParseResult(cleanTitle: rawTitle.trim(), tags: const []);
  }

  // Удаляем тег-спаны из строки (с конца, чтобы индексы не сдвигались).
  var clean = rawTitle;
  for (final (start, end) in spans.reversed) {
    clean = clean.substring(0, start) + clean.substring(end);
  }

  // Схлопываем лишние пробелы и trim.
  clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  return TagParseResult(cleanTitle: clean, tags: tagNames);
}

/// Собирает заголовок для сохранения в Drift: чистый заголовок + теги в конце.
///
/// Теги добавляются через пробел в формате «#tag1 #tag2».
/// Если [tags] пуст — возвращает [cleanTitle] без изменений.
String buildStoredTitle(String cleanTitle, List<String> tags) {
  if (tags.isEmpty) return cleanTitle;
  final tagStr = tags.map((t) => '#$t').join(' ');
  final base = cleanTitle.trim();
  return base.isEmpty ? tagStr : '$base $tagStr';
}

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

/// Является ли символ разрешённой левой границей для тега.
/// Граница = пробел, пунктуация, открывающие скобки или НАЧАЛО строки.
/// «Не граница» = буква, цифра, '_', '#' (тег внутри слова или ##).
bool _isBoundaryChar(String ch) {
  // Цифры и «_» — не граница
  final code = ch.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) return false; // 0-9
  if (ch == '_') return false;
  if (ch == '#') return false; // «##» → не тег
  // ASCII буквы
  if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
    return false;
  }
  // Кириллица (включая ё/Ё)
  if (code >= 0x0410 && code <= 0x044F) return false; // А-я
  if (code == 0x0451 || code == 0x0401) return false; // ё / Ё
  // Все остальные (пробелы, знаки препинания, скобки и т.д.) — граница
  return true;
}

/// Является ли символ допустимым в теле тега (после «#»).
/// Допустимо: буква (Latin/Cyrillic/ё), цифра (0-9), «_».
bool _isTagBodyChar(String ch) {
  final code = ch.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) return true; // 0-9
  if (ch == '_') return true;
  if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
    return true; // A-Z a-z
  }
  if (code >= 0x0410 && code <= 0x044F) return true; // А-я
  if (code == 0x0451 || code == 0x0401) return true; // ё / Ё
  return false;
}

/// Есть ли в строке хотя бы одна буква (не только цифры/подчёркивания).
bool _hasLetter(String s) {
  for (final ch in s.split('')) {
    final code = ch.codeUnitAt(0);
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
      return true; // Latin
    }
    if (code >= 0x0410 && code <= 0x044F) return true; // Cyrillic А-я
    if (code == 0x0451 || code == 0x0401) return true; // ё / Ё
  }
  return false;
}
