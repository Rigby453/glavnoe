// Офлайн-первый расчёт серии (streak) Kaizen.
//
// Серия — заявленная фишка продукта ("всё главное закрыто N дней подряд").
// Приложение работает offline-first и без аккаунта, поэтому серия считается
// ЛОКАЛЬНО по данным Drift. Правила синхронизированы с backend
// `checkAndUpdateStreak` (rule-based, без AI), чтобы локальное и серверное
// значения сходились к одному числу.
//
// РЕШЕНИЕ ВЛАДЕЛЬЦА — стрик v2 (docs/TASKS-2026-07-02.md §8), предикат «день
// завершён» СМОТРИТ на не-skipped задачи дня ("counted"):
//   1. counted пуст (нет задач за день, либо все были skipped) → день
//      НЕЙТРАЛЬНЫЙ: не растит и не обнуляет серию. Пустой день — не
//      наказание; «все skipped» тоже не даёт зачёта (иначе можно было бы
//      накрутить серию, ничего реально не сделав).
//   2. Есть хотя бы одна задача priority='main' среди counted (mains) → день
//      ЗАСЧИТАН, если сделаны ВСЕ mains (status=='done'). Остальные (не-main)
//      задачи НЕ блокируют зачёт дня, когда main есть — «сделал главное»
//      важнее полного списка.
//   3. Mains нет вообще → день ЗАСЧИТАН, если недоделанных (status != 'done')
//      среди counted не больше max(1, floor(counted.length * 0.1)) — то есть
//      допускается «почти всё» (~90%+), но минимум одна задача прощается
//      ВСЕГДА, даже в короткий день (иначе 2-задачный день наказывался бы
//      строже 20-задачного).
//   4. Иначе — день НЕ завершён (incomplete).
// Заменяет более строгое правило v1 «ВСЕ counted задачи done» (решение #2,
// 2026-07-01), которое наказывало за любую некритичную незакрытую задачу,
// даже когда всё главное было сделано. См. _DayStatus/_dayStatus ниже —
// общий предикат для recomputeForDay и recomputeFromHistory. Это ЕДИНАЯ
// точка правды для предиката — бэкенд-зеркало в
// backend/src/engine/streaks.ts (checkAndUpdateStreak) должно оставаться в
// лок-степе с этой функцией.
//
// РЕШЕНИЕ ВЛАДЕЛЬЦА #14, подход B (2026-07-01) — стрик как функция от истории:
//   Раньше SyncService при каждой синхронизации ЗАПИСЫВАЛ current/longest,
//   пришедшие в ответе /sync, "как есть". На новом устройстве/после
//   переустановки сервер мог не знать локальную историю (или прислать 0) —
//   и честно накопленная серия обнулялась. Теперь current/longest — функция
//   от ЛОКАЛЬНОЙ истории завершённых дней (см. [recomputeFromHistory]),
//   вызываемая после каждого синка ВМЕСТО слепого доверия серверному числу.
//   freeze_count/last_freeze_accrual_at — отдельный контракт (ADR-044),
//   продолжают синкаться как раньше, эта правка их не трогает.
//
// Пропущенные (status='skipped') задачи НЕ считаются закрытыми — так же, как
// и раньше (строгое сравнение со 'done' для оставшихся после фильтра).

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

/// Итог предиката «день завершён» для одного календарного дня.
enum _DayStatus {
  /// Нет задач (или все задачи skipped) — день не участвует в расчёте серии.
  neutral,

  /// Есть хотя бы одна не-skipped задача, но день не набрал зачёт по
  /// предикату v2 (main не все done, либо недоделанных больше forgiveness).
  incomplete,

  /// День набрал зачёт по предикату v2 — см. [_dayStatus].
  complete,
}

/// Общий предикат «день завершён» — стрик v2 (см. заголовок файла).
_DayStatus _dayStatus(List<ItemsTableData> dayItems) {
  if (dayItems.isEmpty) return _DayStatus.neutral;
  final counted = dayItems.where((i) => i.status != 'skipped').toList();
  if (counted.isEmpty) return _DayStatus.neutral; // все задачи были skipped

  final mains = counted.where((i) => i.priority == 'main').toList();
  if (mains.isNotEmpty) {
    // Есть главное на день — считаем ТОЛЬКО по нему: "сделал главное" важнее
    // полного списка. Не-main задачи не блокируют зачёт.
    final allMainsDone = mains.every((i) => i.status == 'done');
    return allMainsDone ? _DayStatus.complete : _DayStatus.incomplete;
  }

  // Главного нет — прощаем недоделанное в пределах ~10%, но минимум 1 задачу
  // прощаем всегда (короткие дни не наказываются строже длинных).
  final undone = counted.where((i) => i.status != 'done').length;
  final tenPercent = (counted.length * 0.1).floor();
  final forgiveness = tenPercent > 1 ? tenPercent : 1;
  return undone <= forgiveness ? _DayStatus.complete : _DayStatus.incomplete;
}

class StreakService {
  StreakService({required ItemsDao itemsDao, required StreakDao streakDao})
      : _itemsDao = itemsDao,
        _streakDao = streakDao;

  final ItemsDao _itemsDao;
  final StreakDao _streakDao;

  /// Пересчитывает серию за указанный день (обычно `DateTime.now()`).
  ///
  /// Идемпотентно: безопасно вызывать при каждом изменении задач дня — если
  /// день уже засчитан или не завершён (см. [_dayStatus]), метод ничего не
  /// делает. Это единственное место, которое РЕАЛЬНО тратит freeze_count —
  /// в отличие от [recomputeFromHistory] (см. её doc-комментарий).
  Future<void> recomputeForDay(DateTime day) async {
    final dayItems = await _itemsDao.itemsForDay(day);
    if (_dayStatus(dayItems) != _DayStatus.complete) return;

    final dayMarker = _dayMarker(day);
    final streak = await _streakDao.getOrCreate();

    final todayKey = _key(dayMarker);
    final last = streak.lastCompletedDate;
    final lastKey = last == null ? null : _key(last.toUtc());

    // Этот день уже засчитан — повторно не считаем.
    if (lastKey == todayKey) return;

    final yesterdayKey = _key(dayMarker.subtract(const Duration(days: 1)));

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

    final newLongest =
        newCurrent > streak.longest ? newCurrent : streak.longest;

    await _streakDao.updateStreak(
      StreakTableCompanion(
        current: Value(newCurrent),
        longest: Value(newLongest),
        freezeCount: Value(newFreeze),
        lastCompletedDate: Value(dayMarker),
      ),
    );

    debugPrint(
      '[StreakService] streak updated: current=$newCurrent longest=$newLongest '
      'freeze=$newFreeze day=$todayKey',
    );
  }

  /// Полный пересчёт current/longest/lastCompletedDate из ЛОКАЛЬНОЙ истории
  /// задач — решение владельца #14 (подход B, 2026-07-01). См. заголовок файла
  /// для контекста бага, который это чинит.
  ///
  /// Сканирует календарные дни от `asOf` (по умолчанию — сегодня) назад на
  /// [maxLookbackDays] дней, применяет тот же предикат «день завершён»
  /// ([_dayStatus]) и тот же алгоритм грейса/заморозки, что [recomputeForDay]
  /// и серверный `checkAndUpdateStreak`.
  ///
  /// ВАЖНЫЕ отличия от [recomputeForDay] (не путать друг с другом):
  ///  - freeze_count здесь ТОЛЬКО читается один раз как «бюджет» на весь скан
  ///    и НИКОГДА не сохраняется обратно. Реальные списания заморозок по мере
  ///    того, как дни РЕАЛЬНО закрываются, происходят только в
  ///    [recomputeForDay] (и на бэкенде). Повторное списание здесь задвоило
  ///    бы уже случившиеся в реальном времени траты.
  ///  - longest никогда не УМЕНЬШАЕТСЯ относительно уже сохранённого значения:
  ///    итоговый longest = max(посчитанный по истории, ранее сохранённый).
  ///    Защищает личный рекорд от урезанного окна скана ([maxLookbackDays])
  ///    или неполной локальной истории (например, сразу после установки на
  ///    новом устройстве, если вызвать до того, как элементы домержились).
  ///  - current, наоборот, ВСЕГДА берётся как есть из скана — это и есть цель
  ///    решения #14: не доверять транзитному числу (в том числе серверному
  ///    0 на новом устройстве), а вывести его из фактической истории задач.
  ///  - нейтральные дни (без задач или все skipped) между двумя завершёнными
  ///    "прозрачны": цепочка current продолжается сквозь них, как будто их
  ///    не было ([_hasIncompleteDayBetween]). РЕАЛЬНЫЙ разрыв (день с
  ///    incomplete-статусом между ними) либо прощается заморозкой из
  ///    бюджета — и тогда current ПРОДОЛЖАЕТ расти как через нейтральный
  ///    день, — либо, без заморозки, обнуляет серию до 1.
  ///
  /// Идемпотентно: если история не изменилась — результат не изменится.
  /// Предполагаемая точка вызова — ПОСЛЕ того, как входящие items уже
  /// смержены в Drift (иначе сканировать нечего).
  Future<void> recomputeFromHistory({
    DateTime? asOf,
    int maxLookbackDays = 1500,
  }) async {
    final now = asOf ?? DateTime.now();
    final todayMarker = _dayMarker(DateTime(now.year, now.month, now.day));

    final rangeStart = todayMarker.subtract(Duration(days: maxLookbackDays));
    // Верхняя граница — начало следующего дня (полуоткрытый интервал), как и
    // у остальных DAO-запросов диапазона (itemsInRange/watchItemsInRange).
    final rangeEndExclusive = todayMarker.add(const Duration(days: 1));

    final items = await _itemsDao.itemsInRange(rangeStart, rangeEndExclusive);

    // Группируем по календарному дню — маркер строим тем же "UTC-релейбл"
    // трюком, что и lastCompletedDate (см. _dayMarker), чтобы ключи совпадали
    // при последующем сравнении.
    final byDay = <DateTime, List<ItemsTableData>>{};
    for (final item in items) {
      final marker = _dayMarker(item.scheduledAt);
      byDay.putIfAbsent(marker, () => <ItemsTableData>[]).add(item);
    }

    final sortedDays = byDay.keys.toList()..sort();

    final priorStreak = await _streakDao.getOrCreate();
    // "Бюджет" заморозок на весь скан — см. doc-комментарий метода: только
    // читаем текущий остаток, никогда не пишем обратно.
    var freezeBudget = priorStreak.freezeCount;

    var current = 0;
    var longest = 0;
    DateTime? lastCompleted;

    for (final day in sortedDays) {
      final status = _dayStatus(byDay[day]!);
      if (status != _DayStatus.complete) {
        // neutral — прозрачно пропускаем (как будто дня не было).
        // incomplete (в т.ч. сегодня, если день ещё не закончен) — молча
        // пропускаем: разрыв обнаружится (и будет прощён заморозкой, если
        // есть) на СЛЕДУЮЩЕМ завершённом дне — так же, как в живом
        // recomputeForDay/checkAndUpdateStreak, которые реагируют только на
        // событие завершения, а не на сам факт "день не закрыт".
        continue;
      }

      if (lastCompleted == null) {
        // Первый когда-либо завершённый день в окне скана.
        current = 1;
      } else if (!_hasIncompleteDayBetween(byDay, lastCompleted, day)) {
        // Между предыдущим завершённым днём и этим НЕТ ни одного реально
        // несделанного (incomplete) дня — либо дни идут подряд, либо разрыв
        // заполнен только нейтральными днями (без задач или все skipped).
        // Нейтральные дни "прозрачны": цепочка продолжается сквозь них, не
        // растрачивая заморозку — решение владельца, п.1 (см. заголовок
        // файла и коммит-сообщение с описанием бага).
        current += 1;
      } else if (freezeBudget > 0) {
        // Настоящий разрыв (есть incomplete-день между), но есть заморозка в
        // бюджете — она "перепрыгивает" разрыв и серия ПРОДОЛЖАЕТСЯ (не
        // просто не обнуляется, а растёт дальше), так же, как если бы
        // пропущенного дня не было. freezeBudget — только read-бюджет на
        // весь скан (см. doc-комментарий метода), реального списания здесь
        // нет — п.2 бага.
        freezeBudget -= 1;
        current += 1;
      } else {
        // Настоящий разрыв без заморозки — серия начинается заново.
        current = 1;
      }
      longest = current > longest ? current : longest;
      lastCompleted = day;
    }

    final finalLongest =
        longest > priorStreak.longest ? longest : priorStreak.longest;

    await _streakDao.updateStreak(
      StreakTableCompanion(
        current: Value(current),
        longest: Value(finalLongest),
        lastCompletedDate: Value(lastCompleted),
      ),
    );

    debugPrint(
      '[StreakService] recomputeFromHistory: current=$current '
      'longest=$finalLongest '
      'lastCompleted=${lastCompleted == null ? null : _key(lastCompleted)} '
      'scannedDays=${sortedDays.length}',
    );
  }

  /// true, если среди календарных дней СТРОГО между [from] и [to] (оба —
  /// маркеры [_dayMarker], оба исключаются) есть хотя бы один день со
  /// статусом [_DayStatus.incomplete] — то есть РЕАЛЬНЫЙ разрыв (задачи были,
  /// но не все done), а не просто "дня не было"/"все skipped". Дни,
  /// отсутствующие в [byDay] (нет задач вообще), трактуются как нейтральные и
  /// не в счёт — решение владельца, п.1 (см. заголовок файла).
  bool _hasIncompleteDayBetween(
    Map<DateTime, List<ItemsTableData>> byDay,
    DateTime from,
    DateTime to,
  ) {
    var d = from.add(const Duration(days: 1));
    while (d.isBefore(to)) {
      final items = byDay[d];
      if (items != null && _dayStatus(items) == _DayStatus.incomplete) {
        return true;
      }
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  /// "UTC-релейбл" маркер календарного дня: берёт ЛОКАЛЬНЫЕ Y/M/D компоненты
  /// [d] (независимо от того, локальный это DateTime или UTC) и строит из них
  /// DateTime.utc(...) с нулевым временем. Это НЕ настоящая конвертация в UTC —
  /// это стабильный "ключ дня", которым исторически помечается
  /// lastCompletedDate (см. старую реализацию), поэтому здесь и в
  /// [recomputeFromHistory] используется тот же трюк, чтобы значения совпадали
  /// при сравнении.
  DateTime _dayMarker(DateTime d) => DateTime.utc(d.year, d.month, d.day);

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
