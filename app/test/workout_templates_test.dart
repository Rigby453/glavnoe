// Unit-тесты офлайн-генератора программ (buildTemplateProgram), AI-парсера
// (parseAiWorkoutProgram) и маппинга reps-строки в int (repsToInt).
// PURE: без Flutter-виджетов и без БД.

import 'package:app/core/settings/rest_default_provider.dart';
import 'package:app/features/health/workout_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTemplateProgram — структура', () {
    test('возвращает ровно daysPerWeek дней (зажато в [1,7])', () {
      for (final d in [1, 2, 3, 4, 5, 6, 7]) {
        final p = buildTemplateProgram(
          goal: 'muscle',
          experience: 'intermediate',
          equipment: const ['full_gym'],
          daysPerWeek: d,
        );
        expect(p.days.length, d, reason: 'daysPerWeek=$d');
      }
    });

    test('число дней зажимается: 0 → 1, 10 → 7', () {
      final low = buildTemplateProgram(
        goal: 'general',
        experience: 'beginner',
        equipment: const ['bodyweight'],
        daysPerWeek: 0,
      );
      expect(low.days.length, 1);

      final high = buildTemplateProgram(
        goal: 'general',
        experience: 'advanced',
        equipment: const ['full_gym'],
        daysPerWeek: 10,
      );
      expect(high.days.length, 7);
    });

    test('каждый день содержит ≥1 упражнение', () {
      final p = buildTemplateProgram(
        goal: 'fat_loss',
        experience: 'intermediate',
        equipment: const ['dumbbells', 'pullup_bar'],
        daysPerWeek: 5,
      );
      for (final day in p.days) {
        expect(day.exercises, isNotEmpty, reason: day.title);
      }
    });
  });

  group('buildTemplateProgram — фильтрация по инвентарю', () {
    // Имена в каталоге несут инвентарь: Barbell*/Dumbbell* и т.п.
    bool mentions(WorkoutProgram p, String needle) => p.days.any(
          (d) => d.exercises.any(
            (e) => e.name.toLowerCase().contains(needle),
          ),
        );

    test('bodyweight-only: НЕТ barbell/dumbbell упражнений', () {
      final p = buildTemplateProgram(
        goal: 'general',
        experience: 'intermediate',
        equipment: const ['bodyweight'],
        daysPerWeek: 6,
      );
      expect(mentions(p, 'barbell'), isFalse);
      expect(mentions(p, 'dumbbell'), isFalse);
      // Должно остаться хотя бы одно упражнение со своим весом.
      expect(p.days.expand((d) => d.exercises), isNotEmpty);
    });

    test('пустой инвентарь деградирует к bodyweight (программа всё равно собирается)', () {
      final p = buildTemplateProgram(
        goal: 'muscle',
        experience: 'beginner',
        equipment: const [],
        daysPerWeek: 3,
      );
      expect(mentions(p, 'barbell'), isFalse);
      expect(mentions(p, 'dumbbell'), isFalse);
      for (final day in p.days) {
        expect(day.exercises, isNotEmpty);
      }
    });

    test('full_gym разблокирует штангу/гантели', () {
      final p = buildTemplateProgram(
        goal: 'strength',
        experience: 'advanced',
        equipment: const ['full_gym'],
        daysPerWeek: 5,
      );
      expect(mentions(p, 'barbell'), isTrue);
    });
  });

  group('buildTemplateProgram — цель/опыт влияют на схему и сплит', () {
    test('strength и endurance дают разную схему подходов/повторов', () {
      final strength = buildTemplateProgram(
        goal: 'strength',
        experience: 'intermediate',
        equipment: const ['full_gym'],
        daysPerWeek: 3,
      );
      final endurance = buildTemplateProgram(
        goal: 'endurance',
        experience: 'intermediate',
        equipment: const ['full_gym'],
        daysPerWeek: 3,
      );
      // Первое силовое упражнение: низкие повторы (4-6) vs высокие (15-20).
      final sReps = strength.days.first.exercises.first.reps;
      final eReps = endurance.days.first.exercises.first.reps;
      expect(sReps, isNot(equals(eReps)));
      expect(strength.programName, isNot(equals(endurance.programName)));
    });

    test('новичок при 4 днях получает full-body сплит, продвинутый — upper/lower', () {
      final beginner = buildTemplateProgram(
        goal: 'muscle',
        experience: 'beginner',
        equipment: const ['full_gym'],
        daysPerWeek: 4,
      );
      final advanced = buildTemplateProgram(
        goal: 'muscle',
        experience: 'advanced',
        equipment: const ['full_gym'],
        daysPerWeek: 4,
      );
      // Заголовки дней теперь КЛЮЧИ (локализуются в localizeWorkoutProgram).
      // Новичок — все дни full-body ('workout.day_full|N'); продвинутый — upper/lower.
      expect(
        beginner.days.every((d) => d.title.startsWith('workout.day_full')),
        isTrue,
      );
      expect(
        advanced.days.any(
          (d) => d.title == 'workout.day_upper' || d.title == 'workout.day_lower',
        ),
        isTrue,
      );
    });
  });

  group('repsToInt — reps-строка → int для БД', () {
    test('"8-12" → 8 (ведущее число диапазона)', () {
      expect(repsToInt('8-12'), 8);
    });

    test('"12" → 12', () {
      expect(repsToInt('12'), 12);
    });

    test('en-dash диапазон "30–45s" → 30', () {
      expect(repsToInt('30–45s'), 30);
    });

    test('"AMRAP" → fallback 10', () {
      expect(repsToInt('AMRAP'), 10);
    });

    test('пустая/нечисловая строка → кастомный fallback', () {
      expect(repsToInt('max', fallback: 8), 8);
      expect(repsToInt(''), 10);
    });
  });

  group('parseAiWorkoutProgram — защитный маппинг ответа бэкенда', () {
    test('полный валидный ответ маппится 1:1', () {
      final p = parseAiWorkoutProgram({
        'program_name': 'AI Strength',
        'note': 'Push hard',
        'days': [
          {
            'title': 'Day 1',
            'exercises': [
              {
                'name': 'Squat',
                'sets': 5,
                'reps': '4-6',
                'rest_seconds': 150,
                'note': 'brace core',
              },
            ],
          },
        ],
      });
      expect(p.programName, 'AI Strength');
      expect(p.note, 'Push hard');
      expect(p.days, hasLength(1));
      final ex = p.days.first.exercises.single;
      expect(ex.name, 'Squat');
      expect(ex.sets, 5);
      expect(ex.reps, '4-6');
      expect(ex.restSeconds, 150);
      expect(ex.note, 'brace core');
    });

    test('пропущенные поля подменяются дефолтами; день/упражнение без имени отбрасываются', () {
      final p = parseAiWorkoutProgram({
        'days': [
          {
            // нет title → авто-заголовок; одно упражнение валидно, одно без имени.
            'exercises': [
              {'name': 'Push-Up'}, // sets/reps/rest отсутствуют → дефолты
              {'sets': 3}, // нет name → отбрасывается
            ],
          },
          {
            'title': 'Empty',
            'exercises': [], // пустой день → отбрасывается
          },
        ],
      });
      expect(p.programName, 'AI Program'); // дефолт
      expect(p.days, hasLength(1));
      final ex = p.days.first.exercises.single;
      expect(ex.name, 'Push-Up');
      expect(ex.sets, 3);
      expect(ex.reps, '10');
      // Пропущенный rest_seconds → сентинель «использовать глобальный дефолт»
      // (kUseDefaultRest = -1, Phase A3), а не легаси-«магическая» 60.
      expect(ex.restSeconds, kUseDefaultRest);
    });

    test('полностью пустой/битый ответ → программа с нулём дней (не падает)', () {
      expect(parseAiWorkoutProgram({}).days, isEmpty);
      expect(parseAiWorkoutProgram({'days': 'nonsense'}).days, isEmpty);
    });
  });

  group('localizeWorkoutProgram — ключи → display-строки', () {
    test('identity-translate: программа из ключей сохраняет ключи', () {
      final p = buildTemplateProgram(
        goal: 'muscle',
        experience: 'beginner', // full-body дни → 'workout.day_full|N'
        equipment: const ['full_gym'],
        daysPerWeek: 2,
      );
      // С translate = identity programName/title остаются ключами (день full
      // теряет суффикс |N после подстановки {n}, которого в ключе нет).
      final loc = localizeWorkoutProgram(p, (k) => k);
      expect(loc.programName, 'workout.program_muscle');
      expect(loc.days.first.title, 'workout.day_full'); // |N снят, {n} не найден
    });

    test('стаб-перевод маппит слаги упражнений через exercise.<slug>', () {
      final p = buildTemplateProgram(
        goal: 'strength',
        experience: 'advanced',
        equipment: const ['barbell'],
        daysPerWeek: 3,
      );
      // Перевод подменяет известные ключи на читаемые строки.
      final dict = {
        'exercise.barbell_bench_press': 'Жим штанги лёжа',
        'workout.program_strength': 'Силовая программа',
        'workout.day_push': 'День жима',
        'workout.day_full': 'Всё тело {n}',
      };
      final loc = localizeWorkoutProgram(p, (k) => dict[k] ?? k);
      expect(loc.programName, 'Силовая программа');
      // Перевод из словаря применился.
      final allNames =
          loc.days.expand((d) => d.exercises.map((e) => e.name)).toList();
      expect(allNames, contains('Жим штанги лёжа'));
      // Имя НИКОГДА не остаётся «голым» слагом без префикса (напр. 'barbell_bench_press').
      // Непереведённый ключ выглядит как 'exercise.<slug>' — это допустимый фолбэк,
      // но bare-слаг (содержит '_', нет точки и нет пробела) — баг маппинга.
      for (final name in allNames) {
        final looksLikeBareSlug =
            name.contains('_') && !name.contains('.') && !name.contains(' ');
        expect(looksLikeBareSlug, isFalse,
            reason: 'имя не должно остаться голым слагом: $name');
      }
    });

    test('нумерованный full-body день подставляет номер {n}', () {
      final p = buildTemplateProgram(
        goal: 'general',
        experience: 'beginner',
        equipment: const ['bodyweight'],
        daysPerWeek: 3, // три дня 'workout.day_full|1..3'
      );
      final loc = localizeWorkoutProgram(
        p,
        (k) => k == 'workout.day_full' ? 'Full Body {n}' : k,
      );
      final titles = loc.days.map((d) => d.title).toList();
      expect(titles, ['Full Body 1', 'Full Body 2', 'Full Body 3']);
    });
  });
}
