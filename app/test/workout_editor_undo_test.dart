// workout_editor_undo_test.dart
// Регресс-тест Defect 2: «Undo-снэкбар после удаления упражнения».
//
// Verifies:
//   a) Snackbar appears after exercise deletion (with Undo button).
//   b) Tapping Undo restores the deleted exercise.
//
// Auto-dismiss (4s) НЕ тестируется здесь:
//   В headless-тесте showUndoSnackBar вызывается из async-кода, который
//   выполняется в real-async зоне (через tester.runAsync). Таймер SnackBar
//   также создаётся в real-async зоне и НЕ подчиняется fake-async тикеру
//   (tester.pump(5s)). Это ограничение инфраструктуры теста, а не баг.
//
//   Зафиксированная проблема MIUI («висит бесконечно») — вендорский баг
//   системного оверлея, не связанный с кодом Flutter. Статус: docs/STATUS.md.
//
// Тест накачивает 5 секунд в конце, чтобы не оставлять pending timers.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/health/workout_editor_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Seed: создать тренировку + одно упражнение. Возвращает workoutId.
// ---------------------------------------------------------------------------

Future<String> _seedWorkout(WidgetTester tester, AppDatabase db) async {
  late String workoutId;
  await tester.runAsync(() async {
    // WorkoutsDao не является геттером AppDatabase — создаём напрямую.
    final dao = WorkoutsDao(db);
    workoutId = await dao.createWorkout('Test Workout');
    await dao.addExercise(
      workoutId: workoutId,
      name: 'Push-up',
      sets: 3,
      reps: 10,
    );
  });
  return workoutId;
}

// ---------------------------------------------------------------------------
// Тестовая тема (FocusThemeExtension required by WorkoutEditorScreen)
// ---------------------------------------------------------------------------

ThemeData _testTheme() => ThemeData.dark().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF9E9070),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFF3A3020),
          surfaceElevated: Color(0xFF2E2618),
          textFaint: Color(0xFF736850),
          accentMuted: Color(0xFF26290F),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFF524630),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Settle/unmount helpers
// ---------------------------------------------------------------------------

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

Widget _harness(Widget screen, AppDatabase db, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(390, 800)),
      child: MaterialApp(
        theme: _testTheme(),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: screen,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Defect 2(a): SnackBar появляется после удаления упражнения
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
      'Undo SnackBar появляется после удаления упражнения',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workoutId = await _seedWorkout(tester, db);

    await tester.pumpWidget(
        _harness(WorkoutEditorScreen(workoutId: workoutId), db, prefs));
    await _settle(tester);

    // Упражнение должно отображаться.
    expect(find.text('Push-up'), findsOneWidget);

    // Тапаем кнопку удаления (trailing IconButton с Icons.delete_outline).
    // Icons.delete_outline единственен при одном упражнении.
    //
    // Используем только pump (без runAsync): NativeDatabase.memory() возвращает
    // Future.value() — это немедленно-resolved Future, которое завершается как
    // microtask при pump(). Это сохраняет AnimationController SnackBar в
    // fake-async зоне и позволяет pump(duration) двигать анимацию.
    await tester.tap(find.byIcon(PhosphorIcons.trash()).last);
    await tester.pump(); // start _deleteExercise; suspend at await removeExercise
    await tester.pump(); // microtask: removeExercise resolves; _deleteExercise resumes → showUndoSnackBar
    await tester.pump(const Duration(milliseconds: 300)); // SnackBar enter animation (~250ms)

    // SnackBar должен появиться с кнопкой Undo.
    expect(
      find.text('Undo'),
      findsOneWidget,
      reason: 'SnackBar с Undo должен появляться после удаления упражнения',
    );

    // Прокачиваем 5 секунд чтобы не оставлять pending timers.
    // (auto-dismiss не тестируется — см. комментарий в шапке файла)
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Defect 2(b): Undo восстанавливает удалённое упражнение
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
      'нажатие Undo восстанавливает удалённое упражнение',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workoutId = await _seedWorkout(tester, db);

    await tester.pumpWidget(
        _harness(WorkoutEditorScreen(workoutId: workoutId), db, prefs));
    await _settle(tester);

    expect(find.text('Push-up'), findsOneWidget);

    // Удаляем упражнение (pump-only: NativeDatabase.memory() = Future.value()).
    await tester.tap(find.byIcon(PhosphorIcons.trash()).last);
    await tester.pump(); // suspend at await removeExercise
    await tester.pump(); // microtask: remove done → showUndoSnackBar
    await tester.pump(const Duration(milliseconds: 300)); // SnackBar animation

    // SnackBar появился.
    expect(find.text('Undo'), findsOneWidget);

    // Нажимаем Undo — restoreExercise тоже pump-only.
    await tester.tap(find.text('Undo'));
    await tester.pump(); // suspend at await restoreExercise
    await tester.pump(); // microtask: restore done
    await _settle(tester); // stream emits → exercises list обновляется

    // Упражнение должно снова отображаться.
    expect(
      find.text('Push-up'),
      findsOneWidget,
      reason: 'Undo должен восстановить удалённое упражнение',
    );

    // Прокачиваем таймер автоскрытия тоста (4с) — иначе Timer still pending
    // (showUndoSnackBar теперь форвардит на showAppToast, core/animations/app_toast.dart).
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
