// Локальные уведомления Kaizen: напоминания об утреннем и вечернем разборе
// (SPEC C3 — «по расписанию (вечером)»). Только клиент, без бэкенда.
// Inexact-планирование (без разрешения SCHEDULE_EXACT_ALARM); время — ежедневно
// в фиксированные часы (matchDateTimeComponents: time). Перепланируется при
// каждом запуске приложения (если включено).

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/settings/timezone_provider.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider

const int _kMorningId = 1001;
const int _kEveningId = 1002;
const int kMorningHour = 8;
const int kEveningHour = 20;

class NotificationService {
  /// [overrideTzGetter] возвращает выбранный пользователем IANA-таймзон
  /// (или null/пусто = авто/зона устройства). Передаётся провайдером, который
  /// читает SharedPreferences. Если не задан — поведение по умолчанию (авто).
  NotificationService(this._plugin, {String? Function()? overrideTzGetter})
      : _overrideTzGetter = overrideTzGetter; // ignore: prefer_initializing_formals

  final FlutterLocalNotificationsPlugin _plugin;
  final String? Function()? _overrideTzGetter;
  bool _inited = false;

  Future<void> init() async {
    if (_inited || kIsWeb) return;
    tzdata.initializeTimeZones();
    await _applyLocalTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _inited = true;
  }

  /// Устанавливает tz.local в эффективную зону: выбранный override, если он
  /// задан и валиден, иначе — зону устройства. При ошибке остаётся UTC
  /// (часы сместятся, но приложение не упадёт).
  Future<void> _applyLocalTimezone() async {
    // 1. Override пользователя имеет приоритет.
    final override = locationFromOverride(_overrideTzGetter?.call());
    if (override != null) {
      tz.setLocalLocation(override);
      return;
    }
    // 2. Авто — зона устройства (прежнее поведение).
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Запасной вариант — UTC.
    }
  }

  /// Перечитывает эффективную зону и применяет её к tz.local.
  /// Вызывать при смене настройки таймзона — после этого нужно перепланировать
  /// уведомления (zonedSchedule считает время от tz.local в момент планирования).
  Future<void> refreshTimezone() async {
    if (kIsWeb) return;
    await init(); // гарантирует, что база timezone инициализирована
    await _applyLocalTimezone();
  }

  /// Запрашивает разрешение на уведомления. true = выдано.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kaizen_reviews',
      'Daily reviews',
      channelDescription: 'Morning & evening planning reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Планирует ежедневные напоминания (утро/вечер). Сначала отменяет старые.
  Future<void> scheduleDailyReviews({
    int morningHour = kMorningHour,
    int eveningHour = kEveningHour,
  }) async {
    if (kIsWeb) return;
    await init();
    await cancelAll();
    await _plugin.zonedSchedule(
      id: _kMorningId,
      title: 'Plan your day',
      body: 'Carry over what slipped and protect what matters.',
      scheduledDate: _nextInstanceOf(morningHour),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    await _plugin.zonedSchedule(
      id: _kEveningId,
      title: 'Plan tomorrow',
      body: 'Two minutes now saves a panicked morning.',
      scheduledDate: _nextInstanceOf(eveningHour),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: _kMorningId);
    await _plugin.cancel(id: _kEveningId);
  }

  // ---------------------------------------------------------------------------
  // Напоминания об осанке (SPEC C5 Ф2)
  // ---------------------------------------------------------------------------

  // ID для напоминаний «выпрямись» — каждые 2 часа с 10 до 18 (5 слотов).
  static const _kPostureIds = [301, 302, 303, 304, 305];
  static const _kPostureHours = [10, 12, 14, 16, 18];

  static const _postureDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'kaizen_posture',
      'Posture reminders',
      channelDescription: 'Sit-up-straight check-ins every 2 hours',
      importance: Importance.low,
      priority: Priority.low,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Планирует 5 ежедневных напоминаний об осанке (10, 12, 14, 16, 18).
  /// Сначала отменяет старые posture-уведомления.
  Future<void> schedulePostureReminders() async {
    if (kIsWeb) return;
    await init();
    await cancelPostureReminders();
    for (var i = 0; i < _kPostureHours.length; i++) {
      await _plugin.zonedSchedule(
        id: _kPostureIds[i],
        title: 'Sit up straight',
        body: 'Quick check: shoulders relaxed, back tall.',
        scheduledDate: _nextInstanceOf(_kPostureHours[i]),
        notificationDetails: _postureDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Отменяет все posture-уведомления (не трогает утро/вечер).
  Future<void> cancelPostureReminders() async {
    if (kIsWeb) return;
    await init();
    for (final id in _kPostureIds) {
      await _plugin.cancel(id: id);
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    FlutterLocalNotificationsPlugin(),
    // Эффективная зона: override из настроек (если задан), иначе зона устройства.
    overrideTzGetter: () =>
        ref.read(sharedPreferencesProvider).getString(kTimezoneOverrideKey),
  );
});

// ---------------------------------------------------------------------------
// Флаг «уведомления включены» (prefs) + оркестрация разрешения/планирования.
// ---------------------------------------------------------------------------

const _kNotifEnabledKey = 'notifications_enabled';

class NotificationsEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNotifEnabledKey) ?? false;

  /// Включает/выключает напоминания. При включении запрашивает разрешение;
  /// если не выдано — остаётся выключенным. Возвращает фактическое состояние.
  Future<bool> setEnabled(bool enabled) async {
    final service = ref.read(notificationServiceProvider);
    try {
      if (enabled) {
        final granted = await service.requestPermission();
        if (!granted) return false; // state остаётся false
        await service.scheduleDailyReviews();
      } else {
        await service.cancelAll();
      }
      await ref
          .read(sharedPreferencesProvider)
          .setBool(_kNotifEnabledKey, enabled);
      state = enabled;
      return enabled;
    } catch (e) {
      debugPrint('[Notifications] setEnabled($enabled) failed: $e');
      return state;
    }
  }

  /// Перепланирует уже активные уведомления в текущей эффективной зоне.
  /// Вызывается при смене настройки часового пояса (timezone_provider).
  /// Перечитывает зону устройства/override, затем заново планирует разборы
  /// (если включены) и напоминания об осанке (если их тумблер активен).
  /// Часы разборов берутся из тех же ключей prefs, что и при старте
  /// (review_morning_hour / review_evening_hour — см. onboarding/setup_flow).
  Future<void> reschedule() async {
    if (kIsWeb) return;
    final service = ref.read(notificationServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      await service.refreshTimezone();
      if (state) {
        await service.scheduleDailyReviews(
          morningHour: prefs.getInt('review_morning_hour') ?? kMorningHour,
          eveningHour: prefs.getInt('review_evening_hour') ?? kEveningHour,
        );
      }
      // Напоминания об осанке планируются отдельным тумблером
      // (posture_reminders_on, см. posture_screen) — перепланируем, если активны.
      if (prefs.getBool('posture_reminders_on') ?? false) {
        await service.schedulePostureReminders();
      }
    } catch (e) {
      debugPrint('[Notifications] reschedule failed: $e');
    }
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabled, bool>(NotificationsEnabled.new);
