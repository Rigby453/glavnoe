// Парсер iCalendar (.ics) файлов.
// Поддерживает экспорт из Google Calendar, Apple Calendar, Outlook.
// Используется в ImportSheet для импорта событий по дате.

/// Одно событие из ICS-файла
class IcsEvent {
  const IcsEvent({
    required this.summary,
    required this.dtStart,
    required this.durationMinutes,
  });

  /// Заголовок события (поле SUMMARY)
  final String summary;

  /// Время начала в локальном времени (null = не удалось распарсить)
  final DateTime? dtStart;

  /// Длительность в минутах (вычислено из DTEND - DTSTART или DURATION; по умолчанию 60)
  final int durationMinutes;
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

    for (final line in lines) {
      // Убираем параметры типа DTSTART;TZID=America/New_York: → берём только значение
      if (line.startsWith('SUMMARY:') || line.startsWith('SUMMARY;')) {
        summary = _extractValue(line);
      } else if (line.startsWith('DTSTART') ) {
        dtStart = _parseDateTime(line);
      } else if (line.startsWith('DTEND')) {
        dtEnd = _parseDateTime(line);
      } else if (line.startsWith('DURATION:')) {
        final val = _extractValue(line);
        durationMinutes = _parseDuration(val);
      }
    }

    // Пропускаем события без заголовка
    if (summary == null || summary.isEmpty) return null;

    // Вычисляем длительность
    int dur = 60; // по умолчанию
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
    );
  }

  /// Извлекает значение из строки вида "KEY:value" или "KEY;params:value"
  static String _extractValue(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx < 0) return '';
    return line.substring(colonIdx + 1).trim();
  }

  /// Парсит DTSTART/DTEND строку в DateTime (локальное время)
  /// Форматы:
  ///   20240617T090000Z   — UTC
  ///   20240617T090000    — локальное
  ///   20240617           — весь день → 09:00 локальное
  static DateTime? _parseDateTime(String line) {
    final value = _extractValue(line);
    final isUtc = value.endsWith('Z');
    final clean = value.replaceAll('Z', '');

    if (clean.length == 8) {
      // Формат даты: YYYYMMDD (весь день) → 09:00 локальное
      final year = int.tryParse(clean.substring(0, 4));
      final month = int.tryParse(clean.substring(4, 6));
      final day = int.tryParse(clean.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      return DateTime(year, month, day, 9, 0);
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
  static int _parseDuration(String value) {
    int minutes = 0;

    // Дни: P1D
    final days = RegExp(r'(\d+)D').firstMatch(value);
    if (days != null) {
      minutes += int.parse(days.group(1)!) * 24 * 60;
    }

    // Часы: PT1H
    final hours = RegExp(r'(\d+)H').firstMatch(value);
    if (hours != null) {
      minutes += int.parse(hours.group(1)!) * 60;
    }

    // Минуты: PT30M
    final mins = RegExp(r'(\d+)M').firstMatch(value);
    if (mins != null) {
      minutes += int.parse(mins.group(1)!);
    }

    return minutes > 0 ? minutes : 60;
  }
}
