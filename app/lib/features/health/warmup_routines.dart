// Контент для фичи «Зарядка / растяжка» (гайдед-рутины «проснуться»).
//
// PURE-данные: без Flutter-стейта, без Drift, без сети. Хранятся только
// l10n-КЛЮЧИ (nameKey/descKey) — UI резолвит их через context.s() (правило
// app/CLAUDE.md: никаких const английских строк в данных).
//
// Образец — posture_exercises.dart / meditation_screen.dart: упражнения идут
// одно за другим, у каждого либо длительность в секундах, либо число повторов.
// Это НЕ лог по подходам и НЕ мержится в дневник тренировок.

import 'package:flutter/material.dart';

/// Одно упражнение в гайдед-рутине.
///
/// Ровно одно из [seconds] / [reps] задано (другое — null):
///   • [seconds] != null → шаг с обратным отсчётом (таймер + пауза);
///   • [reps] != null    → шаг по повторам (счётчик, ручное «дальше»).
class WarmupStep {
  const WarmupStep({
    required this.nameKey,
    required this.descKey,
    this.seconds,
    this.reps,
    this.icon = Icons.accessibility_new,
  }) : assert(
          (seconds == null) != (reps == null),
          'Задайте ровно одно из seconds / reps',
        );

  /// Ключ l10n названия упражнения.
  final String nameKey;

  /// Ключ l10n короткой инструкции (1–2 предложения).
  final String descKey;

  /// Длительность шага в секундах (для шага-таймера) либо null.
  final int? seconds;

  /// Число повторов (для шага по повторам) либо null.
  final int? reps;

  /// Нейтральная Material-иконка (без своей графики).
  final IconData icon;

  /// true — шаг по повторам (нет таймера).
  bool get isReps => reps != null;

  /// Приблизительная длительность для оценки общего времени рутины.
  /// Шаг по повторам считаем как ~4 секунды на повтор.
  int get approxSeconds => seconds ?? (reps! * 4);
}

/// Готовый комплекс (рутина) — список упражнений по порядку.
class WarmupRoutine {
  const WarmupRoutine({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.icon,
    required this.steps,
  });

  /// Стабильный слаг (для ключей/аналитики, эфемерно).
  final String id;

  /// Ключ l10n названия рутины.
  final String nameKey;

  /// Ключ l10n короткого описания рутины.
  final String descKey;

  /// Иконка рутины (нейтральная).
  final IconData icon;

  /// Упражнения по порядку.
  final List<WarmupStep> steps;

  /// Оценка общей длительности в минутах (минимум 1) для мета-строки.
  int get approxMinutes {
    final total = steps.fold<int>(0, (sum, s) => sum + s.approxSeconds);
    return (total / 60).round().clamp(1, 1 << 30);
  }
}

/// Три готовые рутины: «Утренняя зарядка», «Растяжка» и «Осанка».
/// nameKey/descKey резолвятся через context.s() на UI-уровне.
const kWarmupRoutines = <WarmupRoutine>[
  // --- Утренняя зарядка: суставная разминка + махи + приседания ---
  WarmupRoutine(
    id: 'morning',
    nameKey: 'warmup.morning.name',
    descKey: 'warmup.morning.desc',
    icon: Icons.wb_sunny_outlined,
    steps: [
      WarmupStep(
        nameKey: 'warmup.ex.neck_rolls.name',
        descKey: 'warmup.ex.neck_rolls.desc',
        seconds: 30,
        icon: Icons.self_improvement,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.shoulder_circles.name',
        descKey: 'warmup.ex.shoulder_circles.desc',
        seconds: 30,
        icon: Icons.sync,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.arm_swings.name',
        descKey: 'warmup.ex.arm_swings.desc',
        seconds: 30,
        icon: Icons.open_with,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.torso_twists.name',
        descKey: 'warmup.ex.torso_twists.desc',
        seconds: 30,
        icon: Icons.cached,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.side_bends.name',
        descKey: 'warmup.ex.side_bends.desc',
        seconds: 30,
        icon: Icons.swap_horiz,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.bodyweight_squats.name',
        descKey: 'warmup.ex.bodyweight_squats.desc',
        reps: 12,
        icon: Icons.fitness_center,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.jumping_jacks.name',
        descKey: 'warmup.ex.jumping_jacks.desc',
        seconds: 30,
        icon: Icons.directions_run,
      ),
    ],
  ),

  // --- Растяжка: мягкие растяжки на всё тело ---
  WarmupRoutine(
    id: 'stretch',
    nameKey: 'warmup.stretch.name',
    descKey: 'warmup.stretch.desc',
    icon: Icons.self_improvement,
    steps: [
      WarmupStep(
        nameKey: 'warmup.ex.neck_stretch.name',
        descKey: 'warmup.ex.neck_stretch.desc',
        seconds: 30,
        icon: Icons.self_improvement,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.shoulder_stretch.name',
        descKey: 'warmup.ex.shoulder_stretch.desc',
        seconds: 30,
        icon: Icons.accessibility_new,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.triceps_stretch.name',
        descKey: 'warmup.ex.triceps_stretch.desc',
        seconds: 30,
        icon: Icons.back_hand_outlined,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.forward_fold.name',
        descKey: 'warmup.ex.forward_fold.desc',
        seconds: 30,
        icon: Icons.arrow_downward,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.quad_stretch.name',
        descKey: 'warmup.ex.quad_stretch.desc',
        seconds: 30,
        icon: Icons.accessibility,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.hamstring_stretch.name',
        descKey: 'warmup.ex.hamstring_stretch.desc',
        seconds: 30,
        icon: Icons.airline_seat_legroom_extra,
      ),
      WarmupStep(
        nameKey: 'warmup.ex.cat_cow_stretch.name',
        descKey: 'warmup.ex.cat_cow_stretch.desc',
        seconds: 40,
        icon: Icons.pets,
      ),
    ],
  ),

  // --- Осанка: 6 упражнений из posture_exercises.dart, адаптированных
  //     под WarmupStep (nameKey/descKey переиспользуют ключи posture.*) ---
  WarmupRoutine(
    id: 'posture',
    nameKey: 'warmup.posture.name',
    descKey: 'warmup.posture.desc',
    icon: Icons.accessibility,
    steps: [
      WarmupStep(
        nameKey: 'posture.chin_tucks.name',
        descKey: 'posture.chin_tucks.steps',
        seconds: 30,
        icon: Icons.face_retouching_natural,
      ),
      WarmupStep(
        nameKey: 'posture.shoulder_blade_squeeze.name',
        descKey: 'posture.shoulder_blade_squeeze.steps',
        seconds: 30,
        icon: Icons.accessibility_new,
      ),
      WarmupStep(
        nameKey: 'posture.wall_angels.name',
        descKey: 'posture.wall_angels.steps',
        seconds: 60,
        icon: Icons.back_hand_outlined,
      ),
      WarmupStep(
        nameKey: 'posture.doorway_chest_stretch.name',
        descKey: 'posture.doorway_chest_stretch.steps',
        seconds: 30,
        icon: Icons.open_with,
      ),
      WarmupStep(
        nameKey: 'posture.upper_trap_stretch.name',
        descKey: 'posture.upper_trap_stretch.steps',
        seconds: 30,
        icon: Icons.self_improvement,
      ),
      WarmupStep(
        nameKey: 'posture.cat_cow.name',
        descKey: 'posture.cat_cow.steps',
        seconds: 60,
        icon: Icons.pets,
      ),
    ],
  ),
];
