// Виджет-дымовой тест пейвола: рендерится без рантайм-ошибок, показывает
// преимущества/цену/кнопки «Start free» и «Restore purchases».
// Ассерты обновлены под актуальный экран: headline «Unlock the AI», бенефиты
// из _benefits (reschedule, menu, photo, voice, wrapped), CTA «Start free»,
// суффикс цены « / mo».

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/auth/auth_controller.dart' show isPremiumProvider;
import 'package:app/features/paywall/paywall_screen.dart';
import 'package:app/services/purchases/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Заглушка PurchaseService для тестов — не ходит в сеть.
class _FakePurchaseService implements PurchaseService {
  @override
  Future<PurchaseOutcome> buyPremium() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
}

/// Лёгкая тестовая тема: системный шрифт + FocusThemeExtension с палитрой Focus.
/// Избегает GoogleFonts (в тестах шрифты не доступны через сеть/ассеты),
/// но предоставляет `extension<FocusThemeExtension>()!`, который нужен экранам.
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

void main() {
  testWidgets(
      'PaywallScreen renders benefits, price, Start free and Restore purchases',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Не ходим в сеть за /me — фиксируем free.
          isPremiumProvider.overrideWith((ref) async => false),
          // Изолируем от сети: подставляем фейковый PurchaseService.
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService()),
        ],
        // _testTheme() содержит FocusThemeExtension — PaywallScreen вызывает extension<FocusThemeExtension>()!
        // Используем системный шрифт вместо GoogleFonts (шрифты недоступны в тест-окружении).
        child: MaterialApp(theme: _testTheme(), home: const PaywallScreen()),
      ),
    );
    await tester.pump();

    // Верх списка (виден сразу): заголовок и первый бенефит.
    expect(find.text('Unlock the AI'), findsOneWidget);
    expect(find.text('AI smart reschedule'), findsOneWidget);

    // Низ ListView ленивый — доскролливаем до кнопки Restore purchases.
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Restore purchases'), findsOneWidget);
    // Основная CTA — «Start free» (paywall.cta_start_free)
    expect(find.text('Start free'), findsOneWidget);
    // Суффикс цены месячного плана — « / mo» (paywall.per_month)
    expect(find.textContaining('/ mo'), findsWidgets);
    // Dev: unlock premium больше нет — dev-кнопки проверяем в kDebugMode;
    // в тесте они могут быть видны (debug build) — не ломаем тест их наличием.
    expect(find.text('Dev: unlock premium'), findsNothing);
  });
}
