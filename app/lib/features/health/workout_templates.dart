// Бесплатный (offline, без ИИ) генератор программ тренировок (Feature A).
//
// PURE + тестируемый: никаких Flutter-зависимостей, никакой сети, никакой БД*.
// На вход — ответы анкеты, на выход — структурированная WorkoutProgram
// (имя + дни + упражнения с подходами/повторами/отдыхом).
//
// ВАЖНО: и бесплатный путь (buildTemplateProgram), и AI-путь (ответ
// /ai/workout-build → parseAiWorkoutProgram) маппятся в ОДНУ И ТУ ЖЕ модель
// WorkoutProgram, чтобы маршрут сохранения был общим (saveWorkoutProgram).
//
// * Единственная не-pure функция — saveWorkoutProgram (внизу файла): она пишет
//   программу в Drift через WorkoutsDao. Сам Dao — чистый Dart (без Flutter),
//   так что файл по-прежнему не тянет Flutter SDK и тестируется без виджетов.

import '../../core/database/daos/workouts_dao.dart';
import '../../core/settings/rest_default_provider.dart';

// ---------------------------------------------------------------------------
// Модель программы (общая для template-пути и AI-ответа)
// ---------------------------------------------------------------------------

/// Одно упражнение в дне программы.
/// [reps] — СТРОКА (как и в API): диапазон "8-12" или "AMRAP". Целое для БД
/// извлекается отдельно в маршруте сохранения (см. repsToInt).
class ProgramExercise {
  const ProgramExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.note,
  });

  final String name;
  final int sets;
  final String reps;
  final int restSeconds;
  final String? note;
}

/// Один тренировочный день программы (станет одним шаблоном Workout).
class ProgramDay {
  const ProgramDay({required this.title, required this.exercises});

  final String title;
  final List<ProgramExercise> exercises;
}

/// Готовая программа: имя + дни + заметка тренера.
class WorkoutProgram {
  const WorkoutProgram({
    required this.programName,
    required this.days,
    this.note = '',
  });

  final String programName;
  final List<ProgramDay> days;
  final String note;
}

// ---------------------------------------------------------------------------
// Каталог упражнений (модест, первый драфт — пользователь потом правит)
// ---------------------------------------------------------------------------

/// Шаблон упражнения с требуемым инвентарём и группой движения.
/// [equipment] — какой инвентарь НУЖЕН (одно из barbell/dumbbells/pullup_bar/
/// bodyweight). 'full_gym' в запросе разблокирует всё (см. _hasEquipment).
class _ExerciseTemplate {
  const _ExerciseTemplate({
    required this.key,
    required this.equipment,
    required this.group, // 'push' | 'pull' | 'legs' | 'core' | 'cardio'
  });

  /// Стабильный слаг-ключ упражнения (без префикса 'exercise.').
  /// Локализация делается в localizeWorkoutProgram() через `exercise.<key>`.
  /// ВАЖНО: слаг сохраняет подстроку 'barbell'/'dumbbell', если упражнению
  /// нужен этот инвентарь — на это завязан unit-тест фильтрации по e.name.
  final String key;
  final String equipment;
  final String group;
}

// Скромный пул упражнений. Достаточно разнообразный, чтобы собрать
// push/pull/legs и full-body под доступный инвентарь.
// Английские названия в комментариях — реальные display-строки лежат в
// lib/core/l10n/strings/health_b.dart под ключами 'exercise.<key>'.
const List<_ExerciseTemplate> _catalog = [
  // --- Push (грудь/плечи/трицепс) ---
  _ExerciseTemplate(key: 'barbell_bench_press', equipment: 'barbell', group: 'push'), // Barbell Bench Press
  _ExerciseTemplate(key: 'overhead_barbell_press', equipment: 'barbell', group: 'push'), // Overhead Barbell Press
  _ExerciseTemplate(key: 'dumbbell_bench_press', equipment: 'dumbbells', group: 'push'), // Dumbbell Bench Press
  _ExerciseTemplate(key: 'dumbbell_shoulder_press', equipment: 'dumbbells', group: 'push'), // Dumbbell Shoulder Press
  _ExerciseTemplate(key: 'dumbbell_lateral_raise', equipment: 'dumbbells', group: 'push'), // Dumbbell Lateral Raise
  _ExerciseTemplate(key: 'push_up', equipment: 'bodyweight', group: 'push'), // Push-Up
  _ExerciseTemplate(key: 'pike_push_up', equipment: 'bodyweight', group: 'push'), // Pike Push-Up
  _ExerciseTemplate(key: 'dip', equipment: 'bodyweight', group: 'push'), // Dip

  // --- Pull (спина/бицепс) ---
  _ExerciseTemplate(key: 'barbell_row', equipment: 'barbell', group: 'pull'), // Barbell Row
  _ExerciseTemplate(key: 'barbell_curl', equipment: 'barbell', group: 'pull'), // Barbell Curl
  _ExerciseTemplate(key: 'dumbbell_row', equipment: 'dumbbells', group: 'pull'), // Dumbbell Row
  _ExerciseTemplate(key: 'dumbbell_curl', equipment: 'dumbbells', group: 'pull'), // Dumbbell Curl
  _ExerciseTemplate(key: 'pull_up', equipment: 'pullup_bar', group: 'pull'), // Pull-Up
  _ExerciseTemplate(key: 'chin_up', equipment: 'pullup_bar', group: 'pull'), // Chin-Up
  _ExerciseTemplate(key: 'inverted_row', equipment: 'bodyweight', group: 'pull'), // Inverted Row
  _ExerciseTemplate(key: 'superman_hold', equipment: 'bodyweight', group: 'pull'), // Superman Hold

  // --- Legs (ноги/ягодицы) ---
  _ExerciseTemplate(key: 'barbell_back_squat', equipment: 'barbell', group: 'legs'), // Barbell Back Squat
  _ExerciseTemplate(key: 'barbell_deadlift', equipment: 'barbell', group: 'legs'), // Barbell Deadlift
  _ExerciseTemplate(key: 'barbell_romanian_deadlift', equipment: 'barbell', group: 'legs'), // Barbell Romanian Deadlift
  _ExerciseTemplate(key: 'dumbbell_goblet_squat', equipment: 'dumbbells', group: 'legs'), // Dumbbell Goblet Squat
  _ExerciseTemplate(key: 'dumbbell_lunge', equipment: 'dumbbells', group: 'legs'), // Dumbbell Lunge
  _ExerciseTemplate(key: 'bodyweight_squat', equipment: 'bodyweight', group: 'legs'), // Bodyweight Squat
  _ExerciseTemplate(key: 'bulgarian_split_squat', equipment: 'bodyweight', group: 'legs'), // Bulgarian Split Squat
  _ExerciseTemplate(key: 'glute_bridge', equipment: 'bodyweight', group: 'legs'), // Glute Bridge

  // --- Core ---
  _ExerciseTemplate(key: 'plank', equipment: 'bodyweight', group: 'core'), // Plank
  _ExerciseTemplate(key: 'hanging_knee_raise', equipment: 'pullup_bar', group: 'core'), // Hanging Knee Raise
  _ExerciseTemplate(key: 'hollow_body_hold', equipment: 'bodyweight', group: 'core'), // Hollow Body Hold
  _ExerciseTemplate(key: 'russian_twist', equipment: 'bodyweight', group: 'core'), // Russian Twist

  // --- Cardio / conditioning (для fat_loss/endurance) ---
  _ExerciseTemplate(key: 'burpee', equipment: 'bodyweight', group: 'cardio'), // Burpee
  _ExerciseTemplate(key: 'mountain_climber', equipment: 'bodyweight', group: 'cardio'), // Mountain Climber
  _ExerciseTemplate(key: 'jumping_jack', equipment: 'bodyweight', group: 'cardio'), // Jumping Jack
  _ExerciseTemplate(key: 'high_knees', equipment: 'bodyweight', group: 'cardio'), // High Knees
];

/// Доступен ли инвентарь упражнения. 'full_gym' разблокирует всё; bodyweight
/// доступен всегда, если пользователь выбрал bodyweight ИЛИ full_gym (или если
/// список вообще пуст — деградация к bodyweight).
bool _hasEquipment(String needed, List<String> available) {
  if (available.contains('full_gym')) return true;
  return available.contains(needed);
}

/// Фильтрует каталог по доступному инвентарю.
List<_ExerciseTemplate> _availableExercises(List<String> equipment) {
  // Пустой ввод деградирует к собственному весу — программа всегда соберётся.
  final eq = equipment.isEmpty ? const ['bodyweight'] : equipment;
  return _catalog.where((e) => _hasEquipment(e.equipment, eq)).toList();
}

// ---------------------------------------------------------------------------
// Подходы/повторы/отдых по цели и опыту
// ---------------------------------------------------------------------------

/// Схема подходов/повторов для цели тренировки (без поля rest — он теперь всегда
/// kUseDefaultRest для силовых/обычных упражнений, см. pick() ниже).
/// Исключение: core/cardio (timed holds) получают явный короткий отдых (30с) в pick().
({int sets, String reps}) _schemeFor(String goal, String experience) {
  // Новичкам — меньше объёма (меньше подходов).
  final setBias = experience == 'beginner' ? -1 : (experience == 'advanced' ? 1 : 0);
  switch (goal) {
    case 'strength':
      return (sets: 4 + setBias, reps: '4-6');
    case 'muscle':
      return (sets: 4 + setBias, reps: '8-12');
    case 'fat_loss':
      return (sets: 3 + setBias, reps: '12-15');
    case 'endurance':
      return (sets: 3 + setBias, reps: '15-20');
    case 'general':
    default:
      return (sets: 3 + setBias, reps: '10-12');
  }
}

// Порядок «сплитов» по числу дней. Новичкам и при 1-3 днях — full-body,
// иначе классический push/pull/legs (с повтором при 4+).
List<String> _splitFor({required int daysPerWeek, required String experience}) {
  final d = daysPerWeek.clamp(1, 7);
  // Новичок всегда тренируется full-body — лучшая частота на группу.
  if (experience == 'beginner' || d <= 2) {
    return List.filled(d, 'full');
  }
  if (d == 3) return ['push', 'pull', 'legs'];
  if (d == 4) return ['upper', 'lower', 'upper', 'lower'];
  if (d == 5) return ['push', 'pull', 'legs', 'upper', 'lower'];
  if (d == 6) return ['push', 'pull', 'legs', 'push', 'pull', 'legs'];
  return ['push', 'pull', 'legs', 'upper', 'lower', 'full', 'core'];
}

/// Группы движений, которые входят в день данного типа.
List<String> _groupsForDay(String dayType, String goal) {
  // fat_loss/endurance добавляют кардио-финишер в каждый день.
  final conditioning =
      (goal == 'fat_loss' || goal == 'endurance') ? const ['cardio'] : const <String>[];
  switch (dayType) {
    case 'push':
      return ['push', 'push', ...conditioning];
    case 'pull':
      return ['pull', 'pull', 'core', ...conditioning];
    case 'legs':
      return ['legs', 'legs', 'core', ...conditioning];
    case 'upper':
      return ['push', 'pull', 'push', 'pull', ...conditioning];
    case 'lower':
      return ['legs', 'legs', 'core', ...conditioning];
    case 'core':
      return ['core', 'core', ...conditioning];
    case 'full':
    default:
      return ['legs', 'push', 'pull', 'core', ...conditioning];
  }
}

/// КЛЮЧ заголовка дня (не display-строка). Локализуется в
/// localizeWorkoutProgram(). Для нумерованного full-body дня ключ несёт
/// индекс через разделитель '|': 'workout.day_full|N' (N = index+1).
String _dayTitle(String dayType, int index) {
  switch (dayType) {
    case 'push':
      return 'workout.day_push';
    case 'pull':
      return 'workout.day_pull';
    case 'legs':
      return 'workout.day_legs';
    case 'upper':
      return 'workout.day_upper';
    case 'lower':
      return 'workout.day_lower';
    case 'core':
      return 'workout.day_core';
    case 'full':
    default:
      return 'workout.day_full|${index + 1}';
  }
}

/// КЛЮЧ имени программы по цели (не display-строка).
/// Локализуется в localizeWorkoutProgram().
String _programName(String goal) {
  switch (goal) {
    case 'strength':
      return 'workout.program_strength';
    case 'muscle':
      return 'workout.program_muscle';
    case 'fat_loss':
      return 'workout.program_fat_loss';
    case 'endurance':
      return 'workout.program_endurance';
    case 'general':
    default:
      return 'workout.program_general';
  }
}

// ---------------------------------------------------------------------------
// Главная функция: собрать программу из ответов анкеты (PURE)
// ---------------------------------------------------------------------------

/// Собирает программу тренировок из ответов анкеты, БЕЗ ИИ и без сети.
///
/// [goal]         — strength | muscle | fat_loss | endurance | general
/// [experience]   — beginner | intermediate | advanced
/// [equipment]    — доступный инвентарь (barbell/dumbbells/pullup_bar/
///                  bodyweight/full_gym); пустой список деградирует к bodyweight.
/// [daysPerWeek]  — 1..7; число дней в программе равно этому значению.
///
/// Гарантии (см. тесты):
///  - days.length == daysPerWeek (зажато в [1,7]);
///  - используются ТОЛЬКО упражнения с доступным инвентарём;
///  - каждый день непустой.
WorkoutProgram buildTemplateProgram({
  required String goal,
  required String experience,
  required List<String> equipment,
  required int daysPerWeek,
}) {
  final available = _availableExercises(equipment);
  final scheme = _schemeFor(goal, experience);
  final split = _splitFor(daysPerWeek: daysPerWeek, experience: experience);

  // Группируем доступные упражнения по группе движения для быстрого выбора.
  final byGroup = <String, List<_ExerciseTemplate>>{};
  for (final e in available) {
    byGroup.putIfAbsent(e.group, () => []).add(e);
  }

  // Курсор по каждой группе, чтобы дни не повторяли одни и те же упражнения.
  final cursor = <String, int>{};

  ProgramExercise? pick(String group) {
    final pool = byGroup[group];
    if (pool == null || pool.isEmpty) return null;
    final i = (cursor[group] ?? 0) % pool.length;
    cursor[group] = i + 1;
    final t = pool[i];
    // Кор/кардио выполняются на время удержания → явный короткий отдых 30с.
    // Силовые/обычные упражнения → kUseDefaultRest: тренажёр подставит
    // глобальный дефолт пользователя из restDefaultProvider.
    final isHold = t.group == 'core' || t.group == 'cardio';
    return ProgramExercise(
      name: t.key, // слаг; локализуется в localizeWorkoutProgram()
      sets: scheme.sets.clamp(2, 6),
      reps: isHold ? (t.group == 'core' ? '30-45s' : '30s') : scheme.reps,
      restSeconds: isHold ? 30 : kUseDefaultRest,
    );
  }

  final days = <ProgramDay>[];
  for (var d = 0; d < split.length; d++) {
    final dayType = split[d];
    final groups = _groupsForDay(dayType, goal);
    final exercises = <ProgramExercise>[];
    for (final g in groups) {
      final ex = pick(g);
      if (ex != null) exercises.add(ex);
    }
    // Защита: если для типа дня ничего не нашлось (узкий инвентарь),
    // докидываем любое доступное упражнение, чтобы день не был пустым.
    if (exercises.isEmpty && available.isNotEmpty) {
      final t = available[d % available.length];
      exercises.add(ProgramExercise(
        name: t.key, // слаг; локализуется в localizeWorkoutProgram()
        sets: scheme.sets.clamp(2, 6),
        reps: scheme.reps,
        restSeconds: kUseDefaultRest, // глобальный дефолт
      ));
    }
    days.add(ProgramDay(title: _dayTitle(dayType, d), exercises: exercises));
  }

  return WorkoutProgram(
    programName: _programName(goal),
    days: days,
    note: '',
  );
}

// ---------------------------------------------------------------------------
// Локализация шаблонной программы (PURE): ключи → display-строки
// ---------------------------------------------------------------------------

/// Превращает программу с КЛЮЧАМИ (которую отдаёт buildTemplateProgram) в
/// программу с локализованными display-строками, готовую к сохранению в БД.
///
/// Маппинг ключей на переводы:
///  - programName уже хранит полный ключ 'workout.program_*' → translate(...).
///  - day.title:
///      * 'workout.day_full|N' → translate('workout.day_full') с подстановкой
///        {n} = N (нумерованный full-body день);
///      * иначе полный ключ 'workout.day_*' → translate(...).
///  - exercise.name хранит «голый» слаг (напр. 'barbell_bench_press');
///    переводим как `translate('exercise.<slug>')`. note/sets/reps/rest — как есть.
///
/// РОБАСТНОСТЬ: translate() сам откатывается на en, а затем на сам ключ, поэтому
/// отсутствующий перевод (translate(key) == key) — не ошибка. [translate]
/// совместима с сигнатурой context.s.
WorkoutProgram localizeWorkoutProgram(
  WorkoutProgram program,
  String Function(String key) translate,
) {
  String localizeDayTitle(String title) {
    const fullPrefix = 'workout.day_full|';
    if (title.startsWith(fullPrefix)) {
      final n = title.substring(fullPrefix.length);
      return translate('workout.day_full').replaceAll('{n}', n);
    }
    return translate(title);
  }

  final days = program.days.map((day) {
    final exercises = day.exercises
        .map((ex) => ProgramExercise(
              name: translate('exercise.${ex.name}'),
              sets: ex.sets,
              reps: ex.reps,
              restSeconds: ex.restSeconds,
              note: ex.note,
            ))
        .toList();
    return ProgramDay(title: localizeDayTitle(day.title), exercises: exercises);
  }).toList();

  return WorkoutProgram(
    programName: translate(program.programName),
    days: days,
    note: program.note,
  );
}

// ---------------------------------------------------------------------------
// AI-путь: ответ бэкенда /ai/workout-build → WorkoutProgram (защитный парсер)
// ---------------------------------------------------------------------------

/// Маппит тело ответа /ai/workout-build в [WorkoutProgram].
///
/// Ожидаемая форма (snake_case, как в api-spec):
///   { program_name, note, days: [ { title, exercises: [
///       { name, sets, reps(строка), rest_seconds, note? } ] } ] }
///
/// ЗАЩИТНЫЙ: любое отсутствующее/кривое поле подменяется разумным дефолтом,
/// чтобы UI никогда не падал на неполном ответе модели. Пустые/битые
/// упражнения и дни без упражнений отбрасываются.
WorkoutProgram parseAiWorkoutProgram(Map<String, dynamic> json) {
  final programName = (json['program_name'] as String?)?.trim();
  final note = (json['note'] as String?)?.trim() ?? '';

  final rawDays = json['days'];
  final days = <ProgramDay>[];
  if (rawDays is List) {
    for (final rawDay in rawDays) {
      if (rawDay is! Map) continue;
      final day = Map<String, dynamic>.from(rawDay);

      final rawExercises = day['exercises'];
      final exercises = <ProgramExercise>[];
      if (rawExercises is List) {
        for (final rawEx in rawExercises) {
          if (rawEx is! Map) continue;
          final ex = Map<String, dynamic>.from(rawEx);
          final name = (ex['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue; // упражнение без имени — мусор
          exercises.add(
            ProgramExercise(
              name: name,
              sets: _asPositiveInt(ex['sets'], fallback: 3),
              // reps приходит строкой ("8-12"/"AMRAP"); число для БД извлекаем позже.
              reps: _asReps(ex['reps']),
              // Если AI не прислал rest_seconds — используем kUseDefaultRest, чтобы
              // тренажёр применил глобальный дефолт пользователя.
              restSeconds: _asNonNegativeInt(ex['rest_seconds']) ?? kUseDefaultRest,
              note: (ex['note'] as String?)?.trim(),
            ),
          );
        }
      }

      if (exercises.isEmpty) continue; // день без упражнений не сохраняем
      final title = (day['title'] as String?)?.trim();
      days.add(
        ProgramDay(
          title: title == null || title.isEmpty ? 'Workout ${days.length + 1}' : title,
          exercises: exercises,
        ),
      );
    }
  }

  return WorkoutProgram(
    programName: programName == null || programName.isEmpty ? 'AI Program' : programName,
    days: days,
    note: note,
  );
}

/// Приводит динамическое значение к положительному int (терпит num/строку).
int _asPositiveInt(Object? v, {required int fallback}) {
  if (v is int && v > 0) return v;
  if (v is num && v > 0) return v.round();
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null && n > 0) return n;
  }
  return fallback;
}

/// Приводит динамическое значение к неотрицательному int или null.
/// Используется для парсинга rest_seconds из ответа AI: отсутствующее поле
/// возвращает null, из которого вызывающий выбирает kUseDefaultRest.
int? _asNonNegativeInt(Object? v) {
  if (v is int && v >= 0) return v;
  if (v is num && v >= 0) return v.round();
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null && n >= 0) return n;
  }
  return null;
}

/// Приводит reps к непустой строке (модель может прислать число или строку).
String _asReps(Object? v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  if (v is num) return '${v is int ? v : v.round()}';
  return '10';
}

// ---------------------------------------------------------------------------
// reps-строка → int для БД (колонка reps — INT)
// ---------------------------------------------------------------------------

/// Извлекает представительное целое из reps-строки для целочисленной колонки БД.
///
/// Правила:
///  - "8-12" / "8–12" → 8 (ведущее число диапазона);
///  - "12" → 12;
///  - "30s" / "45s" (удержание/время) → 30 / 45;
///  - "AMRAP" / "max" / любое без чисел → [fallback] (по умолчанию 10).
///
/// Оригинальная строка сохраняется отдельно (в technique) — не теряется.
int repsToInt(String reps, {int fallback = 10}) {
  final match = RegExp(r'\d+').firstMatch(reps);
  if (match == null) return fallback;
  final n = int.tryParse(match.group(0)!);
  return (n == null || n <= 0) ? fallback : n;
}

// ---------------------------------------------------------------------------
// Сохранение программы в Drift (общий маршрут для template- и AI-пути)
// ---------------------------------------------------------------------------

/// Сохраняет [program] в локальную БД: КАЖДЫЙ [ProgramDay] становится отдельным
/// шаблоном Workout, а его упражнения — строками WorkoutExercisesTable.
///
/// Маппинг полей упражнения на addExercise:
///  - sets        → sets (как есть);
///  - reps(строка)→ reps (int через [repsToInt]); ОРИГИНАЛ диапазона/AMRAP
///    кладём в technique (колонки note у упражнения нет), чтобы не терять "8-12";
///  - restSeconds → restSeconds;
///  - sortOrder   — addExercise сам выставляет по порядку добавления.
///
/// AI-заметка по упражнению (note) дописывается к technique, если задана.
Future<void> saveWorkoutProgram(WorkoutsDao dao, WorkoutProgram program) async {
  for (final day in program.days) {
    final workoutId = await dao.createWorkout(day.title);
    for (final ex in day.exercises) {
      // technique сохраняет человекочитаемый диапазон + опциональную заметку,
      // т.к. колонка reps в БД — int и теряет "8-12"/"AMRAP".
      final parts = <String>[
        if (ex.reps.trim().isNotEmpty) ex.reps.trim(),
        if (ex.note != null && ex.note!.trim().isNotEmpty) ex.note!.trim(),
      ];
      final technique = parts.isEmpty ? null : parts.join(' · ');
      await dao.addExercise(
        workoutId: workoutId,
        name: ex.name,
        sets: ex.sets,
        reps: repsToInt(ex.reps),
        restSeconds: ex.restSeconds,
        technique: technique,
      );
    }
  }
}
