// Профиль здоровья пользователя — три вопроса в свободной форме.
// Используется для персонализации AI-меню (исключение аллергенов, учёт питательных особенностей).
// Хранится в SharedPreferences. Не отправляется на сервер отдельно —
// передаётся в POST /api/v1/ai/menu-build как health_profile (только если непустой).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// Ключи SharedPreferences для профиля здоровья.
const kHealthAllergiesKey = 'health_allergies';
const kHealthHealingKey = 'health_healing';
const kHealthDeficienciesKey = 'health_deficiencies';

// Ключи сна — приблизительное расписание пользователя.
// Формат: час в 24-часовом формате (int, 0..23).
// TODO(sleep-distribution): когда будет реализовано распределение задач
// вокруг сна, читать kSleepBedtimeHourKey и kSleepWakeHourKey из prefs,
// чтобы не ставить задачи/напоминания в ночное окно [bedtime, wake].
const kSleepBedtimeHourKey = 'sleep_bedtime_hour';   // час отхода ко сну
const kSleepWakeHourKey = 'sleep_wake_hour';           // час подъёма

const kDefaultBedtimeHour = 23; // 23:00
const kDefaultWakeHour = 7;     // 07:00

/// Модель профиля здоровья.
class HealthProfile {
  const HealthProfile({
    this.allergies = '',
    this.healing = '',
    this.deficiencies = '',
    this.bedtimeHour = kDefaultBedtimeHour,
    this.wakeHour = kDefaultWakeHour,
  });

  final String allergies;

  /// Скорость заживления: 'fast'|'week'|'slow'|'' (пусто = не заполнено).
  /// Значения соответствуют временным диапазонам (ITEM C).
  final String healing;

  final String deficiencies;

  /// Приблизительный час отхода ко сну (0..23). По умолчанию 23.
  final int bedtimeHour;

  /// Приблизительный час подъёма (0..23). По умолчанию 7.
  final int wakeHour;

  /// true, если все три текстовых поля пустые (данные не были заполнены).
  bool get isEmpty =>
      allergies.trim().isEmpty &&
      healing.trim().isEmpty &&
      deficiencies.trim().isEmpty;

  HealthProfile copyWith({
    String? allergies,
    String? healing,
    String? deficiencies,
    int? bedtimeHour,
    int? wakeHour,
  }) =>
      HealthProfile(
        allergies: allergies ?? this.allergies,
        healing: healing ?? this.healing,
        deficiencies: deficiencies ?? this.deficiencies,
        bedtimeHour: bedtimeHour ?? this.bedtimeHour,
        wakeHour: wakeHour ?? this.wakeHour,
      );

  /// Сериализация в snake_case для API (POST body).
  Map<String, String> toApiMap() => {
        'allergies': allergies.trim(),
        'healing': healing.trim(),
        'deficiencies': deficiencies.trim(),
      };
}

/// Notifier для профиля здоровья: читает/пишет 3 ключа в SharedPreferences.
/// Паттерн идентичен WaterGoalNotifier / LocaleNotifier.
class HealthProfileNotifier extends Notifier<HealthProfile> {
  @override
  HealthProfile build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return HealthProfile(
      allergies: prefs.getString(kHealthAllergiesKey) ?? '',
      healing: prefs.getString(kHealthHealingKey) ?? '',
      deficiencies: prefs.getString(kHealthDeficienciesKey) ?? '',
      bedtimeHour: prefs.getInt(kSleepBedtimeHourKey) ?? kDefaultBedtimeHour,
      wakeHour: prefs.getInt(kSleepWakeHourKey) ?? kDefaultWakeHour,
    );
  }

  /// Сохраняет новый профиль в prefs и обновляет состояние.
  Future<void> save(HealthProfile profile) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(kHealthAllergiesKey, profile.allergies.trim());
    await prefs.setString(kHealthHealingKey, profile.healing.trim());
    await prefs.setString(kHealthDeficienciesKey, profile.deficiencies.trim());
    await prefs.setInt(kSleepBedtimeHourKey, profile.bedtimeHour);
    await prefs.setInt(kSleepWakeHourKey, profile.wakeHour);
    state = profile;
  }

  /// Удобный метод для обновления одного поля из виджета-редактора.
  Future<void> updateField({
    String? allergies,
    String? healing,
    String? deficiencies,
    int? bedtimeHour,
    int? wakeHour,
  }) =>
      save(state.copyWith(
        allergies: allergies,
        healing: healing,
        deficiencies: deficiencies,
        bedtimeHour: bedtimeHour,
        wakeHour: wakeHour,
      ));
}

final healthProfileProvider =
    NotifierProvider<HealthProfileNotifier, HealthProfile>(
  HealthProfileNotifier.new,
);
