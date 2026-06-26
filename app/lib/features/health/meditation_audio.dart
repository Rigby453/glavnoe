// Аудио-слой плеера медитаций (ADR-054, Phase 1 — полностью локально, без сети).
//
// Два независимых, опциональных канала, оба выключены по умолчанию, оба
// аддитивны к существующему пошаговому плееру (его таймер/шаги НЕ трогаем):
//
//   1. MeditationNarrator — озвучка текущего шага системным TTS (flutter_tts).
//      Бесплатно, без ключей и сети. На платформах, где плагина нет
//      (web/desktop без поддержки) — мягкий no-op: любая ошибка глушится.
//
//   2. MeditationAmbientPlayer — зацикленный фоновый «коричневый шум» через
//      уже подключённый audioplayers. Ассет синтезирован детерминированно
//      (assets/audio/ambient_brown.wav, генератор tool/generate_ambient_brown.py)
//      — без лицензионных рисков. Микшируется ПОД озвучкой на своей громкости.
//
// Оба сервиса спрятаны за абстракциями + Riverpod-провайдерами, чтобы в тестах
// их можно было заменить no-op фейками (платформенные каналы не дёргаются).

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ---------------------------------------------------------------------------
// Ключи настроек (SharedPreferences). Дефолты: всё выключено, эмбиент тихий.
// ---------------------------------------------------------------------------

/// Озвучка шагов включена. По умолчанию false — ничего не меняем для тех,
/// кто привык к текстовому плееру.
const String kMeditationNarrationEnabledKey = 'meditation_narration_enabled';

/// Фоновый эмбиент включён. По умолчанию false.
const String kMeditationAmbientEnabledKey = 'meditation_ambient_enabled';

/// Громкость эмбиента (0.0–1.0). По умолчанию 0.4 — тихий фон под голосом.
const String kMeditationAmbientVolumeKey = 'meditation_ambient_volume';

/// Громкость эмбиента по умолчанию.
const double kMeditationAmbientDefaultVolume = 0.4;

// ---------------------------------------------------------------------------
// Озвучка (TTS)
// ---------------------------------------------------------------------------

/// Сервис озвучки текущего шага. Реализация может быть как реальной
/// (flutter_tts), так и no-op фейком в тестах.
abstract class MeditationNarrator {
  /// Произнести [text] на языке приложения [localeTag] ('en', 'ru', 'pt-BR'…).
  /// Прерывает предыдущую фразу. Никогда не бросает.
  Future<void> speak(String text, String localeTag);

  /// Остановить и сбросить очередь речи (pause/exit/смена шага).
  Future<void> stop();

  /// Освободить ресурсы.
  Future<void> dispose();
}

/// Маппинг тега локали приложения → BCP-47 язык для TTS-движка.
///
/// Теги приложения — короткие ('en', 'ru') либо с регионом ('pt-BR', 'es-ES').
/// TTS-движкам нужен регион, поэтому для коротких тегов подставляем
/// разумный дефолтный регион. Если движок не знает язык — вызывающий код
/// деградирует (см. [FlutterTtsNarrator.speak]).
String meditationTtsLanguage(String localeTag) {
  // Уже содержит регион ('pt-BR', 'es-ES') — используем как есть.
  if (localeTag.contains('-')) return localeTag;
  const byLanguage = <String, String>{
    'en': 'en-US',
    'ru': 'ru-RU',
    'de': 'de-DE',
    'fr': 'fr-FR',
    'it': 'it-IT',
    'pt': 'pt-BR',
    'id': 'id-ID',
    'hi': 'hi-IN',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'es': 'es-ES',
  };
  return byLanguage[localeTag] ?? localeTag;
}

/// Реальная озвучка через системный TTS. Полностью обёрнута в try/catch:
/// на web/desktop без плагина или при любой платформенной ошибке — no-op.
class FlutterTtsNarrator implements MeditationNarrator {
  FlutterTtsNarrator([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _disabled = false; // плагин недоступен — больше не пытаемся
  String? _appliedLanguage; // последний успешно выставленный язык (кэш)

  @override
  Future<void> speak(String text, String localeTag) async {
    if (_disabled || text.trim().isEmpty) return;
    try {
      await _applyLanguage(localeTag);
      // Прерываем предыдущую фразу — каждый шаг начинается с чистого листа.
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      // TTS — необязательная добавка: любая ошибка не должна ломать сессию.
      _disabled = true;
      if (kDebugMode) {
        debugPrint('FlutterTtsNarrator: speak failed, disabling TTS. ($e)');
      }
    }
  }

  /// Выставить язык с мягким откатом: целевой тег → базовый язык → как есть.
  Future<void> _applyLanguage(String localeTag) async {
    final target = meditationTtsLanguage(localeTag);
    if (_appliedLanguage == target) return;
    try {
      // isLanguageAvailable возвращает dynamic (bool на iOS/Android, может быть
      // null на web) — приводим осторожно.
      final available = await _tts.isLanguageAvailable(target);
      if (available == true) {
        await _tts.setLanguage(target);
      } else {
        // Пробуем базовый язык без региона ('ru-RU' → 'ru').
        final base = target.split('-').first;
        await _tts.setLanguage(base);
      }
    } catch (_) {
      // Не удалось проверить/выставить — просто пробуем целевой и идём дальше.
      try {
        await _tts.setLanguage(target);
      } catch (_) {/* оставляем язык движка по умолчанию */}
    }
    _appliedLanguage = target;
  }

  @override
  Future<void> stop() async {
    if (_disabled) return;
    try {
      await _tts.stop();
    } catch (_) {/* no-op */}
  }

  @override
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {/* no-op */}
  }
}

/// No-op озвучка — для тестов и платформ, где TTS отключён.
class SilentMeditationNarrator implements MeditationNarrator {
  const SilentMeditationNarrator();
  @override
  Future<void> speak(String text, String localeTag) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Фоновый эмбиент (зацикленный шум)
// ---------------------------------------------------------------------------

/// Зацикленный фоновый эмбиент с регулируемой громкостью.
abstract class MeditationAmbientPlayer {
  /// Запустить луп на громкости [volume] (0.0–1.0). Идемпотентно.
  Future<void> start(double volume);

  /// Поменять громкость на лету.
  Future<void> setVolume(double volume);

  /// Остановить воспроизведение (pause/exit/выключение тумблера).
  Future<void> stop();

  /// Освободить ресурсы.
  Future<void> dispose();
}

/// Путь к ассету эмбиента. audioplayers/AssetSource ожидает путь БЕЗ
/// префикса 'assets/'.
const String kAmbientBrownNoiseAsset = 'audio/ambient_brown.wav';

/// Реальный эмбиент через audioplayers (ReleaseMode.loop). Любая платформенная
/// ошибка глушится — деградирует в тишину, не ломая сессию.
class BrownNoiseAmbientPlayer implements MeditationAmbientPlayer {
  BrownNoiseAmbientPlayer([AudioPlayer? player])
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _playing = false;
  bool _disabled = false;

  @override
  Future<void> start(double volume) async {
    if (_disabled) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      if (_playing) {
        await _player.setVolume(volume.clamp(0.0, 1.0));
        return;
      }
      await _player.play(
        AssetSource(kAmbientBrownNoiseAsset),
        volume: volume.clamp(0.0, 1.0),
      );
      _playing = true;
    } catch (e) {
      _disabled = true;
      if (kDebugMode) {
        debugPrint('BrownNoiseAmbientPlayer: start failed, disabling. ($e)');
      }
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_disabled || !_playing) return;
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {/* no-op */}
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    try {
      await _player.stop();
    } catch (_) {/* no-op */}
    _playing = false;
  }

  @override
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {/* no-op */}
    _playing = false;
  }
}

/// No-op эмбиент — для тестов и платформ без аудио.
class SilentMeditationAmbientPlayer implements MeditationAmbientPlayer {
  const SilentMeditationAmbientPlayer();
  @override
  Future<void> start(double volume) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Провайдеры — точка инъекции. В тестах переопределяются на Silent*-фейки,
// чтобы не дёргать платформенные каналы flutter_tts/audioplayers.
// ---------------------------------------------------------------------------

/// Фабрика озвучки. Каждый плеер создаёт свой экземпляр (autoDispose не нужен —
/// фабрика лёгкая; реальный ресурс создаётся внутри сервиса лениво).
final meditationNarratorProvider = Provider<MeditationNarrator>(
  (ref) => FlutterTtsNarrator(),
);

/// Фабрика фонового эмбиента.
final meditationAmbientPlayerProvider = Provider<MeditationAmbientPlayer>(
  (ref) => BrownNoiseAmbientPlayer(),
);
