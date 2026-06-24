// Регрессионные тесты для appendMeditationMood / readMeditationMoodLogs.
//
// Покрываемые сценарии:
//  1. Пустые prefs → запись добавляется, читается корректно.
//  2. Существующий валидный список → новая запись добавляется в конец.
//  3. Повреждённая строка (не-JSON) → appendMeditationMood не бросает,
//     сбрасывает до [] и добавляет новую запись.
//  4. JSON-объект вместо массива (root cause «pos 12») → аналогично п. 3.
//  5. JSON-null → аналогично п. 3.
//  6. readMeditationMoodLogs с повреждёнными данными → [] без исключения.
//  7. Запись с note → поле сохраняется и читается.
//  8. Запись без note (note=null) → поле отсутствует в JSON, fromJson не падает.

import 'package:app/core/mood/meditation_mood_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> getPrefs() => SharedPreferences.getInstance();

  // Вспомогательная фабрика записи.
  MeditationMoodEntry makeEntry({
    String sessionId = 'body_scan',
    int mood = 3,
    String? note,
  }) {
    return MeditationMoodEntry(
      sessionId: sessionId,
      mood: mood,
      note: note,
      loggedAt: DateTime.utc(2026, 6, 24, 10),
    );
  }

  // -------------------------------------------------------------------------
  // 1. Пустые prefs — первая запись
  // -------------------------------------------------------------------------

  test('append to empty prefs stores one entry, read returns it', () async {
    final prefs = await getPrefs();

    await appendMeditationMood(prefs, makeEntry(mood: 4));

    final logs = readMeditationMoodLogs(prefs);
    expect(logs, hasLength(1));
    expect(logs.first.sessionId, 'body_scan');
    expect(logs.first.mood, 4);
    expect(logs.first.note, isNull);
  });

  // -------------------------------------------------------------------------
  // 2. Существующий валидный список — добавление в конец
  // -------------------------------------------------------------------------

  test('append second entry adds to existing list', () async {
    final prefs = await getPrefs();

    await appendMeditationMood(prefs, makeEntry(sessionId: 'focus_reset', mood: 2));
    await appendMeditationMood(prefs, makeEntry(sessionId: 'exam_calm', mood: 5));

    final logs = readMeditationMoodLogs(prefs);
    expect(logs, hasLength(2));
    expect(logs[0].sessionId, 'focus_reset');
    expect(logs[0].mood, 2);
    expect(logs[1].sessionId, 'exam_calm');
    expect(logs[1].mood, 5);
  });

  // -------------------------------------------------------------------------
  // 3. Повреждённая строка (не-JSON) → не бросает, сбрасывает и добавляет
  // -------------------------------------------------------------------------

  test('append with corrupted prefs value does not throw and stores entry',
      () async {
    final prefs = await getPrefs();
    // Вручную кладём невалидный JSON (имитация повреждения).
    await prefs.setString('meditation_mood_logs', 'NOT_VALID_JSON!!');

    // Не должно бросать FormatException.
    await expectLater(
      appendMeditationMood(prefs, makeEntry(mood: 1)),
      completes,
    );

    final logs = readMeditationMoodLogs(prefs);
    // Старый мусор сброшен, новая запись доступна.
    expect(logs, hasLength(1));
    expect(logs.first.mood, 1);
  });

  // -------------------------------------------------------------------------
  // 4. JSON-объект вместо массива — root cause «pos 12»
  //    Если под ключом хранится одиночный JSON-объект (не обёрнутый в []),
  //    jsonDecode успевает распарсить его как Map, но «as List<dynamic>» раньше
  //    (до фикса) бросало _CastError. Проверяем, что фикс устраняет краш.
  // -------------------------------------------------------------------------

  test('append when prefs contains a bare JSON object (not array) — no throw',
      () async {
    final prefs = await getPrefs();
    // Одиночный объект — не массив.
    await prefs.setString(
      'meditation_mood_logs',
      '{"session_id":"body_scan","mood":3,"logged_at":"2026-06-24T10:00:00.000"}',
    );

    await expectLater(
      appendMeditationMood(prefs, makeEntry(mood: 5)),
      completes,
    );

    final logs = readMeditationMoodLogs(prefs);
    // Старый одиночный объект сброшен, добавлен только новый.
    expect(logs, hasLength(1));
    expect(logs.first.mood, 5);
  });

  // -------------------------------------------------------------------------
  // 5. JSON-null под ключом → не бросает
  // -------------------------------------------------------------------------

  test('append when prefs contains JSON null — no throw', () async {
    final prefs = await getPrefs();
    await prefs.setString('meditation_mood_logs', 'null');

    await expectLater(
      appendMeditationMood(prefs, makeEntry(mood: 2)),
      completes,
    );

    final logs = readMeditationMoodLogs(prefs);
    expect(logs, hasLength(1));
  });

  // -------------------------------------------------------------------------
  // 6. readMeditationMoodLogs с повреждёнными данными → [] без исключения
  // -------------------------------------------------------------------------

  test('read with corrupted data returns empty list without throwing', () async {
    final prefs = await getPrefs();
    await prefs.setString('meditation_mood_logs', 'GARBAGE');

    expect(() => readMeditationMoodLogs(prefs), returnsNormally);
    expect(readMeditationMoodLogs(prefs), isEmpty);
  });

  // -------------------------------------------------------------------------
  // 7. Запись с заметкой
  // -------------------------------------------------------------------------

  test('entry with note is persisted and read back correctly', () async {
    final prefs = await getPrefs();

    await appendMeditationMood(
      prefs,
      makeEntry(mood: 4, note: 'Felt calm and focused'),
    );

    final logs = readMeditationMoodLogs(prefs);
    expect(logs, hasLength(1));
    expect(logs.first.note, 'Felt calm and focused');
  });

  // -------------------------------------------------------------------------
  // 8. Запись без заметки (note=null) → fromJson не падает
  // -------------------------------------------------------------------------

  test('entry without note serializes and deserializes correctly', () async {
    final prefs = await getPrefs();

    await appendMeditationMood(prefs, makeEntry(mood: 3, note: null));

    final logs = readMeditationMoodLogs(prefs);
    expect(logs, hasLength(1));
    expect(logs.first.note, isNull);
  });

  // -------------------------------------------------------------------------
  // 9. Пустая строка note обрезается до null при сохранении
  //    (логика в _showCompletionDialog: trim().isEmpty → null)
  // -------------------------------------------------------------------------

  test('MeditationMoodEntry toJson omits note when null', () {
    final entry = makeEntry(note: null);
    final json = entry.toJson();
    expect(json.containsKey('note'), isFalse);
  });

  test('MeditationMoodEntry toJson omits note when empty', () {
    // Имитируем логику диалога: trim().isEmpty → передаём null
    final note = '   '.trim().isEmpty ? null : '   '.trim();
    final entry = makeEntry(note: note);
    final json = entry.toJson();
    expect(json.containsKey('note'), isFalse);
  });

  // -------------------------------------------------------------------------
  // 10. fromJson валиден для записей без поля 'note' в JSON
  // -------------------------------------------------------------------------

  test('fromJson handles missing note field gracefully', () {
    final json = {
      'session_id': 'sleep_prep',
      'mood': 5,
      'logged_at': '2026-06-24T22:00:00.000',
      // 'note' отсутствует намеренно
    };

    expect(
      () => MeditationMoodEntry.fromJson(json),
      returnsNormally,
    );

    final entry = MeditationMoodEntry.fromJson(json);
    expect(entry.note, isNull);
    expect(entry.mood, 5);
  });
}
