// Полное дымовое покрытие экранов: КАЖДЫЙ экран инстанцируется и рендерится
// через общий in-memory-харнесс (Drift NativeDatabase.memory + мок SharedPreferences).
// Цель — поймать red-screen / lifecycle / overflow краши ДО сборки на телефон.
//
// Харнесс скопирован из screens_smoke_test.dart (тот же ProviderScope с
// sharedPreferencesProvider + appDatabaseProvider, _testTheme c FocusThemeExtension,
// тот же паттерн unmountAndFlush — Drift-таймеры должны сработать в теле теста).
//
// Принципы (НЕ маскируем краши):
//  - НИКАКОГО try/catch вокруг экрана, никаких ослабленных ассертов.
//  - Фейковый ApiClient возвращает ПУСТЫЕ данные — это честно: экран обязан
//    отрисовать своё empty-состояние. Это НЕ глушение исключений кода экрана.
//  - notificationServiceProvider переопределён no-op фейком: иначе тогглы/планирование
//    дёрнут платформенный канал flutter_local_notifications (на рендере он не нужен).
//
// Не дублируем 5 экранов из screens_smoke_test.dart (Today, Plan, ShoppingList,
// Meditation, Diary) и PaywallScreen (свой paywall_screen_test.dart).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/recipes_dao.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/services/api/api_client.dart'
    show ApiClient, apiClientProvider;
import 'package:app/services/notifications/notification_service.dart'
    show NotificationService, notificationServiceProvider;

// Экраны
import 'package:app/features/auth/auth_screen.dart';
import 'package:app/features/auth/forgot_password_screen.dart';
import 'package:app/features/onboarding/onboarding_screen.dart';
import 'package:app/features/onboarding/setup_flow.dart';
import 'package:app/features/plan/goals_screen.dart';
import 'package:app/features/health/health_screen.dart';
import 'package:app/features/health/water_fullscreen_screen.dart';
import 'package:app/features/health/water_report_screen.dart';
import 'package:app/features/health/sleep_report_screen.dart';
import 'package:app/features/health/breathing_screen.dart';
import 'package:app/features/health/posture_screen.dart';
import 'package:app/features/health/screen_time_screen.dart';
import 'package:app/features/health/costudy_screen.dart';
import 'package:app/features/health/workouts_screen.dart';
import 'package:app/features/health/workout_editor_screen.dart';
import 'package:app/features/health/workout_trainer_screen.dart';
import 'package:app/features/health/exercise_history_screen.dart';
import 'package:app/features/diary/diary_history_screen.dart';
import 'package:app/features/food/food_screen.dart';
import 'package:app/features/food/recipes_screen.dart';
import 'package:app/features/food/recipe_editor_screen.dart';
import 'package:app/features/food/barcode_scanner_screen.dart';
import 'package:app/features/focus/focus_screen.dart';
import 'package:app/features/profile/profile_screen.dart';
import 'package:app/features/profile/custom_theme_editor_screen.dart';
import 'package:app/features/profile/terms_screen.dart';
import 'package:app/features/wrapped/wrapped_screen.dart';

import 'package:drift/native.dart';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — копия из screens_smoke_test.dart (FocusThemeExtension нужен
// экранам через Theme.of(context).extension<FocusThemeExtension>()!).
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
// Фейковый ApiClient: пустые данные вместо сетевых вызовов. Экраны должны
// отрисовать пустое состояние. Переопределяем все методы, дёргаемые в
// initState/при загрузке (costudy._load, profile.me, food/recipe search).
// ---------------------------------------------------------------------------

class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.prefs);

  @override
  Future<List<Map<String, dynamic>>> getFriends() async => [];

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard() async => [];

  @override
  Future<List<Map<String, dynamic>>> getStudyGroups() async => [];

  // ProfileScreen.currentUserProvider зовёт me() только если токен задан;
  // в тестах токена нет (offline-режим) → me() не вызывается. На всякий случай.
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
// No-op NotificationService: не трогает платформенный канал. Все методы,
// дёргаемые экранами (тогглы напоминаний осанки/воды/разборов), переопределены
// в пустышки. init() не вызывается — плагин остаётся незаинициализированным.
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
// GoogleFonts в тестах: сетевая загрузка отключена (flutter_test_config.dart).
// Большинство экранов используют _testTheme() (системный шрифт) и не трогают
// GoogleFonts. Но CustomThemeEditorScreen внутри сам строит превью-тему через
// AppTheme.forKeyWithCustom(...) → Fraunces/HankenGrotesk → GoogleFonts пытается
// загрузить шрифт и (без ассетов и без сети) бросает исключение.
//
// Это артефакт тест-окружения (на устройстве шрифт качается по сети), а НЕ баг
// экрана. Легитимный харнесс-фикс: мокаем asset-бандл так, чтобы GoogleFonts
// нашёл шрифт в «ассетах» (ветка assetPath в loadFontIfNecessary не проверяет
// hash — подойдёт любой валидный TTF). Подставляем локальный NotoSans.ttf
// под именами семейств-вариантов, которые запрашивает экран.
void _mockGoogleFontsAssets() {
  final fontBytes =
      File('test/fixtures/NotoSans.ttf').readAsBytesSync();
  final fontByteData = ByteData.sublistView(Uint8List.fromList(fontBytes));

  // Ключи ассетов: имя без расширения должно ОКАНЧИВАТЬСЯ на apiFilenamePrefix
  // GoogleFonts (см. _findFamilyWithVariantAssetPath). Покрываем варианты,
  // используемые AppTheme.custom (Fraunces display + HankenGrotesk body).
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

  // Бинарный AssetManifest.bin: { assetKey: [ {asset: assetKey, dpr: null} ] }.
  final manifest = <String, Object?>{
    for (final key in fontAssetKeys)
      key: <Object?>[
        <Object?, Object?>{'asset': key, 'dpr': null},
      ],
  };
  final manifestMessage =
      const StandardMessageCodec().encodeMessage(manifest)!;

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
    return null; // прочие ассеты — не наше дело (вернёт ошибку загрузки, если будет)
  });
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _mockGoogleFontsAssets();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  // Харнесс: оборачивает экран в ProviderScope + MaterialApp(Scaffold).
  // extraOverrides — для экранов, которым нужен fake API и т.п.
  Widget harness(Widget screen, {List<Override> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        // No-op уведомления — иначе тогглы дёрнут платформенный канал.
        notificationServiceProvider.overrideWithValue(_NoopNotificationService()),
        ...extraOverrides,
      ],
      child: MaterialApp(theme: _testTheme(), home: Scaffold(body: screen)),
    );
  }

  // Fake API override — общий для экранов, ходящих в сеть на старте.
  List<Override> apiOverride() => [
        apiClientProvider.overrideWith((ref) => _FakeApiClient(prefs)),
      ];

  // Drift при отписке стримов создаёт zero-duration таймер (markAsClosed).
  // Размонтируем дерево и прокачиваем кадр, чтобы таймер сработал в теле теста.
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // Прокачка экрана: первичный pump + реальные микротаски для Drift-стримов
  // (runAsync) + ещё пара кадров для анимаций. Как в существующих тестах.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------

  group('AuthScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        harness(const AuthScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(AuthScreen), findsOneWidget);
      // Бренд-заголовок виден сразу.
      expect(find.text('Kaizen'), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('renders step-1 (request code) without crashing',
        (tester) async {
      await tester.pumpWidget(
        harness(const ForgotPasswordScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Onboarding
  // -------------------------------------------------------------------------

  group('OnboardingScreen', () {
    testWidgets('renders first step without crashing', (tester) async {
      await tester.pumpWidget(harness(const OnboardingScreen()));
      await settle(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      // Кнопка «Skip» видна на онбординге.
      expect(find.text('Skip'), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('SetupFlowScreen', () {
    testWidgets('renders first setup step without crashing', (tester) async {
      await tester.pumpWidget(harness(const SetupFlowScreen()));
      await settle(tester);

      expect(find.byType(SetupFlowScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Plan
  // -------------------------------------------------------------------------

  group('GoalsScreen', () {
    testWidgets('empty state renders flag icon', (tester) async {
      await tester.pumpWidget(harness(const GoalsScreen()));
      await settle(tester);

      expect(find.byType(GoalsScreen), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Health
  // -------------------------------------------------------------------------

  group('HealthScreen', () {
    testWidgets('renders hub without crashing', (tester) async {
      await tester.pumpWidget(harness(const HealthScreen()));
      await settle(tester);

      expect(find.byType(HealthScreen), findsOneWidget);
      // HealthScreen — body-виджет (без своего AppBar, живёт в ScaffoldWithNavBar).
      // Карточка воды содержит водяную каплю — стабильный признак рендера.
      expect(find.byIcon(Icons.water_drop_outlined), findsWidgets);

      await unmountAndFlush(tester);
    });
  });

  group('WaterFullscreenScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(harness(const WaterFullscreenScreen()));
      await settle(tester);

      expect(find.byType(WaterFullscreenScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('WaterReportScreen', () {
    testWidgets('renders (default today) without crashing', (tester) async {
      await tester.pumpWidget(harness(const WaterReportScreen()));
      await settle(tester);

      expect(find.byType(WaterReportScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('SleepReportScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(harness(const SleepReportScreen()));
      await settle(tester);

      expect(find.byType(SleepReportScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('BreathingScreen', () {
    testWidgets('renders idle (preset selection) without crashing',
        (tester) async {
      // Чистый StatefulWidget с таймером — таймер стартует ТОЛЬКО по тапу Start,
      // не в initState. unmountAndFlush гарантированно снимет любой таймер.
      await tester.pumpWidget(harness(const BreathingScreen()));
      await settle(tester);

      expect(find.byType(BreathingScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('PostureScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(harness(const PostureScreen()));
      await settle(tester);

      expect(find.byType(PostureScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('ScreenTimeScreen', () {
    testWidgets('renders permission/empty state without crashing',
        (tester) async {
      // На не-Android (тест на Dart VM) провайдер сразу отдаёт denied + пустые
      // данные и НЕ трогает usage_stats — платформенный канал мокать не нужно.
      await tester.pumpWidget(harness(const ScreenTimeScreen()));
      await settle(tester);

      expect(find.byType(ScreenTimeScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('CoStudyScreen', () {
    testWidgets('renders empty state with fake API', (tester) async {
      // _load() в initState зовёт getFriends/getLeaderboard/getStudyGroups —
      // фейк возвращает пустые списки, экран рисует empty-состояние.
      await tester.pumpWidget(
        harness(const CoStudyScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(CoStudyScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('WorkoutsScreen', () {
    testWidgets('empty state renders fitness icon', (tester) async {
      await tester.pumpWidget(harness(const WorkoutsScreen()));
      await settle(tester);

      expect(find.byType(WorkoutsScreen), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center_outlined), findsWidgets);

      await unmountAndFlush(tester);
    });
  });

  group('WorkoutEditorScreen', () {
    testWidgets('renders a seeded workout without crashing', (tester) async {
      // Сидим шаблон тренировки и передаём его id.
      final dao = WorkoutsDao(db);
      final workoutId =
          await tester.runAsync(() => dao.createWorkout('Push Day')) as String;

      await tester
          .pumpWidget(harness(WorkoutEditorScreen(workoutId: workoutId)));
      await settle(tester);

      expect(find.byType(WorkoutEditorScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('WorkoutTrainerScreen', () {
    testWidgets('renders a seeded workout with one exercise without crashing',
        (tester) async {
      // Тренажёр индексирует _exercises[0] — без упражнений упал бы (out of range).
      // Сидим шаблон + одно упражнение.
      final dao = WorkoutsDao(db);
      final workoutId = await tester.runAsync(() async {
        final id = await dao.createWorkout('Push Day');
        await dao.addExercise(workoutId: id, name: 'Bench Press');
        return id;
      }) as String;

      await tester
          .pumpWidget(harness(WorkoutTrainerScreen(workoutId: workoutId)));
      await settle(tester);

      expect(find.byType(WorkoutTrainerScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('ExerciseHistoryScreen', () {
    testWidgets('renders seeded history with a logged set', (tester) async {
      // Сидим тренировку + упражнение, логируем 3 подхода → экран рисует историю.
      final dao = WorkoutsDao(db);
      final exerciseId = await tester.runAsync(() async {
        final workoutId = await dao.createWorkout('Push Day');
        await dao.addExercise(workoutId: workoutId, name: 'Bench Press');
        final ex = (await dao.watchExercises(workoutId).first).single;
        final sid = await dao.startSession(workoutId, 'Push Day');
        await dao.logSet(
            sessionId: sid, exerciseId: ex.id, setIndex: 0, reps: 10, weightKg: 40);
        await dao.logSet(
            sessionId: sid, exerciseId: ex.id, setIndex: 1, reps: 9, weightKg: 40);
        await dao.logSet(
            sessionId: sid, exerciseId: ex.id, setIndex: 2, reps: 8, weightKg: 40);
        return ex.id;
      }) as String;

      await tester
          .pumpWidget(harness(ExerciseHistoryScreen(exerciseId: exerciseId)));
      await settle(tester);

      expect(find.byType(ExerciseHistoryScreen), findsOneWidget);
      // Хотя бы одна строка подхода «reps × weight» отрисована.
      expect(find.textContaining('10 × 40'), findsOneWidget);

      await unmountAndFlush(tester);
    });

    testWidgets('empty state (valid id, no logs) renders chart icon',
        (tester) async {
      // Упражнение есть, но подходов не логировали → пустое состояние.
      final dao = WorkoutsDao(db);
      final exerciseId = await tester.runAsync(() async {
        final workoutId = await dao.createWorkout('Push Day');
        await dao.addExercise(workoutId: workoutId, name: 'Bench Press');
        return (await dao.watchExercises(workoutId).first).single.id;
      }) as String;

      await tester
          .pumpWidget(harness(ExerciseHistoryScreen(exerciseId: exerciseId)));
      await settle(tester);

      expect(find.byType(ExerciseHistoryScreen), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Diary
  // -------------------------------------------------------------------------

  group('DiaryHistoryScreen', () {
    testWidgets('renders (no entry for today) without crashing',
        (tester) async {
      await tester.pumpWidget(harness(const DiaryHistoryScreen()));
      await settle(tester);

      expect(find.byType(DiaryHistoryScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Food
  // -------------------------------------------------------------------------

  group('FoodScreen', () {
    testWidgets('empty state renders with fake API', (tester) async {
      // targetMeal: null — обычный вход без скролла к слоту.
      await tester.pumpWidget(
        harness(const FoodScreen(targetMeal: null),
            extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(FoodScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('RecipesScreen', () {
    testWidgets('empty state renders utensils icon', (tester) async {
      await tester.pumpWidget(harness(const RecipesScreen()));
      await settle(tester);

      expect(find.byType(RecipesScreen), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu_outlined), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('RecipeEditorScreen', () {
    testWidgets('renders a seeded recipe without crashing', (tester) async {
      final dao = RecipesDao(db);
      final recipeId =
          await tester.runAsync(() => dao.createRecipe('Oatmeal')) as String;

      await tester.pumpWidget(
        harness(RecipeEditorScreen(recipeId: recipeId),
            extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(RecipeEditorScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('BarcodeScannerScreen', () {
    // SKIP-причина: mobile_scanner стартует нативную камеру в initState
    // (MethodChannel) — headless-тест её предоставить не может. Это
    // единственный допустимый skip (превью камеры действительно требует девайс).
    testWidgets(
      'renders with camera (skipped: camera plugin not available in headless test)',
      (tester) async {
        await tester.pumpWidget(harness(const BarcodeScannerScreen()));
        await settle(tester);
        expect(find.byType(BarcodeScannerScreen), findsOneWidget);
        await unmountAndFlush(tester);
      },
      skip: true,
    );
  });

  // -------------------------------------------------------------------------
  // Focus
  // -------------------------------------------------------------------------

  group('FocusScreen', () {
    testWidgets('renders idle (preset selection) without crashing',
        (tester) async {
      // Таймер стартует только по тапу Start — не в initState.
      await tester.pumpWidget(harness(const FocusScreen()));
      await settle(tester);

      expect(find.byType(FocusScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Profile
  // -------------------------------------------------------------------------

  group('ProfileScreen', () {
    testWidgets('renders offline state without crashing', (tester) async {
      // currentUserProvider возвращает null при отсутствии токена (offline) →
      // рендерится offline-состояние. Fake API на случай вызова me().
      await tester.pumpWidget(
        harness(const ProfileScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('CustomThemeEditorScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(harness(const CustomThemeEditorScreen()));
      await settle(tester);

      expect(find.byType(CustomThemeEditorScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  group('TermsScreen', () {
    testWidgets('renders static terms without crashing', (tester) async {
      await tester.pumpWidget(harness(const TermsScreen()));
      await settle(tester);

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Wrapped
  // -------------------------------------------------------------------------

  group('WrappedScreen', () {
    testWidgets('renders (local stats, empty DB) without crashing',
        (tester) async {
      // wrappedStatsProvider считает статистику из локального Drift (без сети).
      // apiClientProvider нужен только для AI-сводки (по кнопке) — fake на всякий.
      await tester.pumpWidget(
        harness(const WrappedScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      expect(find.byType(WrappedScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });
}
