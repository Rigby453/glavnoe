// Выбор часового пояса для планирования уведомлений (SPEC C3 / C5).
//
// По умолчанию — «авто»: уведомления планируются в часовом поясе устройства
// (как раньше, через FlutterTimezone). Пользователь может переопределить зону
// конкретным IANA-идентификатором (напр. 'Europe/Moscow') — например, если
// живёт «по другому городу». Хранится в SharedPreferences (ключ
// 'timezone_override'): пустая строка/отсутствие = авто.
//
// Эффективная зона применяется к планированию в notification_service.dart
// (он читает override по ключу [kTimezoneOverrideKey] и вызывает
// tz.setLocalLocation при инициализации/перепланировании).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../services/notifications/notification_service.dart'
    show notificationsEnabledProvider;
import '../theme/theme_provider.dart'; // sharedPreferencesProvider

/// Ключ SharedPreferences для override зоны. Пусто/отсутствует = авто.
/// Публичный, чтобы notification_service мог прочитать значение напрямую.
const kTimezoneOverrideKey = 'timezone_override';

/// Список IANA-зон для пикера в UI. Намеренно сокращённый и практичный:
/// полная база timezone (~600 зон) перегрузила бы мобильный список. Сюда
/// входят все зоны РФ/СНГ + популярные мировые зоны + UTC. Если нужной зоны
/// нет — её всё равно можно сохранить программно (override принимает любой
/// валидный IANA-идентификатор).
///
/// Порядок: РФ/СНГ сначала (основная аудитория), затем мир, UTC в конце.
const List<String> kSelectableTimezones = [
  // Россия
  'Europe/Kaliningrad', // UTC+2 (MSK-1)
  'Europe/Moscow', // UTC+3 (MSK)
  'Europe/Samara', // UTC+4
  'Asia/Yekaterinburg', // UTC+5
  'Asia/Omsk', // UTC+6
  'Asia/Novosibirsk', // UTC+7
  'Asia/Krasnoyarsk', // UTC+7
  'Asia/Irkutsk', // UTC+8
  'Asia/Yakutsk', // UTC+9
  'Asia/Vladivostok', // UTC+10
  'Asia/Magadan', // UTC+11
  'Asia/Kamchatka', // UTC+12
  // СНГ / соседние
  'Europe/Minsk', // Беларусь UTC+3
  'Europe/Kiev', // Украина UTC+2
  'Asia/Almaty', // Казахстан UTC+5/+6
  'Asia/Tashkent', // Узбекистан UTC+5
  'Asia/Tbilisi', // Грузия UTC+4
  'Asia/Yerevan', // Армения UTC+4
  'Asia/Baku', // Азербайджан UTC+4
  // Мир
  'Europe/London',
  'Europe/Berlin',
  'Europe/Paris',
  'Europe/Istanbul',
  'Asia/Dubai',
  'Asia/Kolkata',
  'Asia/Shanghai',
  'Asia/Tokyo',
  'Australia/Sydney',
  'America/New_York',
  'America/Chicago',
  'America/Los_Angeles',
  'America/Sao_Paulo',
  'UTC',
];

/// Значение настройки часового пояса.
///
/// [TimezonePref.auto] — использовать зону устройства (поведение по умолчанию).
/// [TimezonePref.override] — конкретный IANA-идентификатор, заданный юзером.
class TimezonePref {
  const TimezonePref.auto() : iana = null;
  const TimezonePref.override(String this.iana);

  /// IANA-идентификатор переопределения, либо null для авто.
  final String? iana;

  /// true, если используется зона устройства (авто).
  bool get isAuto => iana == null || iana!.isEmpty;
}

/// Хранилище выбора часового пояса.
///
/// UI:
///  - текущее значение: `ref.watch(timezoneOverrideProvider)` → [TimezonePref];
///  - список зон для пикера: [kSelectableTimezones];
///  - изменить: [setAuto] (зона устройства) или [setOverride] (IANA).
///
/// При изменении настройка не только сохраняется, но и (если уведомления
/// включены) перепланирует их в новой зоне — см. реализацию ниже.
class TimezoneNotifier extends Notifier<TimezonePref> {
  @override
  TimezonePref build() {
    final saved =
        ref.read(sharedPreferencesProvider).getString(kTimezoneOverrideKey);
    if (saved == null || saved.isEmpty) return const TimezonePref.auto();
    return TimezonePref.override(saved);
  }

  /// Сбрасывает на зону устройства (авто) и перепланирует уведомления.
  Future<void> setAuto() async {
    await ref.read(sharedPreferencesProvider).remove(kTimezoneOverrideKey);
    state = const TimezonePref.auto();
    await _applyToNotifications();
  }

  /// Задаёт конкретную IANA-зону и перепланирует уведомления.
  /// Пустая строка трактуется как авто.
  Future<void> setOverride(String iana) async {
    if (iana.isEmpty) {
      await setAuto();
      return;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setString(kTimezoneOverrideKey, iana);
    state = TimezonePref.override(iana);
    await _applyToNotifications();
  }

  /// Применяет новую зону к уже запланированным уведомлениям: переинициализирует
  /// сервис (чтобы tz.local указывал на новую зону) и перепланирует разборы.
  /// No-op, если уведомления выключены. Ошибки гасим — настройка уже сохранена.
  Future<void> _applyToNotifications() async {
    try {
      // Импорт через ref, чтобы не создавать циклическую зависимость файлов:
      // notification_service сам зависит от этого файла (читает ключ).
      final notifier = ref.read(notificationsEnabledProvider.notifier);
      await notifier.reschedule();
    } catch (_) {
      // Сервис мог быть недоступен (тесты/web) — настройка всё равно сохранена.
    }
  }
}

final timezoneOverrideProvider =
    NotifierProvider<TimezoneNotifier, TimezonePref>(TimezoneNotifier.new);

/// Преобразует сохранённый идентификатор в [tz.Location].
/// Возвращает null для авто (пусто/null) или невалидного идентификатора —
/// в этом случае вызывающий код использует зону устройства.
/// База timezone должна быть инициализирована (`tzdata.initializeTimeZones()`).
tz.Location? locationFromOverride(String? iana) {
  if (iana == null || iana.isEmpty) return null;
  try {
    return tz.getLocation(iana);
  } catch (_) {
    return null; // невалидный идентификатор — откат на зону устройства
  }
}
