// Unit-тесты для WorkoutsDao (Phase 2).
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

  test('createWorkout → watchWorkouts возвращает шаблон', () async {
    final id = await dao.createWorkout('Push Day');
    final all = await dao.watchWorkouts().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.name, 'Push Day');
  });

  test('addExercise сохраняет сортировку по порядку добавления', () async {
    final id = await dao.createWorkout('Full Body');
    await dao.addExercise(workoutId: id, name: 'Squat');
    await dao.addExercise(workoutId: id, name: 'Bench Press');
    await dao.addExercise(workoutId: id, name: 'Deadlift');

    final exs = await dao.watchExercises(id).first;
    expect(exs, hasLength(3));
    expect(exs[0].name, 'Squat');
    expect(exs[0].sortOrder, 0);
    expect(exs[1].name, 'Bench Press');
    expect(exs[1].sortOrder, 1);
    expect(exs[2].name, 'Deadlift');
    expect(exs[2].sortOrder, 2);
  });

  test('updateExercise меняет sets и вес', () async {
    final id = await dao.createWorkout('Strength');
    await dao.addExercise(workoutId: id, name: 'OHP', sets: 3, reps: 8);
    final ex = (await dao.watchExercises(id).first).single;

    await dao.updateExercise(ex.id, sets: 5, weightKg: 60.0);
    final updated = (await dao.watchExercises(id).first).single;
    expect(updated.sets, 5);
    expect(updated.weightKg, 60.0);
    // Имя не изменилось
    expect(updated.name, 'OHP');
  });

  test('updateExercise clearWeight обнуляет вес', () async {
    final id = await dao.createWorkout('Cardio');
    await dao.addExercise(workoutId: id, name: 'Run', weightKg: 10.0);
    final ex = (await dao.watchExercises(id).first).single;

    await dao.updateExercise(ex.id, clearWeight: true);
    final updated = (await dao.watchExercises(id).first).single;
    expect(updated.weightKg, isNull);
  });

  test('removeExercise удаляет только указанное упражнение', () async {
    final id = await dao.createWorkout('Pull Day');
    await dao.addExercise(workoutId: id, name: 'Pull-up');
    await dao.addExercise(workoutId: id, name: 'Row');

    final exs = await dao.watchExercises(id).first;
    await dao.removeExercise(exs.first.id);

    final rest = await dao.watchExercises(id).first;
    expect(rest, hasLength(1));
    expect(rest.single.name, 'Row');
  });

  test('deleteWorkout удаляет шаблон каскадно с упражнениями', () async {
    final id = await dao.createWorkout('Leg Day');
    await dao.addExercise(workoutId: id, name: 'Squat');
    await dao.addExercise(workoutId: id, name: 'Lunge');

    final other = await dao.createWorkout('Other');
    await dao.addExercise(workoutId: other, name: 'Plank');

    await dao.deleteWorkout(id);

    // Удалённый шаблон исчез
    expect(await dao.watchWorkouts().first, hasLength(1));
    // Упражнения каскадно удалены
    expect(await dao.watchExercises(id).first, isEmpty);
    // Чужие упражнения не тронуты
    expect(await dao.watchExercises(other).first, hasLength(1));
  });

  test('addExercise сдвигает updatedAt шаблона', () async {
    final id = await dao.createWorkout('Test');
    final before = (await dao.watchWorkouts().first).single.updatedAt;

    // Небольшая задержка чтобы время изменилось
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await dao.addExercise(workoutId: id, name: 'Curl');

    final after = (await dao.watchWorkouts().first).single.updatedAt;
    // updatedAt не ушёл назад
    expect(after.isBefore(before), isFalse);
  });

  test('watchWorkout возвращает null после deleteWorkout', () async {
    final id = await dao.createWorkout('Temp');
    await dao.deleteWorkout(id);
    final result = await dao.watchWorkout(id).first;
    expect(result, isNull);
  });
}
