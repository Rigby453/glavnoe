// Парсер естественного языка для дат и времени.
// Поддерживает RU / EN / DE без внешних зависимостей — только чистый Dart.
//
// ВАЖНО: \b в Dart regexp не работает с кириллицей — используем _findWord()
// которая проверяет пробельные/пунктуационные границы.
//
// Использование:
//   final r = parseNaturalDateTime('Сдать лабу завтра 17:00', DateTime.now());
//   r.when          → DateTime(2026, 6, 18, 17, 0)
//   r.cleanedTitle  → 'Сдать лабу'
//
// Консервативный подход: если ничего не распознано, when == null,
// cleanedTitle == исходный текст без изменений.

/// Результат парсинга.
class NlDateTimeResult {
  const NlDateTimeResult({required this.when, required this.cleanedTitle});

  /// null — ничего не распознано.
  final DateTime? when;

  /// Заголовок с удалённой временной фразой.
  final String cleanedTitle;
}

/// Парсит временные/датовые фразы из [text] относительно [now].
///
/// Поддерживаемые шаблоны (RU / EN / DE):
///   • "завтра 17:00" / "tomorrow 5pm" / "morgen 17 uhr"
///   • "завтра в 5" / "tomorrow at 5"
///   • "сегодня в 9" / "today at 9" / "heute um 9"
///   • "через 2 часа" / "in 2 hours" / "in 2 stunden"
///   • "в пятницу" / "on friday" / "am Freitag" → следующее вхождение
///   • голое "17:00" / "5pm" → сегодня (или завтра если уже прошло)
///   • голое ЧЧММ "700" / "1830" (Todoist-стиль) → 7:00 / 18:30
///
/// Если ничего не распознано — when=null, cleanedTitle == text.
NlDateTimeResult parseNaturalDateTime(String text, DateTime now) {
  final input = text.trim();
  if (input.isEmpty) {
    return NlDateTimeResult(when: null, cleanedTitle: input);
  }

  return _tryRelativeHours(input, now) ??
      _tryTomorrowTime(input, now) ??
      _tryTodayTime(input, now) ??
      _tryWeekdayTime(input, now) ??
      _tryBareTime(input, now) ??
      NlDateTimeResult(when: null, cleanedTitle: input);
}

// ---------------------------------------------------------------------------
// Низкоуровневые утилиты
// ---------------------------------------------------------------------------

DateTime _withTime(DateTime base, int hour, int minute) =>
    DateTime(base.year, base.month, base.day, hour, minute);

DateTime _futureOrTomorrow(DateTime dt, DateTime now) =>
    dt.isAfter(now) ? dt : dt.add(const Duration(days: 1));

/// Unicode-безопасная проверка границы слова (кириллица и ASCII).
bool _isBoundary(String ch) =>
    ch == ' ' || ch == '\t' || ch == ',' || ch == '.' ||
    ch == '!' || ch == '?' || ch == ';';

/// Ищет [word] (нижний регистр) в [lower] как отдельное слово.
/// Возвращает [start, end] позицию в lower / исходном тексте, или null.
_Span? _findWord(String lower, String word) {
  int from = 0;
  while (true) {
    final idx = lower.indexOf(word, from);
    if (idx < 0) return null;
    final end = idx + word.length;
    final before = idx == 0 || _isBoundary(lower[idx - 1]);
    final after = end >= lower.length || _isBoundary(lower[end]);
    if (before && after) return _Span(idx, end);
    from = idx + 1;
  }
}

class _Span {
  const _Span(this.start, this.end);
  final int start;
  final int end;
}

/// Удаляет диапазоны [spans] из [text] (сортировка в обратном порядке),
/// затем убирает одиночные граничные предлоги и лишние пробелы.
String _eraseSpans(String text, List<_Span> spans) {
  // Сортируем по убыванию start, чтобы удаление справа не сдвигало левые позиции.
  final sorted = [...spans]..sort((a, b) => b.start.compareTo(a.start));
  var result = text;
  for (final s in sorted) {
    if (s.start < 0 || s.end > result.length) continue;
    result = '${result.substring(0, s.start)} ${result.substring(s.end)}';
  }
  // Убираем одиночные предлоги на краях строки (ASCII — \b работает).
  result = result
      .replaceAll(
        RegExp(r'(?:(?<=\s)|^)(в|at|um|на|on|am)(?=\s|$)',
            caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  return result;
}

// ---------------------------------------------------------------------------
// Паттерны времени
// ---------------------------------------------------------------------------

class _TimeSpan {
  const _TimeSpan(this.hour, this.minute, this.span);
  final int hour;
  final int minute;
  final _Span span;
}

/// Ищет время в [text]. Возвращает null если не найдено.
/// НЕ удаляет предлоги — их убирает _eraseSpans.
_TimeSpan? _parseTime(String text) {
  // HH:MM (24h) — высший приоритет
  var m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h <= 23 && min <= 59) {
      return _TimeSpan(h, min, _Span(m.start, m.end));
    }
  }

  // 12h: "5pm", "9am", "5 pm", "9 am"
  m = RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false).firstMatch(text);
  if (m != null) {
    var h = int.parse(m.group(1)!);
    final isPm = m.group(2)!.toLowerCase() == 'pm';
    if (h == 12 && !isPm) h = 0;
    if (h != 12 && isPm) h += 12;
    if (h <= 23) return _TimeSpan(h, 0, _Span(m.start, m.end));
  }

  // "17 uhr" / "9 uhr" (DE)
  m = RegExp(r'(\d{1,2})\s+uhr', caseSensitive: false).firstMatch(text);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    if (h <= 23) return _TimeSpan(h, 0, _Span(m.start, m.end));
  }

  // "в 9" / "at 9" / "um 9" — голый час с предлогом (включает предлог в span)
  m = RegExp(r'(?:в|at|um)\s+(\d{1,2})(?!\s*:)', caseSensitive: false)
      .firstMatch(text);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    if (h <= 23) return _TimeSpan(h, 0, _Span(m.start, m.end));
  }

  return null;
}

// ---------------------------------------------------------------------------
// Стратегии парсинга
// ---------------------------------------------------------------------------

/// "через 2 часа" / "in 2 hours" / "in 2 stunden"
NlDateTimeResult? _tryRelativeHours(String text, DateTime now) {
  final m = RegExp(
    r'(?:через|in)\s+(\d+)\s+(?:час[аов]*|hour[s]?|stunde[n]?)',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;

  final hours = int.parse(m.group(1)!);
  final dt = now.add(Duration(hours: hours));
  final cleaned = _eraseSpans(text, [_Span(m.start, m.end)]);
  return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
}

/// "завтра" / "tomorrow" / "morgen" [+ время]
NlDateTimeResult? _tryTomorrowTime(String text, DateTime now) {
  final lower = text.toLowerCase();
  _Span? kwSpan;
  for (final kw in ['завтра', 'tomorrow', 'morgen']) {
    kwSpan = _findWord(lower, kw);
    if (kwSpan != null) break;
  }
  if (kwSpan == null) return null;

  final tomorrow = now.add(const Duration(days: 1));

  // Ищем время в ОРИГИНАЛЬНОМ тексте (до любых удалений).
  final timeSpan = _parseTime(text);

  if (timeSpan != null) {
    final cleaned = _eraseSpans(text, [kwSpan, timeSpan.span]);
    final dt = _withTime(tomorrow, timeSpan.hour, timeSpan.minute);
    return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
  }

  // Только "завтра" → 09:00.
  final cleaned = _eraseSpans(text, [kwSpan]);
  return NlDateTimeResult(when: _withTime(tomorrow, 9, 0), cleanedTitle: cleaned);
}

/// "сегодня" / "today" / "heute" + время
NlDateTimeResult? _tryTodayTime(String text, DateTime now) {
  final lower = text.toLowerCase();
  _Span? kwSpan;
  for (final kw in ['сегодня', 'today', 'heute']) {
    kwSpan = _findWord(lower, kw);
    if (kwSpan != null) break;
  }
  if (kwSpan == null) return null;

  final timeSpan = _parseTime(text);
  if (timeSpan == null) return null; // "сегодня" без времени — слишком неопределённо

  final cleaned = _eraseSpans(text, [kwSpan, timeSpan.span]);
  var dt = _withTime(now, timeSpan.hour, timeSpan.minute);
  dt = _futureOrTomorrow(dt, now);
  return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
}

/// Дни недели → следующее вхождение.
NlDateTimeResult? _tryWeekdayTime(String text, DateTime now) {
  const days = <String, int>{
    // RU (именительный и косвенные падежи — длиннее сначала во избежание коллизий)
    'понедельник': 1, 'понедельника': 1,
    'воскресенье': 7, 'воскресения': 7, 'воскресенья': 7,
    'вторник': 2, 'вторника': 2,
    'четверг': 4, 'четверга': 4,
    'пятницу': 5, 'пятницы': 5, 'пятница': 5,
    'субботу': 6, 'субботы': 6, 'суббота': 6,
    'среду': 3, 'среды': 3, 'среда': 3,
    // EN
    'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
    'friday': 5, 'saturday': 6, 'sunday': 7,
    // DE
    'montag': 1, 'dienstag': 2, 'mittwoch': 3, 'donnerstag': 4,
    'freitag': 5, 'samstag': 6, 'sonntag': 7,
  };

  final lower = text.toLowerCase();
  _Span? kwSpan;
  int? targetWeekday;

  for (final entry in days.entries) {
    final pos = _findWord(lower, entry.key);
    if (pos != null) {
      kwSpan = pos;
      targetWeekday = entry.value;
      break;
    }
  }
  if (kwSpan == null || targetWeekday == null) return null;

  var daysAhead = targetWeekday - now.weekday;
  if (daysAhead <= 0) daysAhead += 7; // тот же день → следующая неделя
  final targetDate = now.add(Duration(days: daysAhead));

  final timeSpan = _parseTime(text);
  final int hour;
  final int minute;
  final List<_Span> toErase;

  if (timeSpan != null) {
    hour = timeSpan.hour;
    minute = timeSpan.minute;
    toErase = [kwSpan, timeSpan.span];
  } else {
    hour = 9;
    minute = 0;
    toErase = [kwSpan];
  }

  return NlDateTimeResult(
    when: _withTime(targetDate, hour, minute),
    cleanedTitle: _eraseSpans(text, toErase),
  );
}

/// Голое время (без контекста даты): "17:00", "5pm" → сегодня/завтра.
NlDateTimeResult? _tryBareTime(String text, DateTime now) {
  // HH:MM
  var m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h <= 23 && min <= 59) {
      var dt = _withTime(now, h, min);
      dt = _futureOrTomorrow(dt, now);
      final cleaned = _eraseSpans(text, [_Span(m.start, m.end)]);
      return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
    }
  }

  // 12h: "5pm", "9am"
  m = RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false).firstMatch(text);
  if (m != null) {
    var h = int.parse(m.group(1)!);
    final isPm = m.group(2)!.toLowerCase() == 'pm';
    if (h == 12 && !isPm) h = 0;
    if (h != 12 && isPm) h += 12;
    if (h <= 23) {
      var dt = _withTime(now, h, 0);
      dt = _futureOrTomorrow(dt, now);
      final cleaned = _eraseSpans(text, [_Span(m.start, m.end)]);
      return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
    }
  }

  // Голое ЧЧММ: 3-4 цифры подряд в духе Todoist ("700"→7:00, "1830"→18:30).
  // Только отдельно стоящий числовой токен (границы — пробел/пунктуация/край),
  // не часть длинного числа и не примыкает к ':' (чтобы не пересечь HH:MM).
  // Невалидные часы/минуты не распознаём → токен трактуется как обычный текст.
  final compact = _tryCompactDigits(text, now);
  if (compact != null) return compact;

  return null;
}

/// Парсит отдельный токен из 3-4 цифр как ЧЧММ ("700"→7:00, "1830"→18:30).
/// Возвращает null, если такого валидного токена нет.
NlDateTimeResult? _tryCompactDigits(String text, DateTime now) {
  for (final m in RegExp(r'\d{3,4}').allMatches(text)) {
    final start = m.start;
    final end = m.end;
    // Границы: только пробел/пунктуация по краям (не буква, не цифра, не ':').
    final beforeOk = start == 0 || _isDigitBoundary(text[start - 1]);
    final afterOk = end >= text.length || _isDigitBoundary(text[end]);
    if (!beforeOk || !afterOk) continue;

    final digits = m.group(0)!;
    // ЧЧММ: последние 2 цифры — минуты, остальное — часы.
    final hour = int.parse(digits.substring(0, digits.length - 2));
    final minute = int.parse(digits.substring(digits.length - 2));
    if (hour > 23 || minute > 59) continue;

    var dt = _withTime(now, hour, minute);
    dt = _futureOrTomorrow(dt, now);
    final cleaned = _eraseSpans(text, [_Span(start, end)]);
    return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
  }
  return null;
}

/// Граница для числового токена: НЕ буква, НЕ цифра, НЕ ':' (двоеточие отдаём HH:MM).
/// Иначе "12:34" или "1830x" не должны трактоваться как ЧЧММ.
bool _isDigitBoundary(String ch) {
  if (ch == ':') return false;
  final code = ch.codeUnitAt(0);
  final isDigit = code >= 0x30 && code <= 0x39;
  if (isDigit) return false;
  // Латиница / кириллица — считаем буквой (не граница), иначе граница.
  final isLatin =
      (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  final isCyrillic = code >= 0x0410 && code <= 0x044F;
  if (isLatin || isCyrillic) return false;
  return true;
}
