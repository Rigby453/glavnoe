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

import '../../features/plan/recurrence.dart';

/// Результат парсинга.
///
/// Помимо даты/времени ([when]) парсер опционально распознаёт (Todoist-стиль):
///   • [durationMinutes] — длительность («1.5ч», «30 мин», «1.5h»),
///   • [priority]        — приоритет («!важно», «p1», «p2», «низкий» …),
///   • [recurrenceRule]  — повтор-правило (строка из recurrence.dart:
///                          «каждый день», «по пн,ср,пт», «15 числа» …).
/// Любое из этих полей == null, если соответствующая фраза не распознана.
/// [cleanedTitle] — заголовок без ВСЕХ распознанных фраз (время + длительность
/// + приоритет + повтор).
class NlDateTimeResult {
  const NlDateTimeResult({
    required this.when,
    required this.cleanedTitle,
    this.durationMinutes,
    this.priority,
    this.recurrenceRule,
    this.reminderMinutesBefore,
    this.moduleLink,
    this.type,
  });

  /// null — дата/время не распознаны.
  final DateTime? when;

  /// Заголовок с удалёнными распознанными фразами.
  final String cleanedTitle;

  /// Длительность в минутах (1..1440) или null.
  final int? durationMinutes;

  /// Приоритет: 'main' | 'medium' | 'low' или null.
  final String? priority;

  /// Строка правила повтора (см. recurrence.dart::toRuleString) или null.
  final String? recurrenceRule;

  /// Напоминание за N минут до [when] («напомни за 10 мин») или null.
  /// Час → 60 минут. Распознаётся только рядом со словом-маркером
  /// «напомни/напоминание/remind/reminder» (защита от ложных срабатываний).
  final int? reminderMinutesBefore;

  /// Ссылка на модуль, распознанная по ключевым словам названия, или null.
  /// Значения совпадают с пикером «Открыть в модуле» в add_task_sheet.dart:
  /// 'workout' | 'meal:breakfast' | 'meal:lunch' | 'meal:dinner' | 'sleep'.
  /// Ключевые слова (RU + базовый EN) НЕ вырезаются из [cleanedTitle] —
  /// это смысловые слова названия, которые пользователь видит как есть.
  final String? moduleLink;

  /// Тип задачи, распознанный по ключевым словам названия, или null.
  /// Значения совпадают с чипами типа в add_task_sheet.dart:
  /// 'event' (пара/лекция/семинар) | 'deadline' (сдать/дедлайн/срок) |
  /// 'exam' (экзамен/зачёт). null = не распознано → вызывающий код подставит
  /// дефолт 'task'. Ключевые слова НЕ вырезаются из [cleanedTitle].
  final String? type;
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
///
/// Порядок обработки (важно против ложных срабатываний и конфликтов с числами):
///   1. Сначала вырезаем повтор-фразы («каждый день», «по пн,ср,пт», «15 числа»),
///      затем длительность («1.5ч», «30 мин»), затем приоритет («p1», «!важно»).
///      Эти фразы содержат цифры/слова, которые иначе мог бы перехватить
///      разбор времени (например «15» в «15 числа» как компактное ЧЧММ).
///   2. На ОСТАВШЕМСЯ тексте запускаем существующий разбор даты/времени —
///      его API и поведение («700»→7:00 и т.д.) не меняются.
NlDateTimeResult parseNaturalDateTime(String text, DateTime now) {
  final input = text.trim();
  if (input.isEmpty) {
    return NlDateTimeResult(when: null, cleanedTitle: input);
  }

  // --- Шаг 1: распознаём и вырезаем повтор / длительность / приоритет. ---
  var working = input;

  final recur = _parseRecurrence(working);
  String? recurrenceRule;
  if (recur != null) {
    recurrenceRule = recur.ruleString;
    working = _eraseSpans(working, [recur.span]);
  }

  // Напоминание — ДО длительности: фраза «напомни за 10 мин» содержит «10 мин»,
  // которую иначе перехватил бы _parseDuration как длительность задачи.
  final reminder = _parseReminder(working);
  int? reminderMinutesBefore;
  if (reminder != null) {
    reminderMinutesBefore = reminder.minutes;
    working = _eraseSpans(working, [reminder.span]);
  }

  // Диапазон времени → длительность: «с 7 до 9», «700-900», «до 900» (с началом).
  // Должен идти ДО _parseDuration, иначе «900» в «700-900» может зацепиться
  // обычным разбором. Сам диапазон вырезаем из текста; его старт применяем
  // ПОСЛЕ разбора даты (Шаг 2) — так дата берётся из «завтра»/словесной даты,
  // если она есть, а время = старт диапазона. ВАЖНО: к старту диапазона НЕ
  // применяем _futureOrTomorrow — явный блок остаётся на опорном дне (сегодня),
  // даже если старт чуть в прошлом относительно now. durationMinutes от
  // диапазона приоритетнее явной длительности — диапазон задаёт старт и конец.
  final range = _parseTimeRange(working);
  int? durationMinutes;
  if (range != null) {
    durationMinutes = range.minutes;
    working = _eraseSpans(working, [range.span]);
  }

  if (durationMinutes == null) {
    final dur = _parseDuration(working);
    if (dur != null) {
      durationMinutes = dur.minutes;
      working = _eraseSpans(working, [dur.span]);
    }
  }

  final prio = _parsePriority(working);
  String? priority;
  if (prio != null) {
    priority = prio.value;
    working = _eraseSpans(working, [prio.span]);
  }

  // --- Шаг 2: дата/время на оставшемся тексте (существующее поведение). ---
  var dt = _tryRelativeHours(working, now) ??
      _tryTomorrowTime(working, now) ??
      _tryTodayTime(working, now) ??
      _tryWeekdayTime(working, now) ??
      _tryWordDate(working, now) ??
      _tryBareTime(working, now) ??
      NlDateTimeResult(when: null, cleanedTitle: working);

  // Диапазон задаёт стартовое время: дата — от распознанного ключевого слова
  // («завтра»/словесная дата/день недели), если оно есть; иначе опорный день
  // (now), БЕЗ сдвига на завтра (явный блок остаётся на сегодня).
  if (range != null) {
    final base = dt.when ?? now;
    dt = NlDateTimeResult(
      when: _withTime(base, range.startHour, range.startMinute),
      cleanedTitle: dt.cleanedTitle,
    );
  }

  // --- Шаг 3: модуль / тип по ключевым словам названия. ---
  // Распознаём по ИСХОДНОМУ тексту (не по обрезанному working), т.к. дата/время
  // могли вырезать слова. Ключевые слова НЕ вырезаем из cleanedTitle — это
  // смысловые слова названия, пользователь видит заголовок как есть.
  final moduleLink = _detectModuleLink(input);
  final type = _detectType(input);

  return NlDateTimeResult(
    when: dt.when,
    cleanedTitle: dt.cleanedTitle,
    durationMinutes: durationMinutes,
    priority: priority,
    recurrenceRule: recurrenceRule,
    reminderMinutesBefore: reminderMinutesBefore,
    moduleLink: moduleLink,
    type: type,
  );
}

// ---------------------------------------------------------------------------
// РАСШИРЕНИЕ: модуль / тип по ключевым словам названия.
//
// В отличие от времени/длительности/приоритета/повтора — эти распознаватели
// НЕ возвращают _Span и НЕ вырезают слова из заголовка: ключевые слова
// (тренировка, обед, лекция, сдать…) — это смысловое ядро названия, которое
// пользователь должен видеть как есть.
//
// КОНСЕРВАТИВНОСТЬ (защита от ложных срабатываний): сопоставление идёт НЕ по
// произвольной подстроке, а по ГРАНИЦАМ СЛОВА. Каждый ключ — это либо:
//   • _kStem  — корень-префикс: совпадает, если в тексте есть слово, КОТОРОЕ
//               НАЧИНАЕТСЯ с этого корня (левая граница слова обязательна,
//               правая — нет). «тренировк» → «тренировка/тренировку», «лекци» →
//               «лекция/лекции/лекцию», «обед» → «обед/обедать» (но НЕ «победа»,
//               т.к. «обед» там не на границе слова);
//   • _kWord  — целое слово: совпадает только как самостоятельный токен
//               (границы с обеих сторон). «трен» (но НЕ «тренд/трендовый»),
//               «пара» (но НЕ «парад/пародия/напарник»), «сон» (но НЕ «соната/
//               персональный»), «спать», «зачёт».
// Это убирает ложные срабатывания на коротких двусмысленных корнях.
// ---------------------------------------------------------------------------

/// Ключевое слово модуля/типа с режимом сопоставления.
class _Keyword {
  const _Keyword(this.text, {this.wholeWord = false});

  /// Корень/слово (нижний регистр).
  final String text;

  /// true → совпадает только как целое слово (границы с обеих сторон);
  /// false → корень-префикс (левая граница + начало слова, правая не нужна).
  final bool wholeWord;
}

const _kStem = _Keyword.new; // короткий конструктор для стемов
_Keyword _kWord(String t) => _Keyword(t, wholeWord: true);

/// Карта ключевые-слова → значение moduleLink (в порядке проверки).
/// Значения совпадают с пикером в add_task_sheet.dart (meal-модули — с
/// префиксом 'meal:').
final List<(List<_Keyword>, String)> _moduleKeywords = [
  // «трен» — только целое слово (иначе ловит «тренд/трендовый»). Полные формы —
  // через стем «тренировк». «зал» убран совсем; покрываем «спортзал».
  (
    [
      _kStem('тренировк'),
      _kWord('трен'),
      _kStem('качал'),
      _kStem('спортзал'),
      _kStem('workout'),
      _kWord('gym'),
    ],
    'workout',
  ),
  ([_kStem('завтрак'), _kStem('breakfast')], 'meal:breakfast'),
  // «обед» как стем ловит «обед/обедать»; «пообед» — «пообедать». «победа» НЕ
  // совпадает (там «обед» не на границе слова).
  ([_kStem('пообед'), _kStem('обед'), _kStem('lunch')], 'meal:lunch'),
  ([_kStem('ужин'), _kStem('dinner'), _kStem('supper')], 'meal:dinner'),
  // «сон»/«спать» — целые слова (иначе ловят «соната/персональный/спать→...»);
  // стемы «поспат»/«выспат» ловят формы «поспать/выспаться».
  (
    [
      _kStem('поспат'),
      _kStem('выспат'),
      _kWord('спать'),
      _kWord('сон'),
      _kStem('sleep'),
    ],
    'sleep',
  ),
];

/// Карта ключевые-слова → значение type (в порядке проверки).
/// Значения совпадают с чипами типа в add_task_sheet.dart.
/// Порядок специфичности: exam/deadline проверяем до event, т.к. экзамен/
/// дедлайн «весомее» обычного занятия.
final List<(List<_Keyword>, String)> _typeKeywords = [
  ([_kStem('экзамен'), _kWord('зачёт'), _kWord('зачет'), _kStem('exam')], 'exam'),
  // «сдать»/«срок» — целые слова (иначе «сделать»/«срочное» не должны, но они и
  // так не содержат корней; целое слово страхует). «дедлайн»/«сдач» — стемы.
  (
    [
      _kWord('сдать'),
      _kStem('сдач'),
      _kStem('дедлайн'),
      _kWord('срок'),
      _kStem('deadline'),
      _kWord('due'),
    ],
    'deadline',
  ),
  // «пара» — целое слово (иначе «парад/пародия/напарник»). Остальное — стемы.
  (
    [
      _kWord('пара'),
      _kStem('лекци'),
      _kStem('семинар'),
      _kStem('занятие'),
      _kStem('lecture'),
      _kStem('class'),
    ],
    'event',
  ),
];

/// Проверяет, есть ли в [lower] совпадение ключа [k] по границам слова.
bool _matchesKeyword(String lower, _Keyword k) {
  if (k.wholeWord) return _findWord(lower, k.text) != null;
  return _findStem(lower, k.text) != null;
}

/// Ищет слово, НАЧИНАЮЩЕЕСЯ со стема [stem]: обязательна левая граница слова
/// (начало строки/пробел/пунктуация перед стемом), правая граница НЕ требуется
/// (после стема могут идти буквы — окончание словоформы). Возвращает индекс
/// начала или null.
_Span? _findStem(String lower, String stem) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(stem, from);
    if (idx < 0) return null;
    final before = idx == 0 || _isBoundary(lower[idx - 1]);
    if (before) return _Span(idx, idx + stem.length);
    from = idx + 1;
  }
}

/// Определяет moduleLink по ключевым словам в [text] (регистронезависимо,
/// по границам слова). Возвращает первое совпадение или null.
String? _detectModuleLink(String text) {
  final lower = text.toLowerCase();
  for (final (keys, value) in _moduleKeywords) {
    for (final k in keys) {
      if (_matchesKeyword(lower, k)) return value;
    }
  }
  return null;
}

/// Определяет тип задачи по ключевым словам в [text] (регистронезависимо,
/// по границам слова). Возвращает первое совпадение или null
/// (вызывающий код подставит дефолт 'task').
String? _detectType(String text) {
  final lower = text.toLowerCase();
  for (final (keys, value) in _typeKeywords) {
    for (final k in keys) {
      if (_matchesKeyword(lower, k)) return value;
    }
  }
  return null;
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

/// Связки-предлоги (RU / EN / DE), которые могут «осиротеть» после вырезания
/// распознанного фрагмента: «сдать курсовую к 18 июня» → вырезаем «18 июня»,
/// остаётся висячий «к», который надо убрать. Список как ОДНА группа регэкспа
/// (длинные варианты раньше коротких не важны — все целые токены).
/// ВАЖНО: эти предлоги вырезаются ТОЛЬКО когда они примыкают к удалённому
/// фрагменту (к «дырке»), а не где попало в названии — иначе можно отрезать
/// осмысленное слово (например «с» как начало настоящего слова невозможно, но
/// «к»/«до»/«за» как самостоятельные токены в осмысленном тексте редки и всё
/// равно режутся лишь у границы выреза). См. _eraseSpans.
const String _danglingPrepRe =
    r'в|во|на|с|со|к|ко|до|по|за|от|am|um|at|on|in|to|by|from|till|until|bis|ab|von';

/// Маркер «дырки» (вырезанного фрагмента). Берём символ, которого заведомо нет
/// в пользовательском тексте, чтобы привязать к нему чистку висячих предлогов.
const String _gapMarker = '\u0000';

/// Удаляет диапазоны [spans] из [text], затем убирает предлоги-связки, которые
/// «повисли» вплотную к месту выреза, и схлопывает лишние пробелы.
///
/// Алгоритм:
///   1. Вырезаем спаны (с конца, чтобы индексы слева не сдвигались), вставляя на
///      их место [_gapMarker] — он помечает, ГДЕ был удалён фрагмент.
///   2. Убираем предлог-связку (в/во/с/к/до/по/за/at/on/um…), стоящий ВПЛОТНУЮ
///      СЛЕВА от маркера (он управлял удалённым фрагментом). Предлог справа от
///      дырки относится к следующему слову названия — его НЕ трогаем.
///   3. Удаляем маркеры, схлопываем пробелы, обрезаем края.
String _eraseSpans(String text, List<_Span> spans) {
  // 1) Вырезаем спаны (по убыванию start), помечая дырки маркером.
  final sorted = [...spans]..sort((a, b) => b.start.compareTo(a.start));
  var result = text;
  for (final s in sorted) {
    if (s.start < 0 || s.end > result.length) continue;
    result =
        '${result.substring(0, s.start)}$_gapMarker${result.substring(s.end)}';
  }

  // 2) Подчищаем висячий предлог СЛЕВА от дырки — он управлял удалённым
  //    фрагментом: «сдать курсовую к [18 июня]», «пара во [вторник]», «дедлайн
  //    сдать до [пятницы]». ТОЛЬКО левый: предлог СПРАВА от дырки почти всегда
  //    относится к следующему слову названия («встреча [9:00] на работе» — здесь
  //    «на работе» НАДО оставить; «звонок [9:00] с клиентом» — «с клиентом»),
  //    поэтому правый край НЕ трогаем. Повторяем, пока режется (на случай цепочки
  //    «… в к [дата]» — редко, но дёшево); обычно хватает одного прохода.
  final g = RegExp.escape(_gapMarker);
  final leftPrep = RegExp(
    '(?:(?<=\\s)|^)(?:$_danglingPrepRe)\\s*$g',
    caseSensitive: false,
    unicode: true,
  );

  String prev;
  do {
    prev = result;
    result = result.replaceAll(leftPrep, _gapMarker);
  } while (result != prev);

  // 3) Маркеры → пробел, схлопываем, обрезаем.
  result = result
      .replaceAll(_gapMarker, ' ')
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

/// Применяет RU-маркер части суток к часу 1..12.
///   «утра»/«ночи»  → как есть (но 12 ночи → 00);
///   «дня»/«вечера» → +12 для 1..11 (12 дня = 12:00, остаётся как есть).
/// Возвращает скорректированный час 0..23 или null, если час вне 0..23.
int? _applyRuMeridiem(int hour, String marker) {
  final m = marker.toLowerCase();
  var h = hour;
  if (m == 'утра' || m == 'ночи') {
    if (h == 12) h = 0; // 12 ночи / 12 утра → полночь
  } else if (m == 'дня' || m == 'вечера') {
    if (h != 12) h += 12; // 7 вечера → 19, 12 дня → 12
  }
  if (h < 0 || h > 23) return null;
  return h;
}

/// RU-часть-суток как хвост паттерна времени (необязательная группа).
/// «утра|вечера|дня|ночи» с границей слова справа.
const String _ruMeridiemRe = r'(?:\s*(утра|вечера|дня|ночи)(?![а-яё]))?';

/// Распознаёт RU-время с опциональным предлогом «в», пробельным форматом минут
/// («7 00» = 07:00) и опциональным маркером части суток («утра/вечера/дня/ночи»).
/// Span покрывает предлог «в», час, минуты И маркер — чтобы _eraseSpans вырезал
/// всё это из названия. Возвращает null, если такой конструкции нет.
///
/// Поддерживает:
///   • «в 7 00 утра» / «7 00» / «в 7 00» — час ПРОБЕЛ минуты;
///   • «в 7 утра» / «7 утра» / «в 8 вечера» — час + маркер (минуты = 00);
///   • «7:00 утра» — двоеточие + маркер.
/// НЕ матчит голый «в 7» без минут/маркера (его берёт существующая ветка) и
/// НЕ матчит, если за минутами/часом сразу идёт ещё цифра (часть длинного числа).
_TimeSpan? _parseRuSpacedTime(String text) {
  // Предлог «в»/«во» — опционально, попадает в span (group 0).
  // Час 1-2 цифры; затем ЛИБО «:MM»/« MM» (пробельные минуты), ЛИБО ничего —
  // но тогда ОБЯЗАТЕЛЕН маркер части суток (иначе это просто число).
  // (?<![\d]) перед часом — не середина длинного числа.
  // Вариант A: час + минуты (пробел/двоеточие) + опц. маркер.
  final withMin = RegExp(
    r'(?:(?:^|\s)(?:во|в)\s+)?(?<![\d:])(\d{1,2})[\s:](\d{2})(?![\d:])' +
        _ruMeridiemRe,
    caseSensitive: false,
    unicode: true,
  );
  for (final m in withMin.allMatches(text)) {
    final h0 = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h0 > 23 || min > 59) continue;
    final marker = m.group(3);
    final h = marker != null ? _applyRuMeridiem(h0, marker) : h0;
    if (h == null) continue;
    return _TimeSpan(h, min, _Span(m.start, m.end));
  }

  // Вариант B: час + ОБЯЗАТЕЛЬНЫЙ маркер (минуты = 00): «7 утра», «в 8 вечера».
  final withMarker = RegExp(
    r'(?:(?:^|\s)(?:во|в)\s+)?(?<![\d:])(\d{1,2})\s*(утра|вечера|дня|ночи)(?![а-яё])',
    caseSensitive: false,
    unicode: true,
  );
  final mm = withMarker.firstMatch(text);
  if (mm != null) {
    final h0 = int.parse(mm.group(1)!);
    if (h0 <= 23) {
      final h = _applyRuMeridiem(h0, mm.group(2)!);
      if (h != null) return _TimeSpan(h, 0, _Span(mm.start, mm.end));
    }
  }

  return null;
}

/// Ищет время в [text]. Возвращает null если не найдено.
/// НЕ удаляет предлоги — их убирает _eraseSpans.
_TimeSpan? _parseTime(String text) {
  // RU пробельный формат «7 00» / маркеры «утра/вечера» — высший приоритет,
  // т.к. иначе HH:MM или «в N» перехватят часть конструкции.
  final ru = _parseRuSpacedTime(text);
  if (ru != null) return ru;

  // HH:MM (24h)
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

/// Русские даты словом: «18 июня», «5 мая», «1 сентября», «июня 18».
/// Месяцы — в родительном падеже (января…декабря). Выставляет [when] на
/// ближайшую такую дату: если она уже прошла в этом году — следующий год
/// (согласованно с логикой _futureOrTomorrow). Время сохраняется, если оно
/// тоже распознано (через _parseTime). Иначе — 09:00.
NlDateTimeResult? _tryWordDate(String text, DateTime now) {
  final lower = text.toLowerCase();

  // Родительный падеж месяцев → номер месяца.
  const months = <String, int>{
    'января': 1, 'февраля': 2, 'марта': 3, 'апреля': 4,
    'мая': 5, 'июня': 6, 'июля': 7, 'августа': 8,
    'сентября': 9, 'октября': 10, 'ноября': 11, 'декабря': 12,
  };

  _Span? monthSpan;
  int? month;
  for (final entry in months.entries) {
    final pos = _findWord(lower, entry.key);
    if (pos != null) {
      monthSpan = pos;
      month = entry.value;
      break;
    }
  }
  if (monthSpan == null || month == null) return null;

  // Число дня: «18 июня» (день перед месяцем) или «июня 18» (после месяца).
  // Берём ближайший отдельно стоящий 1–2-значный токен 1..31, примыкающий
  // к слову месяца (через пробел/предлог), сначала слева, затем справа.
  final dayBefore = RegExp(r'(\d{1,2})\s+$')
      .firstMatch(lower.substring(0, monthSpan.start));
  final dayAfter = RegExp(r'^\s+(\d{1,2})')
      .firstMatch(lower.substring(monthSpan.end));

  int? day;
  int spanStart = monthSpan.start;
  int spanEnd = monthSpan.end;

  if (dayBefore != null) {
    final d = int.parse(dayBefore.group(1)!);
    if (d >= 1 && d <= 31) {
      day = d;
      spanStart = monthSpan.start - dayBefore.group(0)!.length;
    }
  }
  if (day == null && dayAfter != null) {
    final d = int.parse(dayAfter.group(1)!);
    if (d >= 1 && d <= 31) {
      day = d;
      spanEnd = monthSpan.end + dayAfter.group(0)!.length;
    }
  }
  if (day == null) return null; // месяц без числа — слишком неопределённо

  // Опциональное время в исходном тексте.
  final timeSpan = _parseTime(text);
  final hour = timeSpan?.hour ?? 9;
  final minute = timeSpan?.minute ?? 0;

  // Ближайшая дата: этот год, иначе следующий (если уже прошла).
  var candidate = DateTime(now.year, month, day, hour, minute);
  if (!candidate.isAfter(now)) {
    candidate = DateTime(now.year + 1, month, day, hour, minute);
  }

  final toErase = <_Span>[_Span(spanStart, spanEnd)];
  if (timeSpan != null) toErase.add(timeSpan.span);
  return NlDateTimeResult(
    when: candidate,
    cleanedTitle: _eraseSpans(text, toErase),
  );
}

/// Голое время (без контекста даты): "17:00", "5pm" → сегодня/завтра.
NlDateTimeResult? _tryBareTime(String text, DateTime now) {
  // RU пробельный формат «7 00» и маркеры «утра/вечера/дня/ночи» (вкл. предлог
  // «в») — высший приоритет: ловит «в 7 00 утра», «7 утра», «в 8 вечера» и
  // вырезает всю конструкцию (предлог + час + минуты + маркер) из названия.
  final ru = _parseRuSpacedTime(text);
  if (ru != null) {
    var dt = _withTime(now, ru.hour, ru.minute);
    dt = _futureOrTomorrow(dt, now);
    final cleaned = _eraseSpans(text, [ru.span]);
    return NlDateTimeResult(when: dt, cleanedTitle: cleaned);
  }

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

  // Голый час с ТЕМПОРАЛЬНЫМ предлогом: «в 7», «во 7», «к 9», «at 7», «um 9».
  // Одиночное число становится временем ТОЛЬКО при явном предлоге-маркере —
  // защита от «съесть 2 банана», «5 задач» (там предлога перед числом нет).
  // «с 7» намеренно НЕ берём здесь: одиночное «с N» без «до N» неоднозначно
  // (может быть «с 5 друзьями»); диапазон «с 7 до 9» ловит _parseTimeRange.
  m = RegExp(r'(?:^|\s)(?:в|во|к|at|um)\s+(\d{1,2})(?!\s*[:\d])',
          caseSensitive: false, unicode: true)
      .firstMatch(text);
  if (m != null) {
    final h = int.parse(m.group(1)!);
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
///
/// КОНСЕРВАТИВНОСТЬ: компактное ЧЧММ принимается только когда число похоже на
/// время, а не на количество/год. Отклоняем, если:
///   • за числом сразу идёт СЛОВО («700 листов», «1000 шагов», «300 страниц») —
///     это количество, а не время;
///   • перед числом стоит нетемпоральный предлог «за»/«про» («за 2024» — год,
///     не 20:24). Темпоральные предлоги (в/во/с/к…) число НЕ дисквалифицируют.
NlDateTimeResult? _tryCompactDigits(String text, DateTime now) {
  for (final m in RegExp(r'\d{3,4}').allMatches(text)) {
    final start = m.start;
    final end = m.end;
    // Границы: только пробел/пунктуация по краям (не буква, не цифра, не ':').
    final beforeOk = start == 0 || _isDigitBoundary(text[start - 1]);
    final afterOk = end >= text.length || _isDigitBoundary(text[end]);
    if (!beforeOk || !afterOk) continue;

    // За числом сразу идёт слово (пробел(ы)+буква) → это количество, не время.
    final rest = text.substring(end);
    if (RegExp(r'^\s+[а-яёa-z]', caseSensitive: false, unicode: true)
        .hasMatch(rest)) {
      continue;
    }
    // Перед числом нетемпоральный предлог «за»/«про» → не время (год/счёт).
    final head = text.substring(0, start);
    if (RegExp(r'(?:^|\s)(?:за|про)\s+$', caseSensitive: false, unicode: true)
        .hasMatch(head)) {
      continue;
    }

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

// ===========================================================================
// РАСШИРЕНИЕ: длительность / приоритет / повтор (Todoist-стиль).
// Каждый экстрактор возвращает распознанное значение + _Span для вырезания.
// Экстракторы работают с ИСХОДНЫМ (необрезанным) текстом; вырезание делает
// вызывающая функция через _eraseSpans, как и для времени.
// ===========================================================================

// --- Длительность ----------------------------------------------------------

class _DurationMatch {
  const _DurationMatch(this.minutes, this.span);
  final int minutes;
  final _Span span;
}

/// Распознаёт длительность и возвращает минуты (1..1440) + span.
///
/// Поддерживаемые форматы (RU / EN):
///   • часы (вкл. дробные .5): «1.5ч», «1.5 часа», «2 часа», «1.5h», «2 h»,
///     «1,5ч» (запятая как десятичный разделитель в RU);
///   • минуты: «30 мин», «45м», «90 минут», «30 min», «45 m».
///
/// Правила против ложных срабатываний:
///   • число ОБЯЗАНО примыкать к единице (ч/час[а/ов]/h | м/мин[ут]/min/m);
///     одиночное число без единицы НЕ трактуется как длительность;
///   • единица «h»/«m» латиницей требует границы справа (не часть слова),
///     чтобы «5 home» не дало 5h. Регэксп уже привязан к границам токена.
///   • результат клампится в диапазон 1..1440 мин; вне диапазона → не матч.
_DurationMatch? _parseDuration(String text) {
  // Часы: «1.5ч», «1.5 часа», «2 часа», «1,5ч», «1.5h», «2 h».
  // Группа единицы: ч | час | часа | часов | h (h — только как отдельный токен).
  // Негативный lookbehind на «через »/«in » — это относительное СМЕЩЕНИЕ
  // («через 2 часа»), а не длительность; его разбирает _tryRelativeHours.
  final hoursRe = RegExp(
    r'(?<!через\s)(?<!in\s)(\d+(?:[.,]\d+)?)\s*(час(?:а|ов|)|ч|hours?|hrs?|h)(?![a-zа-яё])',
    caseSensitive: false,
    unicode: true,
  );
  // Минуты: «30 мин», «45м», «90 минут», «30 min», «45 m».
  final minutesRe = RegExp(
    r'(\d+)\s*(минут[ы]?|мин|м|minutes?|mins?|min|m)(?![a-zа-яё])',
    caseSensitive: false,
    unicode: true,
  );

  // Сначала пробуем часы (более «ценная» единица). Если не нашли — минуты.
  final hm = hoursRe.firstMatch(text);
  if (hm != null) {
    final raw = hm.group(1)!.replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value != null && value > 0) {
      final minutes = (value * 60).round();
      if (minutes >= 1 && minutes <= 1440) {
        return _DurationMatch(minutes, _Span(hm.start, hm.end));
      }
    }
  }

  final mm = minutesRe.firstMatch(text);
  if (mm != null) {
    final value = int.tryParse(mm.group(1)!);
    if (value != null && value >= 1 && value <= 1440) {
      return _DurationMatch(value, _Span(mm.start, mm.end));
    }
  }

  return null;
}

// --- Диапазон времени → длительность ---------------------------------------

class _TimeRangeMatch {
  const _TimeRangeMatch(
      this.startHour, this.startMinute, this.minutes, this.span);

  /// Час/минута старта (для нормализации в «HH:MM»).
  final int startHour;
  final int startMinute;

  /// Длительность (конец − старт) в минутах, 1..1440.
  final int minutes;

  /// Диапазон в тексте, покрывающий всю конструкцию (включая «с»/«до»/тире).
  final _Span span;
}

/// Парсит одиночное время в строке-токене ([HH:MM] / [HHMM] / [H]).
/// Возвращает (hour, minute) или null. Чисто числовой токен: «9», «900», «9:00».
({int hour, int minute})? _parseTimeToken(String token) {
  final t = token.trim();
  // HH:MM
  var m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h <= 23 && min <= 59) return (hour: h, minute: min);
    return null;
  }
  // Компактное ЧЧММ: 3–4 цифры.
  m = RegExp(r'^(\d{3,4})$').firstMatch(t);
  if (m != null) {
    final d = m.group(1)!;
    final h = int.parse(d.substring(0, d.length - 2));
    final min = int.parse(d.substring(d.length - 2));
    if (h <= 23 && min <= 59) return (hour: h, minute: min);
    return null;
  }
  // Голый час: 1–2 цифры.
  m = RegExp(r'^(\d{1,2})$').firstMatch(t);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    if (h <= 23) return (hour: h, minute: 0);
    return null;
  }
  return null;
}

/// Распознаёт диапазон времени и возвращает старт + длительность (конец−старт).
///
/// Поддерживаемые формы (RU):
///   • «с 7 до 9», «с 7:00 до 9:30», «с 700 до 900»;
///   • «7 до 9», «700 до 900», «7:00 до 9:00» (без «с»);
///   • «700-900», «7:00-9:00», «7:00–9:00» (тире/дефис/en-dash/em-dash).
///
/// Требует И старт, И конец, причём конец позже старта (иначе → null, игнор).
/// «до 900» (только конец) НЕ распознаётся как диапазон — старта нет.
_TimeRangeMatch? _parseTimeRange(String text) {
  // Токен времени: HH:MM | ЧЧММ(3-4) | голый час(1-2).
  const tk = r'(\d{1,2}:\d{2}|\d{3,4}|\d{1,2})';

  // 1) «с <старт> до <конец>» (предлоги RU).
  final re = RegExp('(?:(?<![а-яё])с\\s+)?$tk\\s*(?:до|по)\\s*$tk',
      caseSensitive: false, unicode: true);
  // 2) «<старт> - <конец>» (тире). Разделитель: -, –, —.
  final dashRe = RegExp('$tk\\s*[\\-–—]\\s*$tk',
      caseSensitive: false, unicode: true);

  for (final candidate in [re.firstMatch(text), dashRe.firstMatch(text)]) {
    if (candidate == null) continue;
    final startTok = _parseTimeToken(candidate.group(1)!);
    final endTok = _parseTimeToken(candidate.group(2)!);
    if (startTok == null || endTok == null) continue;

    final startMin = startTok.hour * 60 + startTok.minute;
    final endMin = endTok.hour * 60 + endTok.minute;
    final diff = endMin - startMin;
    if (diff < 1 || diff > 1440) continue; // конец не позже старта → игнор

    // candidate.start уже включает предлог «с » при наличии (он в group 0).
    return _TimeRangeMatch(
        startTok.hour, startTok.minute, diff,
        _Span(candidate.start, candidate.end));
  }
  return null;
}

// --- Напоминание -----------------------------------------------------------

class _ReminderMatch {
  const _ReminderMatch(this.minutes, this.span);
  final int minutes;
  final _Span span;
}

/// Распознаёт «напомнить за N (минут/часов) до» и возвращает минуты + span.
///
/// Поддерживаемые формы (RU / EN):
///   • «напомни за 10 мин», «напоминание за 15 минут», «напомнить за 30 мин до»,
///     «напомни за 1 час», «напоминание за 2 часа до»;
///   • EN «remind 10 min before», «reminder 1h before», «remind me 15 minutes before»,
///     «remind in 30 min».
///
/// Час → 60 минут (множитель). Результат в диапазоне 1..1440 (сутки макс).
///
/// Защита от ложных срабатываний: ОБЯЗАТЕЛЕН маркер
/// «напомни/напоминание/напомнить/remind/reminder» рядом с числом+единицей.
/// Поэтому «напоминалка» (нет числа+единицы рядом) не триггерит,
/// а «30 мин» без маркера трактуется как длительность, а не напоминание.
_ReminderMatch? _parseReminder(String text) {
  // Маркер ... [за|in] N (мин|минут|ч|час...|min|h|hour...) [до|before]
  // Единственный регэксп ловит весь фрагмент от маркера до числа+единицы,
  // включая необязательные «за»/«до» (RU) и «in»/«before»/«me» (EN).
  final re = RegExp(
    r'(?:напомни(?:ть|нание)?|напоминание|remind(?:er)?)'
    r'(?:\s+me)?'
    r'(?:\s+(?:за|in))?'
    r'\s+(\d+)\s*'
    r'(минут[аы]?|мин|час(?:а|ов|)|ч|minutes?|mins?|min|hours?|hrs?|h)'
    r'(?![a-zа-яё])'
    r'(?:\s+(?:до|before))?',
    caseSensitive: false,
    unicode: true,
  );
  final m = re.firstMatch(text);
  if (m == null) return null;

  final value = int.tryParse(m.group(1)!);
  if (value == null || value <= 0) return null;

  final unit = m.group(2)!.toLowerCase();
  // Часовые единицы: ч / час / часа / часов / h / hour(s) / hr(s).
  final isHours = unit == 'ч' ||
      unit.startsWith('час') ||
      unit == 'h' ||
      unit.startsWith('hour') ||
      unit.startsWith('hr');
  final minutes = isHours ? value * 60 : value;
  if (minutes < 1 || minutes > 1440) return null;

  return _ReminderMatch(minutes, _Span(m.start, m.end));
}

// --- Приоритет -------------------------------------------------------------

class _PriorityMatch {
  const _PriorityMatch(this.value, this.span);

  /// 'main' | 'medium' | 'low'.
  final String value;
  final _Span span;
}

/// Распознаёт приоритет и возвращает значение модели + span.
///
/// Маппинг:
///   main   ← «p1», «!важно», «!!!», «важно», «главное», «important»
///   medium ← «p2», «средний»
///   low    ← «p3», «low», «низкий»
///
/// Правила против ложных срабатываний (главное — НЕ ловить обычный «!» в тексте):
///   • явный маркер обязателен. Допустимы только:
///       — токены «p1/p2/p3» (латиница, как отдельное слово);
///       — «!!!» (три и более «!») → main;
///       — ведущий «!» вплотную к ключевому слову: «!важно», «!important»;
///       — отдельные ключевые слова: «важно», «главное», «important»,
///         «средний», «низкий», «low» (как самостоятельные слова).
///   • одиночный «!» в произвольном месте текста («ура!») приоритет НЕ даёт.
///   • первый по порядку специфичности: «p1/2/3» → «!!!» → «!слово» → слова.
_PriorityMatch? _parsePriority(String text) {
  final lower = text.toLowerCase();

  // 1) p1 / p2 / p3 — самые однозначные маркеры (как отдельное слово).
  final pRe = RegExp(r'(?<![a-zа-яё0-9])p([123])(?![a-zа-яё0-9])',
      caseSensitive: false, unicode: true);
  final pm = pRe.firstMatch(lower);
  if (pm != null) {
    final level = pm.group(1)!;
    final value = level == '1'
        ? 'main'
        : level == '2'
            ? 'medium'
            : 'low';
    return _PriorityMatch(value, _Span(pm.start, pm.end));
  }

  // 2) «!!!» (три и более восклицательных) → main.
  final bangRe = RegExp(r'!{3,}');
  final bm = bangRe.firstMatch(text);
  if (bm != null) {
    return _PriorityMatch('main', _Span(bm.start, bm.end));
  }

  // 3) Ведущий «!» вплотную к ключевому слову: «!важно», «!important».
  //    А также сами ключевые слова без «!». Порядок: длинные/специфичные слова.
  //    Каждый кортеж: (слово, значение). Слова matchаем как отдельные токены
  //    через _findWord (с поддержкой ведущего «!»).
  const keywords = <(String, String)>[
    ('важно', 'main'),
    ('главное', 'main'),
    ('important', 'main'),
    ('средний', 'medium'),
    ('низкий', 'low'),
    ('low', 'low'),
  ];

  for (final (word, value) in keywords) {
    // Ищем «!слово» (ведущий «!») или само «слово» как отдельный токен.
    final span = _findWordWithOptionalBang(lower, word);
    if (span != null) return _PriorityMatch(value, span);
  }

  return null;
}

/// Ищет [word] как отдельный токен, опционально с ведущим «!» (вплотную).
/// Граница слева — начало строки/пробел/пунктуация ИЛИ «!»; справа — обычная
/// граница слова. Если перед словом стоит «!» — он включается в span.
_Span? _findWordWithOptionalBang(String lower, String word) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(word, from);
    if (idx < 0) return null;
    final end = idx + word.length;
    final hasBang = idx > 0 && lower[idx - 1] == '!';
    final beforeOk =
        idx == 0 || hasBang || _isBoundary(lower[idx - 1]);
    final afterOk = end >= lower.length || _isBoundary(lower[end]);
    if (beforeOk && afterOk) {
      return _Span(hasBang ? idx - 1 : idx, end);
    }
    from = idx + 1;
  }
}

// --- Повтор ----------------------------------------------------------------

class _RecurrenceMatch {
  const _RecurrenceMatch(this.ruleString, this.span);
  final String ruleString;
  final _Span span;
}

/// Распознаёт фразу повтора и собирает правило через API recurrence.dart.
///
/// Поддерживаемые формы (RU / EN):
///   daily   ← «каждый день», «ежедневно», «daily», «every day»
///   monthly ← «N числа», «каждый месяц», «ежемесячно», «monthly»
///   weekly  ← «по будням» (Пн-Пт), «по пн,ср,пт» / «каждый понедельник»
///             «every monday», «каждую неделю», «еженедельно», «weekly»
///
/// Порядок (специфичные → общие):
///   1. «N числа» (monthly с конкретным числом).
///   2. daily-фразы.
///   3. weekly: «по будням», списки дней «по пн,ср,пт», конкретный день недели.
///   4. monthly-общие («каждый месяц» …) и weekly-общие («каждую неделю» …).
///
/// Правила против ложных срабатываний:
///   • все фразы — целые токены (через _findWord / якорные регэкспы),
///     одиночное «день» / «day» без «каждый/every» повтор НЕ даёт;
///   • «N числа» требует слова «числа» рядом с числом 1..31.
_RecurrenceMatch? _parseRecurrence(String text) {
  final lower = text.toLowerCase();

  // 1) «15 числа» / «1 числа» → monthly(monthDay).
  final monthDayRe = RegExp(
    r'(\d{1,2})\s*(?:-?е|-?го)?\s*числа',
    caseSensitive: false,
    unicode: true,
  );
  final mdm = monthDayRe.firstMatch(lower);
  if (mdm != null) {
    final day = int.tryParse(mdm.group(1)!);
    if (day != null && day >= 1 && day <= 31) {
      final rule = monthlyRule(monthDay: day);
      return _RecurrenceMatch(rule.toRuleString(), _Span(mdm.start, mdm.end));
    }
  }

  // 2) daily-фразы.
  const dailyPhrases = ['каждый день', 'ежедневно', 'every day', 'daily'];
  for (final phrase in dailyPhrases) {
    final span = _findPhrase(lower, phrase);
    if (span != null) {
      return _RecurrenceMatch(dailyRule().toRuleString(), span);
    }
  }

  // 3) weekly: «по будням» (Пн-Пт).
  for (final phrase in ['по будням', 'будни', 'on weekdays', 'every weekday']) {
    final span = _findPhrase(lower, phrase);
    if (span != null) {
      final days = {
        RecurWeekday.mo,
        RecurWeekday.tu,
        RecurWeekday.we,
        RecurWeekday.th,
        RecurWeekday.fr,
      };
      return _RecurrenceMatch(weeklyRule(days).toRuleString(), span);
    }
  }

  // 3b) Список дней недели: «по пн,ср,пт» / «по пн ср пт» /
  //     «every mon,wed,fri». Требуем ведущий маркер «по» (RU) или «every» (EN),
  //     иначе обычный текст с днями недели не превращаем в повтор.
  final weekdayList = _parseWeekdayList(lower);
  if (weekdayList != null) {
    return _RecurrenceMatch(
      weeklyRule(weekdayList.days).toRuleString(),
      weekdayList.span,
    );
  }

  // 3c) Конкретный одиночный день: «каждый понедельник», «every monday»,
  //     «по понедельникам».
  final singleDay = _parseSingleWeekday(lower);
  if (singleDay != null) {
    return _RecurrenceMatch(
      weeklyRule({singleDay.day}).toRuleString(),
      singleDay.span,
    );
  }

  // 4) Общие weekly-фразы (без указания дня → день недели якоря выберется при
  //    сборке правила в add_task_sheet; здесь даём пустой набор дней).
  for (final phrase in [
    'каждую неделю',
    'еженедельно',
    'every week',
    'weekly',
  ]) {
    final span = _findPhrase(lower, phrase);
    if (span != null) {
      return _RecurrenceMatch(weeklyRule(const {}).toRuleString(), span);
    }
  }

  // 4b) Общие monthly-фразы (без числа → день месяца якоря выберется позже).
  for (final phrase in [
    'каждый месяц',
    'ежемесячно',
    'every month',
    'monthly',
  ]) {
    final span = _findPhrase(lower, phrase);
    if (span != null) {
      return _RecurrenceMatch(monthlyRule().toRuleString(), span);
    }
  }

  return null;
}

/// Карта токенов дней недели (RU короткие/полные + EN) → RecurWeekday.
/// Длинные ключи идут первыми, чтобы «понедельникам» не словился как «пн».
const Map<String, RecurWeekday> _weekdayTokens = {
  // RU полные (вкл. падежи «по понедельникам»)
  'понедельникам': RecurWeekday.mo, 'понедельник': RecurWeekday.mo,
  'вторникам': RecurWeekday.tu, 'вторник': RecurWeekday.tu,
  'средам': RecurWeekday.we, 'среду': RecurWeekday.we, 'среда': RecurWeekday.we,
  'четвергам': RecurWeekday.th, 'четверг': RecurWeekday.th,
  'пятницам': RecurWeekday.fr, 'пятницу': RecurWeekday.fr,
  'пятница': RecurWeekday.fr,
  'субботам': RecurWeekday.sa, 'субботу': RecurWeekday.sa,
  'суббота': RecurWeekday.sa,
  'воскресеньям': RecurWeekday.su, 'воскресенье': RecurWeekday.su,
  // RU короткие
  'пн': RecurWeekday.mo, 'вт': RecurWeekday.tu, 'ср': RecurWeekday.we,
  'чт': RecurWeekday.th, 'пт': RecurWeekday.fr, 'сб': RecurWeekday.sa,
  'вс': RecurWeekday.su,
  // EN полные
  'monday': RecurWeekday.mo, 'tuesday': RecurWeekday.tu,
  'wednesday': RecurWeekday.we, 'thursday': RecurWeekday.th,
  'friday': RecurWeekday.fr, 'saturday': RecurWeekday.sa,
  'sunday': RecurWeekday.su,
  // EN короткие
  'mon': RecurWeekday.mo, 'tue': RecurWeekday.tu, 'wed': RecurWeekday.we,
  'thu': RecurWeekday.th, 'fri': RecurWeekday.fr, 'sat': RecurWeekday.sa,
  'sun': RecurWeekday.su,
};

class _WeekdayListMatch {
  const _WeekdayListMatch(this.days, this.span);
  final Set<RecurWeekday> days;
  final _Span span;
}

/// Парсит список дней после маркера «по …» (RU) или «every …» (EN):
/// «по пн,ср,пт» / «по пн ср пт» / «every mon, wed, fri».
/// Возвращает набор дней + span (включая маркер). null если ≥2 дней не нашли.
_WeekdayListMatch? _parseWeekdayList(String lower) {
  // Маркер + хвост до конца строки. Хвост режем по словам и сверяем со словарём.
  final markerRe = RegExp(r'(?<![a-zа-яё])(по|every)\s+',
      caseSensitive: false, unicode: true);
  final mk = markerRe.firstMatch(lower);
  if (mk == null) return null;

  // Берём токены сразу после маркера, разделённые запятой/пробелом.
  var pos = mk.end;
  final days = <RecurWeekday>{};
  var lastEnd = mk.start; // конец последнего распознанного токена дня

  // Идём по токенам, пока они являются днями недели или разделителями.
  final tokenRe = RegExp(r'[a-zа-яё]+', caseSensitive: false, unicode: true);
  while (pos < lower.length) {
    // Пропускаем разделители (пробелы, запятые, «и»/«and» — простые союзы).
    final sepMatch = RegExp(r'^[\s,]+').firstMatch(lower.substring(pos));
    if (sepMatch != null) {
      pos += sepMatch.end;
      continue;
    }
    final tm = tokenRe.matchAsPrefix(lower, pos);
    if (tm == null) break;
    final token = tm.group(0)!;
    // Союз «и»/«and» между днями — пропускаем, продолжаем.
    if (token == 'и' || token == 'and') {
      pos = tm.end;
      continue;
    }
    final wd = _weekdayTokens[token];
    if (wd == null) break; // не день недели → конец списка
    days.add(wd);
    lastEnd = tm.end;
    pos = tm.end;
  }

  if (days.length < 2) return null; // «по пн» — это одиночный день (см. ниже)
  return _WeekdayListMatch(days, _Span(mk.start, lastEnd));
}

class _SingleWeekdayMatch {
  const _SingleWeekdayMatch(this.day, this.span);
  final RecurWeekday day;
  final _Span span;
}

/// Парсит одиночный повторяющийся день: «каждый понедельник»,
/// «every monday», «по понедельникам», «по пн». Требует маркера повтора
/// («каждый/каждую/every/по»), иначе обычное упоминание дня недели — это
/// одноразовая дата (её обрабатывает _tryWeekdayTime), а не серия.
_SingleWeekdayMatch? _parseSingleWeekday(String lower) {
  final markerRe = RegExp(r'(?<![a-zа-яё])(кажд(?:ый|ую|ое)|every|по)\s+',
      caseSensitive: false, unicode: true);
  for (final mk in markerRe.allMatches(lower)) {
    // Берём первый словарный токен после маркера.
    final tm = RegExp(r'[a-zа-яё]+', caseSensitive: false, unicode: true)
        .matchAsPrefix(lower, mk.end);
    if (tm == null) continue;
    final token = tm.group(0)!;
    final wd = _weekdayTokens[token];
    if (wd != null) {
      return _SingleWeekdayMatch(wd, _Span(mk.start, tm.end));
    }
  }
  return null;
}

/// Ищет точную фразу [phrase] (может содержать пробелы) как отдельный фрагмент:
/// границы слева/справа — край строки или не-буквенный символ.
/// Возвращает span или null.
_Span? _findPhrase(String lower, String phrase) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(phrase, from);
    if (idx < 0) return null;
    final end = idx + phrase.length;
    final before = idx == 0 || _isPhraseBoundary(lower[idx - 1]);
    final after = end >= lower.length || _isPhraseBoundary(lower[end]);
    if (before && after) return _Span(idx, end);
    from = idx + 1;
  }
}

/// Граница для фраз повтора: не буква и не цифра (пробел/пунктуация/край).
bool _isPhraseBoundary(String ch) {
  final code = ch.codeUnitAt(0);
  final isDigit = code >= 0x30 && code <= 0x39;
  final isLatin =
      (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  final isCyrillic = (code >= 0x0410 && code <= 0x044F) ||
      code == 0x0401 ||
      code == 0x0451; // Ё/ё
  return !(isDigit || isLatin || isCyrillic);
}
