// Тест адопции профиля пользователя с сервера в локальные SharedPreferences
// (ADR-062, services/sync/profile_adoption_service.dart).
//
// Ядро логики: applyServerProfile() пишет в prefs ТОЛЬКО заданные (non-null)
// поля из объекта `user`, пришедшего с сервера (login/register/GET me).
// Поля, которые сервер не прислал (null/отсутствуют), НЕ должны стирать
// локальное значение — так гостевые/только что введённые локально данные не
// затираются нулями до первой push-синхронизации. Это симметрично паттерну
// shouldMarkSetupDone/onboarding_sync_test.dart («серверная истина включает,
// серверное отсутствие/null не выключает»).

import 'package:app/core/settings/food_preferences_provider.dart'
    show kFoodGoalKey;
import 'package:app/core/settings/macro_override_provider.dart';
import 'package:app/core/settings/water_goal_provider.dart';
import 'package:app/services/sync/profile_adoption_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Реальные ключи prefs (water_goal_provider.dart) — не дублируем строки,
// импортируем константы, чтобы тест не разошёлся с продовым кодом.
const _kUserWeightKgKey = kUserWeightKgKey;
const _kUserHeightCmKey = kUserHeightCmKey;
const _kUserAgeKey = kUserAgeKey;
const _kUserSexKey = kUserSexKey;
const _kUserActivityKey = kUserActivityKey;

void main() {
  group('applyServerProfile', () {
    test('пишет ВСЕ заданные (не-null) поля в соответствующие prefs-ключи',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final user = <String, dynamic>{
        'weight_kg': 72.5,
        'height_cm': 180,
        'age_years': 21,
        'sex': 'male',
        'activity_level': 'high',
        'food_goal': 'lose',
        'macro_override_enabled': true,
        'macro_kcal_target': 2200,
        'macro_protein_g': 150,
        'macro_fat_g': 70,
        'macro_carbs_g': 220,
        'water_goal_ml': 2500,
      };

      await applyServerProfile(user, prefs);

      expect(prefs.getDouble(_kUserWeightKgKey), 72.5);
      expect(prefs.getInt(_kUserHeightCmKey), 180);
      expect(prefs.getInt(_kUserAgeKey), 21);
      expect(prefs.getString(_kUserSexKey), 'male');
      expect(prefs.getString(_kUserActivityKey), 'high');
      expect(prefs.getString(kFoodGoalKey), 'lose');
      expect(prefs.getBool(kMacroOverrideEnabledKey), isTrue);
      expect(prefs.getInt(kMacroKcalTargetKey), 2200);
      expect(prefs.getInt(kMacroProteinGKey), 150);
      expect(prefs.getInt(kMacroFatGKey), 70);
      expect(prefs.getInt(kMacroCarbsGKey), 220);
      expect(prefs.getInt(kWaterGoalMlKey), 2500);
    });

    test(
        'null/отсутствующие серверные поля НЕ перезатирают уже имеющееся '
        'локальное значение', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        _kUserWeightKgKey: 80.0,
        _kUserHeightCmKey: 175,
        kWaterGoalMlKey: 2400,
      });
      final prefs = await SharedPreferences.getInstance();

      // Сервер прислал профиль без антропометрии (например, новый аккаунт
      // без заполненных полей) — локальные значения (введённые в онбординге
      // на этом устройстве, ещё не отправленные на сервер) должны выжить.
      final user = <String, dynamic>{
        'weight_kg': null,
        'height_cm': null,
        // age_years вообще отсутствует в мапе — эквивалентно null.
      };

      await applyServerProfile(user, prefs);

      expect(prefs.getDouble(_kUserWeightKgKey), 80.0);
      expect(prefs.getInt(_kUserHeightCmKey), 175);
      expect(prefs.getInt(kWaterGoalMlKey), 2400);
    });

    test('пустой объект user — no-op (ничего не пишет и не бросает)',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await applyServerProfile(<String, dynamic>{}, prefs);

      expect(prefs.getDouble(_kUserWeightKgKey), isNull);
      expect(prefs.getInt(kWaterGoalMlKey), isNull);
    });

    test('частичное серверное обновление — трогает только присланные поля',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        _kUserWeightKgKey: 80.0,
        _kUserSexKey: 'male',
      });
      final prefs = await SharedPreferences.getInstance();

      // Сервер прислал только новый вес (например, обновлён с другого
      // устройства) — пол не тронут, остаётся прежним локальным значением.
      await applyServerProfile(<String, dynamic>{'weight_kg': 68.0}, prefs);

      expect(prefs.getDouble(_kUserWeightKgKey), 68.0);
      expect(prefs.getString(_kUserSexKey), 'male');
    });
  });
}
