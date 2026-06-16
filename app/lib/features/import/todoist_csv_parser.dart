// Парсер CSV-экспорта из Todoist (Settings → Backups / Export).
// Колонки: TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE,DATE_LANG,TIMEZONE
// Импортируем только строки с TYPE == "task".

/// Одна задача из Todoist CSV
class TodoistTask {
  const TodoistTask({
    required this.content,
    required this.date,
    required this.priority,
  });

  /// Заголовок задачи (поле CONTENT)
  final String content;

  /// Дата выполнения ("2024-06-17", "Jun 17 2024") или null
  final String? date;

  /// Приоритет: "1"=urgent→main, "2"=high→medium, "3"/"4"=low
  final String priority;
}

/// Парсер Todoist CSV
class TodoistCsvParser {
  /// Разбирает строку содержимого CSV и возвращает список задач.
  /// Поддерживает поля в кавычках с запятыми внутри.
  static List<TodoistTask> parse(String csvContent) {
    final tasks = <TodoistTask>[];

    // Нормализуем переносы строк
    final lines = csvContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    if (lines.isEmpty) return tasks;

    // Первая строка — заголовок, парсим индексы колонок
    final headers = _parseCsvRow(lines[0]);
    final typeIdx = _indexOf(headers, 'TYPE');
    final contentIdx = _indexOf(headers, 'CONTENT');
    final priorityIdx = _indexOf(headers, 'PRIORITY');
    final dateIdx = _indexOf(headers, 'DATE');

    // Если обязательных колонок нет — возвращаем пустой список
    if (typeIdx < 0 || contentIdx < 0) return tasks;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvRow(line);
      if (cols.length <= contentIdx) continue;

      // Импортируем только задачи
      if (typeIdx < cols.length && cols[typeIdx].toLowerCase() != 'task') {
        continue;
      }

      final content = contentIdx < cols.length ? cols[contentIdx].trim() : '';
      if (content.isEmpty) continue;

      final priority = priorityIdx < cols.length
          ? cols[priorityIdx].trim()
          : '4';

      final date = dateIdx < cols.length ? cols[dateIdx].trim() : '';

      tasks.add(TodoistTask(
        content: content,
        date: date.isEmpty ? null : date,
        priority: priority,
      ));
    }

    return tasks;
  }

  /// Находит индекс колонки по имени (регистронезависимо), -1 если нет
  static int _indexOf(List<String> headers, String name) {
    final lower = name.toLowerCase();
    for (int i = 0; i < headers.length; i++) {
      if (headers[i].trim().toLowerCase() == lower) return i;
    }
    return -1;
  }

  /// Парсит одну строку CSV с учётом полей в двойных кавычках.
  /// Поддерживает: запятые внутри кавычек, экранированные кавычки ("").
  static List<String> _parseCsvRow(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (inQuotes) {
        if (ch == '"') {
          // Проверяем: экранированная кавычка "" или конец поля
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // пропускаем вторую кавычку
          } else {
            inQuotes = false; // конец закавыченного поля
          }
        } else {
          buffer.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          fields.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(ch);
        }
      }
    }

    fields.add(buffer.toString()); // последнее поле
    return fields;
  }

  /// Конвертирует приоритет Todoist в приоритет Kaizen.
  /// Todoist: 1=urgent, 2=high, 3=medium, 4=low (в CSV: "1"..."4")
  static String mapPriority(String todoistPriority) {
    switch (todoistPriority) {
      case '1':
        return 'main';
      case '2':
        return 'medium';
      default:
        return 'low';
    }
  }

  /// Парсит строку даты из Todoist в DateTime или null.
  /// Форматы: "2024-06-17", "Jun 17 2024", "June 17 2024 @ 09:00"
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    // ISO-формат: 2024-06-17
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final isoMatch = iso.firstMatch(dateStr);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      return DateTime(year, month, day, 9, 0);
    }

    // Формат "Jun 17 2024" или "June 17 2024"
    final named = RegExp(
      r'^(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
      r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)'
      r'\s+(\d{1,2})\s+(\d{4})',
      caseSensitive: false,
    );
    final namedMatch = named.firstMatch(dateStr);
    if (namedMatch != null) {
      final monthName = namedMatch.group(1)!.toLowerCase();
      final day = int.parse(namedMatch.group(2)!);
      final year = int.parse(namedMatch.group(3)!);
      final month = _monthFromName(monthName);
      if (month > 0) return DateTime(year, month, day, 9, 0);
    }

    return null;
  }

  static int _monthFromName(String name) {
    const months = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    return months[name.toLowerCase()] ?? 0;
  }
}
