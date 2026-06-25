// Unit-тесты частото-зависимого стрика привычек (ADR-053, slice 1).
// Только чистые функции: computeHabitStats / isScheduledDay. БЕЗ БД.
//
// Календарь июня 2026 (для справки):
//   Пн  1  8 15 22 29
//   Вт  2  9 16 23 30
//   Ср  3 10 17 24
//   Чт  4 11 18 25
//   Пт  5 12 19 26
//   Сб  6 13 20 27
//   Вс  7 14 21 28
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/database/daos/habits_dao.dart';

void main() {
  // Маска Пн/Ср/Пт = бит1 + бит4 + бит16 = 21.
  const monWedFri = 1 | 4 | 16; // 21

  group('isScheduledDay', () {
    test('daily — всегда запланировано', () {
      // Любой день недели.
      for (var day = 22; day <= 28; day++) {
        final d = DateTime.utc(2026, 6, day);
        expect(isScheduledDay(d, 'daily', 0), isTrue);
      }
    });

    test('weekly_count — всегда запланировано (недели считаются отдельно)', () {
      final tuesday = DateTime.utc(2026, 6, 23);
      expect(isScheduledDay(tuesday, 'weekly_count', 0), isTrue);
    });

    test('weekly_days — только дни из маски', () {
      final monday = DateTime.utc(2026, 6, 22); // Пн
      final tuesday = DateTime.utc(2026, 6, 23); // Вт
      final wednesday = DateTime.utc(2026, 6, 24); // Ср
      final friday = DateTime.utc(2026, 6, 26); // Пт
      final sunday = DateTime.utc(2026, 6, 28); // Вс
      expect(isScheduledDay(monday, 'weekly_days', monWedFri), isTrue);
      expect(isScheduledDay(tuesday, 'weekly_days', monWedFri), isFalse);
      expect(isScheduledDay(wednesday, 'weekly_days', monWedFri), isTrue);
      expect(isScheduledDay(friday, 'weekly_days', monWedFri), isTrue);
      expect(isScheduledDay(sunday, 'weekly_days', monWedFri), isFalse);
    });
  });

  group('daily streak (без изменений)', () {
    test('три выполненных дня подряд → стрик 3', () {
      final now = DateTime.utc(2026, 6, 25); // Чт
      final s = computeHabitStats(
        dayCounts: {
          '2026-06-23': 1,
          '2026-06-24': 1,
          '2026-06-25': 1,
        },
        type: 'good',
        targetPerDay: 1,
        frequencyType: 'daily',
        now: now,
      );
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
    });
  });

  group('weekly_days streak', () {
    test('дни отдыха (Вт/Чт) не рвут стрик — Пн/Ср/Пт выполнены', () {
      final now = DateTime.utc(2026, 6, 26); // Пт
      final s = computeHabitStats(
        dayCounts: {
          '2026-06-22': 1, // Пн ✓
          '2026-06-24': 1, // Ср ✓
          '2026-06-26': 1, // Пт ✓
          // Вт 23 и Чт 25 — дни отдыха (не запланированы), логов нет.
        },
        type: 'good',
        targetPerDay: 1,
        frequencyType: 'weekly_days',
        weekdayMask: monWedFri,
        now: now,
      );
      // Пн+Ср+Пт подряд, дни отдыха между ними пропущены → стрик 3.
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
    });

    test('пропущенный ЗАПЛАНИРОВАННЫЙ день (Ср) рвёт стрик', () {
      final now = DateTime.utc(2026, 6, 26); // Пт
      final s = computeHabitStats(
        dayCounts: {
          '2026-06-22': 1, // Пн ✓
          // Ср 24 пропущена (запланирована, не выполнена)
          '2026-06-26': 1, // Пт ✓
        },
        type: 'good',
        targetPerDay: 1,
        frequencyType: 'weekly_days',
        weekdayMask: monWedFri,
        now: now,
      );
      // Сегодня (Пт) выполнено = 1; идём назад: Чт пропуск (отдых),
      // Ср запланирована и НЕ выполнена → разрыв. Стрик = 1.
      expect(s.currentStreak, 1);
    });

    test('сегодня запланировано, но ещё не выполнено — стрик не рвётся', () {
      final now = DateTime.utc(2026, 6, 26); // Пт, ещё не отмечен
      final s = computeHabitStats(
        dayCounts: {
          '2026-06-22': 1, // Пн ✓
          '2026-06-24': 1, // Ср ✓
          // Пт 26 ещё не выполнен (день не закончился)
        },
        type: 'good',
        targetPerDay: 1,
        frequencyType: 'weekly_days',
        weekdayMask: monWedFri,
        now: now,
      );
      // Пт не отмечен, но день идёт → не рвёт; Ср+Пн дают стрик 2.
      expect(s.currentStreak, 2);
    });
  });

  group('weekly_count streak', () {
    test('подряд успешные недели считаются; текущая в процессе не рвёт', () {
      final now = DateTime.utc(2026, 6, 25); // Чт, неделя Пн 22 в процессе
      final s = computeHabitStats(
        dayCounts: {
          '2026-06-01': 1, // неделя Пн 1: 1 < 3 → НЕуспешна
          '2026-06-08': 4, // неделя Пн 8: 4 >= 3 → успешна
          '2026-06-15': 3, // неделя Пн 15: 3 >= 3 → успешна
          '2026-06-22': 1, // текущая неделя Пн 22: 1 < 3 → ещё не успешна
        },
        type: 'good',
        targetPerDay: 1,
        frequencyType: 'weekly_count',
        weeklyTarget: 3,
        now: now,
      );
      // Текущая неделя (1<3) не рвёт; назад: неделя 15 ✓, неделя 8 ✓,
      // неделя 1 (1<3) рвёт. → стрик 2 успешных недели.
      expect(s.currentStreak, 2);
      expect(s.bestStreak, 2);
      expect(s.totalCompletions, 2); // две успешные недели
    });

    test('одна успешная неделя в прошлом + успешная текущая → стрик 2', () {
      final now = DateTime.utc(2026, 6, 25);
      final s = computeHabitStats(
        dayCounts: {
          '2026-06-15': 3, // прошлая неделя ✓
          '2026-06-22': 3, // текущая неделя уже успешна ✓
        },
        type: 'good',
        targetPerDay: 1,
        frequencyType: 'weekly_count',
        weeklyTarget: 3,
        now: now,
      );
      expect(s.currentStreak, 2);
    });
  });
}
