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

import '../../core/database/daos/habits_dao.dart'
    show HabitReminder, computeHabitReminders, habitReminderBaseId,
        kHabitReminderSlots;
import '../../core/l10n/app_strings.dart';
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
  ///
  /// [localeLangGetter] возвращает сохранённый в SharedPreferences тег локали
  /// ('ru', 'en', 'pt-BR'...). Используется для локализации текстов уведомлений
  /// без BuildContext. Если null/пусто — откат на 'en'.
  NotificationService(
    this._plugin, {
    String? Function()? overrideTzGetter,
    String? Function()? localeLangGetter,
  })  : _overrideTzGetter = overrideTzGetter,
        _localeLangGetter = localeLangGetter;

  final FlutterLocalNotificationsPlugin _plugin;
  final String? Function()? _overrideTzGetter;
  final String? Function()? _localeLangGetter;
  bool _inited = false;

  /// Резолвит строку по ключу из S.all, используя сохранённую локаль приложения.
  /// Не требует BuildContext — предназначен для текстов уведомлений.
  /// Порядок: точный тег ('pt-BR') → языковой код ('pt') → 'en' → сам ключ.
  String _ls(String key) {
    final tag = _localeLangGetter?.call() ?? 'en';
    final entry = S.all[key];
    if (entry == null) return key;
    final langCode = tag.split('-').first;
    return entry[tag] ?? entry[langCode] ?? entry['en'] ?? key;
  }

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

  /// Гарантирует разрешение на уведомления для путей, которые планируют их
  /// напрямую (напоминания задач), не проходя через глобальный тумблер.
  /// Возвращает true, если уведомления разрешены (или платформа их не требует).
  ///
  /// Переиспользует [requestPermission]: на Android 13+/iOS системный диалог
  /// показывается один раз — повторные вызовы просто возвращают текущее
  /// состояние, поэтому метод идемпотентен и его безопасно дёргать при каждом
  /// сохранении напоминания. На web/неподдерживаемых платформах — no-op (true),
  /// чтобы не блокировать сохранение.
  Future<bool> ensurePermission() async {
    if (kIsWeb) return true;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Если уже выдано — не показываем диалог повторно.
      final enabled = await android.areNotificationsEnabled() ?? false;
      if (enabled) return true;
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
    // Прочие платформы (desktop) — разрешение не требуется.
    return true;
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
      title: _ls('notif.morning_title'),
      body: _ls('notif.morning_body'),
      scheduledDate: _nextInstanceOf(morningHour),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    await _plugin.zonedSchedule(
      id: _kEveningId,
      title: _ls('notif.evening_title'),
      body: _ls('notif.evening_body'),
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
        title: _ls('notif.posture_title'),
        body: _ls('notif.posture_body'),
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

  // ---------------------------------------------------------------------------
  // Напоминания перед задачей (reminder_minutes_before)
  // ---------------------------------------------------------------------------

  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'kaizen_tasks',
      'Task reminders',
      channelDescription: 'Reminders before a scheduled task',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Стабильный положительный int-id уведомления из UUID задачи [itemId].
  /// Один и тот же itemId всегда даёт один id — поэтому повторное планирование
  /// перетирает прежнее, а cancelTaskReminder гарантированно его отменяет.
  /// Диапазон смещён от системных id (review/posture) добавлением базы.
  static int taskReminderId(String itemId) {
    // FNV-1a 32-бит → положительный диапазон [1_000_000, ~1_004M].
    var hash = 0x811c9dc5;
    for (final code in itemId.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 1000000 + (hash % 1000000000);
  }

  /// Планирует одноразовое локальное уведомление-напоминание для задачи [itemId]
  /// на момент [fireAt] (абсолютное локальное время, обычно scheduledAt − N мин).
  /// Сначала отменяет прежнее напоминание этой задачи (id стабилен по itemId).
  /// Если [fireAt] в прошлом — ничего не планирует (и снимает старое).
  /// Время интерпретируется в tz.local (уважает override таймзоны).
  Future<void> scheduleTaskReminder(
    String itemId,
    String title,
    DateTime fireAt,
  ) async {
    if (kIsWeb) return;
    await init();
    final id = taskReminderId(itemId);
    // Всегда снимаем прежнее напоминание этой задачи перед перепланированием.
    await _plugin.cancel(id: id);

    final scheduled = tz.TZDateTime.from(fireAt, tz.local);
    final nowTz = tz.TZDateTime.now(tz.local);
    if (!scheduled.isAfter(nowTz)) return; // в прошлом — не планируем

    await _plugin.zonedSchedule(
      id: id,
      title: title.isEmpty ? 'Reminder' : title,
      body: 'Starts soon — get ready.',
      scheduledDate: scheduled,
      notificationDetails: _taskDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Отменяет напоминание задачи [itemId] (id стабилен по itemId).
  Future<void> cancelTaskReminder(String itemId) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: taskReminderId(itemId));
  }

  // ---------------------------------------------------------------------------
  // Напоминания привычек (ADR-053, slice 4)
  // ---------------------------------------------------------------------------

  static const _habitDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'kaizen_habits',
      'Habit reminders',
      channelDescription: 'Reminders for your habits',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// (Пере)планирует локальные напоминания привычки [habitId].
  /// Чистый расчёт слотов — в [computeHabitReminders] (habits_dao, юнит-тест без
  /// БД/плагина). Сначала отменяет все прежние слоты этой привычки (id стабильны
  /// по habitId), затем планирует:
  ///   - daily / weekly_count → одно ежедневное (matchDateTimeComponents: time);
  ///   - weekly_days → по одному на каждый день недели маски
  ///     (matchDateTimeComponents: dayOfWeekAndTime — нативное еженедельное
  ///     повторение плагина).
  /// При [reminderMinutes] == null список пуст → метод просто снимает прежние.
  /// [title] обычно = имя привычки, [body] — локализованный текст напоминания.
  Future<void> scheduleHabitReminders({
    required String habitId,
    required int? reminderMinutes,
    required String frequencyType,
    required int weekdayMask,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    await cancelHabitReminders(habitId);
    final reminders = computeHabitReminders(
      habitId: habitId,
      reminderMinutes: reminderMinutes,
      frequencyType: frequencyType,
      weekdayMask: weekdayMask,
    );
    for (final HabitReminder r in reminders) {
      await _plugin.zonedSchedule(
        id: r.notificationId,
        title: title.isEmpty ? 'Reminder' : title,
        body: body,
        scheduledDate: r.weekday == null
            ? _nextInstanceOfTime(r.hour, r.minute)
            : _nextInstanceOfWeekdayTime(r.weekday!, r.hour, r.minute),
        notificationDetails: _habitDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: r.weekday == null
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Отменяет все слоты напоминаний привычки [habitId] (весь диапазон id).
  Future<void> cancelHabitReminders(String habitId) async {
    if (kIsWeb) return;
    await init();
    final base = habitReminderBaseId(habitId);
    for (var i = 0; i < kHabitReminderSlots; i++) {
      await _plugin.cancel(id: base + i);
    }
  }

  /// Следующее наступление времени [hour]:[minute] (сегодня или завтра).
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Следующее наступление [hour]:[minute] в день недели [weekday] (Пн=1..Вс=7).
  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    FlutterLocalNotificationsPlugin(),
    // Эффективная зона: override из настроек (если задан), иначе зона устройства.
    overrideTzGetter: () =>
        ref.read(sharedPreferencesProvider).getString(kTimezoneOverrideKey),
    // Локаль для текстов уведомлений (сохранена в prefs при смене языка).
    // Ключ 'app_locale' — тот же, что в locale_provider.dart (_kLocaleKey).
    localeLangGetter: () =>
        ref.read(sharedPreferencesProvider).getString('app_locale'),
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
        // Часы разборов берём из prefs (онбординг/setup_flow), как main.dart
        // и reschedule(), а не дефолтные 8/20 — иначе off→on сбрасывает время.
        final hours = _reviewHours();
        await service.scheduleDailyReviews(
          morningHour: hours.$1,
          eveningHour: hours.$2,
        );
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

  /// Часы утреннего/вечернего разбора из prefs (онбординг/setup_flow),
  /// дефолты 8/20. Единый источник для setEnabled() и reschedule(), чтобы
  /// включение/перепланирование не сбрасывало пользовательское время.
  (int, int) _reviewHours() {
    final prefs = ref.read(sharedPreferencesProvider);
    return (
      prefs.getInt('review_morning_hour') ?? kMorningHour,
      prefs.getInt('review_evening_hour') ?? kEveningHour,
    );
  }

  /// Перепланирует уже активные уведомления в текущей эффективной зоне.
  /// Вызывается при смене настройки часового пояса (timezone_provider).
  /// Перечитывает зону устройства/override, затем заново планирует разборы
  /// (если включены) и напоминания об осанке (если их тумблер активен).
  /// Часы разборов берутся из тех же ключей prefs, что и при старте
  /// (review_morning_hour / review_evening_hour — см. onboarding/setup_flow).
  //
  // TODO(notifications, LOW): per-task напоминания (scheduleTaskReminder)
  // НЕ перепланируются при смене часового пояса — они привязаны к старому
  // tz.local на момент планирования. Короткогоризонтные, поэтому пока ОК;
  // при необходимости перепланировать активные task-reminder здесь же.
  Future<void> reschedule() async {
    if (kIsWeb) return;
    final service = ref.read(notificationServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      await service.refreshTimezone();
      if (state) {
        final hours = _reviewHours();
        await service.scheduleDailyReviews(
          morningHour: hours.$1,
          eveningHour: hours.$2,
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
