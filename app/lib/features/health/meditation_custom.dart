// Кодек пользовательских медитативных сессий — чистый файл без зависимостей на
// Flutter/Drift. Преобразует список шагов (List<MeditationStep>) в JSON-строку
// для хранения в БД и обратно. Юнит-тестируется напрямую.
//
// Формат JSON: массив объектов шагов
//   [{ "text": "Breathe slowly", "seconds": 60 }, ...]
// Порядок шагов сохраняется. Любой невалидный JSON (битый, не-массив, не-объекты)
// безопасно деградирует в ПУСТОЙ список — вызывающий код сам решает, что делать
// (обычно — игнорировать сессию без шагов).
//
// ВАЖНО: text — это СЫРОЙ пользовательский текст (данные), а не l10n-ключ.
// Он показывается пользователю как есть и НЕ переводится (это его контент).

import 'dart:convert';

/// Один шаг пользовательской медитации: инструкция (сырой текст) + длительность.
class MeditationStep {
  const MeditationStep({required this.text, required this.seconds});

  /// Сырой пользовательский текст инструкции (НЕ l10n-ключ).
  final String text;

  /// Длительность шага в секундах (> 0).
  final int seconds;
}

/// Кодирует список шагов в компактную JSON-строку.
/// Сохраняем text (инструкция) и seconds (длительность) в исходном порядке.
String encodeSteps(List<MeditationStep> steps) {
  final list = steps
      .map((s) => <String, Object?>{
            'text': s.text,
            'seconds': s.seconds,
          })
      .toList();
  return jsonEncode(list);
}

/// Декодирует JSON-строку в список шагов.
///
/// Контракт безопасности: при любой ошибке (битый JSON, не-массив, элемент не
/// объект, отсутствует/невалидный text или seconds) возвращает ПУСТОЙ список,
/// а не бросает исключение. Невалидные отдельные элементы пропускаются, валидные
/// сохраняются (с сохранением исходного порядка). Шаги с пустым текстом или
/// неположительной длительностью отбрасываются.
List<MeditationStep> decodeSteps(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    final out = <MeditationStep>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final text = item['text'];
      final seconds = item['seconds'];
      if (text is! String || text.trim().isEmpty) continue;
      if (seconds is! num) continue;
      final secs = seconds.toInt();
      if (secs <= 0) continue;
      out.add(MeditationStep(text: text, seconds: secs));
    }
    return out;
  } catch (_) {
    // Любая ошибка парсинга → безопасный дефолт.
    return const [];
  }
}
