// Тесты «оконных» вычислений календарного дня в ЛОКАЛЬНОМ времени.
//
// Регрессия таймзоны: scheduledAt хранится Drift и читается обратно как ЛОКАЛЬНЫЙ
// DateTime, но раньше границы дня строились через DateTime.utc(...). На хосте
// Europe/Moscow (UTC+3) окно «сегодня» съезжало на 3 часа, и задача на 01:00
// уезжала в предыдущий календарный день. Эти тесты проходят ТОЛЬКО на
// положительном смещении (например UTC+3) — CI/локальный прогон ведём в Москве.
//
// In-memory Drift (NativeDatabase.memory()), чистый Dart — как в *_dao_test.dart.

import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/database.dart';
import 'package:app/core/utils/day_window.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('day_window pure helpers', () {
    test('localDayStart обнуляет время до локальной полуночи', () {
      final d = DateTime(2026, 6, 23, 23, 30);
      final start = localDayStart(d);
      expect(start, DateTime(2026, 6, 23));
      expect(start.hour, 0);
      expect(start.minute, 0);
      // Чистое local-время (не UTC).
      expect(start.isUtc, isFalse);
    });

    test('localDayEnd — начало следующего локального дня', () {
      final d = DateTime(2026, 6, 23, 1, 0);
      expect(localDayEnd(d), DateTime(2026, 6, 24));
      expect(localDayEnd(d).difference(localDayStart(d)),
          const Duration(days: 1));
    });

    test('localDayKey строится по локальным компонентам, без ведущих нулей', () {
      expect(localDayKey(DateTime(2026, 6, 23, 23, 0)), '2026-6-23');
      // Время суток не влияет на ключ.
      expect(localDayKey(DateTime(2026, 6, 23, 1, 0)), '2026-6-23');
    });

    test('isSameLocalDay сравнивает только Y/M/D', () {
      expect(
        isSameLocalDay(DateTime(2026, 6, 23, 1, 0), DateTime(2026, 6, 23, 23, 0)),
        isTrue,
      );
      expect(
        isSameLocalDay(DateTime(2026, 6, 23, 23, 0), DateTime(2026, 6, 24, 1, 0)),
        isFalse,
      );
    });
  });

  group('watchTodayItems учитывает local-границы дня', () {
    late AppDatabase db;
    late ItemsDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = ItemsDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertTask({
      required String id,
      required DateTime scheduledAt,
    }) async {
      final now = DateTime.now();
      await dao.insertItem(ItemsTableCompanion(
        id: Value(id),
        userId: const Value('local'),
        title: Value('task-$id'),
        type: const Value('task'),
        priority: const Value('medium'),
        status: const Value('pending'),
        scheduledAt: Value(scheduledAt),
        durationMinutes: const Value(30),
        isProtected: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
    }

    test(
        'задачи у краёв суток (01:00 и 23:00) попадают в свой локальный день, '
        'а не в соседний', () async {
      // Обе задачи — локальное «настенное» время 23 июня 2026.
      await insertTask(id: 'early', scheduledAt: DateTime(2026, 6, 23, 1, 0));
      await insertTask(id: 'late', scheduledAt: DateTime(2026, 6, 23, 23, 0));

      final today = await dao.watchTodayItems(DateTime(2026, 6, 23)).first;
      final todayIds = today.map((i) => i.id).toSet();
      expect(
        todayIds,
        containsAll(<String>['early', 'late']),
        reason: 'обе задачи 23 июня должны попасть в окно 23 июня '
            '(до фикса 01:00-задача уезжала в 22 июня на UTC+3)',
      );

      // Соседние дни не должны содержать ни одну из задач.
      final prev = await dao.watchTodayItems(DateTime(2026, 6, 22)).first;
      expect(prev.map((i) => i.id), isNot(contains('early')));
      expect(prev.map((i) => i.id), isNot(contains('late')));

      final next = await dao.watchTodayItems(DateTime(2026, 6, 24)).first;
      expect(next.map((i) => i.id), isNot(contains('early')));
      expect(next.map((i) => i.id), isNot(contains('late')));
    });
  });
}
