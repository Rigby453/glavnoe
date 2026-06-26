// Единая точка маршрутизации «блок плана → инструмент».
//
// (a) Чистая функция resolveBlockTool — тестируемая, без BuildContext/навигации.
// (b) openBlockTool — тонкая навигационная обёртка, читает флаги через WidgetRef.
//
// Добавление нового модуля: расширить enum BlockToolKind + добавить ветку
// в resolveBlockTool + добавить case в switch openBlockTool.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/database.dart';
import '../settings/feature_modes_provider.dart';
import '../../features/food/light_food_sheet.dart';

// ---------------------------------------------------------------------------
// Enum — все возможные «инструменты», к которым ведёт тап блока
// ---------------------------------------------------------------------------

enum BlockToolKind {
  /// moduleLink отсутствует или неизвестен — вызывающий открывает редактирование
  none,

  /// Приём пищи в облегчённом режиме (nutritionMode = false)
  foodLight,

  /// Приём пищи в полном режиме КБЖУ (nutritionMode = true)
  foodFull,

  /// Фокус-сессия
  focus,

  /// Тренировка в облегчённом режиме (workoutMode = false)
  workoutLight,

  /// Тренировка в полном режиме (workoutMode = true)
  workoutFull,

  /// Зарядка/растяжка
  warmup,

  /// Дыхательная техника
  breathing,

  /// Медитация
  meditation,

  /// Подготовка ко сну в облегчённом режиме
  sleepLight,
}

// ---------------------------------------------------------------------------
// (а) Чистая функция-резолвер — без BuildContext, без навигации, тестируемая
// ---------------------------------------------------------------------------

/// Определяет [BlockToolKind] по значению [moduleLink] и текущим флагам-режимам.
///
/// - null → [BlockToolKind.none] (вызывающий должен открыть редактирование задачи).
/// - meal:* → foodFull если [nutritionMode], иначе foodLight.
/// - workout → workoutFull если [workoutMode], иначе workoutLight.
/// - focus / warmup / breathing / meditation / sleep → соответствующий Kind.
///
/// [meditationLibraryMode] и [breathingEditorMode] приняты в сигнатуре для
/// будущего гейтинга контента внутри экранов; пока оба маршрута ведут на тот
/// же экран в обоих случаях.
BlockToolKind resolveBlockTool(
  String? moduleLink, {
  required bool nutritionMode,
  required bool workoutMode,
  required bool meditationLibraryMode,
  required bool breathingEditorMode,
}) {
  if (moduleLink == null) return BlockToolKind.none;

  // Все meal:* → еда (слот определяется при навигации, не здесь)
  if (moduleLink.startsWith('meal:')) {
    return nutritionMode ? BlockToolKind.foodFull : BlockToolKind.foodLight;
  }

  return switch (moduleLink) {
    'workout'    => workoutMode ? BlockToolKind.workoutFull : BlockToolKind.workoutLight,
    'focus'      => BlockToolKind.focus,
    'warmup'     => BlockToolKind.warmup,
    'breathing'  => BlockToolKind.breathing,
    'meditation' => BlockToolKind.meditation,
    'sleep'      => BlockToolKind.sleepLight,
    _            => BlockToolKind.none,
  };
}

// ---------------------------------------------------------------------------
// (б) Навигационный helper
// ---------------------------------------------------------------------------

/// Открывает нужный инструмент для задачи [item] по её [moduleLink] и флагам.
///
/// Возвращает true если переход выполнен (вызывающий не должен открывать
/// редактирование); false если moduleLink отсутствует или неизвестен.
///
/// Пример вызова:
/// ```dart
/// onTap: () {
///   if (!openBlockTool(context, ref, item)) {
///     showAddTaskSheet(context, day: day, existing: item);
///   }
/// }
/// ```
bool openBlockTool(BuildContext context, WidgetRef ref, ItemsTableData item) {
  final nutritionMode    = ref.read(nutritionModeProvider);
  final workoutMode      = ref.read(workoutModeProvider);
  final meditationMode   = ref.read(meditationLibraryModeProvider);
  final breathingMode    = ref.read(breathingEditorModeProvider);

  final kind = resolveBlockTool(
    item.moduleLink,
    nutritionMode:         nutritionMode,
    workoutMode:           workoutMode,
    meditationLibraryMode: meditationMode,
    breathingEditorMode:   breathingMode,
  );

  // Слот приёма пищи (breakfast/lunch/dinner) — нужен только для food-маршрутов.
  final mealSlot = (item.moduleLink?.startsWith('meal:') ?? false)
      ? item.moduleLink!.substring(5)
      : null;

  switch (kind) {
    case BlockToolKind.none:
      return false;

    // Задача 3: лёгкая шторка еды (nutritionMode = off) — без КБЖУ в UI.
    // showLightFoodSheet показывает приём пищи без числовых полей.
    case BlockToolKind.foodLight:
      showLightFoodSheet(
        context,
        mealSlot: mealSlot ?? 'snack',
        day: item.scheduledAt,
      );
      return true;

    case BlockToolKind.foodFull:
      context.push('/food?meal=$mealSlot');
      return true;

    case BlockToolKind.workoutFull:
      context.push('/workouts');
      return true;

    // TODO: лёгкая отметка «Сделал тренировку»
    case BlockToolKind.workoutLight:
      context.push('/workouts');
      return true;

    case BlockToolKind.focus:
      context.push('/focus');
      return true;

    case BlockToolKind.warmup:
      context.push('/warmup');
      return true;

    case BlockToolKind.breathing:
      context.push('/breathing');
      return true;

    case BlockToolKind.meditation:
      context.push('/meditation');
      return true;

    // TODO: лёгкая шторка «Ложусь спать»
    case BlockToolKind.sleepLight:
      context.push('/sleep-report');
      return true;
  }
}
