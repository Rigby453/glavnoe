// Unit-тесты для дневника подходов (Feature B, set-by-set diary).
// In-memory Drift — без Flutter-зависимостей, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WorkoutsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = WorkoutsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('logSet вставляет строку с корректными полями', () async {
    await dao.logSet(
      sessionId: 's1',
      exerciseId: 'e1',
      setIndex: 0,
      reps: 12,
      weightKg: 50.0,
    );

    final sets = await dao.watchSessionSets('s1').first;
    expect(sets, hasLength(1));
    final row = sets.single;
    expect(row.sessionId, 's1');
    expect(row.exerciseId, 'e1');
    expect(row.setIndex, 0);
    expect(row.reps, 12);
    expect(row.weightKg, 50.0);
    expect(row.completedAt, isNotNull);
  });

  test('weightKg null обрабатывается (bodyweight)', () async {
    await dao.logSet(
      sessionId: 's1',
      exerciseId: 'e1',
      setIndex: 0,
      reps: 15,
    );

    final sets = await dao.watchSessionSets('s1').first;
    expect(sets.single.weightKg, isNull);
    expect(sets.single.reps, 15);
  });

  test('watchSessionSets возвращает только подходы своей сессии, по порядку',
      () async {
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 1, reps: 8);
    // Чужая сессия — не должна попасть в выборку s1.
    await dao.logSet(sessionId: 's2', exerciseId: 'e1', setIndex: 0, reps: 5);

    final sets = await dao.watchSessionSets('s1').first;
    expect(sets, hasLength(2));
    // Старые первыми (completedAt asc)
    expect(sets[0].setIndex, 0);
    expect(sets[0].reps, 10);
    expect(sets[1].setIndex, 1);
    expect(sets[1].reps, 8);
  });

  test(
      'watchExerciseHistory собирает подходы упражнения через сессии, свежие первыми',
      () async {
    // Старая сессия
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    // Drift хранит DateTime с точностью до секунды — разводим по секундам.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    // Новая сессия, то же упражнение
    await dao.logSet(sessionId: 's2', exerciseId: 'e1', setIndex: 0, reps: 12);
    // Другое упражнение — не должно попасть
    await dao.logSet(sessionId: 's2', exerciseId: 'e2', setIndex: 0, reps: 20);

    final history = await dao.watchExerciseHistory('e1').first;
    expect(history, hasLength(2));
    // Свежие первыми (completedAt desc): s2 раньше s1 в списке
    expect(history[0].sessionId, 's2');
    expect(history[0].reps, 12);
    expect(history[1].sessionId, 's1');
    expect(history[1].reps, 10);
  });

  test('getExerciseHistory совпадает с реактивной выборкой', () async {
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 1, reps: 9);

    final oneShot = await dao.getExerciseHistory('e1');
    expect(oneShot, hasLength(2));
    expect(oneShot.every((r) => r.exerciseId == 'e1'), isTrue);
  });
}
