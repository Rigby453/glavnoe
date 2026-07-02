// Тесты StreakService:
//   - предикат «день завершён» v2 (docs/TASKS-2026-07-02.md §8): если среди
//     не-skipped задач дня есть priority='main' — день засчитан, если ВСЕ
//     main сделаны (не-main не блокирует); если main нет — засчитан, если
//     недоделанных не больше max(1, floor(counted.length * 0.1)); skipped
//     исключаются из знаменателя; пустой/весь-skipped день — нейтральный.
//   - recomputeFromHistory (решение владельца #14, подход B): current/longest
//     как функция от локальной истории задач, а не доверие транзитному числу.
//
// Даты фиксированные (не DateTime.now()) — детерминированность, по образцу
// backend-аналога tests/unit/streak-logic.test.ts.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/daos/streak_dao.dart';
import 'package:app/services/streak/streak_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

Future<void> _insert(
  ItemsDao dao, {
  required String id,
  required DateTime scheduledAt,
  String priority = 'medium',
  String status = 'pending',
  String type = 'task',
}) async {
  final now = DateTime.now();
  await dao.insertItem(ItemsTableCompanion(
    id: Value(id),
    userId: const Value('local'),
    title: Value(id),
    type: Value(type),
    priority: Value(priority),
    status: Value(status),
    scheduledAt: Value(scheduledAt),
    durationMinutes: const Value(30),
    isProtected: const Value(false),
    createdAt: Value(now),
    updatedAt: Value(now),
  ));
}

/// Создаёт [count] задач на один день: первые [doneCount] — 'done', остальные
/// — 'pending'. Удобно для тестов "N задач, M недоделано" (forgiveness v2).
Future<void> _insertBatch(
  ItemsDao dao, {
  required DateTime day,
  required int count,
  required int doneCount,
  String priority = 'medium',
  String status = 'pending',
  String idPrefix = 'batch',
}) async {
  for (var i = 0; i < count; i++) {
    await _insert(
      dao,
      id: '$idPrefix$i',
      scheduledAt: day,
      priority: priority,
      status: i < doneCount ? 'done' : status,
    );
  }
}

void main() {
  late AppDatabase db;
  late ItemsDao itemsDao;
  late StreakDao streakDao;
  late StreakService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    itemsDao = ItemsDao(db);
    streakDao = StreakDao(db);
    service = StreakService(itemsDao: itemsDao, streakDao: streakDao);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // recomputeForDay — предикат «день завершён» v2 (docs/TASKS-2026-07-02.md §8)
  // ---------------------------------------------------------------------------
  group('recomputeForDay — предикат «день завершён» v2', () {
    final day = DateTime(2026, 6, 10, 9, 0);

    test('нет main: все задачи done → серия засчитывается', () async {
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'low', status: 'done');
      await _insert(itemsDao,
          id: 'b', scheduledAt: day, priority: 'medium', status: 'done');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
    });

    test(
        'main done + не-main НЕ done → ЗАСЧИТАНО (не-main не блокирует при '
        'наличии main)', () async {
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'main', status: 'done');
      await _insert(itemsDao,
          id: 'b', scheduledAt: day, priority: 'low', status: 'pending');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
    });

    test(
        'хотя бы один main НЕ done → НЕ засчитано, даже если остальные '
        '(включая другой main) done', () async {
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'main', status: 'done');
      await _insert(itemsDao,
          id: 'b', scheduledAt: day, priority: 'main', status: 'pending');
      await _insert(itemsDao,
          id: 'c', scheduledAt: day, priority: 'low', status: 'done');

      await service.recomputeForDay(day);

      // Хелпер выходит до создания Streak — строки не будет вовсе.
      final streak = await streakDao.getStreak();
      expect(streak, isNull);
    });

    test('нет main: 10 задач, 1 недоделана → ЗАСЧИТАНО (прощение <=10%)',
        () async {
      await _insertBatch(itemsDao, day: day, count: 10, doneCount: 9);

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
    });

    test(
        'нет main: 10 задач, 2 недоделаны → НЕ засчитано (превышен порог '
        '10%)', () async {
      await _insertBatch(itemsDao, day: day, count: 10, doneCount: 8);

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak, isNull);
    });

    test(
        'нет main: короткий день (2 задачи), 1 недоделана → ЗАСЧИТАНО '
        '(max(1, floor(2*0.1))=1 всегда прощает минимум одну)', () async {
      await _insertBatch(itemsDao, day: day, count: 2, doneCount: 1);

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
    });

    test(
        'нет main: skipped исключаются из знаменателя — 20 задач, 10 skipped, '
        'из оставшихся 10 недоделаны 2 → НЕ засчитано (порог 10% считается от '
        '10 counted, а не от 20)', () async {
      await _insertBatch(itemsDao,
          day: day,
          count: 10,
          doneCount: 0,
          status: 'skipped',
          idPrefix: 'skip');
      await _insertBatch(itemsDao,
          day: day, count: 10, doneCount: 8, idPrefix: 'counted');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak, isNull);
    });

    test('skipped «не мешает»: done + skipped → засчитано', () async {
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'medium', status: 'done');
      await _insert(itemsDao,
          id: 'b', scheduledAt: day, priority: 'low', status: 'skipped');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
    });

    test('ВСЕ задачи дня skipped (ни одной done) → нейтральный день, НЕ засчитано',
        () async {
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'medium', status: 'skipped');
      await _insert(itemsDao,
          id: 'b', scheduledAt: day, priority: 'low', status: 'skipped');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak, isNull);
    });

    test('нет задач за день → нейтральный день, НЕ засчитано', () async {
      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak, isNull);
    });

    test('идемпотентно: повторный вызов на тот же день не увеличивает current',
        () async {
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'medium', status: 'done');

      await service.recomputeForDay(day);
      await service.recomputeForDay(day);
      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
    });

    test('вчера уже засчитан → current += 1', () async {
      final yesterday = DateTime.utc(2026, 6, 9);
      await streakDao.getOrCreate();
      await streakDao.updateStreak(
        StreakTableCompanion(
          current: const Value(2),
          longest: const Value(2),
          lastCompletedDate: Value(yesterday),
        ),
      );
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'medium', status: 'done');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 3);
      expect(streak?.longest, 3);
    });

    test('пропуск + freeze_count > 0 → серия сохраняется, freeze тратится',
        () async {
      final threeDaysAgo = DateTime.utc(2026, 6, 7);
      await streakDao.getOrCreate();
      await streakDao.updateStreak(
        StreakTableCompanion(
          current: const Value(5),
          longest: const Value(5),
          freezeCount: const Value(1),
          lastCompletedDate: Value(threeDaysAgo),
        ),
      );
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'medium', status: 'done');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 5);
      expect(streak?.freezeCount, 0);
    });

    test('пропуск без freeze → current сбрасывается до 1, longest сохраняется',
        () async {
      final threeDaysAgo = DateTime.utc(2026, 6, 7);
      await streakDao.getOrCreate();
      await streakDao.updateStreak(
        StreakTableCompanion(
          current: const Value(5),
          longest: const Value(5),
          freezeCount: const Value(0),
          lastCompletedDate: Value(threeDaysAgo),
        ),
      );
      await _insert(itemsDao,
          id: 'a', scheduledAt: day, priority: 'medium', status: 'done');

      await service.recomputeForDay(day);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1);
      expect(streak?.longest, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // recomputeFromHistory — стрик как функция от истории (решение #14)
  // ---------------------------------------------------------------------------
  group('recomputeFromHistory — не доверяет транзитному числу (решение #14)',
      () {
    final today = DateTime(2026, 6, 10, 9, 0);

    test(
        'даже если сохранённый current="богус" (напр. из старого бага) — '
        'итог считается ЧИСТО из истории задач', () async {
      // Симулируем последствия старого бага: сервер прислал current=99,
      // хотя настоящая локальная история — всего 1 честный завершённый день.
      await streakDao.getOrCreate();
      await streakDao.updateStreak(
        const StreakTableCompanion(current: Value(99), longest: Value(99)),
      );
      await _insert(itemsDao, id: 'a', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      // current выведен из истории (1 день), а не унаследован от богус-99.
      expect(streak?.current, 1);
    });

    test(
        'НЕ обнуляется, когда "серверное" значение было бы 0/пусто — '
        'current выводится из реальной истории завершённых дней', () async {
      // Свежий Streak (current=0 по умолчанию — как будто новое устройство,
      // на которое сервер прислал бы current=0), но локальная история после
      // мержа items показывает честную серию 3 дня подряд, включая сегодня.
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 8, 9), status: 'done');
      await _insert(itemsDao,
          id: 'd2', scheduledAt: DateTime(2026, 6, 9, 9), status: 'done');
      await _insert(itemsDao, id: 'd3', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 3);
      expect(streak?.longest, 3);
      expect(streak?.lastCompletedDate, DateTime.utc(2026, 6, 10));
    });

    test('нейтральный день (без задач) между двумя завершёнными НЕ рвёт серию',
        () async {
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 8, 9), status: 'done');
      // 2026-06-09 — вообще без задач (нейтральный).
      await _insert(itemsDao, id: 'd3', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 2); // цепочка продолжилась через нейтральный день
    });

    test(
        'день, где ВСЕ задачи skipped, между двумя завершёнными — тоже '
        'нейтральный (не рвёт серию, freeze не тратится)', () async {
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 8, 9), status: 'done');
      await _insert(itemsDao,
          id: 'skip1',
          scheduledAt: DateTime(2026, 6, 9, 9),
          status: 'skipped');
      await _insert(itemsDao, id: 'd3', scheduledAt: today, status: 'done');
      await streakDao.getOrCreate();
      await streakDao.updateStreak(const StreakTableCompanion(freezeCount: Value(0)));

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 2); // не 1 — freeze не понадобился
      expect(streak?.freezeCount, 0); // не тронут
    });

    test(
        'настоящий разрыв (день с НЕ завершённой задачей) без freeze → '
        'серия начинается заново', () async {
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 8, 9), status: 'done');
      // priority='main' pending → однозначный разрыв под предикатом v2
      // (main-гейт), а не одинокая недоделанная задача, которую simple
      // forgiveness (max(1, floor(1*0.1))=1) простил бы.
      await _insert(itemsDao,
          id: 'broken',
          scheduledAt: DateTime(2026, 6, 9, 9),
          priority: 'main',
          status: 'pending'); // реальный разрыв, не нейтральный
      await _insert(itemsDao, id: 'd3', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1); // серия оборвалась и началась заново с today
    });

    test(
        'настоящий разрыв С freeze_count>0 → серия перепрыгивает разрыв, '
        'НО freeze_count в БД не меняется (только чтение-бюджет)', () async {
      await streakDao.getOrCreate();
      await streakDao.updateStreak(const StreakTableCompanion(freezeCount: Value(2)));
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 8, 9), status: 'done');
      // priority='main' pending → однозначный разрыв под предикатом v2 (см.
      // комментарий в тесте выше).
      await _insert(itemsDao,
          id: 'broken',
          scheduledAt: DateTime(2026, 6, 9, 9),
          priority: 'main',
          status: 'pending');
      await _insert(itemsDao, id: 'd3', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 2); // разрыв прощён "бюджетом" заморозки
      expect(streak?.freezeCount, 2); // НЕ списано — списание живёт в recomputeForDay
    });

    test('longest никогда не уменьшается ниже уже сохранённого рекорда',
        () async {
      await streakDao.getOrCreate();
      await streakDao.updateStreak(
        const StreakTableCompanion(current: Value(0), longest: Value(50)),
      );
      // В окне скана видно всего 2 дня подряд.
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 9, 9), status: 'done');
      await _insert(itemsDao, id: 'd2', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 2); // current — честно из скана, не защищён
      expect(streak?.longest, 50); // рекорд не понижен
    });

    test(
        'сегодня ещё не завершено (есть pending) → НЕ рвёт серию за вчера, '
        'просто пока не засчитывается', () async {
      await _insert(itemsDao,
          id: 'yesterday',
          scheduledAt: DateTime(2026, 6, 9, 9),
          status: 'done');
      // priority='main' pending → однозначно "ещё не завершено" под
      // предикатом v2 (main-гейт), а не одинокая недоделанная задача,
      // которую forgiveness (max(1, floor(1*0.1))=1) простил бы.
      await _insert(itemsDao,
          id: 'todayPending',
          scheduledAt: today,
          priority: 'main',
          status: 'pending');

      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 1); // от вчера, сегодня пока не в счёт
      expect(streak?.lastCompletedDate, DateTime.utc(2026, 6, 9));
    });

    test('идемпотентно: повторный вызов даёт тот же результат', () async {
      await _insert(itemsDao,
          id: 'd1', scheduledAt: DateTime(2026, 6, 9, 9), status: 'done');
      await _insert(itemsDao, id: 'd2', scheduledAt: today, status: 'done');

      await service.recomputeFromHistory(asOf: today);
      await service.recomputeFromHistory(asOf: today);
      await service.recomputeFromHistory(asOf: today);

      final streak = await streakDao.getStreak();
      expect(streak?.current, 2);
      expect(streak?.longest, 2);
    });
  });
}
