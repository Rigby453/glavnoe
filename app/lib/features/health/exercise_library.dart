// Каталог упражнений с техникой, типичными ошибками и дефолтными параметрами.
//
// PURE файл — без Flutter, без Drift, без сети.
// nameKey / stepKeys / mistakeKeys — l10n-ключи; разрешаются через context.s().
// Строки техники живут в app/lib/core/l10n/strings/workouts_library.dart.
//
// СОВМЕСТИМОСТЬ с workout_templates.dart:
//   ProgramExercise.name хранит «голый» слаг (напр. 'barbell_back_squat').
//   exerciseById(slug) связывает шаблон с записью каталога по этому слагу.
//   exerciseByName(displayName) ищет по en/ru-имени для маппинга строк из БД.

// Группа мышц (enum-like): одна из восьми стандартных категорий.
// Совпадает с ключами muscle.* в health_b.dart (legs/back/chest/shoulders/
// arms/core/full_body/cardio).
class ExerciseMuscleGroup {
  static const legs = 'legs';
  static const back = 'back';
  static const chest = 'chest';
  static const shoulders = 'shoulders';
  static const arms = 'arms';
  static const core = 'core';
  static const fullBody = 'full_body';
  static const cardio = 'cardio';
}

// Инвентарь (enum-like): допустимые значения поля equipment.
class ExerciseEquipment {
  static const none = 'none';
  static const dumbbell = 'dumbbell';
  static const barbell = 'barbell';
  static const machine = 'machine';
  static const bodyweight = 'bodyweight';
  static const band = 'band';
  static const kettlebell = 'kettlebell';
}

// Уровень сложности (enum-like).
class ExerciseDifficulty {
  static const beginner = 'beginner';
  static const intermediate = 'intermediate';
  static const advanced = 'advanced';
}

/// Запись в каталоге упражнений.
///
/// Все пользовательские строки хранятся как l10n-ключи; разрешаются
/// на UI-уровне через context.s(key).
///
/// Поля:
///   [id]               — стабильный слаг (напр. 'barbell_squat').
///                        Совпадает с ProgramExercise.name из workout_templates.dart.
///   [nameKey]          — ключ display-имени (`exercise.<id>` в health_b.dart).
///   [muscleGroup]      — одна из констант ExerciseMuscleGroup.
///   [equipment]        — одна из констант ExerciseEquipment.
///   [difficulty]       — одна из констант ExerciseDifficulty.
///   [stepKeys]         — упорядоченные ключи шагов техники.
///   [mistakeKeys]      — ключи типичных ошибок (может быть пустым).
///   [defaultSets]      — рекомендуемое число подходов (> 0).
///   [defaultReps]      — строка повторений: диапазон '8-12', 'AMRAP', '30-45s'.
///   [defaultRestSeconds] — рекомендуемый отдых в секундах (> 0).
///   [videoUrl]         — ссылка на видео техники; null — пока не заполнена.
class Exercise {
  const Exercise({
    required this.id,
    required this.nameKey,
    required this.muscleGroup,
    required this.equipment,
    required this.difficulty,
    required this.stepKeys,
    this.mistakeKeys = const [],
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultRestSeconds,
    this.videoUrl, // videoUrl: заполнить ссылкой на видео техники позже
  });

  final String id;
  final String nameKey;
  final String muscleGroup;
  final String equipment;
  final String difficulty;
  final List<String> stepKeys;
  final List<String> mistakeKeys;
  final int defaultSets;
  final String defaultReps;
  final int defaultRestSeconds;
  final String? videoUrl;
}

// ---------------------------------------------------------------------------
// Стартовый каталог (~15 упражнений, основные паттерны движения)
// ---------------------------------------------------------------------------

/// Основной каталог упражнений.
///
/// Охватывает: приседания (штанга + собственный вес), тяга (становая,
/// ягодичный мостик), жим (отжимание, жим штанги, жим гантелей, жим над головой),
/// тяга/подтягивания (тяга штанги, тяга гантели, подтягивания),
/// кор (планка, русский твист), кардио (прыжки «звёздочка», бёрпи).
const List<Exercise> kExerciseLibrary = [
  // --- Ноги / Приседание ---
  Exercise(
    id: 'barbell_back_squat',
    nameKey: 'exercise.barbell_back_squat',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.barbell_back_squat.step1',
      'exercise.barbell_back_squat.step2',
      'exercise.barbell_back_squat.step3',
      'exercise.barbell_back_squat.step4',
    ],
    mistakeKeys: [
      'exercise.barbell_back_squat.mistake1',
      'exercise.barbell_back_squat.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'bodyweight_squat',
    nameKey: 'exercise.bodyweight_squat',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.bodyweight_squat.step1',
      'exercise.bodyweight_squat.step2',
      'exercise.bodyweight_squat.step3',
    ],
    mistakeKeys: [
      'exercise.bodyweight_squat.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '15-20',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  // --- Ноги / Тяга (шарнир) ---
  Exercise(
    id: 'barbell_deadlift',
    nameKey: 'exercise.barbell_deadlift',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.barbell_deadlift.step1',
      'exercise.barbell_deadlift.step2',
      'exercise.barbell_deadlift.step3',
      'exercise.barbell_deadlift.step4',
    ],
    mistakeKeys: [
      'exercise.barbell_deadlift.mistake1',
      'exercise.barbell_deadlift.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '5-6',
    defaultRestSeconds: 150,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'glute_bridge',
    nameKey: 'exercise.glute_bridge',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.glute_bridge.step1',
      'exercise.glute_bridge.step2',
      'exercise.glute_bridge.step3',
    ],
    mistakeKeys: [
      'exercise.glute_bridge.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  // --- Грудь / Жим (push) ---
  Exercise(
    id: 'push_up',
    nameKey: 'exercise.push_up',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.push_up.step1',
      'exercise.push_up.step2',
      'exercise.push_up.step3',
    ],
    mistakeKeys: [
      'exercise.push_up.mistake1',
      'exercise.push_up.mistake2',
    ],
    defaultSets: 3,
    defaultReps: 'AMRAP',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'barbell_bench_press',
    nameKey: 'exercise.barbell_bench_press',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.barbell_bench_press.step1',
      'exercise.barbell_bench_press.step2',
      'exercise.barbell_bench_press.step3',
      'exercise.barbell_bench_press.step4',
    ],
    mistakeKeys: [
      'exercise.barbell_bench_press.mistake1',
      'exercise.barbell_bench_press.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'dumbbell_bench_press',
    nameKey: 'exercise.dumbbell_bench_press',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.dumbbell_bench_press.step1',
      'exercise.dumbbell_bench_press.step2',
      'exercise.dumbbell_bench_press.step3',
    ],
    mistakeKeys: [
      'exercise.dumbbell_bench_press.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  // --- Плечи / Жим над головой ---
  Exercise(
    id: 'overhead_barbell_press',
    nameKey: 'exercise.overhead_barbell_press',
    muscleGroup: ExerciseMuscleGroup.shoulders,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.overhead_barbell_press.step1',
      'exercise.overhead_barbell_press.step2',
      'exercise.overhead_barbell_press.step3',
    ],
    mistakeKeys: [
      'exercise.overhead_barbell_press.mistake1',
      'exercise.overhead_barbell_press.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-10',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  // --- Спина / Тяга (pull) ---
  Exercise(
    id: 'barbell_row',
    nameKey: 'exercise.barbell_row',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.barbell_row.step1',
      'exercise.barbell_row.step2',
      'exercise.barbell_row.step3',
      'exercise.barbell_row.step4',
    ],
    mistakeKeys: [
      'exercise.barbell_row.mistake1',
      'exercise.barbell_row.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'dumbbell_row',
    nameKey: 'exercise.dumbbell_row',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.dumbbell_row.step1',
      'exercise.dumbbell_row.step2',
      'exercise.dumbbell_row.step3',
    ],
    mistakeKeys: [
      'exercise.dumbbell_row.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'pull_up',
    nameKey: 'exercise.pull_up',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.pull_up.step1',
      'exercise.pull_up.step2',
      'exercise.pull_up.step3',
    ],
    mistakeKeys: [
      'exercise.pull_up.mistake1',
      'exercise.pull_up.mistake2',
    ],
    defaultSets: 4,
    defaultReps: 'AMRAP',
    defaultRestSeconds: 120,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  // --- Кор ---
  Exercise(
    id: 'plank',
    nameKey: 'exercise.plank',
    muscleGroup: ExerciseMuscleGroup.core,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.plank.step1',
      'exercise.plank.step2',
      'exercise.plank.step3',
    ],
    mistakeKeys: [
      'exercise.plank.mistake1',
      'exercise.plank.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '30-45s',
    defaultRestSeconds: 45,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'russian_twist',
    nameKey: 'exercise.russian_twist',
    muscleGroup: ExerciseMuscleGroup.core,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.russian_twist.step1',
      'exercise.russian_twist.step2',
      'exercise.russian_twist.step3',
    ],
    mistakeKeys: [
      'exercise.russian_twist.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '16-20',
    defaultRestSeconds: 45,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  // --- Кардио / Собственный вес ---
  Exercise(
    id: 'jumping_jack',
    nameKey: 'exercise.jumping_jack',
    muscleGroup: ExerciseMuscleGroup.cardio,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.jumping_jack.step1',
      'exercise.jumping_jack.step2',
    ],
    mistakeKeys: [],
    defaultSets: 3,
    defaultReps: '30s',
    defaultRestSeconds: 30,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'burpee',
    nameKey: 'exercise.burpee',
    muscleGroup: ExerciseMuscleGroup.fullBody,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.burpee.step1',
      'exercise.burpee.step2',
      'exercise.burpee.step3',
      'exercise.burpee.step4',
    ],
    mistakeKeys: [
      'exercise.burpee.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Ноги / Дополнительные упражнения ---
  Exercise(
    id: 'front_squat',
    nameKey: 'exercise.front_squat',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.front_squat.step1',
      'exercise.front_squat.step2',
      'exercise.front_squat.step3',
      'exercise.front_squat.step4',
    ],
    mistakeKeys: [
      'exercise.front_squat.mistake1',
      'exercise.front_squat.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '6-10',
    defaultRestSeconds: 120,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'goblet_squat',
    nameKey: 'exercise.goblet_squat',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.kettlebell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.goblet_squat.step1',
      'exercise.goblet_squat.step2',
      'exercise.goblet_squat.step3',
    ],
    mistakeKeys: [
      'exercise.goblet_squat.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'walking_lunge',
    nameKey: 'exercise.walking_lunge',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.walking_lunge.step1',
      'exercise.walking_lunge.step2',
      'exercise.walking_lunge.step3',
    ],
    mistakeKeys: [
      'exercise.walking_lunge.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'bulgarian_split_squat',
    nameKey: 'exercise.bulgarian_split_squat',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.bulgarian_split_squat.step1',
      'exercise.bulgarian_split_squat.step2',
      'exercise.bulgarian_split_squat.step3',
      'exercise.bulgarian_split_squat.step4',
    ],
    mistakeKeys: [
      'exercise.bulgarian_split_squat.mistake1',
      'exercise.bulgarian_split_squat.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'leg_press',
    nameKey: 'exercise.leg_press',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.machine,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.leg_press.step1',
      'exercise.leg_press.step2',
      'exercise.leg_press.step3',
    ],
    mistakeKeys: [
      'exercise.leg_press.mistake1',
      'exercise.leg_press.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '10-15',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'romanian_deadlift',
    nameKey: 'exercise.romanian_deadlift',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.romanian_deadlift.step1',
      'exercise.romanian_deadlift.step2',
      'exercise.romanian_deadlift.step3',
      'exercise.romanian_deadlift.step4',
    ],
    mistakeKeys: [
      'exercise.romanian_deadlift.mistake1',
      'exercise.romanian_deadlift.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'leg_curl',
    nameKey: 'exercise.leg_curl',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.machine,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.leg_curl.step1',
      'exercise.leg_curl.step2',
      'exercise.leg_curl.step3',
    ],
    mistakeKeys: [
      'exercise.leg_curl.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'leg_extension',
    nameKey: 'exercise.leg_extension',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.machine,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.leg_extension.step1',
      'exercise.leg_extension.step2',
      'exercise.leg_extension.step3',
    ],
    mistakeKeys: [
      'exercise.leg_extension.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'standing_calf_raise',
    nameKey: 'exercise.standing_calf_raise',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.machine,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.standing_calf_raise.step1',
      'exercise.standing_calf_raise.step2',
      'exercise.standing_calf_raise.step3',
    ],
    mistakeKeys: [
      'exercise.standing_calf_raise.mistake1',
    ],
    defaultSets: 4,
    defaultReps: '12-20',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'hip_thrust',
    nameKey: 'exercise.hip_thrust',
    muscleGroup: ExerciseMuscleGroup.legs,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.hip_thrust.step1',
      'exercise.hip_thrust.step2',
      'exercise.hip_thrust.step3',
      'exercise.hip_thrust.step4',
    ],
    mistakeKeys: [
      'exercise.hip_thrust.mistake1',
      'exercise.hip_thrust.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Спина / Дополнительные упражнения ---
  Exercise(
    id: 'chin_up',
    nameKey: 'exercise.chin_up',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.chin_up.step1',
      'exercise.chin_up.step2',
      'exercise.chin_up.step3',
    ],
    mistakeKeys: [
      'exercise.chin_up.mistake1',
      'exercise.chin_up.mistake2',
    ],
    defaultSets: 4,
    defaultReps: 'AMRAP',
    defaultRestSeconds: 120,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'lat_pulldown',
    nameKey: 'exercise.lat_pulldown',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.machine, // тросовый тренажёр; cable-константа не нужна
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.lat_pulldown.step1',
      'exercise.lat_pulldown.step2',
      'exercise.lat_pulldown.step3',
      'exercise.lat_pulldown.step4',
    ],
    mistakeKeys: [
      'exercise.lat_pulldown.mistake1',
      'exercise.lat_pulldown.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'seated_cable_row',
    nameKey: 'exercise.seated_cable_row',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.machine, // тросовый тренажёр
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.seated_cable_row.step1',
      'exercise.seated_cable_row.step2',
      'exercise.seated_cable_row.step3',
    ],
    mistakeKeys: [
      'exercise.seated_cable_row.mistake1',
      'exercise.seated_cable_row.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '10-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'face_pull',
    nameKey: 'exercise.face_pull',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.machine, // тросовый тренажёр
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.face_pull.step1',
      'exercise.face_pull.step2',
      'exercise.face_pull.step3',
    ],
    mistakeKeys: [
      'exercise.face_pull.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 't_bar_row',
    nameKey: 'exercise.t_bar_row',
    muscleGroup: ExerciseMuscleGroup.back,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.t_bar_row.step1',
      'exercise.t_bar_row.step2',
      'exercise.t_bar_row.step3',
      'exercise.t_bar_row.step4',
    ],
    mistakeKeys: [
      'exercise.t_bar_row.mistake1',
      'exercise.t_bar_row.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Грудь / Дополнительные упражнения ---
  Exercise(
    id: 'incline_barbell_bench_press',
    nameKey: 'exercise.incline_barbell_bench_press',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.incline_barbell_bench_press.step1',
      'exercise.incline_barbell_bench_press.step2',
      'exercise.incline_barbell_bench_press.step3',
      'exercise.incline_barbell_bench_press.step4',
    ],
    mistakeKeys: [
      'exercise.incline_barbell_bench_press.mistake1',
      'exercise.incline_barbell_bench_press.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'incline_dumbbell_press',
    nameKey: 'exercise.incline_dumbbell_press',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.incline_dumbbell_press.step1',
      'exercise.incline_dumbbell_press.step2',
      'exercise.incline_dumbbell_press.step3',
    ],
    mistakeKeys: [
      'exercise.incline_dumbbell_press.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'chest_dip',
    nameKey: 'exercise.chest_dip',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.chest_dip.step1',
      'exercise.chest_dip.step2',
      'exercise.chest_dip.step3',
    ],
    mistakeKeys: [
      'exercise.chest_dip.mistake1',
      'exercise.chest_dip.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '8-12',
    defaultRestSeconds: 90,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Грудь / Изоляция ---
  Exercise(
    id: 'dumbbell_fly',
    nameKey: 'exercise.dumbbell_fly',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.dumbbell_fly.step1',
      'exercise.dumbbell_fly.step2',
      'exercise.dumbbell_fly.step3',
    ],
    mistakeKeys: [
      'exercise.dumbbell_fly.mistake1',
      'exercise.dumbbell_fly.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'cable_crossover',
    nameKey: 'exercise.cable_crossover',
    muscleGroup: ExerciseMuscleGroup.chest,
    equipment: ExerciseEquipment.machine, // cable
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.cable_crossover.step1',
      'exercise.cable_crossover.step2',
      'exercise.cable_crossover.step3',
    ],
    mistakeKeys: [
      'exercise.cable_crossover.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Плечи / Жим + изоляция ---
  Exercise(
    id: 'dumbbell_shoulder_press',
    nameKey: 'exercise.dumbbell_shoulder_press',
    muscleGroup: ExerciseMuscleGroup.shoulders,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.dumbbell_shoulder_press.step1',
      'exercise.dumbbell_shoulder_press.step2',
      'exercise.dumbbell_shoulder_press.step3',
    ],
    mistakeKeys: [
      'exercise.dumbbell_shoulder_press.mistake1',
      'exercise.dumbbell_shoulder_press.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'lateral_raise',
    nameKey: 'exercise.lateral_raise',
    muscleGroup: ExerciseMuscleGroup.shoulders,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.lateral_raise.step1',
      'exercise.lateral_raise.step2',
      'exercise.lateral_raise.step3',
    ],
    mistakeKeys: [
      'exercise.lateral_raise.mistake1',
      'exercise.lateral_raise.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'front_raise',
    nameKey: 'exercise.front_raise',
    muscleGroup: ExerciseMuscleGroup.shoulders,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.front_raise.step1',
      'exercise.front_raise.step2',
    ],
    mistakeKeys: [
      'exercise.front_raise.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'rear_delt_fly',
    nameKey: 'exercise.rear_delt_fly',
    muscleGroup: ExerciseMuscleGroup.shoulders,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.rear_delt_fly.step1',
      'exercise.rear_delt_fly.step2',
      'exercise.rear_delt_fly.step3',
    ],
    mistakeKeys: [
      'exercise.rear_delt_fly.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'arnold_press',
    nameKey: 'exercise.arnold_press',
    muscleGroup: ExerciseMuscleGroup.shoulders,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.arnold_press.step1',
      'exercise.arnold_press.step2',
      'exercise.arnold_press.step3',
    ],
    mistakeKeys: [
      'exercise.arnold_press.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Руки / Бицепс ---
  Exercise(
    id: 'barbell_curl',
    nameKey: 'exercise.barbell_curl',
    muscleGroup: ExerciseMuscleGroup.arms,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.barbell_curl.step1',
      'exercise.barbell_curl.step2',
      'exercise.barbell_curl.step3',
    ],
    mistakeKeys: [
      'exercise.barbell_curl.mistake1',
      'exercise.barbell_curl.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'dumbbell_curl',
    nameKey: 'exercise.dumbbell_curl',
    muscleGroup: ExerciseMuscleGroup.arms,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.dumbbell_curl.step1',
      'exercise.dumbbell_curl.step2',
      'exercise.dumbbell_curl.step3',
    ],
    mistakeKeys: [
      'exercise.dumbbell_curl.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'hammer_curl',
    nameKey: 'exercise.hammer_curl',
    muscleGroup: ExerciseMuscleGroup.arms,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.hammer_curl.step1',
      'exercise.hammer_curl.step2',
    ],
    mistakeKeys: [
      'exercise.hammer_curl.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Руки / Трицепс ---
  Exercise(
    id: 'triceps_pushdown',
    nameKey: 'exercise.triceps_pushdown',
    muscleGroup: ExerciseMuscleGroup.arms,
    equipment: ExerciseEquipment.machine, // cable
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.triceps_pushdown.step1',
      'exercise.triceps_pushdown.step2',
      'exercise.triceps_pushdown.step3',
    ],
    mistakeKeys: [
      'exercise.triceps_pushdown.mistake1',
      'exercise.triceps_pushdown.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '12-15',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'overhead_triceps_extension',
    nameKey: 'exercise.overhead_triceps_extension',
    muscleGroup: ExerciseMuscleGroup.arms,
    equipment: ExerciseEquipment.dumbbell,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.overhead_triceps_extension.step1',
      'exercise.overhead_triceps_extension.step2',
      'exercise.overhead_triceps_extension.step3',
    ],
    mistakeKeys: [
      'exercise.overhead_triceps_extension.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '10-12',
    defaultRestSeconds: 60,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'close_grip_bench_press',
    nameKey: 'exercise.close_grip_bench_press',
    muscleGroup: ExerciseMuscleGroup.arms,
    equipment: ExerciseEquipment.barbell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.close_grip_bench_press.step1',
      'exercise.close_grip_bench_press.step2',
      'exercise.close_grip_bench_press.step3',
    ],
    mistakeKeys: [
      'exercise.close_grip_bench_press.mistake1',
      'exercise.close_grip_bench_press.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '8-12',
    defaultRestSeconds: 75,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Кор / Дополнительные ---
  Exercise(
    id: 'hanging_leg_raise',
    nameKey: 'exercise.hanging_leg_raise',
    muscleGroup: ExerciseMuscleGroup.core,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.hanging_leg_raise.step1',
      'exercise.hanging_leg_raise.step2',
      'exercise.hanging_leg_raise.step3',
    ],
    mistakeKeys: [
      'exercise.hanging_leg_raise.mistake1',
      'exercise.hanging_leg_raise.mistake2',
    ],
    defaultSets: 3,
    defaultReps: '10-15',
    defaultRestSeconds: 45,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'crunch',
    nameKey: 'exercise.crunch',
    muscleGroup: ExerciseMuscleGroup.core,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.crunch.step1',
      'exercise.crunch.step2',
      'exercise.crunch.step3',
    ],
    mistakeKeys: [
      'exercise.crunch.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '15-20',
    defaultRestSeconds: 45,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
  Exercise(
    id: 'mountain_climber',
    nameKey: 'exercise.mountain_climber',
    muscleGroup: ExerciseMuscleGroup.core,
    equipment: ExerciseEquipment.bodyweight,
    difficulty: ExerciseDifficulty.beginner,
    stepKeys: [
      'exercise.mountain_climber.step1',
      'exercise.mountain_climber.step2',
      'exercise.mountain_climber.step3',
    ],
    mistakeKeys: [
      'exercise.mountain_climber.mistake1',
    ],
    defaultSets: 3,
    defaultReps: '30s',
    defaultRestSeconds: 30,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),

  // --- Кардио / Полное тело ---
  Exercise(
    id: 'kettlebell_swing',
    nameKey: 'exercise.kettlebell_swing',
    muscleGroup: ExerciseMuscleGroup.cardio,
    equipment: ExerciseEquipment.kettlebell,
    difficulty: ExerciseDifficulty.intermediate,
    stepKeys: [
      'exercise.kettlebell_swing.step1',
      'exercise.kettlebell_swing.step2',
      'exercise.kettlebell_swing.step3',
      'exercise.kettlebell_swing.step4',
    ],
    mistakeKeys: [
      'exercise.kettlebell_swing.mistake1',
      'exercise.kettlebell_swing.mistake2',
    ],
    defaultSets: 4,
    defaultReps: '15-20',
    defaultRestSeconds: 45,
    // videoUrl: заполнить ссылкой на видео техники позже
  ),
];

// ---------------------------------------------------------------------------
// Вспомогательные lookup-функции
// ---------------------------------------------------------------------------

/// Возвращает упражнение по стабильному [id] (слагу).
///
/// Используется для связки ProgramExercise.name (слаг) → запись каталога.
/// Возвращает null, если [id] не найден.
Exercise? exerciseById(String id) {
  for (final e in kExerciseLibrary) {
    if (e.id == id) return e;
  }
  return null;
}

/// Возвращает упражнение по отображаемому имени (en или ru).
///
/// Совпадение регистронезависимо. Используется при маппинге строк из
/// устаревших/AI-записей БД на записи каталога.
///
/// [resolveKey] — функция разрешения l10n-ключа (напр. context.s или
/// (k) => S.of(context, k)); должна возвращать en-строку при locale == en.
Exercise? exerciseByName(
  String name,
  String Function(String key) resolveKey,
) {
  final normalized = name.trim().toLowerCase();
  for (final e in kExerciseLibrary) {
    // Пробуем разрешить nameKey в en и ru и сравниваем без учёта регистра.
    final enName = resolveKey(e.nameKey).toLowerCase();
    if (enName == normalized) return e;
    // Проверяем совпадение по id-слагу как fallback.
    if (e.id == normalized.replaceAll(' ', '_')) return e;
  }
  return null;
}
