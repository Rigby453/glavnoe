// Парсер iCalendar (.ics) файлов.
// Поддерживает экспорт из Google Calendar, Apple Calendar, Outlook.
// Используется в ImportSheet для импорта событий по дате.
//
// RFC 5545: line-unfolding, экранирование TEXT-значений (\\ \, \; \n),
// формы DTSTART (UTC `Z`, floating local, all-day DATE, TZID), RRULE.
//
// TZID: без встроенной базы часовых поясов мы трактуем стенное время
// (DTSTART;TZID=America/New_York:20240617T090000) как локальное wall-clock —
// общепринятый компромисс для офлайн-парсера. UTC (`Z`) конвертируется в
// локальное точно. Floating time трактуется как локальное.

/// Одно событие из ICS-файла
class IcsEvent {
  const IcsEvent({
    required this.summary,
    required this.dtStart,
    required this.durationMinutes,
    this.isAllDay = false,
    this.recurrenceRule,
    this.location,
  });

  /// Заголовок события (поле SUMMARY), уже с раскрытыми escape-последовательностями
  final String summary;

  /// Время начала в локальном времени (null = не удалось распарсить).
  /// Для all-day — полночь локального дня.
  final DateTime? dtStart;

  /// Длительность в минутах (вычислено из DTEND - DTSTART или DURATION;
  /// по умолчанию 60, для all-day без DTEND — 1440).
  final int durationMinutes;

  /// true, если событие занимает весь день (DTSTART;VALUE=DATE или 8-значная дата).
  final bool isAllDay;

  /// Правило повторения в формате приложения (FREQ=...;BYDAY=...;UNTIL=YYYY-MM-DD),
  /// либо null если у события нет RRULE или RRULE невозможно представить
  /// моделью повторов приложения (например INTERVAL>1, COUNT, FREQ=YEARLY).
  /// В таком случае импортируется базовое событие, а правило отбрасывается.
  final String? recurrenceRule;

  /// Место проведения (поле LOCATION), уже с раскрытыми escape-последовательностями.
  /// null, если LOCATION отсутствует или пуст.
  final String? location;
}

/// Парсер ICS-файлов (RFC 5545)
class IcsParser {
  /// Разбирает строку содержимого ICS-файла и возвращает список событий.
  /// Пропускает события с пустым SUMMARY.
  static List<IcsEvent> parse(String icsContent) {
    final events = <IcsEvent>[];

    // Нормализуем переносы строк
    final normalized = icsContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Раскрываем сложенные строки (line folding: следующая строка начинается с пробела/таба)
    final unfolded = normalized.replaceAll('\n ', '').replaceAll('\n\t', '');

    // Извлекаем VEVENT-блоки
    final veventRegex = RegExp(
      r'BEGIN:VEVENT\n(.*?)END:VEVENT',
      dotAll: true,
    );

    for (final match in veventRegex.allMatches(unfolded)) {
      final block = match.group(1) ?? '';
      final event = _parseVevent(block);
      if (event != null) {
        events.add(event);
      }
    }

    return events;
  }

  /// Парсит один VEVENT-блок, возвращает IcsEvent или null если событие некорректно
  static IcsEvent? _parseVevent(String block) {
    final lines = block.split('\n');

    String? summary;
    DateTime? dtStart;
    DateTime? dtEnd;
    int? durationMinutes;
    bool isAllDay = false;
    String? recurrenceRule;
    String? location;

    for (final line in lines) {
      // Убираем параметры типа DTSTART;TZID=America/New_York: → берём только значение
      if (line.startsWith('SUMMARY:') || line.startsWith('SUMMARY;')) {
        summary = _unescapeText(_extractValue(line));
      } else if (line.startsWith('DTSTART')) {
        dtStart = _parseDateTime(line);
        isAllDay = _isDateOnly(line);
      } else if (line.startsWith('DTEND')) {
        dtEnd = _parseDateTime(line);
      } else if (line.startsWith('DURATION:')) {
        final val = _extractValue(line);
        durationMinutes = _parseDuration(val);
      } else if (line.startsWith('RRULE:') || line.startsWith('RRULE;')) {
        recurrenceRule = _convertRrule(_extractValue(line));
      } else if (line.startsWith('LOCATION:') || line.startsWith('LOCATION;')) {
        final unescaped = _unescapeText(_extractValue(line));
        location = unescaped.isNotEmpty ? unescaped : null;
      }
    }

    // Пропускаем события без заголовка
    if (summary == null || summary.isEmpty) return null;

    // Вычисляем длительность (all-day по умолчанию = сутки)
    int dur = isAllDay ? 1440 : 60;
    if (dtStart != null && dtEnd != null) {
      final diff = dtEnd.difference(dtStart).inMinutes;
      if (diff > 0) dur = diff;
    } else if (durationMinutes != null && durationMinutes > 0) {
      dur = durationMinutes;
    }

    return IcsEvent(
      summary: summary,
      dtStart: dtStart,
      durationMinutes: dur,
      isAllDay: isAllDay,
      recurrenceRule: recurrenceRule,
      location: location,
    );
  }

  /// Извлекает значение из строки вида "KEY:value" или "KEY;params:value"
  static String _extractValue(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx < 0) return '';
    return line.substring(colonIdx + 1).trim();
  }

  /// Раскрывает RFC 5545 escape-последовательности в TEXT-значении:
  /// `\\` → `\`, `\,` → `,`, `\;` → `;`, `\n`/`\N` → перевод строки.
  /// Неизвестный escape (`\x`) → оставляем символ как есть (`x`).
  static String _unescapeText(String s) {
    if (!s.contains(r'\')) return s;
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == r'\' && i + 1 < s.length) {
        final next = s[i + 1];
        switch (next) {
          case 'n':
          case 'N':
            buf.write('\n');
          case r'\':
            buf.write(r'\');
          case ',':
            buf.write(',');
          case ';':
            buf.write(';');
          default:
            buf.write(next);
        }
        i++; // пропускаем экранированный символ
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  /// true, если значение DTSTART — это дата без времени (all-day):
  /// либо параметр VALUE=DATE, либо 8-значное значение без 'T'.
  static bool _isDateOnly(String line) {
    final colonIdx = line.indexOf(':');
    final params =
        colonIdx >= 0 ? line.substring(0, colonIdx).toUpperCase() : '';
    if (params.contains('VALUE=DATE') && !params.contains('VALUE=DATE-TIME')) {
      return true;
    }
    final value = _extractValue(line).replaceAll('Z', '');
    return value.length == 8 && !value.contains('T');
  }

  /// Парсит DTSTART/DTEND строку в DateTime (локальное время)
  /// Форматы:
  ///   20240617T090000Z   — UTC → конвертируется в локальное
  ///   20240617T090000    — floating/TZID → трактуется как локальное wall-clock
  ///   20240617           — весь день → полночь локального дня
  static DateTime? _parseDateTime(String line) {
    final value = _extractValue(line);
    final isUtc = value.endsWith('Z');
    final clean = value.replaceAll('Z', '');

    if (clean.length == 8 && !clean.contains('T')) {
      // Формат даты: YYYYMMDD (весь день) → полночь локального дня
      final year = int.tryParse(clean.substring(0, 4));
      final month = int.tryParse(clean.substring(4, 6));
      final day = int.tryParse(clean.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      return DateTime(year, month, day);
    }

    if (clean.length >= 15) {
      // Формат: YYYYMMDDTHHmmss
      final year = int.tryParse(clean.substring(0, 4));
      final month = int.tryParse(clean.substring(4, 6));
      final day = int.tryParse(clean.substring(6, 8));
      final hour = int.tryParse(clean.substring(9, 11));
      final minute = int.tryParse(clean.substring(11, 13));
      if (year == null || month == null || day == null ||
          hour == null || minute == null) {
        return null;
      }

      if (isUtc) {
        // Конвертируем из UTC в локальное
        return DateTime.utc(year, month, day, hour, minute).toLocal();
      } else {
        return DateTime(year, month, day, hour, minute);
      }
    }

    return null;
  }

  /// Парсит DURATION строку (RFC 5545): PT1H30M → 90, PT45M → 45
  /// Поддерживает: P1D, PT1H, PT30M, PT1H30M
  ///
  /// [value] приходит из внешнего .ics-файла (недоверенные данные) — цифровые
  /// группы `\d+` не ограничены по длине, поэтому используем tryParse: битый
  /// файл с аномально длинным числом не должен ронять импорт FormatException'ом
  /// (красный экран).
  static int _parseDuration(String value) {
    int minutes = 0;

    // Дни: P1D
    final days = RegExp(r'(\d+)D').firstMatch(value);
    if (days != null) {
      minutes += (int.tryParse(days.group(1)!) ?? 0) * 24 * 60;
    }

    // Часы: PT1H
    final hours = RegExp(r'(\d+)H').firstMatch(value);
    if (hours != null) {
      minutes += (int.tryParse(hours.group(1)!) ?? 0) * 60;
    }

    // Минуты: PT30M
    final mins = RegExp(r'(\d+)M').firstMatch(value);
    if (mins != null) {
      minutes += int.tryParse(mins.group(1)!) ?? 0;
    }

    return minutes > 0 ? minutes : 60;
  }

  /// Конвертирует ICS RRULE (значение после `RRULE:`) в строку правила в формате
  /// приложения (см. lib/features/plan/recurrence.dart). Возвращает null, если
  /// правило невозможно представить моделью приложения — тогда событие
  /// импортируется без повтора (базовое событие не теряется).
  ///
  /// Поддержано: FREQ=DAILY/WEEKLY/MONTHLY, BYDAY (MO..SU без позиционных
  /// префиксов), BYMONTHDAY (одно число 1..31), UNTIL (→ YYYY-MM-DD).
  /// НЕ поддержано (→ null): FREQ=YEARLY/HOURLY/…, INTERVAL>1, COUNT,
  /// позиционный BYDAY (2MO, -1SU), множественный BYMONTHDAY.
  static String? _convertRrule(String rrule) {
    String? freq;
    String? until;
    bool hadUntil = false;
    final byDay = <String>[];
    int? byMonthDay;

    for (final part in rrule.split(';')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = part.substring(eq + 1).trim();
      switch (key) {
        case 'FREQ':
          freq = value.toUpperCase();
        case 'INTERVAL':
          final n = int.tryParse(value);
          // Приложение умеет только шаг 1 (каждый день/неделю/месяц).
          if (n != null && n != 1) return null;
        case 'COUNT':
          // Нет аналога COUNT в модели приложения — не искажаем семантику.
          return null;
        case 'UNTIL':
          hadUntil = true;
          until = _convertUntil(value);
        case 'BYDAY':
          for (final tok in value.split(',')) {
            final t = tok.trim().toUpperCase();
            // Позиционные префиксы (2MO, -1SU) приложение не умеет.
            if (!_weekdayTokens.contains(t)) return null;
            byDay.add(t);
          }
        case 'BYMONTHDAY':
          final parts = value.split(',');
          if (parts.length != 1) return null;
          final n = int.tryParse(parts.first.trim());
          if (n == null || n < 1 || n > 31) return null;
          byMonthDay = n;
      }
    }

    // UNTIL присутствовал, но не распарсился — не превращаем ограниченную серию
    // в бесконечную, лучше отбросить правило целиком.
    if (hadUntil && until == null) return null;

    if (freq != 'DAILY' && freq != 'WEEKLY' && freq != 'MONTHLY') return null;

    final sb = StringBuffer('FREQ=$freq');
    if (freq == 'WEEKLY' && byDay.isNotEmpty) {
      sb.write(';BYDAY=${byDay.join(',')}');
    }
    if (freq == 'MONTHLY' && byMonthDay != null) {
      sb.write(';BYMONTHDAY=$byMonthDay');
    }
    if (until != null) {
      sb.write(';UNTIL=$until');
    }
    return sb.toString();
  }

  static const _weekdayTokens = {'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'};

  /// Конвертирует ICS UNTIL (YYYYMMDD или YYYYMMDDTHHMMSS[Z]) → YYYY-MM-DD.
  /// null при неверном формате.
  static String? _convertUntil(String value) {
    final clean = value.replaceAll('Z', '');
    if (clean.length < 8) return null;
    final y = clean.substring(0, 4);
    final m = clean.substring(4, 6);
    final d = clean.substring(6, 8);
    if (int.tryParse(y) == null ||
        int.tryParse(m) == null ||
        int.tryParse(d) == null) {
      return null;
    }
    return '$y-$m-$d';
  }
}
