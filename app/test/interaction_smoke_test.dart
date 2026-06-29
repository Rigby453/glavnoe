// Дымовые тесты ВЗАИМОДЕЙСТВИЙ (не первичного рендера). Реальные краши этого
// приложения случаются на ТАПЕ/СВАЙПЕ/смене вида/открытии диалога, а не на
// первом кадре. Здесь мы прогоняем самые краш-опасные интерактивные пути и
// ловим НАСТОЯЩИЕ исключения.
//
// Принципы (НЕ маскируем краши):
//  - НИКАКОГО try/catch вокруг самого взаимодействия, никаких ослабленных
//    ассертов, никакого глотания FlutterError/исключений.
//  - Если тап роняет экран из-за бага в lib/ — оставляем тест КРАСНЫМ и
//    докладываем (это и есть результат работы).
//  - Легитимный харнесс: provider-оверрайды, посев Drift, мок платформенных
//    каналов (path_provider), мок GoogleFonts-ассетов, прокачка кадров.
//
// Харнесс скопирован из screens_smoke_all_test.dart / screens_smoke_test.dart:
// тот же ProviderScope (sharedPreferencesProvider + appDatabaseProvider +
// notificationServiceProvider no-op), _FakeApiClient, _testTheme,
// settle/unmountAndFlush, insertTask, посев Workouts/Recipes DAO.

import 'dart:io' show Directory, File;

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/core/utils/id.dart';
import 'package:app/services/api/api_client.dart' show ApiClient, apiClientProvider;
import 'package:app/services/notifications/notification_service.dart'
    show NotificationService, notificationServiceProvider;

// Экраны / виджеты под тестом
import 'package:app/features/health/meditation_screen.dart';
import 'package:app/features/health/workout_editor_screen.dart';
import 'package:app/features/health/workout_trainer_screen.dart';
import 'package:app/features/health/costudy_screen.dart';
import 'package:app/features/today/today_screen.dart';
import 'package:app/features/plan/plan_screen.dart';
import 'package:app/features/plan/widgets/plan_providers.dart' show PlanView;
import 'package:app/features/diary/diary_screen.dart';
import 'package:app/features/diary/diary_history_screen.dart';
import 'package:app/features/food/food_screen.dart';
import 'package:app/features/today/widgets/add_task_sheet.dart';
import 'package:app/core/widgets/number_input_dialog.dart';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — копия (FocusThemeExtension нужен экранам).
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
// Фейковый ApiClient: пустые данные вместо сети (как в smoke-харнессе).
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
// No-op NotificationService (платформенный канал не трогаем).
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
  Future<void> scheduleDailyReviews(
      {int morningHour = 8, int eveningHour = 20}) async {}
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
// GoogleFonts-ассеты — копия из screens_smoke_all_test.dart. Артефакт теста
// (на устройстве шрифт качается по сети), не баг экрана.
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
    if (key == 'AssetManifest.bin') return manifestMessage;
    if (fontAssetKeys.contains(key)) return fontByteData;
    return null;
  });
}

// path_provider зовётся AddTaskSheet (getApplicationDocumentsDirectory) при
// первом кадре через _initPendingAttachments. Headless-тест канала не имеет —
// мокаем его на временную папку. Это харнесс-фикс (канал недоступен в тесте),
// НЕ обход бага экрана.
void _mockPathProvider() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final tmp = Directory.systemTemp.path;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    // Любой запрос пути → системная временная папка теста.
    return tmp;
  });
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _mockGoogleFontsAssets();
    _mockPathProvider();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget harness(Widget screen, {List<Override> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(_NoopNotificationService()),
        ...extraOverrides,
      ],
      child: MaterialApp(theme: _testTheme(), home: Scaffold(body: screen)),
    );
  }

  List<Override> apiOverride() => [
        apiClientProvider.overrideWith((ref) => _FakeApiClient(prefs)),
      ];

  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  // Посев задачи на сегодня (полдень — стабильно внутри UTC-окна дня).
  Future<void> insertTask(
    String title, {
    String priority = 'medium',
    String status = 'pending',
  }) async {
    final now = DateTime.now();
    await db.into(db.itemsTable).insert(
          ItemsTableCompanion(
            id: Value(uuidV4()),
            userId: const Value('local'),
            title: Value(title),
            type: const Value('task'),
            priority: Value(priority),
            status: Value(status),
            scheduledAt: Value(DateTime(now.year, now.month, now.day, 12)),
            durationMinutes: const Value(30),
            isProtected: Value(priority == 'main'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // -------------------------------------------------------------------------
  // 1. MeditationScreen → плеер: тап по сессии, проверка рендера плеера.
  // Исторический red-screen: MediaQuery.disableAnimationsOf в initState +
  // старт Timer/анимации + overflow. unmountAndFlush снимает периодический Timer.
  // -------------------------------------------------------------------------

  group('Interaction: MeditationScreen → player', () {
    testWidgets('tap session opens player, advance a step, then leave',
        (tester) async {
      await tester.pumpWidget(harness(const MeditationScreen()));
      await tester.pump();

      // Тап по сессии открывает превью позы (ADR-054), затем «Start» — плеер.
      await tester.tap(find.text('Focus Reset'));
      await tester.pump(); // навигация на превью позы
      await tester.pump(const Duration(milliseconds: 350)); // переход доехал

      // Превью позы → _SessionPlayerScreen (pushReplacement MaterialPageRoute).
      await tester.tap(find.text('Start'));
      await tester.pump(); // навигация
      await tester.pump(const Duration(milliseconds: 100)); // первый кадр плеера

      // Плеер отрисовался: прогресс шага «1 / 5» (Focus Reset = 5 шагов).
      expect(find.textContaining('1 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Жмём «Next» — продвигаем шаг (перезапуск Timer/анимации дуги).
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('2 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Уходим из плеера через «End session» → периодический Timer отменяется в dispose.
      // Кнопка Пауза (добавлена в плеер) увеличила высоту контента, и «End session»
      // может оказаться ниже 600px-viewport по умолчанию — прокручиваем перед тапом.
      await tester.ensureVisible(find.text('End session'));
      await tester.pump();
      await tester.tap(find.text('End session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MeditationScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 2. WorkoutEditorScreen — открыть посеянную тренировку (тап-вход в редактор).
  //    WorkoutTrainerScreen — пройти логирование подхода (тренажёр индексирует
  //    _exercises[idx] — провоцируем set-done / skip-rest).
  // (WorkoutsScreen→editor идёт через go_router context.push, который в plain
  //  MaterialApp не работает; монтируем целевые экраны напрямую, как в smoke.)
  // -------------------------------------------------------------------------

  group('Interaction: WorkoutEditorScreen open', () {
    testWidgets('seeded workout opens in editor without crashing',
        (tester) async {
      final dao = WorkoutsDao(db);
      final workoutId =
          await tester.runAsync(() => dao.createWorkout('Push Day')) as String;

      await tester.pumpWidget(harness(WorkoutEditorScreen(workoutId: workoutId)));
      await settle(tester);

      expect(find.byType(WorkoutEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });
  });

  group('Interaction: WorkoutTrainerScreen → log a set', () {
    testWidgets('tap "Set done" then "Skip rest" advances without index crash',
        (tester) async {
      // Тренажёр индексирует _exercises[idx] и _setIndex. Сеем 2 упражнения
      // с sets=2, чтобы пройти полный путь: set-done → rest → skip-rest → set 2.
      final dao = WorkoutsDao(db);
      final workoutId = await tester.runAsync(() async {
        final id = await dao.createWorkout('Push Day');
        await dao.addExercise(
            workoutId: id, name: 'Bench Press', sets: 2, restSeconds: 30);
        await dao.addExercise(
            workoutId: id, name: 'Squat', sets: 2, restSeconds: 30);
        return id;
      }) as String;

      await tester
          .pumpWidget(harness(WorkoutTrainerScreen(workoutId: workoutId)));
      await settle(tester);

      expect(find.byType(WorkoutTrainerScreen), findsOneWidget);
      // Первая фаза — work, первое упражнение.
      expect(find.text('Bench Press'), findsOneWidget);

      // Set done → не последний подход → фаза rest (стартует Timer отдыха).
      // Feature B: тап логирует фактический подход в Drift ДО смены фазы.
      // Плановые reps упражнения = 10 (дефолт addExercise), степперы не трогали.
      await tester.tap(find.text('Set done'));
      // logSet — асинхронная запись в Drift; прокачиваем реальные микротаски.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Skip rest'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Залогированный подход существует: строка workout_set_logs с reps=10
      // (плановые повторы, степперы не меняли) для первого упражнения, setIndex 0.
      final logged = await tester.runAsync(
          () => db.select(db.workoutSetLogsTable).get());
      expect(logged, isNotNull);
      expect(logged!, hasLength(1));
      expect(logged.single.reps, 10);
      expect(logged.single.setIndex, 0);

      // Skip rest → переход к подходу 2 того же упражнения (индексация _setIndex++).
      await tester.tap(find.text('Skip rest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Снова фаза work — кнопка Set done на месте, индекс упражнения валиден.
      expect(find.text('Set done'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 3 + 4. Add-task bottom sheet (TodayScreen FAB):
  //   - открыть лист, ввести заголовок, переключить тип/приоритет;
  //   - открыть кастомный диалог напоминания (NumberInputDialog — класс «6268»):
  //     ввести значение и ПОДТВЕРДИТЬ; затем открыть снова и ОТМЕНИТЬ/закрыть.
  //   - открыть кастомный диалог длительности (inline TextEditingController),
  //     ввести и подтвердить.
  // Краш «TextEditingController used after disposed» — на закрытии диалога.
  // -------------------------------------------------------------------------

  group('Interaction: AddTaskSheet + number-input dialogs', () {
    // Поверхность повыше, чтобы лист помещал больше контента по вертикали.
    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    // Открывает add-task-лист через FAB на TodayScreen.
    Future<void> openSheet(WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
          harness(const TodayScreen(), extraOverrides: apiOverride()));
      await settle(tester);
      // FAB теперь Phosphor plus() (не Material Icons.add).
      await tester.tap(find.widgetWithIcon(FloatingActionButton, PhosphorIcons.plus()));
      await settle(tester);
      expect(find.byType(AddTaskSheet), findsOneWidget);
    }

    // Чип «Custom» в рядах длительности/напоминания несёт avatar Icon(Icons.tune)
    // и стоит в КОНЦЕ горизонтально-прокручиваемого ряда (вне экрана справа).
    // Duration-ряд идёт раньше Reminder-ряда → первый tune = duration, последний = reminder.
    //
    // Двухосевая прокрутка: (1) вертикально — листаем сам лист, пока ряд не
    // окажется на экране; (2) горизонтально — прокручиваем ряд до видимости чипа.
    Future<void> tapCustomChip(WidgetTester tester,
        {required bool reminder}) async {
      final sectionLabel = reminder ? 'Reminder' : 'Duration';
      // (1) Вертикальная прокрутка листа к нужной секции.
      final sheetScrollable = find.byType(Scrollable).first; // внешний вертикальный
      await tester.scrollUntilVisible(
        find.text(sectionLabel),
        300,
        scrollable: sheetScrollable,
      );
      await tester.pump();

      // (2) Целевой tune-иконка чипа «Custom». После вертикальной прокрутки
      // tune-иконок в дереве может быть несколько; берём ту, что в нужном ряду:
      // первая для duration, последняя для reminder.
      Finder tuneTarget() {
        final tunes = find.byIcon(Icons.tune);
        return reminder ? tunes.last : tunes.first;
      }

      // Горизонтальный Scrollable, охватывающий эту иконку.
      final rowScrollable = find
          .ancestor(of: tuneTarget(), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        tuneTarget(),
        200,
        scrollable: rowScrollable,
      );
      await tester.pump();
      // ensureVisible прокручивает ВСЕ охватывающие scrollable (и вертикальный
      // лист, и горизонтальный ряд), гарантируя, что чип полностью на экране и
      // не перекрыт нижней кромкой листа перед тапом.
      await tester.ensureVisible(tuneTarget());
      // НЕ pumpAndSettle: в листе autofocus-TextField c мигающим курсором →
      // дерево «никогда не успокаивается». Прокачиваем фиксированными кадрами.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(tuneTarget());
      // Открытие диалога (showDialog) — фиксированные кадры вместо settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('open sheet, type title, toggle chips, no crash',
        (tester) async {
      await openSheet(tester);

      // Вводим заголовок (autofocus TextField внутри _TitleField).
      await tester.enterText(find.byType(TextField).first, 'Read chapter');
      await tester.pump();

      // Переключаем приоритет на «Important» (priority_chip_high) и тип на «Event».
      await tester.ensureVisible(find.text('Important'));
      await tester.tap(find.text('Important'));
      await tester.pump();
      await tester.ensureVisible(find.text('Event'));
      await tester.tap(find.text('Event'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AddTaskSheet), findsOneWidget);

      await unmountAndFlush(tester);
    });

    testWidgets('custom reminder dialog: confirm a value (NumberInputDialog)',
        (tester) async {
      await openSheet(tester);

      await tapCustomChip(tester, reminder: true);

      // NumberInputDialog открыт — вводим значение и подтверждаем «Add».
      expect(find.byType(NumberInputDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '15');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      // Закрытие диалога с анимацией — здесь раньше падало «used after disposed».
      // Бэз pumpAndSettle (мигающий курсор) — фиксированные кадры на анимацию.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // Лист всё ещё открыт, не упал, диалог закрыт.
      expect(find.byType(AddTaskSheet), findsOneWidget);
      expect(find.byType(NumberInputDialog), findsNothing);

      await unmountAndFlush(tester);
    });

    testWidgets(
        'custom reminder dialog: cancel/dismiss path (dispose-after-close)',
        (tester) async {
      await openSheet(tester);

      await tapCustomChip(tester, reminder: true);
      expect(find.byType(NumberInputDialog), findsOneWidget);

      // Печатаем что-то, затем ОТМЕНА — контроллер диалога должен корректно
      // освободиться ПОСЛЕ анимации закрытия (исторический 6268-краш).
      await tester.enterText(find.byType(TextField).last, '5');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(AddTaskSheet), findsOneWidget);
      expect(find.byType(NumberInputDialog), findsNothing);

      await unmountAndFlush(tester);
    });

    testWidgets('custom duration dialog: confirm a value (inline controller)',
        (tester) async {
      await openSheet(tester);

      await tapCustomChip(tester, reminder: false);

      // Кастомный диалог длительности (inline TextEditingController в State листа).
      await tester.enterText(find.byType(TextField).last, '45');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(AddTaskSheet), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 5. PlanScreen — переключение видов Day → 3 days → Week → Month, с данными.
  // Свитчер на mobile — PopupMenuButton (_ViewDropdown). Тап по нему + пункт.
  // Краш-риск: layout/null при смене вида с/без данных.
  // -------------------------------------------------------------------------

  group('Interaction: PlanScreen view switching', () {
    testWidgets('switch Day → 3 days → Week → Month with seeded tasks',
        (tester) async {
      // Узкая поверхность (телефон) → мобильный макет с view-dropdown
      // (_ViewDropdown — PopupMenuButton<PlanView>), а не планшетный SegmentedButton.
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() => insertTask('Lecture: Algebra'));
      await tester.runAsync(() => insertTask('Gym', priority: 'main'));

      await tester.pumpWidget(harness(const PlanScreen()));
      await settle(tester);

      // Стартовый вид — Day.
      expect(find.byType(PlanScreen), findsOneWidget);
      expect(find.byType(PopupMenuButton<PlanView>), findsOneWidget);
      // Никаких исключений на первичном рендере Day-вида.
      expect(tester.takeException(), isNull, reason: 'initial Day render');

      Future<void> switchTo(String label) async {
        // Открываем view-dropdown (_ViewDropdown — PopupMenuButton<PlanView>).
        await tester.tap(find.byType(PopupMenuButton<PlanView>));
        await tester.pumpAndSettle();
        // В открытом popup-меню пункт лежит в оверлее ПОВЕРХ экрана. Берём
        // hit-testable-совпадение (сам пункт меню), игнорируя лейбл кнопки
        // dropdown под барьером и любые одноимённые тексты под ним.
        await tester.tap(find.text(label).hitTestable().last);
        await tester.pumpAndSettle();
      }

      await switchTo('3 days');
      expect(tester.takeException(), isNull, reason: 'after switch to 3 days');
      await switchTo('Week');
      expect(tester.takeException(), isNull, reason: 'after switch to Week');
      await switchTo('Month');
      expect(tester.takeException(), isNull, reason: 'after switch to Month');
      await switchTo('Day');
      expect(tester.takeException(), isNull, reason: 'after switch to Day');
      expect(find.byType(PlanScreen), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Свайп по задаче на TodayScreen — Dismissible (done/skip). Проверяем,
  // что свайп не роняет дерево (materializeOccurrence / undo-тост).
  // -------------------------------------------------------------------------

  group('Interaction: TodayScreen swipe a task', () {
    testWidgets('swipe a pending task to trigger dismissible action',
        (tester) async {
      // Отключаем звук завершения: иначе CompletionSoundService создаёт
      // AudioPlayer, и его event-канал (audioplayers) бросает асинхронный
      // MissingPluginException в headless-тесте. Это ограничение тест-окружения
      // (нативного плагина нет), а не баг — гасим через пользовательскую настройку.
      await tester.runAsync(
          () => prefs.setBool('completion_sound_enabled', false));
      await tester.runAsync(() => insertTask('Write essay', priority: 'main'));

      await tester.pumpWidget(harness(const TodayScreen(), extraOverrides: apiOverride()));
      await settle(tester);

      final taskFinder = find.text('Write essay');
      expect(taskFinder, findsOneWidget);

      // Свайп вправо (startToEnd) → дефолт «done». confirmDismiss выполняет
      // markDone + показывает Undo-тост (OverlayEntry в корневом Overlay).
      await tester.drag(taskFinder, const Offset(500, 0));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Задача помечена done в БД (свайп-действие отработало).
      final rows = await tester.runAsync(
          () => (db.select(db.itemsTable)..where((t) => t.title.equals('Write essay')))
              .get());
      expect(rows, isNotNull);
      expect(rows!.single.status, 'done');

      // Undo-тост (_AppToastOverlay) ставит таймер автоскрытия ~4с. Тост может
      // появиться на кадр позже (после async markDone) → прокачиваем время дважды,
      // чтобы 4-с таймер гарантированно сработал до unmount (иначе «Timer still pending»).
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 7. DiaryScreen — сохранить день (mood+note); затем DiaryHistoryScreen —
  // открыть/перелистать день (стрелки навигации дат, setState — без go_router).
  // -------------------------------------------------------------------------

  group('Interaction: Diary save + history', () {
    testWidgets('save a day log (mood + note)', (tester) async {
      await tester.pumpWidget(harness(const DiaryScreen()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      // Настроение 🙂 (4/5) + заметка.
      await tester.tap(find.text('🙂'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Good study day');
      await tester.pump();
      await tester.ensureVisible(find.text('Save Day'));
      await tester.tap(find.text('Save Day'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      final rows = await tester.runAsync(() => db.select(db.dayLogsTable).get());
      expect(rows, isNotNull);
      expect(rows!, hasLength(1));
      expect(rows.first.mood, 4);
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });

    testWidgets('DiaryHistoryScreen step to previous day without crashing',
        (tester) async {
      // Посев лога за вчера, чтобы шаг назад показал запись.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.runAsync(() => db.into(db.dayLogsTable).insert(
            DayLogsTableCompanion(
              id: Value(uuidV4()),
              date: Value(DateTime.utc(
                  yesterday.year, yesterday.month, yesterday.day)),
              mood: const Value(4),
              note: const Value('Yesterday note'),
              createdAt: Value(DateTime.now()),
            ),
          ));

      await tester.pumpWidget(harness(const DiaryHistoryScreen()));
      await settle(tester);

      expect(find.byType(DiaryHistoryScreen), findsOneWidget);

      // Шаг на предыдущий день: DateNavigator использует Phosphor caretLeft
      // (а не arrow_back, который остался только в AppBar и вызывает context.pop()).
      await tester.tap(find.byIcon(PhosphorIcons.caretLeft()).first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Вчерашняя заметка отрисовалась.
      expect(find.text('Yesterday note'), findsOneWidget);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 8. FoodScreen — открыть лист «добавить еду» (FAB → showAppSheet),
  // _FakeApiClient.foodSearch возвращает пусто. Просто проверяем, что флоу
  // открывается без краша.
  // -------------------------------------------------------------------------

  group('Interaction: FoodScreen open add-food sheet', () {
    testWidgets('tap add-food FAB opens search sheet without crashing',
        (tester) async {
      await tester.pumpWidget(
        harness(const FoodScreen(targetMeal: null), extraOverrides: apiOverride()),
      );
      await settle(tester);

      // CollapsingFab «Add» открывает _FoodSearchSheet.
      await tester.tap(find.byType(FloatingActionButton).first);
      await settle(tester);

      // Лист поиска открыт: его заголовок — «Add» (headlineSmall) + TextField.
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });
  });

  // -------------------------------------------------------------------------
  // 9. CoStudyScreen — открыть диалог «Create group» / «Join by code».
  // Краш-риск: создание/dispose контроллера диалога, null-доступ к API.
  // -------------------------------------------------------------------------

  group('Interaction: CoStudyScreen group dialogs', () {
    testWidgets('open "Create group" dialog without crashing', (tester) async {
      await tester.pumpWidget(
        harness(const CoStudyScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      // Кнопка «Create group» (TextButton.icon в шапке секции групп).
      await tester.tap(find.text('Create group').first);
      // KaiMascot в пустом состоянии дышит бесконечно → pumpAndSettle зависает.
      // Фиксированные кадры на анимацию открытия диалога.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Диалог открыт: TextField для имени группы.
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);

      // Закрываем «Cancel» — контроллер диалога должен корректно освободиться.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });

    testWidgets('open "Join by code" dialog without crashing', (tester) async {
      await tester.pumpWidget(
        harness(const CoStudyScreen(), extraOverrides: apiOverride()),
      );
      await settle(tester);

      await tester.tap(find.text('Join by code').first);
      // KaiMascot дышит бесконечно → фиксированные кадры вместо pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });
  });
}
