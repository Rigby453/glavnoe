// Тест сериализации тела PATCH /api/v1/auth/me (ADR-062).
//
// buildProfileUpdateBody — чистая функция (без Dio), собирающая тело запроса
// из именованных параметров ApiClient.updateProfile(). Проверяем:
//   1. Все 13 профильных полей (+ onboarding_done) сериализуются в snake_case.
//   2. Не заданные (null) параметры НЕ попадают в тело — контракт
//      /docs/api-spec.yaml описывает все поля как опциональные ("only sent
//      fields are updated").
//   3. Пустой вызов даёт пустое тело (ничего не отправляем зря).

import 'package:app/services/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildProfileUpdateBody', () {
    test('сериализует все поля в snake_case, когда все заданы', () {
      final body = buildProfileUpdateBody(
        onboardingDone: true,
        weightKg: 72.5,
        heightCm: 180,
        ageYears: 21,
        sex: 'male',
        activityLevel: 'medium',
        foodGoal: 'lose',
        calorieGoal: 2200,
        macroOverrideEnabled: true,
        macroKcalTarget: 2200,
        macroProteinG: 150,
        macroFatG: 70,
        macroCarbsG: 220,
        waterGoalMl: 2500,
      );

      expect(body, {
        'onboarding_done': true,
        'weight_kg': 72.5,
        'height_cm': 180,
        'age_years': 21,
        'sex': 'male',
        'activity_level': 'medium',
        'food_goal': 'lose',
        'calorie_goal': 2200,
        'macro_override_enabled': true,
        'macro_kcal_target': 2200,
        'macro_protein_g': 150,
        'macro_fat_g': 70,
        'macro_carbs_g': 220,
        'water_goal_ml': 2500,
      });
    });

    test('опускает не заданные (null) поля', () {
      final body = buildProfileUpdateBody(
        weightKg: 60,
        waterGoalMl: 2000,
      );

      expect(body, {'weight_kg': 60.0, 'water_goal_ml': 2000});
      expect(body.containsKey('height_cm'), isFalse);
      expect(body.containsKey('sex'), isFalse);
      expect(body.containsKey('macro_override_enabled'), isFalse);
      expect(body.containsKey('onboarding_done'), isFalse);
    });

    test('без аргументов возвращает пустое тело', () {
      expect(buildProfileUpdateBody(), <String, dynamic>{});
    });

    test('macro_override_enabled=false тоже сериализуется (bool, не null)',
        () {
      // false — валидное значение, отличное от "не задано" (null); должно
      // попасть в тело, а не быть пропущенным как null.
      final body = buildProfileUpdateBody(macroOverrideEnabled: false);
      expect(body, {'macro_override_enabled': false});
    });
  });
}
