// Юнит-тесты для #A3 (сентинель отдыха kUseDefaultRest) + #23 + #22+F.
//
// effectiveRestSeconds — чистая функция (без Flutter/prefs), тестируется прямо.
// isUseDefaultRest — покрыт отдельными тестами.
// Template builder (buildTemplateProgram) — проверяем что нормальные упражнения
//   получают kUseDefaultRest, а holds/cardio — явный 30с.
// Логирование фактических значений проверяем на уровне DAO (in-memory Drift).
//
// Регрессионные замечания:
//   - kLegacyRestMarkerSeconds (60) по-прежнему рассматривается как «не задан» →
//     сохраняет поведение старых записей БД (обратная совместимость).
//   - kUseDefaultRest (-1) — новый явный сентинель (A3).
//   - Пользователь, введший 60 явно через старый диалог: старые записи остаются
//     со значением 60 и получают глобальный дефолт — известное ограничение,
//     задокументировано тестом.
//   - Новый диалог: пустое поле → kUseDefaultRest (-1); typed 60 → literal 60
//     (всё ещё попадает под legacy-60 маркер — известное ограничение).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/settings/rest_default_provider.dart';
import 'package:app/features/health/workout_templates.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // isUseDefaultRest
  // ---------------------------------------------------------------------------

  group('isUseDefaultRest (A3)', () {
    test('kUseDefaultRest (-1) → true', () {
      expect(isUseDefaultRest(kUseDefaultRest), isTrue);
    });

    test('kLegacyRestMarkerSeconds (60) → true (обратная совместимость)', () {
      expect(isUseDefaultRest(kLegacyRestMarkerSeconds), isTrue);
    });

    test('0 → false (явный ноль — не дефолт)', () {
      expect(isUseDefaultRest(0), isFalse);
    });

    test('положительные явные значения → false', () {
      for (final v in [15, 30, 45, 90, 120, 150, 300, 600]) {
        expect(isUseDefaultRest(v), isFalse, reason: 'value=$v should be explicit');
      }
    });

    test('любое значение кроме -1 и 60 → false', () {
      expect(isUseDefaultRest(61), isFalse);
      expect(isUseDefaultRest(59), isFalse);
      expect(isUseDefaultRest(-2), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // effectiveRestSeconds (#23 + A3)
  // ---------------------------------------------------------------------------

  group('effectiveRestSeconds (#23 + A3)', () {
    test('kUseDefaultRest (-1): явный новый сентинель → глобальный дефолт', () {
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: kUseDefaultRest,
          globalDefaultSeconds: 120,
        ),
        120,
      );
    });

    test('kLegacyRestMarkerSeconds (60): старая запись → глобальный дефолт '
        '(обратная совместимость)', () {
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: kLegacyRestMarkerSeconds,
          globalDefaultSeconds: 240,
        ),
        240,
      );
    });

    test('явное значение != сентинели → используем как есть', () {
      expect(
        effectiveRestSeconds(exerciseRestSeconds: 90, globalDefaultSeconds: 120),
        90,
      );
    });

    test('явное значение 0 → 0, не глобальный дефолт', () {
      expect(
        effectiveRestSeconds(exerciseRestSeconds: 0, globalDefaultSeconds: 120),
        0,
      );
    });

    test('явное большое значение → как есть', () {
      expect(
        effectiveRestSeconds(exerciseRestSeconds: 600, globalDefaultSeconds: 120),
        600,
      );
    });

    test('глобальный дефолт по умолчанию = 120с (2 мин)', () {
      expect(kDefaultRestSeconds, 120);
    });

    // Регресс: глобальный максимум отдыха поднят 600→3600 (60 мин), чтобы
    // совпадать с per-exercise лимитом (clamp(0, 3600) в редакторе) и не
    // обрезать большие значения молча. Минимум не трогаем.
    test('глобальный максимум отдыха = 3600с (60 мин), минимум = 15с', () {
      expect(kRestDefaultMaxSeconds, 3600);
      expect(kRestDefaultMinSeconds, 15);
    });

    test('явное значение 1200с (20 мин) теперь в пределах [min, max]', () {
      expect(1200, greaterThanOrEqualTo(kRestDefaultMinSeconds));
      expect(1200, lessThanOrEqualTo(kRestDefaultMaxSeconds));
    });

    test('упражнение с kUseDefaultRest + глобальный 30 → 30 (диапазон мин)', () {
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: kUseDefaultRest,
          globalDefaultSeconds: kRestDefaultMinSeconds,
        ),
        kRestDefaultMinSeconds,
      );
    });

    // Известное ограничение: пользователь вводит 60 явно → попадает под legacy-маркер.
    // Тест документирует поведение, не исправляет его.
    test('явный ввод 60 → legacy-маркер, получает глобальный дефолт '
        '(известное ограничение — 60 = reserved)', () {
      const globalDefault = 90;
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: 60,
          globalDefaultSeconds: globalDefault,
        ),
        globalDefault, // 60 попадает под legacy-маркер
      );
    });
  });

  // ---------------------------------------------------------------------------
  // buildTemplateProgram: проверяем restSeconds упражнений (A3)
  // ---------------------------------------------------------------------------

  group('buildTemplateProgram: rest за нормальные / hold упражнения (A3)', () {
    // Утилита: собрать простую программу и вернуть все restSeconds.
    List<int> collectRest({
      String goal = 'general',
      String experience = 'intermediate',
      List<String> equipment = const ['bodyweight'],
      int daysPerWeek = 1,
    }) {
      final program = buildTemplateProgram(
        goal: goal,
        experience: experience,
        equipment: equipment,
        daysPerWeek: daysPerWeek,
      );
      return [
        for (final day in program.days)
          for (final ex in day.exercises) ex.restSeconds,
      ];
    }

    test('нормальные силовые (full-body, bodyweight) → kUseDefaultRest', () {
      final rests = collectRest(goal: 'general', equipment: ['bodyweight']);
      // Силовые (push/pull/legs) должны быть kUseDefaultRest.
      final nonHold = rests.where((r) => r != 30).toList();
      for (final r in nonHold) {
        expect(r, kUseDefaultRest,
            reason: 'non-hold exercise rest should be kUseDefaultRest but got $r');
      }
    });

    test('core / cardio holds → явный 30с', () {
      // fat_loss добавляет cardio-финишеры в каждый день.
      final rests = collectRest(goal: 'fat_loss', equipment: ['bodyweight']);
      // Holds (core/cardio) должны быть 30.
      final holds = rests.where((r) => r == 30).toList();
      expect(holds, isNotEmpty, reason: 'fat_loss bodyweight должен содержать holds (30s)');
    });

    test('strength goal: все силовые → kUseDefaultRest', () {
      final rests = collectRest(goal: 'strength', equipment: ['barbell', 'full_gym']);
      final nonHold = rests.where((r) => r != 30).toList();
      for (final r in nonHold) {
        expect(r, kUseDefaultRest,
            reason: 'strength exercise rest should be kUseDefaultRest but got $r');
      }
    });

    test('muscle goal: все силовые → kUseDefaultRest', () {
      final rests = collectRest(goal: 'muscle', equipment: ['dumbbells']);
      final nonHold = rests.where((r) => r != 30).toList();
      for (final r in nonHold) {
        expect(r, kUseDefaultRest);
      }
    });

    test('endurance goal: все силовые → kUseDefaultRest', () {
      final rests = collectRest(goal: 'endurance', equipment: ['bodyweight']);
      final nonHold = rests.where((r) => r != 30).toList();
      for (final r in nonHold) {
        expect(r, kUseDefaultRest);
      }
    });

    test('program содержит только kUseDefaultRest или 30 — никаких других sentinel', () {
      // Убеждаемся, что старый kLegacyRestMarkerSeconds (60) больше НЕ появляется
      // в шаблонных программах.
      final rests = collectRest(
        goal: 'general',
        equipment: ['bodyweight'],
        daysPerWeek: 3,
      );
      for (final r in rests) {
        expect(r == kUseDefaultRest || r == 30, isTrue,
            reason: 'template rest should be -1 or 30, got $r');
      }
    });

    test('effectiveRestSeconds для kUseDefaultRest из шаблона с глобальным 240', () {
      // Полная цепочка: шаблон → kUseDefaultRest → effectiveRestSeconds → глобальный дефолт.
      const globalDefault = 240;
      final rests = collectRest(goal: 'general', equipment: ['bodyweight']);
      final nonHold = rests.where((r) => r != 30).toList();
      expect(nonHold, isNotEmpty);
      for (final r in nonHold) {
        expect(
          effectiveRestSeconds(
            exerciseRestSeconds: r,
            globalDefaultSeconds: globalDefault,
          ),
          globalDefault,
          reason: 'template normal exercise должно резолвиться в globalDefault',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // #22+F: logSet пишет ФАКТИЧЕСКИЕ (отредактированные) значения
  // ---------------------------------------------------------------------------

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

    test('addExercise: дефолт restSeconds = kUseDefaultRest (-1), не 60', () async {
      // Проверяем что DAO по умолчанию пишет kUseDefaultRest, а не 60.
      const workoutId = 'w1';
      await dao.createWorkout(workoutId);
      await dao.addExercise(workoutId: workoutId, name: 'Push-up');

      // Читаем добавленное упражнение.
      final exList = await dao.watchExercises(workoutId).first;
      expect(exList, hasLength(1));
      expect(exList.single.restSeconds, kUseDefaultRest);
    });

    test('addExercise: явное значение 90 сохраняется как есть (≠ сентинель)', () async {
      const workoutId = 'w2';
      await dao.createWorkout(workoutId);
      await dao.addExercise(
        workoutId: workoutId,
        name: 'Squat',
        restSeconds: 90,
      );

      final exList = await dao.watchExercises(workoutId).first;
      expect(exList.single.restSeconds, 90);
    });

    test('полная цепочка: addExercise kUseDefaultRest → effectiveRestSeconds → 120',
        () async {
      const workoutId = 'w3';
      await dao.createWorkout(workoutId);
      await dao.addExercise(workoutId: workoutId, name: 'Pull-up');

      final exList = await dao.watchExercises(workoutId).first;
      final effective = effectiveRestSeconds(
        exerciseRestSeconds: exList.single.restSeconds,
        globalDefaultSeconds: 120,
      );
      expect(effective, 120);
    });
  });
}
