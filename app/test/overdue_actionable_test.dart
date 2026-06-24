// Юнит-тесты для:
// 1. watchOverdueActionable — новый DAO-запрос просроченных task/deadline/exam.
// 2. Математика «перенести на завтра» (дата + время суток) — та же логика, что
//    в _MoveToTomorrowButton.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

Future<String> _insert(
  ItemsDao dao, {
  required String id,
  required DateTime scheduledAt,
  String type = 'task',
  String status = 'pending',
  String? recurrenceRule,
}) async {
  final now = DateTime.now();
  await dao.insertItem(ItemsTableCompanion(
    id: Value(id),
    userId: const Value('local'),
    title: Value(id),
    type: Value(type),
    priority: const Value('medium'),
    status: Value(status),
    scheduledAt: Value(scheduledAt),
    durationMinutes: const Value(30),
    isProtected: const Value(false),
    recurrenceRule: Value(recurrenceRule),
    createdAt: Value(now),
    updatedAt: Value(now),
  ));
  return id;
}

void main() {
  late AppDatabase db;
  late ItemsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ItemsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // watchOverdueActionable
  // ---------------------------------------------------------------------------
  group('watchOverdueActionable', () {
    test('включает task, deadline, exam с scheduledAt < сегодня', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);

      await _insert(dao, id: 'task1', scheduledAt: yesterday, type: 'task');
      await _insert(dao, id: 'dl1', scheduledAt: yesterday, type: 'deadline');
      await _insert(dao, id: 'ex1', scheduledAt: yesterday, type: 'exam');

      final items = await dao.watchOverdueActionable(now).first;
      final ids = items.map((i) => i.id).toList();
      expect(ids, containsAll(['task1', 'dl1', 'ex1']));
      expect(ids.length, 3);
    });

    test('НЕ включает event (тип event исключён)', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);

      await _insert(dao, id: 'ev1', scheduledAt: yesterday, type: 'event');

      final items = await dao.watchOverdueActionable(now).first;
      expect(items, isEmpty);
    });

    test('НЕ включает выполненные/пропущенные (status done/skipped)', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);

      await _insert(dao,
          id: 'done1', scheduledAt: yesterday, type: 'task', status: 'done');
      await _insert(dao,
          id: 'skip1',
          scheduledAt: yesterday,
          type: 'deadline',
          status: 'skipped');

      final items = await dao.watchOverdueActionable(now).first;
      expect(items, isEmpty);
    });

    test('НЕ включает задачи СЕГОДНЯ (scheduledAt >= localDayStart)', () async {
      final now = DateTime.now();
      // Сегодня с конкретным временем
      final todayMid = DateTime(now.year, now.month, now.day, 12, 0);

      await _insert(dao, id: 't_today', scheduledAt: todayMid, type: 'task');

      final items = await dao.watchOverdueActionable(now).first;
      expect(items, isEmpty);
    });

    test('НЕ включает якорные строки серий (recurrenceRule != null)', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);

      await _insert(dao,
          id: 'anchor1',
          scheduledAt: yesterday,
          type: 'task',
          recurrenceRule: 'FREQ=DAILY');

      final items = await dao.watchOverdueActionable(now).first;
      expect(items, isEmpty);
    });

    test('сортирует по scheduledAt по возрастанию', () async {
      final now = DateTime.now();
      final day = now.day;
      final d1 = DateTime(now.year, now.month, day - 3, 9, 0);
      final d2 = DateTime(now.year, now.month, day - 1, 9, 0);
      final d3 = DateTime(now.year, now.month, day - 2, 9, 0);

      await _insert(dao, id: 'a', scheduledAt: d1, type: 'task');
      await _insert(dao, id: 'b', scheduledAt: d2, type: 'deadline');
      await _insert(dao, id: 'c', scheduledAt: d3, type: 'exam');

      final items = await dao.watchOverdueActionable(now).first;
      expect(items.map((i) => i.id).toList(), ['a', 'c', 'b']);
    });
  });

  // ---------------------------------------------------------------------------
  // Математика «перенести на завтра» — дата +1, время суток сохраняется
  // ---------------------------------------------------------------------------
  group('move-to-tomorrow date math', () {
    /// Воспроизводим логику из _MoveToTomorrowButton._moveToTomorrow:
    ///   tomorrow = DateTime(now.year, now.month, now.day + 1, orig.hour, orig.minute)
    DateTime moveToTomorrow(DateTime now, DateTime orig) {
      return DateTime(
        now.year,
        now.month,
        now.day + 1,
        orig.hour,
        orig.minute,
      );
    }

    test('перенос с сохранением времени суток', () {
      final now = DateTime(2026, 6, 24, 9, 0);
      final orig = DateTime(2026, 6, 22, 14, 30);
      final result = moveToTomorrow(now, orig);

      expect(result.year, 2026);
      expect(result.month, 6);
      expect(result.day, 25); // now.day + 1
      expect(result.hour, 14); // оригинальный час
      expect(result.minute, 30); // оригинальная минута
    });

    test('перенос в начало следующего месяца (граничный случай)', () {
      final now = DateTime(2026, 6, 30, 9, 0); // последний день июня
      final orig = DateTime(2026, 6, 28, 10, 0);
      final result = moveToTomorrow(now, orig);

      // DateTime нормализует дату автоматически
      expect(result, DateTime(2026, 7, 1, 10, 0));
    });

    test('перенос без времени суток (00:00 остаётся 00:00)', () {
      final now = DateTime(2026, 6, 24, 9, 0);
      final orig = DateTime(2026, 6, 22); // полночь
      final result = moveToTomorrow(now, orig);

      expect(result.hour, 0);
      expect(result.minute, 0);
    });
  });
}
