// Провайдер тумблера «Напоминания об осанке» (выпрямись).
// Извлечён из posture_screen.dart, чтобы тумблер был доступен из Профиля
// даже когда сам экран /posture убран из навигации (SPEC C5 Ф2, задача 7 эпика).
//
// Паттерн — sound_provider.dart / swipe_hint_provider.dart:
// Notifier + NotifierProvider, хранение в SharedPreferences.
//
// Ключ SharedPreferences: 'posture_reminders_on' — не менять,
// иначе сбросится настройка у существующих пользователей.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../services/notifications/notification_service.dart';

/// Ключ SharedPreferences — экспортируется, чтобы posture_screen.dart
/// ссылался на ту же константу без дублирования.
const String kPostureRemindersKey = 'posture_reminders_on';

/// Notifier тумблера «выпрямись»-напоминаний.
/// При включении запрашивает разрешение и планирует уведомления;
/// при выключении — отменяет. Возвращает фактическое состояние после операции.
class PostureRemindersNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(kPostureRemindersKey) ??
      false;

  /// Включить или выключить напоминания.
  /// Возвращает фактическое новое состояние (false, если разрешение отказано).
  Future<bool> setEnabled(bool enabled) async {
    final service = ref.read(notificationServiceProvider);
    try {
      if (enabled) {
        final granted = await service.requestPermission();
        if (!granted) return false;
        await service.schedulePostureReminders();
      } else {
        await service.cancelPostureReminders();
      }
      await ref
          .read(sharedPreferencesProvider)
          .setBool(kPostureRemindersKey, enabled);
      state = enabled;
      return enabled;
    } catch (e) {
      debugPrint('[PostureReminders] setEnabled($enabled) failed: $e');
      return state;
    }
  }
}

/// Провайдер состояния тумблера «напоминания об осанке».
/// Читает/пишет SharedPreferences['posture_reminders_on'].
final postureRemindersProvider =
    NotifierProvider<PostureRemindersNotifier, bool>(
  PostureRemindersNotifier.new,
);
