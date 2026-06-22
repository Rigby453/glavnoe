// Юнит-тесты парсера естественного языка дат/времени.
// Все тесты используют фиксированный [now] — DateTime.now() не вызывается.
//
// Структура фиксации:
//   now = Среда 2026-06-17 14:30 (weekday=3)
//   Фикс: "завтра" → четверг 2026-06-18
//         "пятница" → следующая пятница = 2026-06-19
//         голое "17:00" в 14:30 → сегодня (ещё не прошло)
//         голое "9:00" в 14:30 → завтра (уже прошло)

import 'package:app/core/utils/nl_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Фиксированная «сейчас»: среда 2026-06-17 14:30
  final now = DateTime(2026, 6, 17, 14, 30);

  group('parseNaturalDateTime — no match', () {
    test('empty string → when=null, cleanedTitle empty', () {
      final r = parseNaturalDateTime('', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, '');
    });

    test('plain title without time → no match', () {
      final r = parseNaturalDateTime('Сдать лабу', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'Сдать лабу');
    });

    test('EN plain title → no match', () {
      final r = parseNaturalDateTime('Buy groceries', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'Buy groceries');
    });
  });

  group('RU — завтра + время', () {
    test('"Сдать лабу завтра 17:00" → tomorrow 17:00, title "Сдать лабу"', () {
      final r = parseNaturalDateTime('Сдать лабу завтра 17:00', now);
      final expected = DateTime(2026, 6, 18, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Сдать лабу');
    });

    test('"завтра в 5" → tomorrow 05:00', () {
      final r = parseNaturalDateTime('тренировка завтра в 5', now);
      final expected = DateTime(2026, 6, 18, 5, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"завтра" alone → tomorrow 09:00', () {
      final r = parseNaturalDateTime('Встреча завтра', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Встреча');
    });
  });

  group('RU — сегодня + время', () {
    test('"сегодня в 9" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('позвонить сегодня в 9', now);
      // 09:00 уже прошло (now=14:30) → завтра
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'позвонить');
    });

    test('"сегодня 17:00" — future → today 17:00', () {
      final r = parseNaturalDateTime('зарядка сегодня 17:00', now);
      final expected = DateTime(2026, 6, 17, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'зарядка');
    });
  });

  group('EN — tomorrow + time', () {
    test('"tomorrow 5pm" → tomorrow 17:00', () {
      final r = parseNaturalDateTime('call mom tomorrow 5pm', now);
      final expected = DateTime(2026, 6, 18, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'call mom');
    });

    test('"today at 9" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('submit report today at 9', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'submit report');
    });
  });

  group('DE — morgen + Uhr', () {
    test('"morgen 17 uhr" → tomorrow 17:00', () {
      final r = parseNaturalDateTime('Hausaufgaben morgen 17 uhr', now);
      final expected = DateTime(2026, 6, 18, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Hausaufgaben');
    });

    test('"heute um 9" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('Anruf heute um 9', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Anruf');
    });
  });

  group('Relative — "через N часов" / "in N hours"', () {
    test('"через 2 часа" → now + 2h', () {
      final r = parseNaturalDateTime('почитать через 2 часа', now);
      final expected = now.add(const Duration(hours: 2));
      expect(r.when, expected);
      expect(r.cleanedTitle, 'почитать');
    });

    test('"in 2 hours" → now + 2h', () {
      final r = parseNaturalDateTime('workout in 2 hours', now);
      final expected = now.add(const Duration(hours: 2));
      expect(r.when, expected);
      expect(r.cleanedTitle, 'workout');
    });

    test('"in 2 stunden" → now + 2h', () {
      final r = parseNaturalDateTime('Training in 2 stunden', now);
      final expected = now.add(const Duration(hours: 2));
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Training');
    });
  });

  group('Weekday names', () {
    // now = среда (weekday=3). Пятница = +2 дня = 2026-06-19.
    test('RU "в пятницу" → next friday 09:00', () {
      final r = parseNaturalDateTime('занятие в пятницу', now);
      final expected = DateTime(2026, 6, 19, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'занятие');
    });

    test('EN "on friday" → next friday 09:00', () {
      final r = parseNaturalDateTime('gym on friday', now);
      final expected = DateTime(2026, 6, 19, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'gym');
    });

    test('DE "am Freitag" → next friday 09:00', () {
      final r = parseNaturalDateTime('Sport am Freitag', now);
      final expected = DateTime(2026, 6, 19, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Sport');
    });

    test('weekday + time: "пятница 18:00" → next friday 18:00', () {
      final r = parseNaturalDateTime('тренировка пятница 18:00', now);
      final expected = DateTime(2026, 6, 19, 18, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'тренировка');
    });

    // Среда (today, weekday=3) → следующая среда +7 дней.
    test('same weekday → next week', () {
      final r = parseNaturalDateTime('лекция среда', now);
      final expected = DateTime(2026, 6, 24, 9, 0); // +7 дней
      expect(r.when, expected);
      expect(r.cleanedTitle, 'лекция');
    });
  });

  group('Bare time (no date keyword)', () {
    test('"17:00" — future → today 17:00', () {
      final r = parseNaturalDateTime('встреча 17:00', now);
      final expected = DateTime(2026, 6, 17, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"9:00" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('звонок 9:00', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'звонок');
    });

    test('"5pm" → today 17:00 (future)', () {
      final r = parseNaturalDateTime('meeting 5pm', now);
      final expected = DateTime(2026, 6, 17, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'meeting');
    });

    test('"9am" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('standup 9am', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'standup');
    });
  });

  group('Compact HHMM digits (Todoist-style)', () {
    test('"лекция 700" → today 07:00 already past → tomorrow, title "лекция"', () {
      final r = parseNaturalDateTime('лекция 700', now);
      // 07:00 уже прошло (now=14:30) → завтра
      final expected = DateTime(2026, 6, 18, 7, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'лекция');
    });

    test('"700" → 07:00 (минуты 00)', () {
      final r = parseNaturalDateTime('подъём 700', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0)); // прошло → завтра
      expect(r.cleanedTitle, 'подъём');
    });

    test('"730" → 07:30', () {
      final r = parseNaturalDateTime('зарядка 730', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 30)); // прошло → завтра
      expect(r.cleanedTitle, 'зарядка');
    });

    test('"1830" → 18:30 (future today)', () {
      final r = parseNaturalDateTime('пара 1830', now);
      expect(r.when, DateTime(2026, 6, 17, 18, 30));
      expect(r.cleanedTitle, 'пара');
    });

    test('"900" → 09:00', () {
      final r = parseNaturalDateTime('встреча 900', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0)); // прошло → завтра
      expect(r.cleanedTitle, 'встреча');
    });

    test('"2359" → 23:59 (future today)', () {
      final r = parseNaturalDateTime('дедлайн 2359', now);
      expect(r.when, DateTime(2026, 6, 17, 23, 59));
      expect(r.cleanedTitle, 'дедлайн');
    });

    test('invalid minutes ">59" → not recognized ("760")', () {
      final r = parseNaturalDateTime('глава 760', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'глава 760');
    });

    test('invalid hours ">23" → not recognized ("2460")', () {
      final r = parseNaturalDateTime('код 2460', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'код 2460');
    });
  });

  group('Compact digits — negatives (do not over-match)', () {
    test('single short number "глава 12" → not time, unchanged', () {
      final r = parseNaturalDateTime('глава 12', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'глава 12');
    });

    test('"задача 5" → not time, unchanged', () {
      final r = parseNaturalDateTime('задача 5', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'задача 5');
    });

    test('5-digit number is not HHMM ("12345")', () {
      final r = parseNaturalDateTime('счёт 12345', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'счёт 12345');
    });

    test('HH:MM still wins over compact ("встреча 17:00")', () {
      final r = parseNaturalDateTime('встреча 17:00', now);
      expect(r.when, DateTime(2026, 6, 17, 17, 0));
      expect(r.cleanedTitle, 'встреча');
    });
  });

  group('Edge cases', () {
    test('already-past time "in 0 hours" stays near now', () {
      final r = parseNaturalDateTime('задача через 0 часов', now);
      // 0 часов → now + 0 = now (не сдвигается)
      expect(r.when, isNotNull);
      expect(r.cleanedTitle, 'задача');
    });

    test('voice-style: "тренировка завтра в шесть" — "шесть" не число → only tomorrow', () {
      // "шесть" — прописное слово, не парсится как число → только "завтра" распознаётся.
      final r = parseNaturalDateTime('тренировка завтра в шесть', now);
      // Завтра без времени → 09:00
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      // "в шесть" останется в заголовке т.к. не распознано как время
      expect(r.cleanedTitle, isNotNull);
    });
  });
}
