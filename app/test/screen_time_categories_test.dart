// Юнит-тесты чистой категоризации экранного времени (categorizeUsageMinutes).
// Без I/O и плагина — проверяем только агрегацию пакетов в 6 категорий.

import 'package:app/features/health/screen_time_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categorizeUsageMinutes', () {
    test('пустой ввод → все категории по 0 (включая other)', () {
      final r = categorizeUsageMinutes(const {});
      expect(r, {
        'social': 0,
        'video': 0,
        'games': 0,
        'browsing': 0,
        'messaging': 0,
        'other': 0,
      });
    });

    test('известные пакеты суммируются по своим категориям', () {
      final r = categorizeUsageMinutes(const {
        'com.instagram.android': 30, // social
        'com.vkontakte.android': 15, // social
        'com.google.android.youtube': 40, // video
        'org.telegram.messenger': 25, // messaging
      });
      expect(r['social'], 45);
      expect(r['video'], 40);
      expect(r['messaging'], 25);
      expect(r['games'], 0);
      expect(r['browsing'], 0);
      expect(r['other'], 0);
    });

    test('неизвестный пакет без override → попадает в other', () {
      final r = categorizeUsageMinutes(const {
        'com.unknown.app': 999,
        'com.android.chrome': 20, // browsing
      });
      expect(r['browsing'], 20);
      // Раньше 999 терялись; теперь идут в other.
      expect(r['other'], 999);
      // Сумма всех значений == исходная сумма минут.
      expect(r.values.fold<int>(0, (a, b) => a + b), 1019);
    });

    test('неизвестный пакет с androidCategoryOverride → попадает в нужную категорию', () {
      final r = categorizeUsageMinutes(
        const {'com.some.game': 120, 'com.some.social': 45},
        androidCategoryOverrides: const {
          'com.some.game': 'games',
          'com.some.social': 'social',
        },
      );
      expect(r['games'], 120);
      expect(r['social'], 45);
      expect(r['other'], 0);
    });

    test('whitelist приоритетнее androidCategoryOverride', () {
      // instagram — в whitelist как social; override пытается сделать games.
      final r = categorizeUsageMinutes(
        const {'com.instagram.android': 60},
        androidCategoryOverrides: const {'com.instagram.android': 'games'},
      );
      // whitelist должен победить
      expect(r['social'], 60);
      expect(r['games'], 0);
    });

    test('нулевые/отрицательные минуты не учитываются', () {
      final r = categorizeUsageMinutes(const {
        'com.whatsapp': 0,
        'com.viber.voip': -5,
        'com.discord': 10, // messaging
      });
      expect(r['messaging'], 10);
      expect(r['other'], 0);
    });

    test('каждый известный пакет маппится в одну из 6 валидных категорий', () {
      const valid = {'social', 'video', 'games', 'browsing', 'messaging', 'other'};
      for (final category in kPackageToCategory.values) {
        expect(valid.contains(category), isTrue,
            reason: 'неизвестная категория: $category');
      }
    });

    test('пакет с override null → попадает в other', () {
      // androidCategoryOverride без записи для пакета → other.
      final r = categorizeUsageMinutes(
        const {'com.unknown.news': 30},
        androidCategoryOverrides: const {}, // нет записи для этого пакета
      );
      expect(r['other'], 30);
    });
  });

  group('sub-minute ceiling contract (provider prepares 1 min for <60 s sessions)', () {
    // Проверяем, что 1-минутная запись (результат ceiling в провайдере)
    // корректно доходит до нужной категории.
    // Конкретно: ночная игровая сессия 30 с → провайдер округляет до 1 мин →
    // categorizeUsageMinutes получает {package: 1} → попадает в 'games'.
    test('1-минутная запись не отфильтровывается (нет floor-до-нуля)', () {
      final r = categorizeUsageMinutes(const {'com.king.candycrushsaga': 1});
      expect(r['games'], 1,
          reason: 'Короткая игровая сессия (1 мин после ceiling) должна попасть в games');
    });

    test('1-минутная запись неизвестного игрового пакета попадает в games через override', () {
      final r = categorizeUsageMinutes(
        const {'com.some.nightgame': 1},
        androidCategoryOverrides: const {'com.some.nightgame': 'games'},
      );
      expect(r['games'], 1);
      expect(r['other'], 0);
    });

    test('нулевые минуты всё равно отбрасываются (ms=0 → не передаём)', () {
      // categorizeUsageMinutes само по себе отбрасывает <= 0 внутри, но
      // провайдер не должен передавать нулей — тест документирует ожидание.
      final r = categorizeUsageMinutes(const {'com.some.game': 0});
      expect(r['games'], 0);
      expect(r['other'], 0);
    });
  });

  group('androidCategoryToOurCategory', () {
    test('CATEGORY_GAME (0) → games', () {
      expect(androidCategoryToOurCategory(0), 'games');
    });

    test('CATEGORY_AUDIO (1) → video', () {
      expect(androidCategoryToOurCategory(1), 'video');
    });

    test('CATEGORY_VIDEO (2) → video', () {
      expect(androidCategoryToOurCategory(2), 'video');
    });

    test('CATEGORY_SOCIAL (4) → social', () {
      expect(androidCategoryToOurCategory(4), 'social');
    });

    test('CATEGORY_NEWS (5) → browsing', () {
      expect(androidCategoryToOurCategory(5), 'browsing');
    });

    test('CATEGORY_IMAGE (3) → null (→ other)', () {
      expect(androidCategoryToOurCategory(3), isNull);
    });

    test('CATEGORY_MAPS (6) → null (→ other)', () {
      expect(androidCategoryToOurCategory(6), isNull);
    });

    test('CATEGORY_PRODUCTIVITY (7) → null (→ other)', () {
      expect(androidCategoryToOurCategory(7), isNull);
    });

    test('CATEGORY_UNDEFINED (-1) → null (→ other)', () {
      expect(androidCategoryToOurCategory(-1), isNull);
    });

    test('неизвестный int → null (→ other)', () {
      expect(androidCategoryToOurCategory(99), isNull);
    });
  });
}
