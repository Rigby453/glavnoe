// onboarding_fork_test.dart
// Покрывает перестроенный единый онбординг (ТЗ редизайна, 2026-07):
// короткое вступление (язык + 2 value-слайда) → развилка «Войти / Продолжить
// как гость» — вход НЕ обязателен, пейвол на этом шаге не участвует.
//
// Группы:
//   'structure'    — порядок и число страниц (4: язык, 2 слайда, развилка),
//                     прогресс-бар, видимость «Пропустить».
//   'fork buttons' — обе кнопки развилки видны и не вызывают исключений.
//   'navigation'   — реальный GoRouter: гость идёт в /setup МИНУЯ /auth;
//                     «Войти» ведёт на /auth; оба пути выставляют onboarding_done.
//   'overflow'     — развилка переживает 320px и textScale 1.5/2.0.
//
// Навигация между страницами внутри PageView (NeverScrollableScrollPhysics в
// SetupFlowScreen, но OnboardingScreen использует обычный PageView.builder —
// здесь физика свайпа доступна, но для надёжности используем jumpToPage).

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/auth/auth_controller.dart';
import 'package:app/features/onboarding/onboarding_screen.dart';
import 'package:app/features/onboarding/setup_flow.dart' show setupDoneKey;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// Узкая ширина + предельный textScale a11y (как во всех overflow-тестах).
const Size _narrowSize = Size(320, 760);

// Число страниц в новом intro-флоу: язык + 2 value-слайда + развилка.
const int _forkPage = 3;

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Прыжок на страницу через PageController (минуя физику свайпов).
  Future<void> goToPage(WidgetTester tester, int page) async {
    final dynamic pageView = tester.widget(find.byType(PageView));
    (pageView.controller as PageController).jumpToPage(page);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ---------------------------------------------------------------------------
  // Харнесс без роутера — для структурных тестов, не требующих навигации.
  // ---------------------------------------------------------------------------

  Widget plainApp() {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: _testTheme(),
        home: const OnboardingScreen(),
      ),
    );
  }

  group('structure', () {
    testWidgets('всего 4 страницы: язык + 2 value-слайда + развилка',
        (tester) async {
      await tester.pumpWidget(plainApp());
      await tester.pump(const Duration(milliseconds: 50));

      // Прогресс-счётчик на первой странице — "1 / 4".
      expect(find.text('1 / 4'), findsOneWidget);

      await goToPage(tester, 1);
      expect(find.text('2 / 4'), findsOneWidget);
      // Первый value-слайд (хук).
      expect(find.text('Plan what matters'), findsOneWidget);

      await goToPage(tester, 2);
      expect(find.text('3 / 4'), findsOneWidget);
      expect(find.text('Nothing slips'), findsOneWidget);

      await goToPage(tester, _forkPage);
      expect(find.text('4 / 4'), findsOneWidget);
      expect(find.text('Ready when you are.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('«Пропустить» видна на вступлении, скрыта на развилке',
        (tester) async {
      await tester.pumpWidget(plainApp());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Skip'), findsOneWidget);

      await goToPage(tester, _forkPage);
      // На развилке скип не нужен — сама развилка предлагает быстрый путь.
      expect(find.text('Skip'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('глобальная «Пропустить» прыгает на развилку (не выходит из онбординга)',
        (tester) async {
      await tester.pumpWidget(plainApp());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ready when you are.'), findsOneWidget);
      // Флаг онбординга НЕ должен быть выставлен только переходом по слайдам —
      // он ставится явно в _goToLogin()/_continueAsGuest().
      expect(prefs.getBool(onboardingDoneKey), isNot(true));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('fork buttons', () {
    testWidgets('обе кнопки развилки видны без исключений', (tester) async {
      await tester.pumpWidget(plainApp());
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      await goToPage(tester, _forkPage);

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(FilledButton, 'Log in or sign up'),
          findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Continue as guest'),
          findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  // ---------------------------------------------------------------------------
  // Навигация: реальный GoRouter с /onboarding + плейсхолдерами /auth и /setup
  // (плейсхолдеры — как в my_data_nav_test.dart: тестируем НАВИГАЦИЮ, а не
  // внутренности AuthScreen/SetupFlowScreen, которые покрыты своими тестами).
  // ---------------------------------------------------------------------------

  group('navigation', () {
    GoRouter router() => GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(
              path: '/onboarding',
              builder: (c, s) => const OnboardingScreen(),
            ),
            GoRoute(
              path: '/auth',
              builder: (c, s) => const Center(child: Text('AUTH_PLACEHOLDER')),
            ),
            GoRoute(
              path: '/setup',
              builder: (c, s) =>
                  const Center(child: Text('SETUP_PLACEHOLDER')),
            ),
          ],
        );

    Widget routedApp() {
      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          theme: _testTheme(),
          routerConfig: router(),
        ),
      );
    }

    // KaiMascot держит бесконечную «дыхательную» анимацию (_breathCtrl.repeat),
    // поэтому pumpAndSettle() здесь НИКОГДА не осядет — используем ограниченные
    // pump() с фиксированной длительностью (как во всех остальных onboarding-тестах).
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      '«Продолжить как гость» → /setup МИНУЯ /auth, guest_mode выставлен',
      (tester) async {
        await tester.pumpWidget(routedApp());
        await settle(tester);

        await goToPage(tester, _forkPage);
        await settle(tester);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Continue as guest'));
        await settle(tester);

        // Сразу /setup, экран /auth ни разу не показан.
        expect(find.text('SETUP_PLACEHOLDER'), findsOneWidget);
        expect(find.text('AUTH_PLACEHOLDER'), findsNothing);

        expect(prefs.getBool(onboardingDoneKey), isTrue);
        // Гостевой режим: authControllerProvider.state == true без токена.
        final container = ProviderScope.containerOf(
          tester.element(find.text('SETUP_PLACEHOLDER')),
        );
        expect(container.read(authControllerProvider), isTrue);
        expect(container.read(authControllerProvider.notifier).isAuthenticated,
            isFalse);

        // Setup-квиз ещё не пройден — никакого преждевременного "setup_done".
        expect(prefs.getBool(setupDoneKey), isNot(true));
      },
    );

    testWidgets(
      '«Войти или зарегистрироваться» → /auth, onboarding_done выставлен',
      (tester) async {
        await tester.pumpWidget(routedApp());
        await settle(tester);

        await goToPage(tester, _forkPage);
        await settle(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Log in or sign up'));
        await settle(tester);

        expect(find.text('AUTH_PLACEHOLDER'), findsOneWidget);
        expect(prefs.getBool(onboardingDoneKey), isTrue);

        // Логин ещё НЕ произошёл — гостевой режим не включается этим путём.
        final container = ProviderScope.containerOf(
          tester.element(find.text('AUTH_PLACEHOLDER')),
        );
        expect(container.read(authControllerProvider), isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Overflow: развилка на узкой ширине + крупном textScale.
  // ---------------------------------------------------------------------------

  group('overflow', () {
    testWidgets('развилка переживает 320px / textScale 1.5', (tester) async {
      await tester.binding.setSurfaceSize(_narrowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: _narrowSize,
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              locale: const Locale('en'),
              theme: _testTheme(),
              home: const OnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      await goToPage(tester, _forkPage);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('развилка переживает 320px / textScale 2.0', (tester) async {
      await tester.binding.setSurfaceSize(_narrowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: _narrowSize,
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              locale: const Locale('en'),
              theme: _testTheme(),
              home: const OnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      await goToPage(tester, _forkPage);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
