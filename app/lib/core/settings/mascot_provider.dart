// Riverpod-провайдер видимости маскота Kai.
// Значение по умолчанию: true (показывать).
// Сохраняется в SharedPreferences под ключом 'show_kai'.
// Паттерн скопирован с tone_provider.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kShowKaiKey = 'show_kai';

class ShowKaiNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Если ключ не задан — показываем по умолчанию
    return ref.read(sharedPreferencesProvider).getBool(_kShowKaiKey) ?? true;
  }

  /// Переключить текущее состояние
  Future<void> toggle() => set(!state);

  /// Установить явное значение и сохранить в SharedPreferences
  Future<void> set(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kShowKaiKey, value);
    state = value;
  }
}

/// Показывать ли маскота Kai. По умолчанию true.
final showKaiProvider =
    NotifierProvider<ShowKaiNotifier, bool>(ShowKaiNotifier.new);
