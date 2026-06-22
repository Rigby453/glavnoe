// Riverpod-провайдер настройки «звук при выполнении задачи».
// Значение по умолчанию: true (звук включён).
// Сохраняется в SharedPreferences под ключом 'completion_sound_enabled'.
// Паттерн скопирован с mascot_provider.dart / swipe_hint_provider.dart.
//
// ВАЖНО: ключ намеренно совпадает с константой
// CompletionSoundService.prefsKey — сервис звука читает ТУ ЖЕ настройку
// напрямую из SharedPreferences (без Riverpod), потому что вызывается из
// слоя данных (items_dao). Единый источник истины для имени ключа — здесь.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

/// Ключ настройки в SharedPreferences. Экспортируется, чтобы сервис звука
/// (CompletionSoundService) использовал ровно тот же ключ.
const String kCompletionSoundEnabledKey = 'completion_sound_enabled';

class CompletionSoundNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Если ключ не задан — звук включён по умолчанию.
    return ref
            .read(sharedPreferencesProvider)
            .getBool(kCompletionSoundEnabledKey) ??
        true;
  }

  /// Переключить текущее состояние.
  Future<void> toggle() => set(!state);

  /// Установить явное значение и сохранить в SharedPreferences.
  Future<void> set(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kCompletionSoundEnabledKey, value);
    state = value;
  }
}

/// Проигрывать ли короткий звук при выполнении задачи. По умолчанию true.
final completionSoundEnabledProvider =
    NotifierProvider<CompletionSoundNotifier, bool>(
  CompletionSoundNotifier.new,
);
