// Юнит-тесты для resolveBlockTool (чистая функция, без Flutter/Riverpod).
// Проверяет все ветки резолвера: null, meal:*, workout, focus, warmup,
// breathing, meditation, sleep — при обоих значениях флагов-режимов.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/routing/block_tool_router.dart';

void main() {
  // Вспомогательные константы флагов
  const allOff = (
    nutritionMode: false,
    workoutMode: false,
    meditationLibraryMode: false,
    breathingEditorMode: false,
  );
  const allOn = (
    nutritionMode: true,
    workoutMode: true,
    meditationLibraryMode: true,
    breathingEditorMode: true,
  );

  BlockToolKind resolve(
    String? link, {
    bool nutritionMode = false,
    bool workoutMode = false,
    bool meditationLibraryMode = false,
    bool breathingEditorMode = false,
  }) =>
      resolveBlockTool(
        link,
        nutritionMode: nutritionMode,
        workoutMode: workoutMode,
        meditationLibraryMode: meditationLibraryMode,
        breathingEditorMode: breathingEditorMode,
      );

  group('resolveBlockTool', () {
    // --- null ---
    test('null → none', () {
      expect(resolve(null), BlockToolKind.none);
    });

    // --- meal:* ---
    test('meal:breakfast + nutritionMode=false → foodLight', () {
      expect(resolve('meal:breakfast'), BlockToolKind.foodLight);
    });

    test('meal:lunch + nutritionMode=true → foodFull', () {
      expect(resolve('meal:lunch', nutritionMode: true), BlockToolKind.foodFull);
    });

    test('meal:dinner + nutritionMode=false → foodLight', () {
      expect(resolve('meal:dinner'), BlockToolKind.foodLight);
    });

    test('meal:dinner + nutritionMode=true → foodFull', () {
      expect(resolve('meal:dinner', nutritionMode: true), BlockToolKind.foodFull);
    });

    // --- workout ---
    test('workout + workoutMode=false → workoutLight', () {
      expect(resolve('workout'), BlockToolKind.workoutLight);
    });

    test('workout + workoutMode=true → workoutFull', () {
      expect(resolve('workout', workoutMode: true), BlockToolKind.workoutFull);
    });

    // --- focus ---
    test('focus → focus (независимо от флагов)', () {
      expect(resolve('focus'), BlockToolKind.focus);
      expect(
        resolve('focus',
            nutritionMode: true,
            workoutMode: true,
            meditationLibraryMode: true,
            breathingEditorMode: true),
        BlockToolKind.focus,
      );
    });

    // --- warmup ---
    test('warmup → warmup', () {
      expect(resolve('warmup'), BlockToolKind.warmup);
    });

    // --- breathing ---
    test('breathing → breathing (оба режима)', () {
      expect(resolve('breathing'), BlockToolKind.breathing);
      expect(resolve('breathing', breathingEditorMode: true), BlockToolKind.breathing);
    });

    // --- meditation ---
    test('meditation → meditation (оба режима)', () {
      expect(resolve('meditation'), BlockToolKind.meditation);
      expect(resolve('meditation', meditationLibraryMode: true), BlockToolKind.meditation);
    });

    // --- sleep ---
    test('sleep → sleepLight', () {
      expect(resolve('sleep'), BlockToolKind.sleepLight);
    });

    // --- неизвестный moduleLink ---
    test('unknown string → none', () {
      expect(resolve('unknown_module'), BlockToolKind.none);
      expect(resolve(''), BlockToolKind.none);
    });

    // --- allOff / allOn комбо-тест ---
    test('all flags off: проверяем light-ветки', () {
      expect(
        resolveBlockTool(
          'meal:breakfast',
          nutritionMode: allOff.nutritionMode,
          workoutMode: allOff.workoutMode,
          meditationLibraryMode: allOff.meditationLibraryMode,
          breathingEditorMode: allOff.breathingEditorMode,
        ),
        BlockToolKind.foodLight,
      );
      expect(
        resolveBlockTool(
          'workout',
          nutritionMode: allOff.nutritionMode,
          workoutMode: allOff.workoutMode,
          meditationLibraryMode: allOff.meditationLibraryMode,
          breathingEditorMode: allOff.breathingEditorMode,
        ),
        BlockToolKind.workoutLight,
      );
    });

    test('all flags on: проверяем full-ветки', () {
      expect(
        resolveBlockTool(
          'meal:breakfast',
          nutritionMode: allOn.nutritionMode,
          workoutMode: allOn.workoutMode,
          meditationLibraryMode: allOn.meditationLibraryMode,
          breathingEditorMode: allOn.breathingEditorMode,
        ),
        BlockToolKind.foodFull,
      );
      expect(
        resolveBlockTool(
          'workout',
          nutritionMode: allOn.nutritionMode,
          workoutMode: allOn.workoutMode,
          meditationLibraryMode: allOn.meditationLibraryMode,
          breathingEditorMode: allOn.breathingEditorMode,
        ),
        BlockToolKind.workoutFull,
      );
    });
  });
}
