// Юнит-тесты для #23 (дефолт отдыха + переопределение) и #22+F (логирование
// фактических reps/weight, отредактированных во время отдыха).
//
// effectiveRestSeconds — чистая функция (без Flutter/prefs), тестируется прямо.
// Логирование фактических значений проверяем на уровне DAO (in-memory Drift):
// тренажёр пишет в Drift через logSet с теми числами, что в полях ввода.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/settings/rest_default_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveRestSeconds (#23: дефолт отдыха + переопределение)', () {
    test('per-exercise == легаси-маркер (60) → берём глобальный дефолт', () {
      // Упражнение «не настраивали» (значение равно старому Constant-дефолту) →
      // применяется глобальный дефолт из Профиля.
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: kLegacyRestMarkerSeconds, // 60
          globalDefaultSeconds: 120,
        ),
        120,
      );
    });

    test('per-exercise задан явно (≠ маркер) → используем его как есть', () {
      // Явное переопределение на упражнении главнее глобального дефолта.
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: 90,
          globalDefaultSeconds: 120,
        ),
        90,
      );
    });

    test('глобальный дефолт по умолчанию = 120с (2 мин)', () {
      expect(kDefaultRestSeconds, 120);
    });

    test('любое значение != 60 явное, даже 0 и большие', () {
      expect(
        effectiveRestSeconds(exerciseRestSeconds: 0, globalDefaultSeconds: 120),
        0,
      );
      expect(
        effectiveRestSeconds(
            exerciseRestSeconds: 240, globalDefaultSeconds: 120),
        240,
      );
    });
  });

  group('#22+F: logSet пишет ФАКТИЧЕСКИЕ (отредактированные) значения', () {
    late AppDatabase db;
    late WorkoutsDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = WorkoutsDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('подход логируется с фактическими reps/weight, а не плановыми',
        () async {
      // Сценарий: план 10×40, во время отдыха пользователь правит на 8×42.5.
      // Тренажёр вызывает logSet с фактическими (отредактированными) числами.
      await dao.logSet(
        sessionId: 's1',
        exerciseId: 'e1',
        setIndex: 0,
        reps: 8, // факт (план был 10)
        weightKg: 42.5, // факт (план был 40)
      );

      final sets = await dao.watchSessionSets('s1').first;
      expect(sets, hasLength(1));
      expect(sets.single.reps, 8);
      expect(sets.single.weightKg, 42.5);
    });

    test('пустое поле веса → bodyweight (null) логируется', () async {
      // #22+F: очистка поля веса = собственный вес.
      await dao.logSet(
        sessionId: 's1',
        exerciseId: 'e1',
        setIndex: 1,
        reps: 12,
      );

      final sets = await dao.watchSessionSets('s1').first;
      expect(sets.single.weightKg, isNull);
      expect(sets.single.reps, 12);
    });
  });
}
