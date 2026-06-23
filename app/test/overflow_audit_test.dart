// overflow_audit_test.dart
// Проверка RenderFlex-переполнений на узкой ширине (320px) и при крупном тексте (scale 1.5).
//
// Методология: flutter_test бросает исключение при любом RenderFlex overflow во время pump.
// Следовательно, успешный pump = отсутствие overflow на этой конфигурации.
//
// Харнесс скопирован из screens_smoke_test.dart (те же in-memory Drift + SharedPreferences).
// Дополнительно переопределяем providerScopeOverrides для провайдеров API / auth
// которые могут кинуть исключение при отсутствии реального бэкенда.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/diary/diary_screen.dart';
import 'package:app/features/food/food_screen.dart';
import 'package:app/features/health/costudy_screen.dart';
import 'package:app/features/health/habits_screen.dart';
import 'package:app/features/health/health_screen.dart';
import 'package:app/features/plan/plan_screen.dart';
import 'package:app/features/plan/widgets/plan_providers.dart'
    show
        PlanLayout,
        PlanLayoutNotifier,
        PlanView,
        planLayoutProvider,
        planViewProvider;
import 'package:app/features/plan/widgets/week_strip.dart' show selectedDayProvider;
import 'package:app/features/today/today_screen.dart';
import 'package:app/services/api/api_client.dart' show ApiClient, apiClientProvider;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — скопирована из screens_smoke_test.dart.
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
// Вспомогательные константы
// ---------------------------------------------------------------------------

/// «Узкий» телефон (iPhone SE 1st gen ширина).
const Size _narrowSize = Size(320, 760);

/// Обычная ширина, но крупный текст (scale 1.5 — крайнее значение а11y).
const Size _normalSize = Size(360, 800);
const double _largeTextScale = 1.5;

// ---------------------------------------------------------------------------
// Харнесс
// ---------------------------------------------------------------------------

class _OverflowHarness {
  _OverflowHarness(this.db, this.prefs);

  final AppDatabase db;
  final SharedPreferences prefs;

  /// Строит дерево виджетов для экрана [screen].
  /// [textScale] — множитель шрифта; по умолчанию 1.0.
  Widget build(
    Widget screen, {
    double textScale = 1.0,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        ...extraOverrides,
      ],
      child: MediaQuery(
        // Переопределяем textScaler здесь — тема приложения уважает это значение.
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: textScale == 1.0 ? _narrowSize : _normalSize,
        ),
        child: MaterialApp(
          theme: _testTheme(),
          // Отключаем GoRouter: экраны используют context.push() — в тестах
          // навигация нас не интересует, нужен только рендер.
          home: Scaffold(body: screen),
        ),
      ),
    );
  }
}

/// Тестовый нотифер раскладки: всегда стартует в grid (без SharedPreferences).
/// Нужен, чтобы тумблер раскладки в тулбаре отрисовался в grid-состоянии.
class _GridLayoutNotifier extends PlanLayoutNotifier {
  @override
  PlanLayout build() => PlanLayout.grid;
}

/// Фейковый ApiClient для co-study: возвращает пустые списки вместо реальных
/// HTTP-вызовов. Без него экран бьётся в недоступный бэкенд (медленно/таймауты)
/// — нам же нужен только детерминированный рендер пустого состояния.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.prefs);

  @override
  Future<List<Map<String, dynamic>>> getFriends() async => [];

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard() async => [];

  @override
  Future<List<Map<String, dynamic>>> getStudyGroups() async => [];
}

/// Размонтирует дерево и прокачивает один кадр, чтобы Drift-таймеры
/// сработали внутри тела теста (иначе flutter_test ругается на pending timers).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// Устанавливает размер поверхности рендера.
Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Прокачивает виджет до успешного render:
/// 1) первичный pump (layout + paint)
/// 2) ждём Drift-стримы (реальный IO в runAsync)
/// 3) ещё несколько кадров для анимаций
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _OverflowHarness harness;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    harness = _OverflowHarness(db, prefs);
  });

  tearDown(() async {
    await db.close();
  });

  // -------------------------------------------------------------------------
  // TodayScreen — узкая ширина
  // -------------------------------------------------------------------------

  group('TodayScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const TodayScreen()));
      await _settle(tester);
      // Если бы был overflow — pump() бросил бы исключение FlutterError.
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const TodayScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // PlanScreen
  // -------------------------------------------------------------------------

  group('PlanScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const PlanScreen()));
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const PlanScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });

    // Худший случай тулбара (строка 2): выбран НЕ сегодня → видна кнопка «Today»
    // вдобавок к дате, поиску и overflow-меню. Двухстрочный тулбар должен
    // помещаться на 320px без переполнения.
    testWidgets('narrow 320px with non-today (Today button visible): no overflow',
        (tester) async {
      await _setSize(tester, _narrowSize);
      final past = DateTime(2020, 1, 1);
      await tester.pumpWidget(
        harness.build(
          const PlanScreen(),
          extraOverrides: [selectedDayProvider.overrideWith((ref) => past)],
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });

    // Вариант с раскладкой grid: тумблер раскладки в строке 1 в grid-состоянии.
    // Проверяем, что первая строка (сегмент + тумблер) помещается на 320px.
    testWidgets('narrow 320px grid layout (toggle in grid state): no overflow',
        (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(
        harness.build(
          const PlanScreen(),
          extraOverrides: [
            planLayoutProvider.overrideWith(() => _GridLayoutNotifier()),
          ],
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // DiaryScreen
  // -------------------------------------------------------------------------

  group('DiaryScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const DiaryScreen()));
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const DiaryScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // HealthScreen (hub)
  // -------------------------------------------------------------------------

  group('HealthScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const HealthScreen()));
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const HealthScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // FoodScreen
  // -------------------------------------------------------------------------

  group('FoodScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const FoodScreen()));
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const FoodScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // CoStudyScreen — заголовок «Группы» с кнопками «Вступить по коду»/«Создать»
  // переполнялся вживую (RIGHT OVERFLOWED BY 93px). Фейковый API → пустое
  // состояние, аудитим обе ширины и оба textScale.
  // -------------------------------------------------------------------------

  List<Override> buildCostudyOverrides() => [
        apiClientProvider.overrideWith((ref) => _FakeApiClient(prefs)),
      ];

  group('CoStudyScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(
        harness.build(const CoStudyScreen(), extraOverrides: buildCostudyOverrides()),
      );
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(
          const CoStudyScreen(),
          textScale: _largeTextScale,
          extraOverrides: buildCostudyOverrides(),
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // HabitsScreen — пустое состояние + (если есть данные) карточки привычек.
  // Аудитим обе ширины и оба textScale.
  // -------------------------------------------------------------------------

  group('HabitsScreen — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const HabitsScreen()));
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const HabitsScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });

    // С реальными привычками (good + bad) — карточки с прогресс-баром,
    // счётчиком, кнопками лога и меню. Самый плотный по ширине случай.
    testWidgets('with habits, narrow 320px: no overflow', (tester) async {
      await db.habitsDao.createHabit(
        name: 'Drink water every single day no matter what',
        type: 'good',
      );
      await db.habitsDao.createHabit(
        name: 'Stop scrolling social media late at night',
        type: 'bad',
      );
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(harness.build(const HabitsScreen()));
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('with habits, large text scale 1.5: no overflow', (tester) async {
      await db.habitsDao.createHabit(
        name: 'Drink water every single day no matter what',
        type: 'good',
      );
      await db.habitsDao.createHabit(
        name: 'Stop scrolling social media late at night',
        type: 'bad',
      );
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(const HabitsScreen(), textScale: _largeTextScale),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  // -------------------------------------------------------------------------
  // PlanScreen — виды «3 дня» (threeDay) и «Месяц» (month, блочный календарь).
  // Недавняя фича plan-views; пользователь ловил overflow вживую. Аудитим
  // обе ширины и оба textScale, переопределяя planViewProvider.
  // -------------------------------------------------------------------------

  group('PlanScreen 3-day view — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(
        harness.build(
          const PlanScreen(),
          extraOverrides: [
            planViewProvider.overrideWith((ref) => PlanView.threeDay),
          ],
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(
          const PlanScreen(),
          textScale: _largeTextScale,
          extraOverrides: [
            planViewProvider.overrideWith((ref) => PlanView.threeDay),
          ],
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });

  group('PlanScreen month (block) view — overflow audits', () {
    testWidgets('narrow 320px: no overflow', (tester) async {
      await _setSize(tester, _narrowSize);
      await tester.pumpWidget(
        harness.build(
          const PlanScreen(),
          extraOverrides: [
            planViewProvider.overrideWith((ref) => PlanView.month),
          ],
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });

    testWidgets('large text scale 1.5: no overflow', (tester) async {
      await _setSize(tester, _normalSize);
      await tester.pumpWidget(
        harness.build(
          const PlanScreen(),
          textScale: _largeTextScale,
          extraOverrides: [
            planViewProvider.overrideWith((ref) => PlanView.month),
          ],
        ),
      );
      await _settle(tester);
      await _unmount(tester);
    });
  });
}
