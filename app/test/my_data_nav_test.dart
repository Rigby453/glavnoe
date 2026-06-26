// Виджет-тесты навигации экрана «Мои данные».
//
// Правка 3: кнопка «Сохранить» НЕ закрывает экран (нет Navigator.pop) — после
//           сохранения пользователь остаётся на My Data и видит снэкбар.
// Правка 4: на ВЛОЖЕННЫХ push-экранах кнопка «назад» есть и на широкой раскладке
//           (≥600px), а на КОРНЕВЫХ вкладках (оболочка ScaffoldWithNavBar) её нет.

import 'package:app/core/router/scaffold_with_nav_bar.dart';
import 'package:app/core/settings/macro_override_provider.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/profile/my_data_screen.dart';
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

/// Роутер с оболочкой (4 корневых таба) + вложенный push-экран /profile/my-data.
GoRouter _router() => GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (c, s, shell) => ScaffoldWithNavBar(navigationShell: shell),
          branches: [
            for (final p in ['/today', '/plan', '/health', '/diary'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: p,
                    builder: (c, s) => Center(child: Text('root $p')),
                  ),
                ],
              ),
          ],
        ),
        GoRoute(
          path: '/profile/my-data',
          builder: (c, s) => const MyDataScreen(),
        ),
      ],
    );

Future<void> _pumpWide(WidgetTester tester, SharedPreferences prefs) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp.router(
        locale: const Locale('en'),
        theme: _testTheme(),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'wide: корневая вкладка без «назад», вложенный экран — с «назад»',
    (tester) async {
      SharedPreferences.setMockInitialValues({kMacroOverrideEnabledKey: false});
      final prefs = await SharedPreferences.getInstance();

      await _pumpWide(tester, prefs);

      // Корневая вкладка (оболочка, wide) — стрелки «назад» НЕТ.
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('root /today'), findsOneWidget);

      // Открываем вложенный экран поверх (push).
      final ctx = tester.element(find.text('root /today'));
      ctx.push('/profile/my-data');
      await tester.pumpAndSettle();

      // На вложенном экране (wide) кнопка «назад» ЕСТЬ и работает.
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('My data'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Вернулись на корень — снова без «назад».
      expect(find.text('root /today'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets('Save не закрывает экран (нет pop)', (tester) async {
    SharedPreferences.setMockInitialValues({
      kMacroOverrideEnabledKey: false,
      'user_weight_kg': 70.0,
      'user_height_cm': 175,
      'user_age': 25,
    });
    final prefs = await SharedPreferences.getInstance();

    await _pumpWide(tester, prefs);

    final ctx = tester.element(find.text('root /today'));
    ctx.push('/profile/my-data');
    await tester.pumpAndSettle();

    expect(find.text('My data'), findsOneWidget);

    // Нажимаем «Сохранить».
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(); // снэкбар + возможный pop
    await tester.pump(const Duration(milliseconds: 50));

    // Экран НЕ закрылся: My Data всё ещё на месте, корень не показан.
    expect(find.text('My data'), findsOneWidget);
    expect(find.text('root /today'), findsNothing);
    // Подтверждение сохранения — снэкбар.
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
