// profile_hub_redesign_test.dart
// Тесты на батч правок хаба профиля:
//   #9  — дубль-раздел «Аккаунт» убран из списка (редактирование имени/аватара
//        остаётся доступным через тап по шапке → /profile/account, см.
//        profile_identity_test.dart, который этот путь не трогает).
//   #10 — «Поделиться стриком» переехал ближе к «Прогрессу», выше блока
//        Subscription/Share week/Shared with me.
//   #11 — премиум-пользователь видит бейдж «Premium» рядом с именем + акцент
//        аватара (корона); free-пользователь — ничего лишнего.
//
// Харнесс — копия паттерна из screens_smoke_all_test.dart / overflow_audit_all_test.dart
// (Drift in-memory DB + мок SharedPreferences + no-op NotificationService +
// фейковый ApiClient): ProfileScreen тянет streakDaoProvider/freezeAccrualServiceProvider
// через appDatabaseProvider, поэтому полегче харнесс (как у profile_identity_test.dart)
// здесь не подходит.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/streak_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/auth/auth_controller.dart' show isPremiumProvider;
import 'package:app/features/profile/profile_screen.dart';
import 'package:app/services/api/api_client.dart'
    show ApiClient, apiClientProvider;
import 'package:app/services/notifications/notification_service.dart'
    show NotificationService, notificationServiceProvider;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема (копия из screens_smoke_all_test.dart).
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
// Фейковый ApiClient — без сети, без токена → ProfileScreen рендерит
// офлайн-состояние, currentUserProvider возвращает null без обращения к me().
// ---------------------------------------------------------------------------

class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.prefs);

  @override
  Future<Map<String, dynamic>> me() async => {
        'name': 'Test User',
        'email': 'test@example.com',
        'subscription_tier': 'free',
      };
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

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget harness({
    bool isPremium = false,
    double width = 390,
    double height = 900,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(_NoopNotificationService()),
        apiClientProvider.overrideWith((ref) => _FakeApiClient(prefs)),
        isPremiumProvider.overrideWith((ref) async => isPremium),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: Size(width, height),
        ),
        child: MaterialApp(
          theme: _testTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
  }

  /// Без pumpAndSettle (deadlock guard) — даём FutureProvider'ам, реальным
  /// микротаскам Drift-стримов (runAsync) и post-frame коллбэкам
  /// (_runAccrual) разрешиться несколькими кадрами.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Drift при отписке стримов создаёт zero-duration таймер (markAsClosed).
  /// Размонтируем дерево и прокачиваем кадр, чтобы таймер сработал в теле
  /// теста — иначе flutter_test падает на "Timer is still pending".
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Пампит ProfileScreen с заданными размерами/премиум-статусом.
  ///
  /// ВАЖНО: `MediaQueryData.size` сам по себе НЕ меняет реальные constraints
  /// рендер-дерева (они идут от `tester.binding`/`tester.view`) — поэтому
  /// здесь обязательно зовём `setSurfaceSize`, а не только оборачиваем в
  /// MediaQuery. Без этого офскрин-Sliver-дети ListView просто не строятся
  /// (см. историю отладки — "Shared with me" не находился даже при
  /// MediaQueryData(size: Size(_, 2400))).
  Future<void> pumpProfile(
    WidgetTester tester, {
    bool isPremium = false,
    double width = 390,
    double height = 900,
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      harness(
        isPremium: isPremium,
        width: width,
        height: height,
        textScale: textScale,
      ),
    );
    await settle(tester);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // #9 — раздел «Аккаунт» убран из списка настроек
  // ═══════════════════════════════════════════════════════════════════════

  group('#9 — дубль-раздел «Аккаунт»', () {
    testWidgets('строки-заголовка "Account" больше нет в хабе профиля',
        (tester) async {
      await pumpProfile(tester);

      // AppBar — это «Kaizen» (kAppWordmark), не «Account»: единственное
      // место, где раньше встречался текст "Account", — удалённый NavRow.
      expect(find.text('Account'), findsNothing);

      await unmountAndFlush(tester);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #10 — «Поделиться стриком» рядом с «Прогрессом»
  // ═══════════════════════════════════════════════════════════════════════

  group('#10 — «Поделиться стриком» рядом с прогрессом', () {
    testWidgets(
        'строка "Share streak" выше блока Subscription/Share week/Shared with me',
        (tester) async {
      final dao = StreakDao(db);
      await dao.getOrCreate();
      await dao.updateStreak(const StreakTableCompanion(current: Value(5)));

      // Высокий viewport — чтобы весь ListView (включая «Shared with me» в
      // самом низу шеринг-блока) был замонтирован без прокрутки: офскрин
      // Sliver-дети не строятся, а сравнивать порядок нужно по всем строкам.
      await pumpProfile(tester, height: 2400);

      final shareStreakY = tester.getTopLeft(find.text('Share streak')).dy;
      final subscriptionY = tester.getTopLeft(find.text('Free plan')).dy;
      final shareWeekY = tester.getTopLeft(find.text('Share my week')).dy;
      final sharedWithMeY = tester.getTopLeft(find.text('Shared with me')).dy;

      expect(shareStreakY, lessThan(subscriptionY));
      expect(shareStreakY, lessThan(shareWeekY));
      expect(shareStreakY, lessThan(sharedWithMeY));

      await unmountAndFlush(tester);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #11 — премиум-бейдж в шапке
  // ═══════════════════════════════════════════════════════════════════════

  group('#11 — премиум-бейдж в шапке профиля', () {
    testWidgets('free-пользователь — бейдж "Premium" не показан',
        (tester) async {
      await pumpProfile(tester);

      expect(find.text('Premium'), findsNothing);

      await unmountAndFlush(tester);
    });

    testWidgets('премиум-пользователь — бейдж "Premium" рядом с именем + корона на аватаре',
        (tester) async {
      await pumpProfile(tester, isPremium: true);

      expect(find.text('Premium'), findsOneWidget);
      // Корона — минимум в двух местах: бейдж рядом с именем + поверх
      // аватара (третья может прийти из строки Subscription, которая для
      // премиум-пользователя тоже легитимно показывает корону — не жёстко
      // фиксируем общее число иконок в списке).
      expect(
        find
            .byIcon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill))
            .evaluate()
            .length,
        greaterThanOrEqualTo(2),
      );

      await unmountAndFlush(tester);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Overflow: премиум-шапка на узком экране / крупном тексте (CLAUDE.md gate B)
  // ═══════════════════════════════════════════════════════════════════════

  group('Overflow — премиум-шапка', () {
    testWidgets('320px + textScale 1.5: без overflow', (tester) async {
      await pumpProfile(tester, isPremium: true, width: 320, textScale: 1.5);

      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });

    testWidgets('320px + textScale 2.0: без overflow', (tester) async {
      await pumpProfile(tester, isPremium: true, width: 320, textScale: 2.0);

      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });
  });
}
