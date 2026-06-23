// Сервис короткого звука «задача выполнена».
//
// Зачем отдельный сервис и почему он читает настройку сам:
//   Завершение задачи инициируется из РАЗНЫХ мест UI (свайп вправо в
//   task_list.dart, тап-чекбокс в task_detail_card.dart) и всегда проходит
//   через слой данных — ItemsDao.markDone / materializeOccurrence(status:done).
//   Чтобы звук срабатывал на ВСЕХ путях завершения (и свайп, и тап), хук
//   стоит именно в DAO. Но DAO — слой данных, тащить туда Riverpod нельзя.
//   Поэтому сервис — статический синглтон, читающий настройку
//   'completion_sound_enabled' напрямую из SharedPreferences.
//
// Воспроизведение:
//   1. Если в ассетах лежит assets/sounds/task_done.mp3 — играем его через
//      audioplayers (короткий приятный звук, один и тот же AudioPlayer
//      переиспользуется — без утечек).
//   2. Если ассета нет ИЛИ воспроизведение упало (например, файл ещё не
//      добавлен в репозиторий) — мягкий fallback на системный клик
//      SystemSound.play(SystemSoundType.click).
//   Как только бинарный файл task_done.mp3 появится в assets/sounds/ и будет
//   зарегистрирован в pubspec — код заиграет его без изменений.
//
// Идемпотентность: единственный экземпляр AudioPlayer, никаких новых
// плееров на каждый вызов. dispose() освобождает ресурсы (вызывать при
// завершении приложения, опционально).

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/sound_provider.dart' show kCompletionSoundEnabledKey;

/// Путь к ассету звука завершения (относительно корня пакета).
/// audioplayers через AssetSource ожидает путь БЕЗ префикса 'assets/'.
/// Сейчас лежит короткий синтезированный «дзинь» task_done.wav (0.6с, колокольный
/// тембр E6→B6). Если заменишь на свой звук — поправь имя/расширение здесь.
const String _kCompletionSoundAsset = 'sounds/task_done.wav';

class CompletionSoundService {
  CompletionSoundService._();

  /// Единственный экземпляр (синглтон).
  static final CompletionSoundService instance = CompletionSoundService._();

  /// Один переиспользуемый плеер — без утечек и без пересоздания на каждый
  /// вызов. Создаётся лениво при первом проигрывании.
  AudioPlayer? _player;

  /// Если ассет не найден один раз — больше не пытаемся его грузить,
  /// сразу идём в системный fallback (без лишних исключений в логах).
  bool _assetMissing = false;

  /// Проиграть звук завершения, ЕСЛИ настройка включена.
  ///
  /// Идемпотентно по отношению к состоянию плеера: при наложении вызовов
  /// текущее воспроизведение прерывается и стартует заново (stop → play),
  /// новые плееры не плодятся.
  ///
  /// [prefs] можно передать заранее (микрооптимизация для горячего пути),
  /// иначе берётся через SharedPreferences.getInstance().
  Future<void> playIfEnabled({SharedPreferences? prefs}) async {
    // На web звук тоже работает (audioplayers поддерживает web), но обёрнут
    // в try/catch ниже — любая платформенная ошибка деградирует в no-op.
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final enabled = sp.getBool(kCompletionSoundEnabledKey) ?? true;
      if (!enabled) return;
      await _play();
    } catch (e) {
      // Звук — необязательный эффект: никогда не должен ломать завершение
      // задачи. Глушим любую ошибку.
      if (kDebugMode) {
        debugPrint('CompletionSoundService: playback failed: $e');
      }
    }
  }

  Future<void> _play() async {
    // Пытаемся проиграть бинарный ассет, если он есть.
    if (!_assetMissing) {
      try {
        final player = _player ??= AudioPlayer();
        // Прерываем возможное предыдущее воспроизведение (идемпотентность).
        await player.stop();
        await player.play(AssetSource(_kCompletionSoundAsset));
        return;
      } catch (e) {
        // Скорее всего ассет ещё не добавлен в репозиторий — переключаемся
        // на системный звук и больше не дёргаем audioplayers.
        _assetMissing = true;
        if (kDebugMode) {
          debugPrint(
            'CompletionSoundService: asset "$_kCompletionSoundAsset" '
            'unavailable, falling back to SystemSound. ($e)',
          );
        }
      }
    }
    // Fallback: системный короткий клик. Доступен на iOS/Android; на web и
    // некоторых платформах может быть no-op — это допустимо.
    await SystemSound.play(SystemSoundType.click);
  }

  /// Освободить ресурсы плеера. Опционально (например, при завершении app).
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
