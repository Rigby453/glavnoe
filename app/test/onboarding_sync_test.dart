// Тест синхронизации флага онбординга между аккаунтом и локальным prefs.
//
// Ядро логики: при входе/регистрации AuthController читает объект `user` из
// auth-ответа сервера. Если сервер сообщает `onboarding_done == true`, локальный
// флаг `setup_done` ставится в true ДО смены auth-состояния — роутер не показывает
// онбординг (на web/новом устройстве). Серверный false НЕ стирает локально
// завершённый онбординг (локальный флаг — оффлайн-кэш).
//
// Здесь проверяется чистый хелпер `shouldMarkSetupDone` (решение «истина
// включает») и применение этого решения к SharedPreferences — без поднятия
// тяжёлого ApiClient/Dio.

import 'package:app/features/auth/auth_controller.dart' show shouldMarkSetupDone;
import 'package:app/features/onboarding/setup_flow.dart' show setupDoneKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('shouldMarkSetupDone', () {
    test('true только когда сервер явно говорит onboarding_done == true', () {
      expect(shouldMarkSetupDone({'onboarding_done': true}), isTrue);
    });

    test('false при onboarding_done=false / отсутствии / null', () {
      expect(shouldMarkSetupDone({'onboarding_done': false}), isFalse);
      expect(shouldMarkSetupDone(<String, dynamic>{}), isFalse);
      expect(shouldMarkSetupDone({'onboarding_done': null}), isFalse);
    });
  });

  test(
      'server onboarding_done == true → локальный setup_done становится true '
      '(онбординг не показывается)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    // Свежее устройство: setup_done ещё не установлен.
    expect(prefs.getBool(setupDoneKey), isNull);

    // Сервер (объект user из auth-ответа) говорит, что онбординг пройден.
    final user = <String, dynamic>{'onboarding_done': true};
    if (shouldMarkSetupDone(user)) {
      await prefs.setBool(setupDoneKey, true);
    }

    expect(prefs.getBool(setupDoneKey), isTrue);
  });

  test('server onboarding_done == false НЕ стирает локально пройденный setup',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{setupDoneKey: true});
    final prefs = await SharedPreferences.getInstance();

    final user = <String, dynamic>{'onboarding_done': false};
    if (shouldMarkSetupDone(user)) {
      await prefs.setBool(setupDoneKey, true);
    }

    // Локальный флаг — оффлайн-кэш: серверный false его не трогает.
    expect(prefs.getBool(setupDoneKey), isTrue);
  });
}
