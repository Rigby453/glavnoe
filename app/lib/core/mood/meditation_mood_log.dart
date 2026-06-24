// Лёгкое хранилище настроения после медитации.
//
// НАМЕРЕННО не использует Drift — чтобы избежать миграции схемы.
// Данные хранятся в SharedPreferences как append-only JSON-список
// под ключом 'meditation_mood_logs'.
//
// Запись ПОЛНОСТЬЮ независима от DayLogsTable.mood (дневник).
// Дневник управляет своим mood отдельно через DayLogsDao.saveForDate —
// этот модуль его НИКОГДА не трогает.
//
// TODO(analytics): когда появится отдельная таблица или аналитика-модуль,
// перенести записи отсюда в Drift (схема: id, session_id, mood 1-5,
// note TEXT?, logged_at DATETIME). На чтение-запись SheetUI — достаточно.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kPrefsKey = 'meditation_mood_logs';

/// Одна запись настроения после медитационной сессии.
class MeditationMoodEntry {
  const MeditationMoodEntry({
    required this.sessionId,
    required this.mood,
    required this.loggedAt,
    this.note,
  });

  /// ID сессии медитации (например 'body_scan').
  final String sessionId;

  /// Настроение 1..5 (совпадает с эмодзи-шкалой дневника).
  final int mood;

  /// Необязательная заметка.
  final String? note;

  /// Момент завершения сессии.
  final DateTime loggedAt;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'mood': mood,
        if (note != null && note!.isNotEmpty) 'note': note,
        'logged_at': loggedAt.toIso8601String(),
      };

  factory MeditationMoodEntry.fromJson(Map<String, dynamic> json) =>
      MeditationMoodEntry(
        sessionId: json['session_id'] as String,
        mood: (json['mood'] as num).toInt(),
        note: json['note'] as String?,
        loggedAt: DateTime.parse(json['logged_at'] as String),
      );
}

/// Добавить запись настроения в список.
/// Вызывается один раз при нажатии «Done» в диалоге завершения медитации.
///
/// [prefs] — SharedPreferences, полученный через sharedPreferencesProvider.
/// Дневник ([DayLogsTable.mood]) остаётся неизменным.
Future<void> appendMeditationMood(
  SharedPreferences prefs,
  MeditationMoodEntry entry,
) async {
  final raw = prefs.getString(_kPrefsKey);
  final List<dynamic> list = raw != null ? jsonDecode(raw) as List<dynamic> : [];
  list.add(entry.toJson());
  await prefs.setString(_kPrefsKey, jsonEncode(list));
}

/// Прочитать все записи (для аналитики / будущего экрана истории).
List<MeditationMoodEntry> readMeditationMoodLogs(SharedPreferences prefs) {
  final raw = prefs.getString(_kPrefsKey);
  if (raw == null) return const [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MeditationMoodEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Повреждённые данные → возвращаем пустой список (никогда не крашим).
    return const [];
  }
}
