// DAO для шаблонов тренировок (Phase 2).
// Офлайн-первый: все данные только в Drift, синхронизация не предусмотрена.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'workouts_dao.g.dart';

@DriftAccessor(tables: [WorkoutsTable, WorkoutExercisesTable, WorkoutSessionsTable])
class WorkoutsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutsDaoMixin {
  WorkoutsDao(super.db);

  // ---------------------------------------------------------------------------
  // Шаблоны тренировок
  // ---------------------------------------------------------------------------

  /// Реактивный список всех шаблонов, сортировка: самые свежие первыми.
  Stream<List<WorkoutsTableData>> watchWorkouts() {
    return (select(workoutsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Реактивно: один шаблон по id (null, если удалён).
  Stream<WorkoutsTableData?> watchWorkout(String id) {
    return (select(workoutsTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Создать новый шаблон; возвращает id созданной записи.
  Future<String> createWorkout(String name) async {
    final id = uuidV4();
    final now = DateTime.now();
    await into(workoutsTable).insert(
      WorkoutsTableCompanion(
        id: Value(id),
        name: Value(name),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  /// Переименовать шаблон; сдвигает updatedAt.
  Future<void> renameWorkout(String id, String name) async {
    await (update(workoutsTable)..where((t) => t.id.equals(id))).write(
      WorkoutsTableCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить шаблон и все его упражнения (каскад в транзакции).
  Future<void> deleteWorkout(String id) async {
    await transaction(() async {
      await (delete(workoutExercisesTable)
            ..where((t) => t.workoutId.equals(id)))
          .go();
      await (delete(workoutsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Упражнения
  // ---------------------------------------------------------------------------

  /// Реактивный список упражнений шаблона, сортировка: по sortOrder.
  Stream<List<WorkoutExercisesTableData>> watchExercises(String workoutId) {
    return (select(workoutExercisesTable)
          ..where((t) => t.workoutId.equals(workoutId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Добавить упражнение в шаблон.
  Future<void> addExercise({
    required String workoutId,
    required String name,
    int sets = 3,
    int reps = 10,
    double? weightKg,
    int restSeconds = 60,
    String? technique,
  }) async {
    // sortOrder = текущее кол-во упражнений
    final existing = await (select(workoutExercisesTable)
          ..where((t) => t.workoutId.equals(workoutId)))
        .get();
    final sortOrder = existing.length;

    await into(workoutExercisesTable).insert(
      WorkoutExercisesTableCompanion(
        id: Value(uuidV4()),
        workoutId: Value(workoutId),
        name: Value(name),
        sets: Value(sets),
        reps: Value(reps),
        weightKg: Value(weightKg),
        restSeconds: Value(restSeconds),
        technique: Value(technique),
        sortOrder: Value(sortOrder),
      ),
    );

    // Сдвигаем updatedAt родительского шаблона
    await (update(workoutsTable)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Обновить поля упражнения (частично — только переданные значения).
  Future<void> updateExercise(
    String id, {
    String? name,
    int? sets,
    int? reps,
    double? weightKg,
    bool clearWeight = false,
    int? restSeconds,
    String? technique,
    bool clearTechnique = false,
  }) async {
    // Читаем workoutId до обновления, чтобы сдвинуть updatedAt шаблона
    final row = await (select(workoutExercisesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    // Собираем Companion вручную: Drift не поддерживает if внутри конструктора
    var companion = const WorkoutExercisesTableCompanion();
    if (name != null) companion = companion.copyWith(name: Value(name));
    if (sets != null) companion = companion.copyWith(sets: Value(sets));
    if (reps != null) companion = companion.copyWith(reps: Value(reps));
    if (clearWeight) {
      companion = companion.copyWith(weightKg: const Value(null));
    } else if (weightKg != null) {
      companion = companion.copyWith(weightKg: Value(weightKg));
    }
    if (restSeconds != null) {
      companion = companion.copyWith(restSeconds: Value(restSeconds));
    }
    if (clearTechnique) {
      companion = companion.copyWith(technique: const Value(null));
    } else if (technique != null) {
      companion = companion.copyWith(technique: Value(technique));
    }

    await (update(workoutExercisesTable)..where((t) => t.id.equals(id)))
        .write(companion);

    // Сдвигаем updatedAt родительского шаблона
    await (update(workoutsTable)
          ..where((t) => t.id.equals(row.workoutId)))
        .write(WorkoutsTableCompanion(updatedAt: Value(DateTime.now())));
  }

  /// Удалить упражнение по id.
  Future<void> removeExercise(String id) async {
    // Читаем workoutId до удаления, чтобы сдвинуть updatedAt шаблона
    final row = await (select(workoutExercisesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (delete(workoutExercisesTable)..where((t) => t.id.equals(id))).go();
    if (row != null) {
      await (update(workoutsTable)
            ..where((t) => t.id.equals(row.workoutId)))
          .write(WorkoutsTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  /// Восстановить удалённое упражнение по снапшоту (Undo-паттерн).
  /// Сохраняет оригинальный id и все поля — без изменений схемы БД.
  Future<void> restoreExercise(WorkoutExercisesTableData snapshot) async {
    // insertOnConflictUpdate: если упражнение вдруг не удалено — обновляем.
    await into(workoutExercisesTable).insertOnConflictUpdate(
      WorkoutExercisesTableCompanion(
        id: Value(snapshot.id),
        workoutId: Value(snapshot.workoutId),
        name: Value(snapshot.name),
        sets: Value(snapshot.sets),
        reps: Value(snapshot.reps),
        weightKg: Value(snapshot.weightKg),
        restSeconds: Value(snapshot.restSeconds),
        technique: Value(snapshot.technique),
        sortOrder: Value(snapshot.sortOrder),
      ),
    );
    // Сдвигаем updatedAt шаблона
    await (update(workoutsTable)
          ..where((t) => t.id.equals(snapshot.workoutId)))
        .write(WorkoutsTableCompanion(updatedAt: Value(DateTime.now())));
  }

  // ---------------------------------------------------------------------------
  // Сессии тренировок
  // ---------------------------------------------------------------------------

  /// Начать новую сессию; возвращает id созданной записи.
  /// finishedAt остаётся null до явного вызова finishSession.
  Future<String> startSession(String workoutId, String workoutName) async {
    final id = uuidV4();
    await into(workoutSessionsTable).insert(
      WorkoutSessionsTableCompanion(
        id: Value(id),
        workoutId: Value(workoutId),
        workoutName: Value(workoutName),
        startedAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  /// Завершить сессию: выставляет finishedAt = now.
  Future<void> finishSession(String id) async {
    await (update(workoutSessionsTable)..where((t) => t.id.equals(id))).write(
      WorkoutSessionsTableCompanion(
        finishedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Реактивный список завершённых сессий за последние [days] дней,
  /// свежие первыми. Незавершённые (finishedAt = null) не включаются.
  Stream<List<WorkoutSessionsTableData>> watchRecentSessions(int days) {
    final since = DateTime.now().subtract(Duration(days: days));
    return (select(workoutSessionsTable)
          ..where(
            (t) =>
                t.finishedAt.isNotNull() &
                t.startedAt.isBiggerOrEqualValue(since),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }
}
