// Виджет-дымовой тест пейвола: рендерится без рантайм-ошибок, показывает
// преимущества/цену/кнопки «Start free» и «Restore purchases».
// Ассерты обновлены под актуальный экран: headline «Unlock the AI», бенефиты
// из _benefits (reschedule, menu, photo, voice, wrapped), CTA «Start free»,
// суффикс цены « / mo».
//
// Дополнительно: тест на узком экране (320×800 dp) проверяет отсутствие
// RenderFlex-overflow в _LinksRow и _PlanCard на крупном textScaler.

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

/// Вспомогательная функция: пампит пейвол с заданными оверрайдами.
Future<void> _pumpPaywall(
  WidgetTester tester, {
  double? textScaleFactor,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  Widget app = MaterialApp(
    theme: _testTheme(),
    home: const PaywallScreen(),
  );

  // Если задан textScaleFactor — оборачиваем в MediaQuery с нужным скейлом
  if (textScaleFactor != null) {
    app = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: app,
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isPremiumProvider.overrideWith((ref) async => false),
        purchaseServiceProvider.overrideWithValue(_FakePurchaseService()),
      ],
      child: app,
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'PaywallScreen renders benefits, price, Start free and Restore purchases',
      (tester) async {
    await _pumpPaywall(tester);

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

  testWidgets(
      'PaywallScreen no overflow on narrow screen 320×800 dp (default text scale)',
      (tester) async {
    // Имитируем узкий экран — такой как Moto G4 / iPhone SE 1-го поколения
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPaywall(tester);

    // Доскролливаем до нижней части, чтобы все виджеты отрендерились
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Тест провалится с «A RenderFlex overflowed» если Row переполнен.
    // Отдельной проверки нет — flutter_test автоматически падает на overflow.
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets(
      'PaywallScreen no overflow on narrow screen 320×800 dp with large text scale (1.5×)',
      (tester) async {
    // Имитируем узкий экран + Extra large accessibility text
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPaywall(tester, textScaleFactor: 1.5);

    // Доскролливаем до нижней части
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Проверяем ключевые элементы; overflow вызовет ошибку в тест-фреймворке
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
  });
}
