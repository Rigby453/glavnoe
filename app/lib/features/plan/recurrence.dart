// FL-RECUR: Чистая (без зависимостей от Flutter/Drift) библиотека повторов задач.
//
// Цель #6: ежедневно повторяющиеся задачи. Хранение — одна «якорная» строка
// (anchor) в items + правило в текстовой колонке recurrenceRule. Никакой
// миграции схемы: переиспользуем существующую nullable-колонку recurrenceRule.
//
// Формат правила — iCal-подобная строка:
//   FREQ=DAILY                      (обязательно для серии)
//   ;UNTIL=YYYY-MM-DD               (необязательно; включительно последний день — механизм отмены)
//   ;EXDATE=YYYYMMDD,YYYYMMDD,...   (необязательно; даты, исключённые из генерации,
//                                    потому что были «материализованы» в обычную строку)
//
// ВСЁ здесь — чистые функции/классы, полностью покрытые test/recurrence_test.dart.
// Даты повторов сравниваются ТОЛЬКО по году/месяцу/дню (время игнорируется).

/// Частота повторения. Пока поддерживается только ежедневная.
enum RecurFreq { daily }

/// Нормализует [d] до полуночи (год/месяц/день, без времени, локально).
/// Все сравнения дат в этой библиотеке идут через нормализованные значения.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `2026-06-22` (для UNTIL).
String _fmtUntil(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `20260622` (для EXDATE).
String _fmtExDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Парсит `YYYY-MM-DD` (UNTIL). null при неверном формате.
DateTime? _parseUntil(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Парсит `YYYYMMDD` (EXDATE). null при неверном формате.
DateTime? _parseExDate(String s) {
  if (s.length != 8) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(4, 6));
  final d = int.tryParse(s.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Правило повторения серии задач.
///
/// [exDates] хранятся как нормализованные (полночь) даты; сравнение — по Y/M/D.
class RecurrenceRule {
  RecurrenceRule({
    this.freq = RecurFreq.daily,
    DateTime? until,
    Set<DateTime>? exDates,
  })  : until = until == null ? null : _dateOnly(until),
        exDates = {
          for (final e in (exDates ?? const <DateTime>{})) _dateOnly(e),
        };

  /// Частота. Сейчас всегда [RecurFreq.daily].
  final RecurFreq freq;

  /// Включительно последний день, после которого повторов нет. null = бессрочно.
  final DateTime? until;

  /// Исключённые даты (материализованные дни). Сравниваются по Y/M/D.
  final Set<DateTime> exDates;

  /// Разбирает строку правила. Возвращает null, если это НЕ серия
  /// (нет `FREQ=DAILY`) — тогда строку нельзя считать повторяющейся.
  static RecurrenceRule? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    RecurFreq? freq;
    DateTime? until;
    final exDates = <DateTime>{};

    for (final part in trimmed.split(';')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = part.substring(eq + 1).trim();
      switch (key) {
        case 'FREQ':
          if (value.toUpperCase() == 'DAILY') freq = RecurFreq.daily;
        case 'UNTIL':
          until = _parseUntil(value);
        case 'EXDATE':
          for (final token in value.split(',')) {
            final t = token.trim();
            if (t.isEmpty) continue;
            final parsed = _parseExDate(t);
            if (parsed != null) exDates.add(parsed);
          }
      }
    }

    // Без поддерживаемой частоты это не серия.
    if (freq == null) return null;
    return RecurrenceRule(freq: freq, until: until, exDates: exDates);
  }

  /// Сериализует обратно в строку правила (round-trip с [parse]).
  /// Порядок частей детерминированный: FREQ, затем UNTIL, затем EXDATE.
  /// EXDATE сортируются по возрастанию для стабильности.
  String toRuleString() {
    final sb = StringBuffer('FREQ=DAILY');
    if (until != null) {
      sb.write(';UNTIL=${_fmtUntil(until!)}');
    }
    if (exDates.isNotEmpty) {
      final sorted = exDates.toList()..sort((a, b) => a.compareTo(b));
      sb.write(';EXDATE=${sorted.map(_fmtExDate).join(',')}');
    }
    return sb.toString();
  }

  /// Копия с заменой полей.
  RecurrenceRule copyWith({
    DateTime? until,
    bool clearUntil = false,
    Set<DateTime>? exDates,
  }) {
    return RecurrenceRule(
      freq: freq,
      until: clearUntil ? null : (until ?? this.until),
      exDates: exDates ?? this.exDates,
    );
  }
}

/// true, если серия с правилом [rule] и началом [anchorStart] порождает
/// повтор на дату [day]. Сравнение только по Y/M/D.
///
/// Условия (daily ⇒ каждый день окна):
///   • day >= даты anchorStart
///   • until == null ИЛИ day <= until
///   • day не входит в exDates
bool occursOn(RecurrenceRule rule, DateTime anchorStart, DateTime day) {
  final d = _dateOnly(day);
  final start = _dateOnly(anchorStart);
  if (d.isBefore(start)) return false;
  if (rule.until != null && d.isAfter(rule.until!)) return false;
  if (rule.exDates.contains(d)) return false;
  return true; // daily: каждый день в окне
}

/// Список дат-повторов в диапазоне [fromDay, toDay] включительно (по Y/M/D).
/// Возвращаются нормализованные даты (полночь). Пустой список, если пересечения
/// окна серии с диапазоном нет.
List<DateTime> occurrenceDatesInRange(
  DateTime anchorStart,
  RecurrenceRule rule,
  DateTime fromDay,
  DateTime toDay,
) {
  final from = _dateOnly(fromDay);
  final to = _dateOnly(toDay);
  if (to.isBefore(from)) return const [];

  final result = <DateTime>[];
  var cursor = from;
  // Жёсткий предохранитель от бесконечного цикла (макс ~10 лет дней).
  var guard = 0;
  const maxGuard = 3700;
  while (!cursor.isAfter(to) && guard < maxGuard) {
    if (occursOn(rule, anchorStart, cursor)) result.add(cursor);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    guard++;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Хелперы для модификации строки правила (используются при materialize/cancel)
// ---------------------------------------------------------------------------

/// Добавляет дату [day] в EXDATE правила [raw] и возвращает новую строку.
/// Если [raw] не является серией — возвращает [raw] без изменений.
/// Идемпотентно: повторное добавление той же даты ничего не меняет.
String? addExDateToRule(String? raw, DateTime day) {
  final rule = RecurrenceRule.parse(raw);
  if (rule == null) return raw;
  final next = {...rule.exDates, _dateOnly(day)};
  return rule.copyWith(exDates: next).toRuleString();
}

/// Устанавливает (заменяет) UNTIL в правиле [raw] на дату [until].
/// Если [raw] не серия — возвращает [raw] без изменений.
String? setUntilOnRule(String? raw, DateTime until) {
  final rule = RecurrenceRule.parse(raw);
  if (rule == null) return raw;
  return rule.copyWith(until: until).toRuleString();
}
