// Юнит-тесты чистой логики советов по экранному времени.
// Покрывают screenTimeLevel (пороги 66%/100%, дефолты vs явный лимит)
// и screenTimeAdviceKey (формат ключа по уровню/тону).

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/settings/tone_provider.dart';
import 'package:app/features/health/screen_time_advice.dart';

void main() {
  group('screenTimeLevel — дефолтный порог (лимит = 0)', () {
    // social → дефолт 60: much с 40 (66% = 39.6), tooMuch с 60.
    test('ниже 66% → ok', () {
      expect(screenTimeLevel(0, 0, 'social'), ScreenTimeLevel.ok);
      expect(screenTimeLevel(39, 0, 'social'), ScreenTimeLevel.ok);
    });

    test('между 66% и порогом → much', () {
      expect(screenTimeLevel(40, 0, 'social'), ScreenTimeLevel.much);
      expect(screenTimeLevel(59, 0, 'social'), ScreenTimeLevel.much);
    });

    test('на пороге и выше → tooMuch', () {
      expect(screenTimeLevel(60, 0, 'social'), ScreenTimeLevel.tooMuch);
      expect(screenTimeLevel(200, 0, 'social'), ScreenTimeLevel.tooMuch);
    });

    test('дефолтные пороги различаются по категориям', () {
      // games → дефолт 120: 100 мин это ещё much (66% = 79.2), но не tooMuch.
      expect(screenTimeLevel(100, 0, 'games'), ScreenTimeLevel.much);
      expect(screenTimeLevel(120, 0, 'games'), ScreenTimeLevel.tooMuch);
      // video → дефолт 90.
      expect(screenTimeLevel(50, 0, 'video'), ScreenTimeLevel.ok);
      expect(screenTimeLevel(90, 0, 'video'), ScreenTimeLevel.tooMuch);
      // browsing → дефолт 60, messaging → дефолт 90.
      expect(screenTimeLevel(60, 0, 'browsing'), ScreenTimeLevel.tooMuch);
      expect(screenTimeLevel(89, 0, 'messaging'), ScreenTimeLevel.much);
    });

    test('таблица дефолтных порогов совпадает со спецификацией', () {
      expect(kScreenTimeDefaultThresholds, {
        'social': 60,
        'video': 90,
        'games': 120,
        'browsing': 60,
        'messaging': 90,
      });
    });
  });

  group('screenTimeLevel — явный лимит перекрывает дефолт', () {
    test('явный лимит используется вместо дефолта категории', () {
      // limit = 30: 66% = 19.8.
      expect(screenTimeLevel(10, 30, 'games'), ScreenTimeLevel.ok);
      expect(screenTimeLevel(20, 30, 'games'), ScreenTimeLevel.much);
      expect(screenTimeLevel(30, 30, 'games'), ScreenTimeLevel.tooMuch);
      expect(screenTimeLevel(45, 30, 'games'), ScreenTimeLevel.tooMuch);
    });

    test('тот же used даёт разный уровень при разных лимитах', () {
      // 50 мин: при дефолте social (60) → much; при лимите 40 → tooMuch.
      expect(screenTimeLevel(50, 0, 'social'), ScreenTimeLevel.much);
      expect(screenTimeLevel(50, 40, 'social'), ScreenTimeLevel.tooMuch);
    });
  });

  group('screenTimeAdviceKey — формат ключа', () {
    test('уровень ok', () {
      expect(
        screenTimeAdviceKey('social', ScreenTimeLevel.ok, AppTone.gentle),
        'screentime_advice_social_ok_gentle',
      );
      expect(
        screenTimeAdviceKey('social', ScreenTimeLevel.ok, AppTone.harsh),
        'screentime_advice_social_ok_harsh',
      );
    });

    test('уровень much', () {
      expect(
        screenTimeAdviceKey('video', ScreenTimeLevel.much, AppTone.gentle),
        'screentime_advice_video_much_gentle',
      );
      expect(
        screenTimeAdviceKey('video', ScreenTimeLevel.much, AppTone.harsh),
        'screentime_advice_video_much_harsh',
      );
    });

    test('уровень tooMuch → too_much в ключе', () {
      expect(
        screenTimeAdviceKey('games', ScreenTimeLevel.tooMuch, AppTone.gentle),
        'screentime_advice_games_too_much_gentle',
      );
      expect(
        screenTimeAdviceKey('messaging', ScreenTimeLevel.tooMuch, AppTone.harsh),
        'screentime_advice_messaging_too_much_harsh',
      );
    });

    test('каждая категория формирует свой ключ', () {
      for (final cat in const [
        'social',
        'video',
        'games',
        'browsing',
        'messaging',
      ]) {
        expect(
          screenTimeAdviceKey(cat, ScreenTimeLevel.ok, AppTone.gentle),
          'screentime_advice_${cat}_ok_gentle',
        );
      }
    });
  });
}
