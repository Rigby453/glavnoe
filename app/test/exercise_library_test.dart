// Unit-тесты каталога упражнений (exercise_library.dart).
// PURE: без Flutter-виджетов, без БД, без сети.
//
// Покрывает:
//   - каталог непустой
//   - id уникальны
//   - каждый nameKey/stepKey разрешается в непустую en-строку (через S._all)
//   - lookup exerciseById и exerciseByName работают корректно
//   - дефолты разумны (sets>0, restSeconds>0, reps непустые)

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/features/health/exercise_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Вспомогательная функция: разрешает l10n-ключ в en-строку.
  String resolveEn(String key) {
    final entry = S.all[key];
    if (entry == null) return '';
    return entry['en'] ?? '';
  }

  group('kExerciseLibrary — базовые инварианты', () {
    test('каталог непустой', () {
      expect(kExerciseLibrary, isNotEmpty);
    });

    test('id уникальны', () {
      final ids = kExerciseLibrary.map((e) => e.id).toList();
      final uniqueIds = ids.toSet().toList();
      expect(ids.length, uniqueIds.length, reason: 'найден дублирующий id');
    });

    test('все id непустые', () {
      for (final e in kExerciseLibrary) {
        expect(e.id, isNotEmpty, reason: 'пустой id в каталоге');
      }
    });
  });

  group('kExerciseLibrary — l10n-ключи разрешаются в en', () {
    test('nameKey каждого упражнения разрешается в непустую en-строку', () {
      for (final e in kExerciseLibrary) {
        final name = resolveEn(e.nameKey);
        expect(name, isNotEmpty,
            reason: 'nameKey "${e.nameKey}" не нашёл en-строку (упражнение: ${e.id})');
      }
    });

    test('каждый stepKey разрешается в непустую en-строку', () {
      for (final e in kExerciseLibrary) {
        expect(e.stepKeys, isNotEmpty,
            reason: 'у упражнения "${e.id}" нет шагов техники');
        for (final key in e.stepKeys) {
          final step = resolveEn(key);
          expect(step, isNotEmpty,
              reason: 'stepKey "$key" не нашёл en-строку (упражнение: ${e.id})');
        }
      }
    });

    test('каждый mistakeKey разрешается в непустую en-строку', () {
      for (final e in kExerciseLibrary) {
        for (final key in e.mistakeKeys) {
          final mistake = resolveEn(key);
          expect(mistake, isNotEmpty,
              reason: 'mistakeKey "$key" не нашёл en-строку (упражнение: ${e.id})');
        }
      }
    });
  });

  group('kExerciseLibrary — ru-переводы присутствуют', () {
    String resolveRu(String key) {
      final entry = S.all[key];
      if (entry == null) return '';
      return entry['ru'] ?? '';
    }

    test('nameKey каждого упражнения имеет ru-строку', () {
      for (final e in kExerciseLibrary) {
        final ruName = resolveRu(e.nameKey);
        expect(ruName, isNotEmpty,
            reason: 'nameKey "${e.nameKey}" не имеет ru-перевода (упражнение: ${e.id})');
      }
    });

    test('каждый stepKey имеет ru-строку', () {
      for (final e in kExerciseLibrary) {
        for (final key in e.stepKeys) {
          final ruStep = resolveRu(key);
          expect(ruStep, isNotEmpty,
              reason: 'stepKey "$key" не имеет ru-перевода (упражнение: ${e.id})');
        }
      }
    });

    test('каждый mistakeKey имеет ru-строку', () {
      for (final e in kExerciseLibrary) {
        for (final key in e.mistakeKeys) {
          final ruMistake = resolveRu(key);
          expect(ruMistake, isNotEmpty,
              reason: 'mistakeKey "$key" не имеет ru-перевода (упражнение: ${e.id})');
        }
      }
    });
  });

  group('kExerciseLibrary — разумные дефолты', () {
    test('defaultSets > 0 у всех упражнений', () {
      for (final e in kExerciseLibrary) {
        expect(e.defaultSets, greaterThan(0),
            reason: 'defaultSets <= 0 у "${e.id}"');
      }
    });

    test('defaultRestSeconds > 0 у всех упражнений', () {
      for (final e in kExerciseLibrary) {
        expect(e.defaultRestSeconds, greaterThan(0),
            reason: 'defaultRestSeconds <= 0 у "${e.id}"');
      }
    });

    test('defaultReps непустая строка у всех упражнений', () {
      for (final e in kExerciseLibrary) {
        expect(e.defaultReps.trim(), isNotEmpty,
            reason: 'defaultReps пуст у "${e.id}"');
      }
    });

    test('у всех упражнений есть хотя бы 2 шага техники', () {
      for (final e in kExerciseLibrary) {
        expect(e.stepKeys.length, greaterThanOrEqualTo(2),
            reason: 'у "${e.id}" меньше 2 шагов техники');
      }
    });
  });

  group('exerciseById — поиск по id', () {
    test('находит существующее упражнение', () {
      expect(exerciseById('barbell_back_squat'), isNotNull);
      expect(exerciseById('push_up'), isNotNull);
      expect(exerciseById('plank'), isNotNull);
    });

    test('возвращает null для несуществующего id', () {
      expect(exerciseById('nonexistent_exercise'), isNull);
      expect(exerciseById(''), isNull);
    });

    test('найденное упражнение имеет корректный id', () {
      final ex = exerciseById('pull_up');
      expect(ex, isNotNull);
      expect(ex!.id, 'pull_up');
    });

    test('все id из каталога находятся через exerciseById', () {
      for (final e in kExerciseLibrary) {
        final found = exerciseById(e.id);
        expect(found, isNotNull, reason: 'exerciseById("${e.id}") вернул null');
        expect(found!.id, e.id);
      }
    });
  });

  group('exerciseByName — поиск по отображаемому имени', () {
    // Используем S.all для получения en-строк без BuildContext.
    String enResolver(String key) {
      final entry = S.all[key];
      return entry?['en'] ?? key;
    }

    test('находит по точному en-имени (регистронезависимо)', () {
      // 'Barbell Back Squat' → exercise.barbell_back_squat
      final ex = exerciseByName('Barbell Back Squat', enResolver);
      expect(ex, isNotNull);
      expect(ex!.id, 'barbell_back_squat');
    });

    test('регистронезависимый поиск', () {
      final ex = exerciseByName('barbell back squat', enResolver);
      expect(ex, isNotNull);
      expect(ex!.id, 'barbell_back_squat');
    });

    test('возвращает null для неизвестного имени', () {
      expect(exerciseByName('Totally Unknown Move', enResolver), isNull);
    });
  });

  group('muscleGroup / equipment / difficulty — допустимые значения', () {
    final validMuscleGroups = {
      'legs', 'back', 'chest', 'shoulders', 'arms', 'core', 'full_body', 'cardio',
    };
    final validEquipment = {
      'none', 'dumbbell', 'barbell', 'machine', 'bodyweight', 'band', 'kettlebell',
    };
    final validDifficulty = {'beginner', 'intermediate', 'advanced'};

    test('muscleGroup в допустимом наборе', () {
      for (final e in kExerciseLibrary) {
        expect(validMuscleGroups, contains(e.muscleGroup),
            reason: '"${e.id}".muscleGroup="${e.muscleGroup}" неизвестна');
      }
    });

    test('equipment в допустимом наборе', () {
      for (final e in kExerciseLibrary) {
        expect(validEquipment, contains(e.equipment),
            reason: '"${e.id}".equipment="${e.equipment}" неизвестен');
      }
    });

    test('difficulty в допустимом наборе', () {
      for (final e in kExerciseLibrary) {
        expect(validDifficulty, contains(e.difficulty),
            reason: '"${e.id}".difficulty="${e.difficulty}" неизвестна');
      }
    });
  });

  group('Структура каталога — покрытие основных движений', () {
    test('каталог содержит >= 12 упражнений', () {
      expect(kExerciseLibrary.length, greaterThanOrEqualTo(12));
    });

    test('есть хотя бы одно упражнение ног', () {
      expect(kExerciseLibrary.any((e) => e.muscleGroup == 'legs'), isTrue);
    });

    test('есть хотя бы одно упражнение кора', () {
      expect(kExerciseLibrary.any((e) => e.muscleGroup == 'core'), isTrue);
    });

    test('есть хотя бы одно кардио-упражнение', () {
      expect(kExerciseLibrary.any((e) => e.muscleGroup == 'cardio'), isTrue);
    });

    test('есть хотя бы одно упражнение для груди', () {
      expect(kExerciseLibrary.any((e) => e.muscleGroup == 'chest'), isTrue);
    });

    test('есть хотя бы одно упражнение для спины', () {
      expect(kExerciseLibrary.any((e) => e.muscleGroup == 'back'), isTrue);
    });

    test('videoUrl у всех упражнений равен null (пока не заполнен)', () {
      for (final e in kExerciseLibrary) {
        expect(e.videoUrl, isNull,
            reason: '"${e.id}".videoUrl не null — это неожиданно для стартового каталога');
      }
    });
  });
}
