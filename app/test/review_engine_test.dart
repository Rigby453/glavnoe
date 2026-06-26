// Юнит-тесты чистой логики разбора (review_engine): слоты, маппинг AI-планов.
// Не требуют Drift/виджетов.

import 'package:app/core/database/database.dart';
import 'package:app/features/today/widgets/review_engine.dart';
import 'package:flutter_test/flutter_test.dart';

ItemsTableData _item(
  String id, {
  DateTime? scheduledAt,
  String priority = 'medium',
  bool isProtected = false,
  int durationMinutes = 30,
}) {
  return ItemsTableData(
    id: id,
    userId: 'local',
    title: id,
    type: 'task',
    priority: priority,
    status: 'pending',
    // null = задача без времени суток (полночь): должна распределиться по слотам.
    scheduledAt: scheduledAt ?? DateTime(2026, 6, 9),
    durationMinutes: durationMinutes,
    isProtected: isProtected,
    recurrenceRule: null,
    reminderMinutesBefore: null,
    moduleLink: null,
    color: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('priorityWeight', () {
    test('orders main > high > medium > low', () {
      expect(priorityWeight('main'), 4);
      expect(priorityWeight('high'), 3);
      expect(priorityWeight('medium'), 2);
      expect(priorityWeight('low'), 1);
      expect(priorityWeight('unknown'), 1);
    });
  });

  group('slotKey', () {
    test('rounds minutes down to :00 / :30', () {
      expect(slotKey(DateTime(2026, 1, 1, 9, 15)), '09:00');
      expect(slotKey(DateTime(2026, 1, 1, 9, 45)), '09:30');
      expect(slotKey(DateTime(2026, 1, 1, 14, 0)), '14:00');
    });
  });

  group('freeSlots', () {
    final day = DateTime(2026, 6, 10);

    test('full day has 28 half-hour slots (08:00–22:00)', () {
      expect(freeSlots(day, {}).length, 28);
    });

    test('excludes occupied slots', () {
      final slots = freeSlots(day, {'09:00', '09:30'});
      expect(slots.length, 26);
      expect(slots.any((s) => slotKey(s) == '09:00'), isFalse);
      expect(slots.any((s) => slotKey(s) == '10:00'), isTrue);
    });
  });

  group('distributeToDay (bulk move — no stacking)', () {
    final day = DateTime(2026, 6, 10);

    test('items WITHOUT time get DIFFERENT scheduledAt (no stack)', () {
      // 5 задач без времени (полночь предыдущего дня) — главный баг-кейс.
      final items = [
        for (var i = 0; i < 5; i++) _item('t$i', scheduledAt: DateTime(2026, 6, 9)),
      ];
      final assign = distributeToDay(items, day, const []);

      expect(assign.length, 5);
      // Все назначенные времена различны — нет стака в одну точку.
      final times = assign.values.toSet();
      expect(times.length, 5, reason: 'все 5 задач должны встать на разное время');
      // Все на целевой день.
      for (final t in assign.values) {
        expect(t.year, day.year);
        expect(t.month, day.month);
        expect(t.day, day.day);
      }
    });

    test('keeps time-of-day when an item had its own time', () {
      final items = [
        _item('a', scheduledAt: DateTime(2026, 6, 9, 9, 30)),
        _item('b', scheduledAt: DateTime(2026, 6, 9, 14, 0)),
      ];
      final assign = distributeToDay(items, day, const []);

      expect(assign['a'], DateTime(2026, 6, 10, 9, 30));
      expect(assign['b'], DateTime(2026, 6, 10, 14, 0));
    });

    test('two items at the same time do not collide — second is shifted', () {
      final items = [
        _item('a', scheduledAt: DateTime(2026, 6, 9, 9, 0)),
        _item('b', scheduledAt: DateTime(2026, 6, 9, 9, 0)),
      ];
      final assign = distributeToDay(items, day, const []);

      expect(assign.values.toSet().length, 2,
          reason: 'две задачи на 09:00 не должны слиться');
    });

    test('protected/main items keep their exact time and are not displaced', () {
      final items = [
        _item('p',
            scheduledAt: DateTime(2026, 6, 9, 9, 0),
            priority: 'main',
            isProtected: true),
        // Гибкая задача тоже хочет 09:00 — но слот занят защищённой.
        _item('x', scheduledAt: DateTime(2026, 6, 9, 9, 0)),
      ];
      final assign = distributeToDay(items, day, const []);

      expect(assign['p'], DateTime(2026, 6, 10, 9, 0));
      expect(assign['x'], isNot(DateTime(2026, 6, 10, 9, 0)));
    });

    test('avoids slots already occupied on the target day', () {
      final items = [_item('a', scheduledAt: DateTime(2026, 6, 9))];
      final existing = [_item('e', scheduledAt: DateTime(2026, 6, 10, 8, 0))];
      final assign = distributeToDay(items, day, existing);

      // 08:00 занят существующей задачей — новая встаёт позже.
      expect(assign['a'], isNot(DateTime(2026, 6, 10, 8, 0)));
    });

    test('long task (300 min) reserves its whole span — next task starts after',
        () {
      // Тренировка 5ч (10 слотов по 30 мин) + обычная задача 30 мин.
      // Разный приоритет → детерминированный порядок раскладки (long первой).
      final items = [
        _item('long',
            scheduledAt: DateTime(2026, 6, 9),
            durationMinutes: 300,
            priority: 'high'),
        _item('next',
            scheduledAt: DateTime(2026, 6, 9),
            durationMinutes: 30,
            priority: 'medium'),
      ];
      final assign = distributeToDay(items, day, const []);

      final longStart = assign['long']!;
      final nextStart = assign['next']!;
      // long встаёт в начало окна (08:00) и занимает 10 слотов до 13:00.
      expect(longStart, DateTime(2026, 6, 10, 8, 0));
      final longEnd = longStart.add(const Duration(minutes: 300));
      // next НЕ должна попасть ВНУТРЬ интервала длинной задачи.
      expect(nextStart.isBefore(longEnd), isFalse,
          reason: 'короткая задача не должна влезать в интервал 5-часовой');
      expect(nextStart, DateTime(2026, 6, 10, 13, 0));
    });

    test('two movable tasks with duration never share a slot', () {
      // Две переносимые задачи по 90 мин (3 слота каждая) без времени.
      final items = [
        _item('x', scheduledAt: DateTime(2026, 6, 9), durationMinutes: 90),
        _item('y', scheduledAt: DateTime(2026, 6, 9), durationMinutes: 90),
      ];
      final assign = distributeToDay(items, day, const []);

      final xStart = assign['x']!;
      final yStart = assign['y']!;
      final xEnd = xStart.add(const Duration(minutes: 90));
      final yEnd = yStart.add(const Duration(minutes: 90));
      // Интервалы [start, end) не пересекаются.
      final overlap = xStart.isBefore(yEnd) && yStart.isBefore(xEnd);
      expect(overlap, isFalse, reason: 'интервалы задач не должны пересекаться');
    });

    test('flexible task with own time reserves slots for its duration', () {
      // Задача в 09:00 на 2ч (4 слота) + задача без времени.
      final items = [
        _item('block',
            scheduledAt: DateTime(2026, 6, 9, 9, 0), durationMinutes: 120),
        _item('fill', scheduledAt: DateTime(2026, 6, 9), durationMinutes: 30),
      ];
      final assign = distributeToDay(items, day, const []);

      expect(assign['block'], DateTime(2026, 6, 10, 9, 0));
      final fill = assign['fill']!;
      // fill не должна попасть в 09:00–11:00 (слоты заняты block).
      final inBlock = !fill.isBefore(DateTime(2026, 6, 10, 9, 0)) &&
          fill.isBefore(DateTime(2026, 6, 10, 11, 0));
      expect(inBlock, isFalse,
          reason: 'fill не должна попасть в интервал block (09:00–11:00)');
    });
  });

  group('mapAiPlans', () {
    test('maps plans with items into PlanVariants', () {
      final raw = [
        {
          'label': 'Balanced',
          'reason': 'spread out',
          'items': [
            {'id': 'a', 'scheduled_at': '2026-06-10T09:00:00.000Z'},
            {'id': 'b', 'scheduled_at': '2026-06-10T11:00:00.000Z'},
          ],
        },
      ];
      final plans = mapAiPlans(raw);
      expect(plans.length, 1);
      expect(plans.first.label, 'Balanced');
      expect(plans.first.reason, 'spread out');
      expect(plans.first.assign.keys, containsAll(['a', 'b']));
    });

    test('skips plans without usable items and tolerates malformed input', () {
      final raw = [
        {'label': 'Empty', 'items': <dynamic>[]},
        {'label': 'Bad items', 'items': 'not-a-list'},
        'garbage',
        {
          'items': [
            {'id': 'x', 'scheduled_at': '2026-06-10T10:00:00.000Z'},
          ],
        },
      ];
      final plans = mapAiPlans(raw);
      // Только последний план имеет валидные items.
      expect(plans.length, 1);
      expect(plans.first.label, 'AI plan'); // дефолтная подпись
      expect(plans.first.assign.keys, ['x']);
    });
  });
}
