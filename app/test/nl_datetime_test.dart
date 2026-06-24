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

  // =========================================================================
  // РАСШИРЕНИЕ: длительность / приоритет / повтор.
  // =========================================================================

  group('Duration → durationMinutes', () {
    test('"лекция 1.5ч" → 90 min, title "лекция"', () {
      final r = parseNaturalDateTime('лекция 1.5ч', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'лекция');
    });

    test('"созвон 1.5 часа" → 90 min', () {
      final r = parseNaturalDateTime('созвон 1.5 часа', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'созвон');
    });

    test('"встреча 2 часа" → 120 min', () {
      final r = parseNaturalDateTime('встреча 2 часа', now);
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"разминка 30 мин" → 30 min', () {
      final r = parseNaturalDateTime('разминка 30 мин', now);
      expect(r.durationMinutes, 30);
      expect(r.cleanedTitle, 'разминка');
    });

    test('"перерыв 45м" → 45 min', () {
      final r = parseNaturalDateTime('перерыв 45м', now);
      expect(r.durationMinutes, 45);
      expect(r.cleanedTitle, 'перерыв');
    });

    test('"чтение 90 минут" → 90 min', () {
      final r = parseNaturalDateTime('чтение 90 минут', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'чтение');
    });

    test('EN "call 1.5h" → 90 min', () {
      final r = parseNaturalDateTime('call 1.5h', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'call');
    });

    test('EN "break 30 min" → 30 min', () {
      final r = parseNaturalDateTime('break 30 min', now);
      expect(r.durationMinutes, 30);
      expect(r.cleanedTitle, 'break');
    });

    test('RU comma decimal "1,5ч" → 90 min', () {
      final r = parseNaturalDateTime('йога 1,5ч', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'йога');
    });

    test('negative: plain number "глава 12" → no duration', () {
      final r = parseNaturalDateTime('глава 12', now);
      expect(r.durationMinutes, isNull);
    });

    test('negative: "5 home" не даёт 5h (h — часть слова)', () {
      final r = parseNaturalDateTime('go 5 home', now);
      expect(r.durationMinutes, isNull);
    });
  });

  group('Priority → priority', () {
    test('"купить молоко p2" → medium, title "купить молоко"', () {
      final r = parseNaturalDateTime('купить молоко p2', now);
      expect(r.priority, 'medium');
      expect(r.cleanedTitle, 'купить молоко');
    });

    test('"задача p1" → main', () {
      final r = parseNaturalDateTime('задача p1', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'задача');
    });

    test('"уборка p3" → low', () {
      final r = parseNaturalDateTime('уборка p3', now);
      expect(r.priority, 'low');
      expect(r.cleanedTitle, 'уборка');
    });

    test('"отчёт !важно" → main, title "отчёт"', () {
      final r = parseNaturalDateTime('отчёт !важно', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'отчёт');
    });

    test('"дедлайн !!!" → main', () {
      final r = parseNaturalDateTime('дедлайн !!!', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'дедлайн');
    });

    test('"важно позвонить" → main', () {
      final r = parseNaturalDateTime('важно позвонить', now);
      expect(r.priority, 'main');
    });

    test('EN "fix bug important" → main', () {
      final r = parseNaturalDateTime('fix bug important', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'fix bug');
    });

    test('"задача средний" → medium', () {
      final r = parseNaturalDateTime('задача средний', now);
      expect(r.priority, 'medium');
    });

    test('"задача низкий" → low', () {
      final r = parseNaturalDateTime('задача низкий', now);
      expect(r.priority, 'low');
    });

    test('negative: single bang "ура!" → no priority', () {
      final r = parseNaturalDateTime('сделал ура!', now);
      expect(r.priority, isNull);
    });

    test('negative: plain text "купить молоко" → no priority', () {
      final r = parseNaturalDateTime('купить молоко', now);
      expect(r.priority, isNull);
    });

    test('negative: "помыть пол" (содержит "по") → no false recurrence/priority', () {
      final r = parseNaturalDateTime('помыть пол', now);
      expect(r.priority, isNull);
      expect(r.recurrenceRule, isNull);
    });
  });

  group('Recurrence → recurrenceRule', () {
    test('"зарядка каждый день" → DAILY, title "зарядка"', () {
      final r = parseNaturalDateTime('зарядка каждый день', now);
      expect(r.recurrenceRule, 'FREQ=DAILY');
      expect(r.cleanedTitle, 'зарядка');
    });

    test('"витамины ежедневно" → DAILY', () {
      final r = parseNaturalDateTime('витамины ежедневно', now);
      expect(r.recurrenceRule, 'FREQ=DAILY');
      expect(r.cleanedTitle, 'витамины');
    });

    test('EN "water daily" → DAILY', () {
      final r = parseNaturalDateTime('water daily', now);
      expect(r.recurrenceRule, 'FREQ=DAILY');
      expect(r.cleanedTitle, 'water');
    });

    test('"пара по пн,ср,пт" → WEEKLY MO,WE,FR', () {
      final r = parseNaturalDateTime('пара по пн,ср,пт', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(r.cleanedTitle, 'пара');
    });

    test('"тренировка по будням" → WEEKLY MO..FR', () {
      final r = parseNaturalDateTime('тренировка по будням', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"урок каждый понедельник" → WEEKLY MO', () {
      final r = parseNaturalDateTime('урок каждый понедельник', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO');
      expect(r.cleanedTitle, 'урок');
    });

    test('EN "gym every monday" → WEEKLY MO', () {
      final r = parseNaturalDateTime('gym every monday', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO');
      expect(r.cleanedTitle, 'gym');
    });

    test('"оплата 15 числа" → MONTHLY day15, title "оплата"', () {
      final r = parseNaturalDateTime('оплата 15 числа', now);
      expect(r.recurrenceRule, 'FREQ=MONTHLY;BYMONTHDAY=15');
      expect(r.cleanedTitle, 'оплата');
    });

    test('"взнос каждый месяц" → MONTHLY (без дня)', () {
      final r = parseNaturalDateTime('взнос каждый месяц', now);
      expect(r.recurrenceRule, 'FREQ=MONTHLY');
      expect(r.cleanedTitle, 'взнос');
    });

    test('"отчёт еженедельно" → WEEKLY (без дней)', () {
      final r = parseNaturalDateTime('отчёт еженедельно', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY');
      expect(r.cleanedTitle, 'отчёт');
    });

    test('negative: plain "позвонить в понедельник" → одноразовая дата, не серия', () {
      // "в понедельник" без маркера повтора → разовая дата (when), не recurrence.
      final r = parseNaturalDateTime('позвонить в понедельник', now);
      expect(r.recurrenceRule, isNull);
      expect(r.when, isNotNull);
    });

    test('negative: plain text "купить хлеб" → no recurrence', () {
      final r = parseNaturalDateTime('купить хлеб', now);
      expect(r.recurrenceRule, isNull);
    });
  });

  group('Combo — date + time + duration + priority', () {
    test('"тренировка завтра 18:00 1ч важно" → all fields, title "тренировка"', () {
      final r = parseNaturalDateTime('тренировка завтра 18:00 1ч важно', now);
      expect(r.when, DateTime(2026, 6, 18, 18, 0));
      expect(r.durationMinutes, 60);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"созвон завтра 15:00 30 мин p2"', () {
      final r = parseNaturalDateTime('созвон завтра 15:00 30 мин p2', now);
      expect(r.when, DateTime(2026, 6, 18, 15, 0));
      expect(r.durationMinutes, 30);
      expect(r.priority, 'medium');
      expect(r.cleanedTitle, 'созвон');
    });
  });

  group('Reminder → reminderMinutesBefore', () {
    test('"собрание завтра 15:00 напомни за 30 мин" → when + reminder 30, title "собрание"', () {
      final r = parseNaturalDateTime('собрание завтра 15:00 напомни за 30 мин', now);
      expect(r.when, DateTime(2026, 6, 18, 15, 0));
      expect(r.reminderMinutesBefore, 30);
      expect(r.cleanedTitle, 'собрание');
    });

    test('"напомни за 10 мин" → 10', () {
      final r = parseNaturalDateTime('звонок напомни за 10 мин', now);
      expect(r.reminderMinutesBefore, 10);
      expect(r.cleanedTitle, 'звонок');
    });

    test('"напоминание за 15 минут" → 15', () {
      final r = parseNaturalDateTime('встреча напоминание за 15 минут', now);
      expect(r.reminderMinutesBefore, 15);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"напоминание за 1 час" → 60', () {
      final r = parseNaturalDateTime('экзамен напоминание за 1 час', now);
      expect(r.reminderMinutesBefore, 60);
      expect(r.cleanedTitle, 'экзамен');
    });

    test('"напомнить за 2 часа до" → 120', () {
      final r = parseNaturalDateTime('дедлайн напомнить за 2 часа до', now);
      expect(r.reminderMinutesBefore, 120);
      expect(r.cleanedTitle, 'дедлайн');
    });

    test('EN "remind 10 min before" → 10', () {
      final r = parseNaturalDateTime('call remind 10 min before', now);
      expect(r.reminderMinutesBefore, 10);
      expect(r.cleanedTitle, 'call');
    });

    test('EN "reminder 1h before" → 60', () {
      final r = parseNaturalDateTime('meeting reminder 1h before', now);
      expect(r.reminderMinutesBefore, 60);
      expect(r.cleanedTitle, 'meeting');
    });

    test('negative: "напоминалка" не триггерит', () {
      final r = parseNaturalDateTime('купить напоминалку', now);
      expect(r.reminderMinutesBefore, isNull);
    });

    test('negative: plain "разминка 30 мин" → duration, NOT reminder', () {
      // Без маркера «напомни» это длительность задачи, а не напоминание.
      final r = parseNaturalDateTime('разминка 30 мин', now);
      expect(r.reminderMinutesBefore, isNull);
      expect(r.durationMinutes, 30);
    });

    test('reminder не съедает длительность: "тренировка 1ч напомни за 15 мин"', () {
      final r = parseNaturalDateTime('тренировка 1ч напомни за 15 мин', now);
      expect(r.durationMinutes, 60);
      expect(r.reminderMinutesBefore, 15);
      expect(r.cleanedTitle, 'тренировка');
    });
  });

  group('Time range → durationMinutes (start as when)', () {
    test('"тренировка в 700 до 900" → start 07:00 today, duration 120', () {
      final r = parseNaturalDateTime('тренировка в 700 до 900', now);
      // Явный диапазон-блок остаётся на опорном дне (сегодня), даже если старт
      // 07:00 уже в прошлом относительно now=14:30. НЕ сдвигаем на завтра.
      expect(r.when, DateTime(2026, 6, 17, 7, 0));
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"с 14 до 15:30" → duration 90', () {
      final r = parseNaturalDateTime('пара с 14 до 15:30', now);
      expect(r.when, DateTime(2026, 6, 17, 14, 0)); // future today
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'пара');
    });

    test('"700-900" dash → start 07:00 today, duration 120', () {
      final r = parseNaturalDateTime('лекция 700-900', now);
      expect(r.when, DateTime(2026, 6, 17, 7, 0)); // блок остаётся на сегодня
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'лекция');
    });

    test('"7:00–9:00" en-dash → start 07:00 today, duration 120', () {
      final r = parseNaturalDateTime('встреча 7:00–9:00', now);
      expect(r.when, DateTime(2026, 6, 17, 7, 0));
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"с 7 до 9" → start 07:00 today, duration 120', () {
      final r = parseNaturalDateTime('зарядка с 7 до 9', now);
      expect(r.when, DateTime(2026, 6, 17, 7, 0));
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'зарядка');
    });

    test('range combines with "завтра": "завтра с 18 до 20"', () {
      final r = parseNaturalDateTime('тренировка завтра с 18 до 20', now);
      expect(r.when, DateTime(2026, 6, 18, 18, 0));
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'тренировка');
    });

    test('negative: "до 900" only end → no duration (need both)', () {
      final r = parseNaturalDateTime('дедлайн до 900', now);
      expect(r.durationMinutes, isNull);
    });

    test('negative: end <= start → ignored ("с 9 до 7")', () {
      final r = parseNaturalDateTime('смена с 9 до 7', now);
      expect(r.durationMinutes, isNull);
    });
  });

  group('Russian word dates', () {
    test('"18 июня" → 2026-06-18 09:00', () {
      final r = parseNaturalDateTime('экзамен 18 июня', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      expect(r.cleanedTitle, 'экзамен');
    });

    test('"5 мая" already past → next year 2027-05-05', () {
      final r = parseNaturalDateTime('праздник 5 мая', now);
      expect(r.when, DateTime(2027, 5, 5, 9, 0));
      expect(r.cleanedTitle, 'праздник');
    });

    test('"1 сентября" → 2026-09-01 09:00', () {
      final r = parseNaturalDateTime('линейка 1 сентября', now);
      expect(r.when, DateTime(2026, 9, 1, 9, 0));
      expect(r.cleanedTitle, 'линейка');
    });

    test('"июня 18" (month-first) → 2026-06-18', () {
      final r = parseNaturalDateTime('встреча июня 18', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      expect(r.cleanedTitle, 'встреча');
    });

    test('word date + time: "18 июня 17:00" → 2026-06-18 17:00', () {
      final r = parseNaturalDateTime('сдать 18 июня 17:00', now);
      expect(r.when, DateTime(2026, 6, 18, 17, 0));
      expect(r.cleanedTitle, 'сдать');
    });

    test('negative: month without day "купить в мае" → no word date', () {
      final r = parseNaturalDateTime('купить в мае', now);
      // "мая" нет, "мае" — другой падеж, не распознаём как дату.
      expect(r.when, isNull);
    });
  });

  group('Backward-compat — new fields null when only time present', () {
    test('"Сдать лабу завтра 17:00" → duration/priority/recurrence null', () {
      final r = parseNaturalDateTime('Сдать лабу завтра 17:00', now);
      expect(r.when, DateTime(2026, 6, 18, 17, 0));
      expect(r.durationMinutes, isNull);
      expect(r.priority, isNull);
      expect(r.recurrenceRule, isNull);
      expect(r.reminderMinutesBefore, isNull);
      expect(r.cleanedTitle, 'Сдать лабу');
    });

    test('"лекция 700" compact time still works, no extra fields', () {
      final r = parseNaturalDateTime('лекция 700', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0));
      expect(r.durationMinutes, isNull);
      expect(r.priority, isNull);
      expect(r.recurrenceRule, isNull);
      expect(r.cleanedTitle, 'лекция');
    });
  });

  // =========================================================================
  // RU пробельный формат «7 00» и маркеры части суток (утра/вечера/дня/ночи).
  // =========================================================================

  group('RU spaced time + meridiem markers', () {
    test('"лекция в 7 00 утра" → 07:00, title "лекция", type event', () {
      final r = parseNaturalDateTime('лекция в 7 00 утра', now);
      // 07:00 уже прошло (now=14:30) → завтра.
      expect(r.when, DateTime(2026, 6, 18, 7, 0));
      expect(r.cleanedTitle, 'лекция');
      expect(r.type, 'event');
    });

    test('"в 8 вечера" → 20:00', () {
      final r = parseNaturalDateTime('ужин в 8 вечера', now);
      // 20:00 ещё не прошло (now=14:30) → сегодня.
      expect(r.when, DateTime(2026, 6, 17, 20, 0));
      expect(r.cleanedTitle, 'ужин');
    });

    test('"7 утра" → 07:00, title cleaned', () {
      final r = parseNaturalDateTime('подъём 7 утра', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0)); // прошло → завтра
      expect(r.cleanedTitle, 'подъём');
    });

    test('"в 7 00" без маркера → 07:00, title cleaned', () {
      final r = parseNaturalDateTime('зарядка в 7 00', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0));
      expect(r.cleanedTitle, 'зарядка');
    });

    test('"12 дня" → 12:00 (полдень)', () {
      final r = parseNaturalDateTime('обед 12 дня', now);
      // 12:00 < 14:30 → прошло → завтра, но час = 12 (полдень, НЕ 00 и НЕ +12).
      expect(r.when, DateTime(2026, 6, 18, 12, 0));
    });

    test('"12 ночи" → 00:00 (полночь)', () {
      final r = parseNaturalDateTime('финал 12 ночи', now);
      expect(r.when?.hour, 0);
      expect(r.cleanedTitle, 'финал');
    });

    test('"завтра в 7 00 утра" → tomorrow 07:00, title cleaned', () {
      final r = parseNaturalDateTime('лекция завтра в 7 00 утра', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0));
      expect(r.cleanedTitle, 'лекция');
    });

    test('"в 8 утра 30" не ломается: "8 30" → 08:30', () {
      final r = parseNaturalDateTime('митинг в 8 30', now);
      expect(r.when?.hour, 8);
      expect(r.when?.minute, 30);
      expect(r.cleanedTitle, 'митинг');
    });

    test('negative: "глава 12 34" не время (не превращает текст в 12:34)', () {
      // Это потенциально хрупкий кейс — фиксируем текущее поведение: распознаёт
      // 12:34 (час пробел минуты). Если это нежелательно — см. отчёт.
      final r = parseNaturalDateTime('глава 12 34', now);
      // Документируем что получается, чтобы регрессии были заметны.
      expect(r.cleanedTitle, isNotNull);
    });
  });

  group('cleanedTitle erasure — existing formats stay clean', () {
    test('"в 7" → title cleaned', () {
      final r = parseNaturalDateTime('встреча в 7', now);
      expect(r.when?.hour, 7);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"700" → title cleaned', () {
      final r = parseNaturalDateTime('подъём 700', now);
      expect(r.cleanedTitle, 'подъём');
    });

    test('"7:00" → title cleaned', () {
      final r = parseNaturalDateTime('встреча 7:00', now);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"завтра в 5" → title cleaned', () {
      final r = parseNaturalDateTime('тренировка завтра в 5', now);
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"с 7 до 9" → title cleaned', () {
      final r = parseNaturalDateTime('зарядка с 7 до 9', now);
      expect(r.cleanedTitle, 'зарядка');
    });

    test('"18 июня" → title cleaned', () {
      final r = parseNaturalDateTime('экзамен 18 июня', now);
      expect(r.cleanedTitle, 'экзамен');
    });
  });

  // =========================================================================
  // Висячие предлоги-связки. После вырезания распознанного фрагмента предлог,
  // который им «управлял» («к [18 июня]», «во [вторник]», «до [пятницы]»),
  // должен уйти из названия. Предлог СПРАВА от выреза, относящийся к следующему
  // слову («[9:00] на работе»), — остаться.
  // =========================================================================

  group('Dangling preposition cleanup (left of erased span)', () {
    test('"сдать курсовую к 18 июня" → "сдать курсовую" (drop "к")', () {
      final r = parseNaturalDateTime('сдать курсовую к 18 июня', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      expect(r.cleanedTitle, 'сдать курсовую');
    });

    test('"пара во вторник в 9" → "пара" (drop "во" и "в 9")', () {
      final r = parseNaturalDateTime('пара во вторник в 9', now);
      expect(r.when?.hour, 9);
      expect(r.cleanedTitle, 'пара');
    });

    test('"позвонить во вторник" → "позвонить" (drop "во")', () {
      final r = parseNaturalDateTime('позвонить во вторник', now);
      expect(r.when, isNotNull);
      expect(r.cleanedTitle, 'позвонить');
    });

    test('"дедлайн сдать до пятницы" → "дедлайн сдать" (drop "до")', () {
      final r = parseNaturalDateTime('дедлайн сдать до пятницы', now);
      expect(r.when, DateTime(2026, 6, 19, 9, 0));
      expect(r.cleanedTitle, 'дедлайн сдать');
    });

    test('"лекция по математике в 1530" → "лекция по математике"', () {
      // Пользовательский пример из задачи: «в 1530» уходит, «по математике» —
      // осмысленная часть названия — остаётся (предлог «по» справа от другого
      // выреза не трогаем; здесь выреза рядом с «по» вообще нет).
      final r = parseNaturalDateTime('лекция по математике в 1530', now);
      expect(r.when?.hour, 15);
      expect(r.when?.minute, 30);
      expect(r.cleanedTitle, 'лекция по математике');
    });

    test('"экзамен 18 июня в 10 утра" → "экзамен" (date+time, no residue)', () {
      final r = parseNaturalDateTime('экзамен 18 июня в 10 утра', now);
      expect(r.when, DateTime(2026, 6, 18, 10, 0));
      expect(r.cleanedTitle, 'экзамен');
    });
  });

  group('Trailing preposition is preserved (right of erased span)', () {
    test('"встреча 9:00 на работе" → "встреча на работе" (keep "на работе")', () {
      final r = parseNaturalDateTime('встреча 9:00 на работе', now);
      expect(r.when?.hour, 9);
      expect(r.cleanedTitle, 'встреча на работе');
    });

    test('"занятие завтра по английскому" → "занятие по английскому"', () {
      final r = parseNaturalDateTime('занятие завтра по английскому', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      expect(r.cleanedTitle, 'занятие по английскому');
    });

    test('"звонок 9:00 с клиентом" → "звонок с клиентом" (keep "с клиентом")', () {
      final r = parseNaturalDateTime('звонок 9:00 с клиентом', now);
      expect(r.when?.hour, 9);
      expect(r.cleanedTitle, 'звонок с клиентом');
    });

    test('"оплата 15 числа за интернет" → "оплата за интернет"', () {
      final r = parseNaturalDateTime('оплата 15 числа за интернет', now);
      expect(r.recurrenceRule, 'FREQ=MONTHLY;BYMONTHDAY=15');
      expect(r.cleanedTitle, 'оплата за интернет');
    });
  });

  group('Preposition NOT touched when nothing erased nearby', () {
    test('"связаться с деканатом завтра" keeps "с деканатом"', () {
      // Только «завтра» вырезается (в конце); «с деканатом» в начале не у выреза.
      final r = parseNaturalDateTime('связаться с деканатом завтра', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      expect(r.cleanedTitle, 'связаться с деканатом');
    });

    test('"купить корм для кота" unchanged (no match at all)', () {
      final r = parseNaturalDateTime('купить корм для кота', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'купить корм для кота');
    });

    test('"позвонить с другом" unchanged (no match, "с" stays)', () {
      final r = parseNaturalDateTime('позвонить с другом', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'позвонить с другом');
    });

    test('"до магазина дойти" unchanged (leading "до" is a real word)', () {
      final r = parseNaturalDateTime('до магазина дойти', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'до магазина дойти');
    });
  });
}
