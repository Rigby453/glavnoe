// Юнит-тесты библиотеки повторов (lib/features/plan/recurrence.dart) и чистых
// функций раскрытия (mergeOccurrencesForDay/Range из recurrence_providers.dart).
// Чистый Dart + минимально Drift (для ItemsTableData как value-object).

import 'package:app/core/database/database.dart';
import 'package:app/features/plan/recurrence.dart';
import 'package:app/features/plan/widgets/recurrence_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Фабрика тестового item (concrete или anchor).
ItemsTableData item({
  required String id,
  required DateTime scheduledAt,
  String? recurrenceRule,
  String status = 'pending',
  String priority = 'medium',
  String title = 'T',
}) {
  return ItemsTableData(
    id: id,
    userId: 'local',
    title: title,
    type: 'task',
    priority: priority,
    status: status,
    scheduledAt: scheduledAt,
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: recurrenceRule,
    moduleLink: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('RecurrenceRule.parse / toRuleString round-trip', () {
    test('FREQ=DAILY only', () {
      final r = RecurrenceRule.parse('FREQ=DAILY');
      expect(r, isNotNull);
      expect(r!.freq, RecurFreq.daily);
      expect(r.until, isNull);
      expect(r.exDates, isEmpty);
      expect(r.toRuleString(), 'FREQ=DAILY');
    });

    test('with UNTIL', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;UNTIL=2026-07-01');
      expect(r!.until, DateTime(2026, 7, 1));
      expect(r.toRuleString(), 'FREQ=DAILY;UNTIL=2026-07-01');
    });

    test('with EXDATE (sorted on serialize)', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;EXDATE=20260625,20260623');
      expect(r!.exDates.length, 2);
      // EXDATE сериализуются отсортированными по возрастанию.
      expect(r.toRuleString(), 'FREQ=DAILY;EXDATE=20260623,20260625');
    });

    test('with UNTIL and EXDATE — full round-trip', () {
      const raw = 'FREQ=DAILY;UNTIL=2026-08-15;EXDATE=20260623,20260624';
      final r = RecurrenceRule.parse(raw);
      expect(r!.toRuleString(), raw);
    });

    test('null / empty / non-series → null', () {
      expect(RecurrenceRule.parse(null), isNull);
      expect(RecurrenceRule.parse(''), isNull);
      expect(RecurrenceRule.parse('   '), isNull);
      // Без FREQ=DAILY — не серия (например, чужой/неподдерживаемый формат).
      expect(RecurrenceRule.parse('FREQ=WEEKLY'), isNull);
      expect(RecurrenceRule.parse('UNTIL=2026-07-01'), isNull);
    });

    test('exDates compared by Y/M/D only (time stripped)', () {
      final r = RecurrenceRule(
        exDates: {DateTime(2026, 6, 23, 14, 30)},
      );
      expect(r.exDates.contains(DateTime(2026, 6, 23)), isTrue);
      expect(r.toRuleString(), 'FREQ=DAILY;EXDATE=20260623');
    });
  });

  group('occursOn boundaries', () {
    final anchor = DateTime(2026, 6, 22, 9, 0);

    test('before anchor start → false', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 21)), isFalse);
    });

    test('on anchor start day → true', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 22, 23, 59)), isTrue);
    });

    test('after start, open-ended → true', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(occursOn(r, anchor, DateTime(2026, 12, 31)), isTrue);
    });

    test('UNTIL is inclusive', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;UNTIL=2026-06-25')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 25)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 6, 26)), isFalse);
    });

    test('EXDATE excludes that day only', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;EXDATE=20260624')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 23)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 6, 24)), isFalse);
      expect(occursOn(r, anchor, DateTime(2026, 6, 25)), isTrue);
    });
  });

  group('occurrenceDatesInRange', () {
    final anchor = DateTime(2026, 6, 22, 9, 0);

    test('generates each day in window', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 25),
      );
      expect(dates, [
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 23),
        DateTime(2026, 6, 24),
        DateTime(2026, 6, 25),
      ]);
    });

    test('respects UNTIL and EXDATE within range', () {
      final r =
          RecurrenceRule.parse('FREQ=DAILY;UNTIL=2026-06-25;EXDATE=20260623')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 21),
        DateTime(2026, 6, 30),
      );
      expect(dates, [
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 24),
        DateTime(2026, 6, 25),
      ]);
    });

    test('empty when range before anchor', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 10),
      );
      expect(dates, isEmpty);
    });

    test('inverted range → empty', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 25),
        DateTime(2026, 6, 22),
      );
      expect(dates, isEmpty);
    });
  });

  group('addExDateToRule / setUntilOnRule helpers', () {
    test('addExDateToRule adds and is idempotent', () {
      var raw = 'FREQ=DAILY';
      raw = addExDateToRule(raw, DateTime(2026, 6, 24))!;
      expect(raw, 'FREQ=DAILY;EXDATE=20260624');
      // Повтор той же даты не дублирует.
      raw = addExDateToRule(raw, DateTime(2026, 6, 24, 10, 0))!;
      expect(raw, 'FREQ=DAILY;EXDATE=20260624');
      raw = addExDateToRule(raw, DateTime(2026, 6, 23))!;
      expect(raw, 'FREQ=DAILY;EXDATE=20260623,20260624');
    });

    test('addExDateToRule on non-series returns input unchanged', () {
      expect(addExDateToRule(null, DateTime(2026, 6, 24)), isNull);
      expect(addExDateToRule('FREQ=WEEKLY', DateTime(2026, 6, 24)),
          'FREQ=WEEKLY');
    });

    test('setUntilOnRule sets/replaces UNTIL', () {
      var raw = 'FREQ=DAILY';
      raw = setUntilOnRule(raw, DateTime(2026, 6, 21))!;
      expect(raw, 'FREQ=DAILY;UNTIL=2026-06-21');
      // Замена существующего UNTIL.
      raw = setUntilOnRule(raw, DateTime(2026, 6, 30))!;
      expect(raw, 'FREQ=DAILY;UNTIL=2026-06-30');
    });

    test('setUntilOnRule preserves EXDATE', () {
      const raw = 'FREQ=DAILY;EXDATE=20260623';
      final out = setUntilOnRule(raw, DateTime(2026, 6, 30))!;
      expect(out, 'FREQ=DAILY;UNTIL=2026-06-30;EXDATE=20260623');
    });
  });

  group('virtual id helpers', () {
    test('isVirtualOccurrenceId', () {
      expect(isVirtualOccurrenceId('abc@20260622'), isTrue);
      expect(isVirtualOccurrenceId('abc'), isFalse);
    });

    test('anchorIdFromVirtual / dateFromVirtual', () {
      expect(anchorIdFromVirtual('abc@20260622'), 'abc');
      expect(anchorIdFromVirtual('plain'), 'plain');
      expect(dateFromVirtual('abc@20260622'), DateTime(2026, 6, 22));
      expect(dateFromVirtual('plain'), isNull);
    });

    test('round-trip via buildVirtualOccurrence', () {
      final anchor = item(
        id: 'anchor1',
        scheduledAt: DateTime(2026, 6, 22, 9, 30),
        recurrenceRule: 'FREQ=DAILY',
      );
      final v = buildVirtualOccurrence(anchor, DateTime(2026, 6, 25));
      expect(v.id, 'anchor1@20260625');
      expect(v.scheduledAt, DateTime(2026, 6, 25, 9, 30));
      expect(v.recurrenceRule, isNull);
      expect(v.status, 'pending');
      expect(anchorIdFromVirtual(v.id), 'anchor1');
      expect(dateFromVirtual(v.id), DateTime(2026, 6, 25));
    });
  });

  group('mergeOccurrencesForDay (pure)', () {
    final anchor = item(
      id: 'a1',
      scheduledAt: DateTime(2026, 6, 22, 8, 0),
      recurrenceRule: 'FREQ=DAILY',
    );

    test('adds virtual occurrence on a matching day, sorted', () {
      final concrete = [
        item(id: 'c1', scheduledAt: DateTime(2026, 6, 23, 12, 0)),
      ];
      final merged =
          mergeOccurrencesForDay(concrete, [anchor], DateTime(2026, 6, 23));
      expect(merged.length, 2);
      // Виртуал в 08:00 идёт раньше concrete в 12:00.
      expect(merged[0].id, 'a1@20260623');
      expect(merged[1].id, 'c1');
    });

    test('no virtual before anchor start', () {
      final merged =
          mergeOccurrencesForDay([], [anchor], DateTime(2026, 6, 21));
      expect(merged, isEmpty);
    });

    test('EXDATE day yields no virtual (materialized day)', () {
      final exAnchor = item(
        id: 'a1',
        scheduledAt: DateTime(2026, 6, 22, 8, 0),
        recurrenceRule: 'FREQ=DAILY;EXDATE=20260623',
      );
      final concrete = [
        item(id: 'c1', scheduledAt: DateTime(2026, 6, 23, 8, 0)),
      ];
      final merged =
          mergeOccurrencesForDay(concrete, [exAnchor], DateTime(2026, 6, 23));
      // Только concrete; виртуал на 23-е исключён EXDATE.
      expect(merged.length, 1);
      expect(merged[0].id, 'c1');
    });

    test('past UNTIL yields no virtual', () {
      final untilAnchor = item(
        id: 'a1',
        scheduledAt: DateTime(2026, 6, 22, 8, 0),
        recurrenceRule: 'FREQ=DAILY;UNTIL=2026-06-25',
      );
      final merged =
          mergeOccurrencesForDay([], [untilAnchor], DateTime(2026, 6, 26));
      expect(merged, isEmpty);
    });

    test('non-series anchor ignored', () {
      final notSeries =
          item(id: 'x', scheduledAt: DateTime(2026, 6, 22, 8, 0));
      final merged =
          mergeOccurrencesForDay([], [notSeries], DateTime(2026, 6, 23));
      expect(merged, isEmpty);
    });
  });

  group('mergeOccurrencesForRange (pure)', () {
    final anchor = item(
      id: 'a1',
      scheduledAt: DateTime(2026, 6, 22, 8, 0),
      recurrenceRule: 'FREQ=DAILY',
    );

    test('expands across the week, merged with concrete', () {
      final concrete = [
        item(id: 'c1', scheduledAt: DateTime(2026, 6, 23, 12, 0)),
      ];
      final merged = mergeOccurrencesForRange(
        concrete,
        [anchor],
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 24),
      );
      // 3 виртуала (22,23,24) + 1 concrete = 4.
      expect(merged.length, 4);
      final ids = merged.map((e) => e.id).toList();
      expect(ids.contains('a1@20260622'), isTrue);
      expect(ids.contains('a1@20260623'), isTrue);
      expect(ids.contains('a1@20260624'), isTrue);
      expect(ids.contains('c1'), isTrue);
    });
  });
}
