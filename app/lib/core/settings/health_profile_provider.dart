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

/// Модель профиля здоровья.
class HealthProfile {
  const HealthProfile({
    this.allergies = '',
    this.healing = '',
    this.deficiencies = '',
  });

  final String allergies;
  final String healing;
  final String deficiencies;

  /// true, если все три поля пустые (данные не были заполнены).
  bool get isEmpty =>
      allergies.trim().isEmpty &&
      healing.trim().isEmpty &&
      deficiencies.trim().isEmpty;

  HealthProfile copyWith({
    String? allergies,
    String? healing,
    String? deficiencies,
  }) =>
      HealthProfile(
        allergies: allergies ?? this.allergies,
        healing: healing ?? this.healing,
        deficiencies: deficiencies ?? this.deficiencies,
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
    );
  }

  /// Сохраняет новый профиль в prefs и обновляет состояние.
  Future<void> save(HealthProfile profile) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(kHealthAllergiesKey, profile.allergies.trim());
    await prefs.setString(kHealthHealingKey, profile.healing.trim());
    await prefs.setString(kHealthDeficienciesKey, profile.deficiencies.trim());
    state = profile;
  }

  /// Удобный метод для обновления одного поля из виджета-редактора.
  Future<void> updateField({
    String? allergies,
    String? healing,
    String? deficiencies,
  }) =>
      save(state.copyWith(
        allergies: allergies,
        healing: healing,
        deficiencies: deficiencies,
      ));
}

final healthProfileProvider =
    NotifierProvider<HealthProfileNotifier, HealthProfile>(
  HealthProfileNotifier.new,
);
