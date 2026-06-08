// Офлайн-первый расчёт серии (streak) Kaizen.
//
// Серия — заявленная фишка продукта ("всё главное закрыто N дней подряд").
// Приложение работает offline-first и без аккаунта, поэтому серия считается
// ЛОКАЛЬНО по данным Drift. Правила полностью совпадают с backend
// `checkAndUpdateStreak` (rule-based, без AI), чтобы локальное и серверное
// значения сходились к одному числу:
//   1. Берём все main-задачи за день. Нет ни одной → серия не меняется.
//   2. Не все выполнены (status='done') → серия не меняется.
//   3. lastCompletedDate == сегодня → идемпотентно, выходим.
//   4. lastCompletedDate == вчера → current += 1.
//   5. Пропуск + freezeCount > 0 → расходуем заморозку, current без изменений.
//   6. Иначе → current = 1.
//   7. longest = max(longest, current); lastCompletedDate = сегодня.
//
// Пропущенные (status='skipped') главные задачи НЕ считаются закрытыми —
// так же, как на бэкенде (строгое сравнение со 'done').

// Именованные параметры конструктора не могут начинаться с "_", поэтому поля
// присваиваются через список инициализации (а не initializing formals).
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/daos/items_dao.dart';
import '../../core/database/daos/streak_dao.dart';
import '../../core/database/database_providers.dart';

class StreakService {
  StreakService({required ItemsDao itemsDao, required StreakDao streakDao})
      : _itemsDao = itemsDao,
        _streakDao = streakDao;

  final ItemsDao _itemsDao;
  final StreakDao _streakDao;

  /// Пересчитывает серию за указанный день (обычно `DateTime.now()`).
  ///
  /// Идемпотентно: безопасно вызывать при каждом изменении main-задач —
  /// если день уже засчитан или не все задачи закрыты, метод ничего не делает.
  Future<void> recomputeForDay(DateTime day) async {
    final dayStart = DateTime.utc(day.year, day.month, day.day);

    final mainItems = await _itemsDao.mainItemsForDay(day);
    // Нет главных задач — серия не обновляется (так же, как на бэкенде).
    if (mainItems.isEmpty) return;

    // Все ли главные задачи именно выполнены (skipped не считается).
    final allDone = mainItems.every((i) => i.status == 'done');
    if (!allDone) return;

    final streak = await _streakDao.getOrCreate();

    final todayKey = _key(dayStart);
    final last = streak.lastCompletedDate;
    final lastKey = last == null ? null : _key(last.toUtc());

    // Этот день уже засчитан — повторно не считаем.
    if (lastKey == todayKey) return;

    final yesterdayKey = _key(dayStart.subtract(const Duration(days: 1)));

    var newCurrent = streak.current;
    var newFreeze = streak.freezeCount;

    if (lastKey == yesterdayKey) {
      // Вчера завершили — продолжаем серию.
      newCurrent += 1;
    } else if (streak.freezeCount > 0) {
      // Пропуск, но есть заморозка — серия сохраняется, тратим заморозку.
      newFreeze -= 1;
    } else {
      // Давно не закрывали (или впервые) и нет заморозки — серия = 1.
      newCurrent = 1;
    }

    final newLongest = newCurrent > streak.longest ? newCurrent : streak.longest;

    await _streakDao.updateStreak(
      StreakTableCompanion(
        current: Value(newCurrent),
        longest: Value(newLongest),
        freezeCount: Value(newFreeze),
        lastCompletedDate: Value(dayStart),
      ),
    );

    debugPrint(
      '[StreakService] streak updated: current=$newCurrent longest=$newLongest '
      'freeze=$newFreeze day=$todayKey',
    );
  }

  /// Ключ дня вида YYYY-MM-DD из UTC-полуночи (для сравнения дней).
  String _key(DateTime utcMidnight) {
    final d = utcMidnight;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

/// Провайдер сервиса серии. Зависит от itemsDaoProvider и streakDaoProvider.
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(
    itemsDao: ref.read(itemsDaoProvider),
    streakDao: ref.read(streakDaoProvider),
  );
});
