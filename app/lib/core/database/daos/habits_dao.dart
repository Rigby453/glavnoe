import 'package:drift/drift.dart';
import '../database.dart';
import '../../utils/id.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [HabitsTable, HabitLogsTable])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  /// Все активные привычки (не заархивированные).
  Stream<List<HabitsTableData>> watchActive() {
    return (select(habitsTable)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Все заархивированные привычки (для экрана архива).
  Stream<List<HabitsTableData>> watchArchived() {
    return (select(habitsTable)
          ..where((t) => t.archived.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Логи за конкретный день (нормализованная дата 00:00 UTC).
  Stream<List<HabitLogsTableData>> watchLogsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          ))
        .watch();
  }

  /// Все логи привычек за ISO-неделю (с понедельника), для всех привычек.
  /// Используется секцией «Привычки сегодня» (ADR-053, slice 3), чтобы для
  /// привычек типа 'weekly_count' посчитать выполнения за текущую неделю и
  /// понять, достигнута ли недельная цель. Дата нормализуется к UTC-дню,
  /// как и [logHabit].
  Stream<List<HabitLogsTableData>> watchLogsForWeek(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final end = monday.add(const Duration(days: 7));
    return (select(habitLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(monday) &
                t.date.isSmallerThanValue(end),
          ))
        .watch();
  }

  /// Количество выполнений привычки за день.
  Future<int> countForDate(String habitId, DateTime date) async {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (select(habitLogsTable)
          ..where(
            (t) =>
                t.habitId.equals(habitId) &
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          ))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.count);
  }

  /// Реактивное количество выполнений привычки за день.
  /// В отличие от [countForDate], эмитит новое значение при каждом logHabit —
  /// карточка обновляется сразу, без ухода/возврата на экран.
  Stream<int> watchCountForDate(String habitId, DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final countExpr = habitLogsTable.count.sum();
    final query = selectOnly(habitLogsTable)
      ..addColumns([countExpr])
      ..where(
        habitLogsTable.habitId.equals(habitId) &
            habitLogsTable.date.isBiggerOrEqualValue(start) &
            habitLogsTable.date.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  /// Все логи привычки, сгруппированные по дню (ключ YYYY-MM-DD в UTC) → сумма count.
  /// Один проход по логам; используется для расчёта стрика, истории и сводки.
  Future<Map<String, int>> dayCountsForHabit(String habitId) async {
    final rows = await (select(habitLogsTable)
          ..where((t) => t.habitId.equals(habitId)))
        .get();
    final counts = <String, int>{};
    for (final r in rows) {
      final key = dayKey(r.date.toUtc());
      counts[key] = (counts[key] ?? 0) + r.count;
    }
    return counts;
  }

  /// Реактивная сводка статистики привычки (стрик, лучший стрик, всего и т.п.).
  /// Эмитит новое значение при каждом logHabit — карточка обновляется сразу.
  Stream<HabitStats> watchStats(HabitsTableData habit, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return (select(habitLogsTable)..where((t) => t.habitId.equals(habit.id)))
        .watch()
        .map((rows) {
      final counts = <String, int>{};
      for (final r in rows) {
        final key = dayKey(r.date.toUtc());
        counts[key] = (counts[key] ?? 0) + r.count;
      }
      return computeHabitStats(
        dayCounts: counts,
        type: habit.type,
        targetPerDay: habit.targetPerDay,
        frequencyType: habit.frequencyType,
        weekdayMask: habit.weekdayMask,
        weeklyTarget: habit.weeklyTarget,
        now: today,
      );
    });
  }

  /// Разовый расчёт статистики (для архива / экранов без стрима).
  Future<HabitStats> statsForHabit(HabitsTableData habit, {DateTime? now}) async {
    final counts = await dayCountsForHabit(habit.id);
    return computeHabitStats(
      dayCounts: counts,
      type: habit.type,
      targetPerDay: habit.targetPerDay,
      frequencyType: habit.frequencyType,
      weekdayMask: habit.weekdayMask,
      weeklyTarget: habit.weeklyTarget,
      now: now ?? DateTime.now(),
    );
  }

  /// Добавить выполнение (+1 или +count).
  Future<void> logHabit(String habitId, {int count = 1}) {
    final date = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return into(habitLogsTable).insert(
      HabitLogsTableCompanion(
        id: Value(uuidV4()),
        habitId: Value(habitId),
        date: Value(date),
        count: Value(count),
      ),
    );
  }

  /// Создать новую привычку.
  ///
  /// Частота (ADR-053) опциональна и по умолчанию daily, чтобы текущие
  /// вызовы не менялись; будущие слайсы (диалог добавления) передают свои
  /// значения [frequencyType]/[weekdayMask]/[weeklyTarget]/[reminderMinutes].
  /// Возвращает сгенерированный id новой привычки, чтобы вызывающий код мог
  /// сразу запланировать напоминание (ADR-053, slice 4) по этому id.
  Future<String> createHabit({
    required String name,
    required String type,
    String emoji = '✅',
    int targetPerDay = 1,
    String frequencyType = 'daily',
    int weekdayMask = 127,
    int weeklyTarget = 0,
    int? reminderMinutes,
  }) async {
    final id = uuidV4();
    await into(habitsTable).insert(
      HabitsTableCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type),
        emoji: Value(emoji),
        targetPerDay: Value(targetPerDay),
        frequencyType: Value(frequencyType),
        weekdayMask: Value(weekdayMask),
        weeklyTarget: Value(weeklyTarget),
        reminderMinutes: Value(reminderMinutes),
        createdAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  /// Архивировать привычку (скрыть без удаления).
  Future<void> archive(String id) {
    return (update(habitsTable)..where((t) => t.id.equals(id)))
        .write(const HabitsTableCompanion(archived: Value(true)));
  }

  /// Разархивировать привычку — вернуть в активный список.
  Future<void> unarchive(String id) {
    return (update(habitsTable)..where((t) => t.id.equals(id)))
        .write(const HabitsTableCompanion(archived: Value(false)));
  }

  /// Полностью удалить привычку по id.
  /// Логи выполнения (HabitLogsTable) при этом НЕ удаляются — они привязаны
  /// по habitId, но foreign key не каскадирует на delete в Drift (нет ON DELETE CASCADE).
  /// При восстановлении через [restoreHabit] привычка вернётся с тем же id,
  /// и существующие логи снова будут доступны.
  Future<void> deleteHabit(String id) {
    return (delete(habitsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Восстановить привычку из снапшота (после Undo).
  /// insertOnConflictUpdate перезапишет запись если она вдруг уже существует.
  /// Логи выполнения сохраняются в HabitLogsTable — прогресс не теряется.
  Future<void> restoreHabit(HabitsTableData snapshot) {
    return into(habitsTable).insertOnConflictUpdate(snapshot);
  }
}

// ---------------------------------------------------------------------------
// Чистые функции расчёта статистики привычки. Вынесены наружу класса, чтобы
// их можно было юнит-тестировать без БД (передаём готовую карту дни→count).
// ---------------------------------------------------------------------------

/// Ключ дня вида YYYY-MM-DD из UTC-полуночи (для группировки и сравнения дней).
/// Дата нормализуется к UTC-дню — так же, как logHabit пишет date.
String dayKey(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Сводка статистики одной привычки.
class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletions,
    required this.daysClean,
  });

  /// Текущая серия.
  /// good: дней подряд (от сегодня/вчера назад), где count за день >= target.
  /// bad: дней подряд БЕЗ логов (дней без срыва), от сегодня назад.
  final int currentStreak;

  /// Лучшая серия за всю историю (того же типа, что и currentStreak).
  final int bestStreak;

  /// good: всего дней, где цель достигнута.
  /// bad: всего нарушений (сумма всех count).
  final int totalCompletions;

  /// Только для bad: дней без срыва (== currentStreak). Для good == currentStreak.
  final int daysClean;
}

/// Считает статистику из карты дни(YYYY-MM-DD)→суммарный count.
///
/// good-привычка:
///   - день «выполнен», если count за день >= targetPerDay;
///   - currentStreak — кол-во выполненных дней подряд, считая от сегодня назад;
///     если сегодня ещё не отмечено, стрик «держится» от вчера (как в StreakService:
///     законченный вчера стрик активен до конца сегодня);
///   - bestStreak — самая длинная серия выполненных дней за всю историю.
/// bad-привычка:
///   - currentStreak/daysClean — дней подряд БЕЗ логов, считая от сегодня назад;
///   - bestStreak — самая длинная серия чистых дней между нарушениями
///     (от первого лога до сегодня);
///   - totalCompletions — суммарное число нарушений.
///
/// Частота (ADR-053, только для good-привычек):
///   - 'daily' — поведение как раньше (каждый день);
///   - 'weekly_days' — стрик считает только ЗАПЛАНИРОВАННЫЕ дни (по [weekdayMask]);
///     незапланированный день пропускается (не рвёт стрик), запланированный
///     невыполненный день — рвёт;
///   - 'weekly_count' — единица стрика = ISO-неделя (с понедельника); неделя
///     «успешна», если суммарных выполнений за неделю >= [weeklyTarget];
///     current/best считаются в успешных неделях, текущая (незавершённая)
///     неделя стрик не рвёт.
HabitStats computeHabitStats({
  required Map<String, int> dayCounts,
  required String type,
  required int targetPerDay,
  required DateTime now,
  String frequencyType = 'daily',
  int weekdayMask = 127,
  int weeklyTarget = 0,
}) {
  final target = targetPerDay < 1 ? 1 : targetPerDay;
  final todayUtc = DateTime.utc(now.year, now.month, now.day);

  if (type == 'bad') {
    final totalViolations =
        dayCounts.values.fold<int>(0, (sum, c) => sum + c);

    // Дней без срыва: от сегодня назад, пока нет логов за день.
    var clean = 0;
    var cursor = todayUtc;
    while (!dayCounts.containsKey(dayKey(cursor))) {
      clean += 1;
      cursor = cursor.subtract(const Duration(days: 1));
      // Защита от бесконечного цикла, если нет ни одного лога вообще.
      if (clean > 3650) break;
    }
    // Если логов нет совсем — нет «истории» чистоты, стрик 0 (нечего считать).
    if (dayCounts.isEmpty) clean = 0;

    // Лучшая серия чистых дней — самый длинный разрыв между днями-нарушениями
    // (плюс хвост до сегодня). Идём от первого нарушения до сегодня.
    var best = clean;
    if (dayCounts.isNotEmpty) {
      final keys = dayCounts.keys.toList()..sort();
      final firstViolation = DateTime.parse('${keys.first}T00:00:00Z');
      var run = 0;
      var d = firstViolation;
      while (!d.isAfter(todayUtc)) {
        if (dayCounts.containsKey(dayKey(d))) {
          run = 0;
        } else {
          run += 1;
          if (run > best) best = run;
        }
        d = d.add(const Duration(days: 1));
      }
    }

    return HabitStats(
      currentStreak: clean,
      bestStreak: best,
      totalCompletions: totalViolations,
      daysClean: clean,
    );
  }

  // good-привычка.
  bool isDone(DateTime day) => (dayCounts[dayKey(day)] ?? 0) >= target;

  // weekly_count — единица стрика — неделя.
  if (frequencyType == 'weekly_count') {
    return _weeklyCountStats(dayCounts, weeklyTarget, todayUtc);
  }
  // weekly_days — стрик по запланированным дням недели.
  if (frequencyType == 'weekly_days') {
    return _weeklyDaysStats(dayCounts, weekdayMask, todayUtc, isDone);
  }

  // daily (по умолчанию).
  final totalDone = dayCounts.values.where((c) => c >= target).length;

  // Текущий стрик: старт = сегодня (если выполнено) иначе вчера.
  var current = 0;
  var cursor = isDone(todayUtc)
      ? todayUtc
      : todayUtc.subtract(const Duration(days: 1));
  while (isDone(cursor)) {
    current += 1;
    cursor = cursor.subtract(const Duration(days: 1));
    if (current > 3650) break;
  }

  // Лучший стрик: проходим все выполненные дни и считаем максимальную серию
  // подряд идущих дат.
  var best = current;
  final doneDays = dayCounts.entries
      .where((e) => e.value >= target)
      .map((e) => e.key)
      .toList()
    ..sort();
  if (doneDays.isNotEmpty) {
    var run = 1;
    best = best < 1 ? 1 : best;
    for (var i = 1; i < doneDays.length; i++) {
      final prev = DateTime.parse('${doneDays[i - 1]}T00:00:00Z');
      final curr = DateTime.parse('${doneDays[i]}T00:00:00Z');
      if (curr.difference(prev).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }
  }

  return HabitStats(
    currentStreak: current,
    bestStreak: best,
    totalCompletions: totalDone,
    daysClean: current,
  );
}

/// Запланирован ли [day] для привычки с данной частотой (ADR-053).
/// - 'daily' → всегда true;
/// - 'weekly_days' → бит дня недели выставлен в [weekdayMask]
///   (Пн = бит 1, Вт = 2, Ср = 4 … Вс = 64; DateTime.weekday: Пн=1..Вс=7);
/// - 'weekly_count' → всегда true (недели обрабатываются отдельно).
bool isScheduledDay(DateTime day, String frequencyType, int weekdayMask) {
  if (frequencyType == 'weekly_days') {
    final bit = 1 << (day.weekday - 1);
    return (weekdayMask & bit) != 0;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Напоминания привычек (ADR-053, slice 4). Чистая часть планирования —
// вынесена сюда, чтобы тестировать БЕЗ БД и БЕЗ плагина уведомлений.
// ---------------------------------------------------------------------------

/// Одно запланированное локальное напоминание привычки.
/// [weekday] == null → ежедневное напоминание (срабатывает каждый день);
/// [weekday] 1..7 (Пн=1..Вс=7, как DateTime.weekday) → еженедельное в этот
/// день недели. [hour]/[minute] — время от полуночи. [notificationId] —
/// стабильный id, выведенный из id привычки (для замены/отмены).
class HabitReminder {
  const HabitReminder({
    required this.notificationId,
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final int notificationId;
  final int? weekday;
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is HabitReminder &&
      other.notificationId == notificationId &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(notificationId, weekday, hour, minute);

  @override
  String toString() =>
      'HabitReminder(id:$notificationId, wd:$weekday, $hour:$minute)';
}

/// Сколько id-слотов резервируется под одну привычку: base (ежедневное) +
/// base+1..base+7 (по одному на день недели). Отмена проходит по всему диапазону.
const int kHabitReminderSlots = 8;

/// Стабильный положительный базовый id уведомления из id привычки [habitId].
/// Один и тот же habitId всегда даёт один base — поэтому повторное планирование
/// перетирает прежнее, а отмена по диапазону [base, base+kHabitReminderSlots)
/// гарантированно снимает все слоты. Базы разнесены шагом 10 (× 10), чтобы
/// диапазоны соседних привычек не пересекались. Диапазон смещён в 2_000_000+,
/// чтобы не пересекаться с review (1001/1002), posture (301..305) и
/// task-напоминаниями (1_000_000+).
int habitReminderBaseId(String habitId) {
  // FNV-1a 32-бит.
  var hash = 0x811c9dc5;
  for (final code in habitId.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 2000000 + (hash % 1000000) * 10;
}

/// Чистый расчёт набора напоминаний для привычки (ADR-053, slice 4).
///   - [reminderMinutes] == null (или вне 0..1439) → пустой список (выключено);
///   - 'daily'        → одно ежедневное напоминание (weekday == null);
///   - 'weekly_count' → одно ежедневное напоминание (v1-упрощение: бьём каждый
///                      день, пока недельная цель не достигнута — это сложно для
///                      v1, поэтому шлём ежедневно; см. ADR-053);
///   - 'weekly_days'  → по одному напоминанию на каждый выставленный в
///                      [weekdayMask] день недели (Пн=бит0..Вс=бит6).
/// Время разбирается из [reminderMinutes]: hour = m ~/ 60, minute = m % 60.
/// id выводятся из [habitId] через [habitReminderBaseId] (стабильны → заменяемы).
List<HabitReminder> computeHabitReminders({
  required String habitId,
  required int? reminderMinutes,
  required String frequencyType,
  required int weekdayMask,
}) {
  final m = reminderMinutes;
  if (m == null || m < 0 || m > 1439) return const [];
  final hour = m ~/ 60;
  final minute = m % 60;
  final base = habitReminderBaseId(habitId);

  if (frequencyType == 'weekly_days') {
    final out = <HabitReminder>[];
    for (var i = 0; i < 7; i++) {
      if ((weekdayMask & (1 << i)) != 0) {
        final weekday = i + 1; // Пн=1..Вс=7
        out.add(HabitReminder(
          notificationId: base + weekday,
          weekday: weekday,
          hour: hour,
          minute: minute,
        ));
      }
    }
    return out;
  }

  // 'daily' и 'weekly_count' → одно ежедневное напоминание.
  return [
    HabitReminder(
      notificationId: base,
      weekday: null,
      hour: hour,
      minute: minute,
    ),
  ];
}

/// Понедельник ISO-недели для [day] (UTC-полночь).
DateTime _mondayOf(DateTime day) {
  final d = DateTime.utc(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Стрик по запланированным дням недели ('weekly_days').
/// Незапланированный день пропускается (не рвёт стрик); запланированный
/// невыполненный день в прошлом — рвёт. Сегодня, если запланировано, но ещё
/// не выполнено, стрик не рвёт (день не закончился).
HabitStats _weeklyDaysStats(
  Map<String, int> dayCounts,
  int weekdayMask,
  DateTime todayUtc,
  bool Function(DateTime) isDone,
) {
  bool scheduled(DateTime d) => isScheduledDay(d, 'weekly_days', weekdayMask);

  final totalDone =
      dayCounts.keys.where((k) {
        final d = DateTime.parse('${k}T00:00:00Z');
        return scheduled(d) && isDone(d);
      }).length;

  // Текущий стрик: от сегодня назад по запланированным дням.
  var current = 0;
  var cursor = todayUtc;
  var guard = 0;
  while (guard < 3650) {
    guard += 1;
    if (scheduled(cursor)) {
      if (isDone(cursor)) {
        current += 1;
      } else if (cursor != todayUtc) {
        // Запланированный невыполненный день в прошлом — стрик прерывается.
        break;
      }
      // Сегодня запланировано, но не выполнено → пропускаем (день не кончился).
    }
    // Незапланированный день — пропускаем без разрыва.
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // Лучший стрик: самая длинная серия запланированных выполненных дней
  // (незапланированные дни не сбрасывают серию).
  var best = current;
  if (dayCounts.isNotEmpty) {
    final keys = dayCounts.keys.toList()..sort();
    var d = DateTime.parse('${keys.first}T00:00:00Z');
    var run = 0;
    while (!d.isAfter(todayUtc)) {
      if (scheduled(d)) {
        if (isDone(d)) {
          run += 1;
          if (run > best) best = run;
        } else if (d != todayUtc) {
          run = 0;
        }
      }
      d = d.add(const Duration(days: 1));
    }
  }

  return HabitStats(
    currentStreak: current,
    bestStreak: best,
    totalCompletions: totalDone,
    daysClean: current,
  );
}

/// Стрик по неделям ('weekly_count'). Единица стрика — ISO-неделя (с Пн).
/// Неделя «успешна», если суммарных выполнений за неделю >= [weeklyTarget].
/// current — успешных недель подряд назад от текущей; текущая (незавершённая)
/// неделя стрик не рвёт. best — самая длинная серия успешных недель.
HabitStats _weeklyCountStats(
  Map<String, int> dayCounts,
  int weeklyTarget,
  DateTime todayUtc,
) {
  final target = weeklyTarget < 1 ? 1 : weeklyTarget;

  // Сумма выполнений по неделям (ключ — понедельник недели).
  final weekCounts = <String, int>{};
  dayCounts.forEach((k, v) {
    final d = DateTime.parse('${k}T00:00:00Z');
    final key = dayKey(_mondayOf(d));
    weekCounts[key] = (weekCounts[key] ?? 0) + v;
  });

  final thisWeek = _mondayOf(todayUtc);
  bool successful(DateTime weekStart) =>
      (weekCounts[dayKey(weekStart)] ?? 0) >= target;

  // Текущий стрик: от текущей недели назад.
  var current = 0;
  var wk = thisWeek;
  var guard = 0;
  while (guard < 520) {
    guard += 1;
    if (successful(wk)) {
      current += 1;
    } else if (wk != thisWeek) {
      // Прошлая неудачная неделя — стрик прерывается.
      break;
    }
    // Текущая неделя ещё не успешна → пропускаем (неделя не кончилась).
    wk = wk.subtract(const Duration(days: 7));
  }

  // Лучший стрик: самая длинная серия успешных недель за всю историю.
  final successfulWeeks =
      weekCounts.values.where((c) => c >= target).length;
  var best = current;
  if (weekCounts.isNotEmpty) {
    final keys = weekCounts.keys.toList()..sort();
    var w = DateTime.parse('${keys.first}T00:00:00Z');
    var run = 0;
    while (!w.isAfter(thisWeek)) {
      if (successful(w)) {
        run += 1;
        if (run > best) best = run;
      } else if (w != thisWeek) {
        run = 0;
      }
      w = w.add(const Duration(days: 7));
    }
  }

  return HabitStats(
    currentStreak: current,
    bestStreak: best,
    totalCompletions: successfulWeeks,
    daysClean: current,
  );
}
