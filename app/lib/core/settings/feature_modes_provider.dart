// Флаги-режимы функциональных модулей приложения.
// Это НЕ премиум-гейты — локальные UX-переключатели (выкл. по умолчанию).
// Пользователь включает нужные модули в разделе «Расширенные функции» профиля.
// Хранятся только в SharedPreferences; Drift не затрагивается.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Ключи SharedPreferences
// ---------------------------------------------------------------------------

const kNutritionModeKey = 'nutrition_mode';
const kWorkoutModeKey = 'workout_mode';
const kMeditationLibraryModeKey = 'meditation_library_mode';
const kBreathingEditorModeKey = 'breathing_editor_mode';
const kWaterModeKey = 'water_mode';

// ---------------------------------------------------------------------------
// Базовый Notifier — булевый флаг в SharedPreferences.
// Подкласс реализует [key]; дефолт всегда false.
// ---------------------------------------------------------------------------

abstract class _BoolFlagNotifier extends Notifier<bool> {
  String get key;

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(key) ?? false;

  /// Установить значение и сохранить в SharedPreferences.
  Future<void> set(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(key, value);
    state = value;
  }

  /// Переключить флаг на противоположное значение.
  Future<void> toggle() => set(!state);
}

// ---------------------------------------------------------------------------
// Nutrition Mode
// Полный экран еды с КБЖУ vs лёгкий список блюд.
// ---------------------------------------------------------------------------

class NutritionModeNotifier extends _BoolFlagNotifier {
  @override
  String get key => kNutritionModeKey;
}

/// true → полный модуль питания (КБЖУ, цели, история).
/// false → лёгкий вид (только быстрый лог).
final nutritionModeProvider =
    NotifierProvider<NutritionModeNotifier, bool>(NutritionModeNotifier.new);

// ---------------------------------------------------------------------------
// Workout Mode
// Редактор и тренер тренировок vs лёгкая отметка «выполнено».
// ---------------------------------------------------------------------------

class WorkoutModeNotifier extends _BoolFlagNotifier {
  @override
  String get key => kWorkoutModeKey;
}

/// true → полный редактор программ + тренировочный трекер.
/// false → только лёгкая отметка задачи-тренировки.
final workoutModeProvider =
    NotifierProvider<WorkoutModeNotifier, bool>(WorkoutModeNotifier.new);

// ---------------------------------------------------------------------------
// Meditation Library Mode
// Библиотека и редактор медитаций vs базовые встроенные сессии.
// ---------------------------------------------------------------------------

class MeditationLibraryModeNotifier extends _BoolFlagNotifier {
  @override
  String get key => kMeditationLibraryModeKey;
}

/// true → полная библиотека медитаций + редактор пользовательских сессий.
/// false → только встроенные базовые сессии.
final meditationLibraryModeProvider =
    NotifierProvider<MeditationLibraryModeNotifier, bool>(
        MeditationLibraryModeNotifier.new);

// ---------------------------------------------------------------------------
// Breathing Editor Mode
// Редактор пользовательских техник дыхания vs только встроенные пресеты.
// ---------------------------------------------------------------------------

class BreathingEditorModeNotifier extends _BoolFlagNotifier {
  @override
  String get key => kBreathingEditorModeKey;
}

/// true → полный редактор техник дыхания + пользовательские пресеты.
/// false → только три встроенных пресета.
final breathingEditorModeProvider =
    NotifierProvider<BreathingEditorModeNotifier, bool>(
        BreathingEditorModeNotifier.new);

// ---------------------------------------------------------------------------
// Water Mode
// Секция/карточка воды на экране Здоровья vs полностью скрыта.
// (#решение владельца: вода — опциональный модуль, как Food/Workouts/
// Meditation/Breathing; Сон при этом остаётся всегда видимым.)
// ---------------------------------------------------------------------------

class WaterModeNotifier extends _BoolFlagNotifier {
  @override
  String get key => kWaterModeKey;
}

/// true → секция «Nutrition» на Health показывает карточку воды.
/// false (дефолт) → карточка воды полностью скрыта; включается в
/// Profile → Behavior, как остальные опциональные модули.
final waterModeProvider =
    NotifierProvider<WaterModeNotifier, bool>(WaterModeNotifier.new);
