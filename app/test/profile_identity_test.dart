// profile_identity_test.dart
// Тесты редактирования имени и аватара в профиле (profile-name-avatar).
//
// Покрытие:
//   1. ProfileIdentityNotifier (провайдер) — set/clear имени, выбор аватара,
//      персистентность через SharedPreferences, обрезка слишком длинного имени.
//   2. ProfileAccountScreen (виджет) — правка имени через диалог сохраняется
//      и отображается; сброс возвращает имя аккаунта; выбор аватара в шите
//      применяется и персистится.
//   3. Overflow: 320px + textScale 1.5/2.0 — без RenderFlex-исключений.
//
// Без pumpAndSettle (deadlock guard — см. правила проекта). Prefs — через
// SharedPreferences.setMockInitialValues. currentUserProvider оверрайднут
// напрямую (без auth/api клиента).

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/profile/profile_identity_provider.dart';
import 'package:app/features/profile/profile_screen.dart' show
    ProfileAccountScreen, currentUserProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

Future<SharedPreferences> _emptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Widget _wrapScreen(
  Widget child,
  SharedPreferences prefs, {
  Map<String, dynamic>? user,
  double width = 390,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWith((ref) async => user),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        size: Size(width, 800),
      ),
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        home: child,
      ),
    ),
  );
}

/// Минимальный settle без pumpAndSettle (даём FutureProvider разрешиться
/// двумя проходами кадра).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

/// Settle после открытия/закрытия диалога или модального шита — даём
/// transition-анимации (по умолчанию ~150ms) полностью доиграть, не
/// прибегая к pumpAndSettle (которая может зависнуть на бесконечных
/// анимациях вроде индикатора загрузки).
Future<void> _settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// ---------------------------------------------------------------------------
// 1. ProfileIdentityNotifier — провайдер
// ---------------------------------------------------------------------------

void main() {
  group('ProfileIdentityNotifier (провайдер)', () {
    test('по умолчанию displayName=null, avatar=defaultAvatar', () async {
      final prefs = await _emptyPrefs();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      final identity = container.read(profileIdentityProvider);
      expect(identity.displayName, isNull);
      expect(identity.avatar, AvatarPreset.defaultAvatar);
    });

    test('setDisplayName сохраняет обрезанное значение и обновляет state',
        () async {
      final prefs = await _emptyPrefs();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      await container
          .read(profileIdentityProvider.notifier)
          .setDisplayName('  Sam  ');

      expect(container.read(profileIdentityProvider).displayName, 'Sam');
      expect(prefs.getString('profile_display_name'), 'Sam');
    });

    test('setDisplayName с пустой строкой сбрасывает переопределение',
        () async {
      final prefs = await _emptyPrefs();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      await container
          .read(profileIdentityProvider.notifier)
          .setDisplayName('Sam');
      await container
          .read(profileIdentityProvider.notifier)
          .setDisplayName('   ');

      expect(container.read(profileIdentityProvider).displayName, isNull);
      expect(prefs.getString('profile_display_name'), isNull);
    });

    test('слишком длинное имя обрезается до kProfileDisplayNameMaxLength',
        () async {
      final prefs = await _emptyPrefs();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      final tooLong = 'A' * (kProfileDisplayNameMaxLength + 20);
      await container
          .read(profileIdentityProvider.notifier)
          .setDisplayName(tooLong);

      final saved = container.read(profileIdentityProvider).displayName;
      expect(saved!.length, kProfileDisplayNameMaxLength);
    });

    test('setAvatar сохраняет пресет и обновляет state', () async {
      final prefs = await _emptyPrefs();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      await container
          .read(profileIdentityProvider.notifier)
          .setAvatar(AvatarPreset.cat);

      expect(container.read(profileIdentityProvider).avatar, AvatarPreset.cat);
      expect(prefs.getString('profile_avatar_preset'), 'cat');
    });

    test('значения переживают пересоздание провайдера (персистентность)',
        () async {
      final prefs = await _emptyPrefs();
      final container1 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      await container1
          .read(profileIdentityProvider.notifier)
          .setDisplayName('Riley');
      await container1
          .read(profileIdentityProvider.notifier)
          .setAvatar(AvatarPreset.rocket);
      container1.dispose();

      // Новый контейнер (как при перезапуске приложения) с теми же prefs.
      final container2 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container2.dispose);

      final identity = container2.read(profileIdentityProvider);
      expect(identity.displayName, 'Riley');
      expect(identity.avatar, AvatarPreset.rocket);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. ProfileAccountScreen — правка имени через диалог
  // ═══════════════════════════════════════════════════════════════════════

  group('ProfileAccountScreen — редактирование имени', () {
    testWidgets(
        'показывает имя аккаунта, когда нет локального переопределения',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _emptyPrefs();
      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: const {'name': 'Alex', 'email': 'alex@example.com'},
        ),
      );
      await _settle(tester);

      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets(
        'правка имени через диалог сохраняется в prefs и отображается',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _emptyPrefs();
      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: const {'name': 'Alex', 'email': 'alex@example.com'},
        ),
      );
      await _settle(tester);

      expect(find.text('Alex'), findsOneWidget);

      // Открываем диалог переименования
      await tester.tap(find.byTooltip('Edit name'));
      await _settleDialog(tester);

      expect(find.text('Your name'), findsOneWidget); // заголовок диалога
      expect(find.widgetWithText(TextField, 'Alex'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.tap(find.text('Save'));
      await _settleDialog(tester);

      // Диалог закрылся, новое имя отображается, снэкбар показан
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Alex'), findsNothing);
      expect(find.text('Name updated'), findsOneWidget);

      // Персистентность
      expect(prefs.getString('profile_display_name'), 'Sam');
    });

    testWidgets(
        'очистка поля в диалоге сбрасывает переопределение → возвращает имя аккаунта',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Симулируем «после перезапуска»: переопределение уже сохранено.
      SharedPreferences.setMockInitialValues({
        'profile_display_name': 'Sam',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: const {'name': 'Alex', 'email': 'alex@example.com'},
        ),
      );
      await _settle(tester);

      expect(find.text('Sam'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit name'));
      await _settleDialog(tester);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await _settleDialog(tester);

      // Вернулось имя аккаунта
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Sam'), findsNothing);
      expect(prefs.getString('profile_display_name'), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. ProfileAccountScreen — выбор аватара
  // ═══════════════════════════════════════════════════════════════════════

  group('ProfileAccountScreen — выбор аватара', () {
    testWidgets('выбор пресета в шите применяется и сохраняется в prefs',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _emptyPrefs();
      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: const {'name': 'Alex', 'email': 'alex@example.com'},
        ),
      );
      await _settle(tester);

      // По умолчанию показан дефолтный аватар (иконка user-fill)
      expect(find.byIcon(AvatarPreset.defaultAvatar.icon()), findsOneWidget);

      // Открываем шит выбора аватара
      await tester.tap(find.text('Change avatar'));
      await _settleDialog(tester);

      expect(find.text('Choose an avatar'), findsOneWidget);

      // В шите доступен пресет «кот» — выбираем его
      await tester.tap(find.byIcon(AvatarPreset.cat.icon()).last);
      await _settleDialog(tester);

      // Шит закрылся, в шапке экрана теперь иконка кота (единственная)
      expect(find.byIcon(AvatarPreset.cat.icon()), findsOneWidget);
      expect(find.text('Choose an avatar'), findsNothing);

      // Персистентность
      expect(prefs.getString('profile_avatar_preset'), 'cat');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. Overflow: 320px + textScale 1.5/2.0
  // ═══════════════════════════════════════════════════════════════════════

  group('ProfileAccountScreen — overflow safety', () {
    testWidgets('нет overflow на 320px при textScale 1.5 с длинным именем',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({
        'profile_display_name':
            'A Very Long Display Name That Should Ellipsize',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: const {
            'name': 'Alex',
            'email': 'a.very.long.email.address@example.com',
          },
          width: 320,
          textScale: 1.5,
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('нет overflow на 320px при textScale 2.0 (офлайн, без имени)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _emptyPrefs();
      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: null, // офлайн-режим: нет аккаунта
          width: 320,
          textScale: 2.0,
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('нет overflow при открытом шите выбора аватара (320px, scale 2.0)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _emptyPrefs();
      await tester.pumpWidget(
        _wrapScreen(
          const ProfileAccountScreen(),
          prefs,
          user: const {'name': 'Alex', 'email': 'alex@example.com'},
          width: 320,
          textScale: 2.0,
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Change avatar'));
      await _settleDialog(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
