// overflow_audit_all_test.dart
// Расширение RenderFlex-overflow аудита на ВСЕ экраны, ещё не покрытые
// overflow_audit_test.dart, на узкой ширине (320px) и при крупном тексте (scale 1.5).
//
// Методология (как в overflow_audit_test.dart): flutter_test бросает исключение
// при любом RenderFlex overflow во время pump. Следовательно, успешный pump =
// отсутствие overflow на этой конфигурации. НЕ маскируем overflow: никаких
// try/catch, никаких ослабленных ассертов.
//
// Харнесс (_OverflowHarness, _setSize, _settle, _unmount, _testTheme) скопирован
// из overflow_audit_test.dart. Провайдерные оверрайды (fake API, no-op
// notifications, fake purchases, GoogleFonts-моки) и сидинг через DAO скопированы
// из screens_smoke_all_test.dart.

import 'dart:io' show File;

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/day_logs_dao.dart';
import 'package:app/core/database/daos/goals_dao.dart';
import 'package:app/core/database/daos/recipes_dao.dart';
import 'package:app/core/database/daos/sleep_dao.dart';
import 'package:app/core/database/daos/streak_dao.dart';
import 'package:app/core/database/daos/water_dao.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;

// Экраны
import 'package:app/features/auth/auth_controller.dart' show isPremiumProvider;
import 'package:app/features/auth/auth_screen.dart';
import 'package:app/features/auth/forgot_password_screen.dart';
import 'package:app/features/diary/diary_history_screen.dart';
import 'package:app/features/focus/focus_screen.dart';
import 'package:app/features/food/food_screen.dart';
import 'package:app/features/food/recipe_editor_screen.dart';
import 'package:app/features/food/recipes_screen.dart';
import 'package:app/features/health/breathing_screen.dart';
import 'package:app/features/health/posture_screen.dart';
import 'package:app/features/health/screen_time_screen.dart';
import 'package:app/features/health/sleep_report_screen.dart';
import 'package:app/features/health/water_fullscreen_screen.dart';
import 'package:app/features/health/water_report_screen.dart';
import 'package:app/features/health/workout_editor_screen.dart';
import 'package:app/features/health/workout_trainer_screen.dart';
import 'package:app/features/health/exercise_history_screen.dart';
import 'package:app/features/health/workouts_screen.dart';
import 'package:app/features/onboarding/onboarding_screen.dart';
import 'package:app/features/onboarding/setup_flow.dart';
import 'package:app/features/paywall/paywall_screen.dart';
import 'package:app/features/plan/goals_screen.dart';
import 'package:app/features/profile/custom_theme_editor_screen.dart';
import 'package:app/features/profile/profile_screen.dart';
import 'package:app/features/profile/terms_screen.dart';
import 'package:app/features/wrapped/wrapped_screen.dart';

import 'package:app/services/api/api_client.dart'
    show ApiClient, apiClientProvider;
import 'package:app/services/notifications/notification_service.dart'
    show NotificationService, notificationServiceProvider;
import 'package:app/services/purchases/purchase_service.dart';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — копия из overflow_audit_test.dart.
// ---------------------------------------------------------------------------

ThemeData _testTheme() {
  return ThemeData.dark().copyWith(
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
}

// ---------------------------------------------------------------------------
// Константы конфигурации (как в overflow_audit_test.dart).
// ---------------------------------------------------------------------------

/// «Узкий» телефон (iPhone SE 1st gen ширина).
const Size _narrowSize = Size(320, 760);

/// Обычная ширина, но крупный текст (scale 1.5 — крайнее значение а11y).
const Size _normalSize = Size(360, 800);
const double _largeTextScale = 1.5;

// ---------------------------------------------------------------------------
// Харнесс — копия из overflow_audit_test.dart, плюс провайдерные оверрайды
// из screens_smoke_all_test.dart (no-op notifications включён по умолчанию,
// чтобы тогглы не дёргали платформенный канал).
// ---------------------------------------------------------------------------

class _OverflowHarness {
  _OverflowHarness(this.db, this.prefs);

  final AppDatabase db;
  final SharedPreferences prefs;

  Widget build(
    Widget screen, {
    double textScale = 1.0,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(_NoopNotificationService()),
        ...extraOverrides,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: textScale == 1.0 ? _narrowSize : _normalSize,
        ),
        child: MaterialApp(
          theme: _testTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Фейковый ApiClient: пустые данные вместо сетевых вызовов (копия из
// screens_smoke_all_test.dart).
// ---------------------------------------------------------------------------

class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.prefs);

  @override
  Future<List<Map<String, dynamic>>> getFriends() async => [];

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard() async => [];

  @override
  Future<List<Map<String, dynamic>>> getStudyGroups() async => [];

  @override
  Future<Map<String, dynamic>> me() async => {
        'name': 'Test User',
        'email': 'test@example.com',
        'subscription_tier': 'free',
      };

  @override
  Future<List<dynamic>> foodSearch(String query) async => [];
}

// ---------------------------------------------------------------------------
// No-op NotificationService (копия из screens_smoke_all_test.dart).
// ---------------------------------------------------------------------------

class _NoopNotificationService extends NotificationService {
  _NoopNotificationService() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> scheduleDailyReviews({
    int morningHour = 8,
    int eveningHour = 20,
  }) async {}

  @override
  Future<void> schedulePostureReminders() async {}

  @override
  Future<void> cancelPostureReminders() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> scheduleTaskReminder(
      String itemId, String title, DateTime fireAt) async {}

  @override
  Future<void> cancelTaskReminder(String itemId) async {}

  @override
  Future<void> refreshTimezone() async {}
}

// ---------------------------------------------------------------------------
// Заглушка PurchaseService (копия из paywall_screen_test.dart) — PaywallScreen
// читает purchaseServiceProvider и isPremiumProvider.
// ---------------------------------------------------------------------------

class _FakePurchaseService implements PurchaseService {
  @override
  Future<PurchaseOutcome> buyPremium() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
}

// ---------------------------------------------------------------------------
// GoogleFonts asset mock (копия из screens_smoke_all_test.dart) —
// CustomThemeEditorScreen строит превью-тему через GoogleFonts (Fraunces +
// HankenGrotesk), которая без ассетов/сети бросает исключение. Это артефакт
// тест-окружения, не баг экрана.
// ---------------------------------------------------------------------------

void _mockGoogleFontsAssets() {
  final fontBytes = File('test/fixtures/NotoSans.ttf').readAsBytesSync();
  final fontByteData = ByteData.sublistView(Uint8List.fromList(fontBytes));

  const fontAssetKeys = <String>[
    'assets/gf/Fraunces-Regular.ttf',
    'assets/gf/Fraunces-Bold.ttf',
    'assets/gf/Fraunces-Medium.ttf',
    'assets/gf/Fraunces-SemiBold.ttf',
    'assets/gf/HankenGrotesk-Regular.ttf',
    'assets/gf/HankenGrotesk-Bold.ttf',
    'assets/gf/HankenGrotesk-Medium.ttf',
    'assets/gf/HankenGrotesk-SemiBold.ttf',
  ];

  final manifest = <String, Object?>{
    for (final key in fontAssetKeys)
      key: <Object?>[
        <Object?, Object?>{'asset': key, 'dpr': null},
      ],
  };
  final manifestMessage = const StandardMessageCodec().encodeMessage(manifest)!;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = const StringCodec().decodeMessage(message);
    if (key == 'AssetManifest.bin') {
      return manifestMessage;
    }
    if (fontAssetKeys.contains(key)) {
      return fontByteData;
    }
    return null;
  });
}

// ---------------------------------------------------------------------------
// Утилиты прокачки/размонтирования (копия из overflow_audit_test.dart).
// ---------------------------------------------------------------------------

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _OverflowHarness harness;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _mockGoogleFontsAssets();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    harness = _OverflowHarness(db, prefs);
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> apiOverride() => [
        apiClientProvider.overrideWith((ref) => _FakeApiClient(prefs)),
      ];

  // Общий хелпер: прокачать экран на узкой ширине (320px, textScale 1.0).
  Future<void> pumpNarrow(
    WidgetTester tester,
    Widget screen, {
    List<Override> extraOverrides = const [],
  }) async {
    await _setSize(tester, _narrowSize);
    await tester
        .pumpWidget(harness.build(screen, extraOverrides: extraOverrides));
    await _settle(tester);
    await _unmount(tester);
  }

  // Общий хелпер: прокачать экран на крупном тексте (360px, textScale 1.5).
  Future<void> pumpLargeText(
    WidgetTester tester,
    Widget screen, {
    List<Override> extraOverrides = const [],
  }) async {
    await _setSize(tester, _normalSize);
    await tester.pumpWidget(
      harness.build(
        screen,
        textScale: _largeTextScale,
        extraOverrides: extraOverrides,
      ),
    );
    await _settle(tester);
    await _unmount(tester);
  }

  // -------------------------------------------------------------------------
  // AuthScreen
  // -------------------------------------------------------------------------

  group('AuthScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const AuthScreen(),
          extraOverrides: apiOverride());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const AuthScreen(),
          extraOverrides: apiOverride());
    });
  });

  // -------------------------------------------------------------------------
  // ForgotPasswordScreen
  // -------------------------------------------------------------------------

  group('ForgotPasswordScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const ForgotPasswordScreen(),
          extraOverrides: apiOverride());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const ForgotPasswordScreen(),
          extraOverrides: apiOverride());
    });
  });

  // -------------------------------------------------------------------------
  // OnboardingScreen
  // -------------------------------------------------------------------------

  group('OnboardingScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const OnboardingScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const OnboardingScreen());
    });
  });

  // -------------------------------------------------------------------------
  // SetupFlowScreen
  // -------------------------------------------------------------------------

  group('SetupFlowScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const SetupFlowScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const SetupFlowScreen());
    });
  });

  // -------------------------------------------------------------------------
  // GoalsScreen — пустое состояние + (с данными) цель с длинным заголовком
  // во всех горизонтах: самый плотный по ширине случай (чипы горизонтов + ряды).
  // -------------------------------------------------------------------------

  group('GoalsScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const GoalsScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const GoalsScreen());
    });

    testWidgets('with goals (long titles across horizons), narrow 320px',
        (tester) async {
      final dao = GoalsDao(db);
      const longTitle =
          'Become fluent in three foreign languages and travel the world';
      for (final horizon in const [
        'month',
        'year',
        'five_years',
        'ten_years',
      ]) {
        await dao.createGoal(longTitle, horizon);
      }
      await pumpNarrow(tester, const GoalsScreen());
    });
  });

  // -------------------------------------------------------------------------
  // WaterFullscreenScreen
  // -------------------------------------------------------------------------

  group('WaterFullscreenScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const WaterFullscreenScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const WaterFullscreenScreen());
    });
  });

  // -------------------------------------------------------------------------
  // WaterReportScreen — пусто + (с данными) несколько логов за сегодня, чтобы
  // отрисовались строки логов/прогресс.
  // -------------------------------------------------------------------------

  group('WaterReportScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const WaterReportScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const WaterReportScreen());
    });

    testWidgets('with water logs (today), narrow 320px', (tester) async {
      final dao = WaterDao(db);
      await dao.addWater(250);
      await dao.addWater(500);
      await dao.addWater(330);
      await pumpNarrow(tester, const WaterReportScreen());
    });
  });

  // -------------------------------------------------------------------------
  // SleepReportScreen — пусто + (с данными) завершённая ночь за сегодня.
  // SleepDao.startNight/endNight используют DateTime.now() → попадают в «сегодня».
  // -------------------------------------------------------------------------

  group('SleepReportScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const SleepReportScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const SleepReportScreen());
    });

    testWidgets('with a completed night (today), narrow 320px', (tester) async {
      final dao = SleepDao(db);
      await dao.startNight();
      await dao.endNight();
      await pumpNarrow(tester, const SleepReportScreen());
    });
  });

  // -------------------------------------------------------------------------
  // BreathingScreen
  // -------------------------------------------------------------------------

  group('BreathingScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const BreathingScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const BreathingScreen());
    });
  });

  // -------------------------------------------------------------------------
  // PostureScreen
  // -------------------------------------------------------------------------

  group('PostureScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const PostureScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const PostureScreen());
    });
  });

  // -------------------------------------------------------------------------
  // ScreenTimeScreen
  // -------------------------------------------------------------------------

  group('ScreenTimeScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const ScreenTimeScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const ScreenTimeScreen());
    });
  });

  // -------------------------------------------------------------------------
  // WorkoutsScreen — пусто + (с данными) 3 шаблона с длинными именами:
  // самый плотный по ширине случай для карточек тренировок.
  // -------------------------------------------------------------------------

  group('WorkoutsScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const WorkoutsScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const WorkoutsScreen());
    });

    testWidgets('with workouts (long names), narrow 320px', (tester) async {
      final dao = WorkoutsDao(db);
      await dao.createWorkout('Upper Body Push Hypertrophy Heavy Compound Day');
      await dao.createWorkout('Lower Body Posterior Chain Strength & Mobility');
      await dao.createWorkout('Full Body Conditioning Circuit With Accessories');
      await pumpNarrow(tester, const WorkoutsScreen());
    });
  });

  // -------------------------------------------------------------------------
  // WorkoutEditorScreen (seeded шаблон)
  // -------------------------------------------------------------------------

  group('WorkoutEditorScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      final id = await WorkoutsDao(db).createWorkout('Push Day');
      await pumpNarrow(tester, WorkoutEditorScreen(workoutId: id));
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      final id = await WorkoutsDao(db).createWorkout('Push Day');
      await pumpLargeText(tester, WorkoutEditorScreen(workoutId: id));
    });
  });

  // -------------------------------------------------------------------------
  // WorkoutTrainerScreen (seeded шаблон + упражнение). С данными: упражнение
  // с длинным именем и множеством подходов — худший случай для ряда set/rep.
  // -------------------------------------------------------------------------

  group('WorkoutTrainerScreen — overflow audits', () {
    testWidgets('narrow 320px (1 exercise): no overflow', (tester) async {
      final dao = WorkoutsDao(db);
      final id = await dao.createWorkout('Push Day');
      await dao.addExercise(workoutId: id, name: 'Bench Press');
      await pumpNarrow(tester, WorkoutTrainerScreen(workoutId: id));
    });

    testWidgets('large text scale 1.5 (1 exercise): no overflow',
        (tester) async {
      final dao = WorkoutsDao(db);
      final id = await dao.createWorkout('Push Day');
      await dao.addExercise(workoutId: id, name: 'Bench Press');
      await pumpLargeText(tester, WorkoutTrainerScreen(workoutId: id));
    });

    testWidgets('with long exercise name + many sets, narrow 320px',
        (tester) async {
      final dao = WorkoutsDao(db);
      final id = await dao.createWorkout('Push Day');
      await dao.addExercise(
        workoutId: id,
        name: 'Incline Dumbbell Bench Press With Slow Eccentric Tempo',
        sets: 6,
        reps: 15,
        weightKg: 42.5,
      );
      await pumpNarrow(tester, WorkoutTrainerScreen(workoutId: id));
    });
  });

  // -------------------------------------------------------------------------
  // ExerciseHistoryScreen — пусто + (с данными) много сессий с длинным именем
  // упражнения: худший случай для динамики веса + строк подходов на 320px.
  // -------------------------------------------------------------------------

  group('ExerciseHistoryScreen — overflow audits', () {
    // Сидирование делаем внутри tester.runAsync: чтение Drift-стрима
    // (.watch().first) зависит от zero-duration таймера Drift, который под
    // фейковыми часами теста сам не срабатывает — без реального клока .first
    // виснет (тест уходил в 10-минутный таймаут).
    Future<String> seedHistory(WidgetTester tester, {int sessions = 8}) async {
      final exId = await tester.runAsync(() async {
        final dao = WorkoutsDao(db);
        final workoutId = await dao.createWorkout('Push Day');
        await dao.addExercise(
          workoutId: workoutId,
          name: 'Incline Dumbbell Bench Press With Slow Eccentric Tempo',
        );
        final ex = (await dao.watchExercises(workoutId).first).single;
        for (var s = 0; s < sessions; s++) {
          final sid = await dao.startSession(workoutId, 'Push Day');
          await dao.logSet(
              sessionId: sid,
              exerciseId: ex.id,
              setIndex: 0,
              reps: 12,
              weightKg: 40.0 + s * 2.5);
        }
        return ex.id;
      });
      return exId!;
    }

    testWidgets('empty state, narrow 320px: no overflow', (tester) async {
      final exId = await tester.runAsync(() async {
        final dao = WorkoutsDao(db);
        final id = await dao.createWorkout('Push Day');
        await dao.addExercise(workoutId: id, name: 'Bench Press');
        return (await dao.watchExercises(id).first).single.id;
      });
      await pumpNarrow(tester, ExerciseHistoryScreen(exerciseId: exId!));
    });

    testWidgets('with many sessions (long name), narrow 320px', (tester) async {
      final exId = await seedHistory(tester);
      await pumpNarrow(tester, ExerciseHistoryScreen(exerciseId: exId));
    });

    testWidgets('with many sessions, large text scale 1.5', (tester) async {
      final exId = await seedHistory(tester);
      await pumpLargeText(tester, ExerciseHistoryScreen(exerciseId: exId));
    });
  });

  // -------------------------------------------------------------------------
  // DiaryHistoryScreen — пусто + (с данными) день с настроением и длинной
  // заметкой за сегодня.
  // -------------------------------------------------------------------------

  group('DiaryHistoryScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const DiaryHistoryScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const DiaryHistoryScreen());
    });

    testWidgets('with a day log (mood + long note), narrow 320px',
        (tester) async {
      await DayLogsDao(db).saveForDate(
        date: DateTime.now(),
        mood: 4,
        note: 'Today was a long and productive day full of small wins and '
            'a couple of unexpected setbacks that I handled calmly.',
      );
      await pumpNarrow(tester, const DiaryHistoryScreen());
    });
  });

  // -------------------------------------------------------------------------
  // FoodScreen
  // -------------------------------------------------------------------------

  group('FoodScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const FoodScreen(targetMeal: null),
          extraOverrides: apiOverride());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const FoodScreen(targetMeal: null),
          extraOverrides: apiOverride());
    });
  });

  // -------------------------------------------------------------------------
  // RecipesScreen — пусто + (с данными) 2 рецепта с длинными именами.
  // -------------------------------------------------------------------------

  group('RecipesScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const RecipesScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const RecipesScreen());
    });

    testWidgets('with recipes (long names), narrow 320px', (tester) async {
      final dao = RecipesDao(db);
      await dao.createRecipe('Slow-Cooked Mediterranean Chickpea & Spinach Stew');
      await dao.createRecipe('Overnight Oats With Banana, Peanut Butter & Chia');
      await pumpNarrow(tester, const RecipesScreen());
    });
  });

  // -------------------------------------------------------------------------
  // RecipeEditorScreen (seeded рецепт)
  // -------------------------------------------------------------------------

  group('RecipeEditorScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      final id = await RecipesDao(db).createRecipe('Oatmeal');
      await pumpNarrow(tester, RecipeEditorScreen(recipeId: id),
          extraOverrides: apiOverride());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      final id = await RecipesDao(db).createRecipe('Oatmeal');
      await pumpLargeText(tester, RecipeEditorScreen(recipeId: id),
          extraOverrides: apiOverride());
    });
  });

  // -------------------------------------------------------------------------
  // FocusScreen
  // -------------------------------------------------------------------------

  group('FocusScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const FocusScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const FocusScreen());
    });
  });

  // -------------------------------------------------------------------------
  // ProfileScreen — пусто (offline) + (с данными) seeded streak, чтобы
  // отрисовался плотный ряд статистики (current / best / freezes).
  // -------------------------------------------------------------------------

  group('ProfileScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const ProfileScreen(),
          extraOverrides: apiOverride());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const ProfileScreen(),
          extraOverrides: apiOverride());
    });

    testWidgets('with streak row (dense stats), narrow 320px', (tester) async {
      final dao = StreakDao(db);
      await dao.getOrCreate();
      await dao.updateStreak(
        const StreakTableCompanion(
          current: Value(128),
          longest: Value(365),
          freezeCount: Value(3),
        ),
      );
      await pumpNarrow(tester, const ProfileScreen(),
          extraOverrides: apiOverride());
    });
  });

  // -------------------------------------------------------------------------
  // CustomThemeEditorScreen — требует GoogleFonts-моки (см. _mockGoogleFontsAssets).
  // -------------------------------------------------------------------------

  group('CustomThemeEditorScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const CustomThemeEditorScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const CustomThemeEditorScreen());
    });
  });

  // -------------------------------------------------------------------------
  // TermsScreen
  // -------------------------------------------------------------------------

  group('TermsScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const TermsScreen());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const TermsScreen());
    });
  });

  // -------------------------------------------------------------------------
  // WrappedScreen
  // -------------------------------------------------------------------------

  group('WrappedScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const WrappedScreen(),
          extraOverrides: apiOverride());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const WrappedScreen(),
          extraOverrides: apiOverride());
    });
  });

  // -------------------------------------------------------------------------
  // PaywallScreen — требует purchaseServiceProvider + isPremiumProvider оверрайды.
  // -------------------------------------------------------------------------

  List<Override> paywallOverrides() => [
        isPremiumProvider.overrideWith((ref) async => false),
        purchaseServiceProvider.overrideWithValue(_FakePurchaseService()),
      ];

  group('PaywallScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await pumpNarrow(tester, const PaywallScreen(),
          extraOverrides: paywallOverrides());
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await pumpLargeText(tester, const PaywallScreen(),
          extraOverrides: paywallOverrides());
    });
  });
}
