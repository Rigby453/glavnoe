// Юнит-тесты DAO-операций повторов: materializeOccurrence / stopSeries и того,
// что concrete-запросы исключают якоря серий. In-memory Drift, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/features/plan/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<String> insertAnchor({
    required DateTime scheduledAt,
    required String rule,
    String title = 'Standup',
  }) async {
    final id = 'anchor-${scheduledAt.millisecondsSinceEpoch}';
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: Value(title),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(scheduledAt),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      recurrenceRule: Value(rule),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  test('watchTodayItems excludes anchor rows; watchSeriesAnchors returns them',
      () async {
    // Якорь на полдень сегодня (UTC-окно watchTodayItems).
    final today = DateTime.now();
    final at = DateTime.utc(today.year, today.month, today.day, 12);
    await insertAnchor(scheduledAt: at, rule: 'FREQ=DAILY');

    final concrete = await dao.watchTodayItems(today).first;
    expect(concrete, isEmpty, reason: 'anchor must not show as a concrete task');

    final anchors = await dao.watchSeriesAnchors().first;
    expect(anchors.length, 1);
  });

  test('materializeOccurrence inserts concrete row and adds EXDATE', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final day = DateTime(2026, 6, 23);

    final newId =
        await dao.materializeOccurrence(anchorId, day, status: 'done');
    expect(newId, isNotNull);

    // Concrete-строка создана, не серия, status=done, время-суток из якоря.
    final concrete = await dao.getItemById(newId!);
    expect(concrete, isNotNull);
    expect(concrete!.recurrenceRule, isNull);
    expect(concrete.status, 'done');
    expect(concrete.scheduledAt, DateTime(2026, 6, 23, 9, 0));

    // Якорь получил EXDATE на эту дату.
    final anchor = await dao.getItemById(anchorId);
    final rule = RecurrenceRule.parse(anchor!.recurrenceRule)!;
    expect(rule.exDates.contains(DateTime(2026, 6, 23)), isTrue);
    // occursOn на этот день теперь false (день материализован).
    expect(occursOn(rule, anchor.scheduledAt, day), isFalse);
  });

  test('materializeOccurrence applies field overrides', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final newId = await dao.materializeOccurrence(
      anchorId,
      DateTime(2026, 6, 24),
      title: 'Edited',
      durationMinutes: 90,
      scheduledAt: DateTime(2026, 6, 24, 15, 30),
    );
    final row = await dao.getItemById(newId!);
    expect(row!.title, 'Edited');
    expect(row.durationMinutes, 90);
    expect(row.scheduledAt, DateTime(2026, 6, 24, 15, 30));
  });

  test('materializeOccurrence returns null for non-series id', () async {
    // Обычная задача (без правила) — не серия.
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: const Value('plain'),
      userId: const Value('local'),
      title: const Value('x'),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(now),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final res = await dao.materializeOccurrence('plain', now);
    expect(res, isNull);
  });

  test('stopSeries sets UNTIL to day before given day', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 1, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final ok = await dao.stopSeries(anchorId, DateTime(2026, 6, 22));
    expect(ok, isTrue);

    final anchor = await dao.getItemById(anchorId);
    final rule = RecurrenceRule.parse(anchor!.recurrenceRule)!;
    expect(rule.until, DateTime(2026, 6, 21));
    // Сегодня и далее — повторов нет; прошлое (до 21-го включительно) — есть.
    expect(occursOn(rule, anchor.scheduledAt, DateTime(2026, 6, 21)), isTrue);
    expect(occursOn(rule, anchor.scheduledAt, DateTime(2026, 6, 22)), isFalse);
  });
}
