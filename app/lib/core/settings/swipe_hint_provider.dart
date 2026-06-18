// Флаг «пользователь уже видел подсказку свайпа».
// Хранится в SharedPreferences под ключом 'seen_swipe_hint'.
// Значение по умолчанию: false — показываем нёдж один раз при первом появлении списка задач.
// Паттерн идентичен mascot_provider.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kSeenSwipeHintKey = 'seen_swipe_hint';

class SwipeHintNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(sharedPreferencesProvider).getBool(_kSeenSwipeHintKey) ??
        false;
  }

  /// Отмечаем подсказку показанной и сохраняем в SharedPreferences.
  Future<void> markSeen() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kSeenSwipeHintKey, true);
    state = true;
  }
}

/// true = пользователь уже видел подсказку свайпа; false = нужно показать.
final swipeHintSeenProvider =
    NotifierProvider<SwipeHintNotifier, bool>(SwipeHintNotifier.new);
