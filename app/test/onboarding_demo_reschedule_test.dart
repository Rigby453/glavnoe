// onboarding_demo_reschedule_test.dart
// Покрывает переработанный демо-экран переноса (индекс 8 в SetupFlowScreen,
// ТЗ редизайна §2): несколько задач с реальным временем (а не одна
// абстрактная карточка), часть из них «не успевает», перенос — через
// настоящую ember-карточку разбора (зеркалит MorningReviewCard с Today) с
// одной реальной кнопкой, а не абстрактной анимацией.
//
// Навигация — прыжок через PageController.jumpToPage() (как в
// onboarding_steps_test.dart): экран демо не зависит от заполнения
// предыдущих полей (первая задача пользователя по умолчанию пуста →
// используется заглушка-подсказка вместо реального текста).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/onboarding/setup_flow.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const int _demoPage = 8;

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

  Widget buildApp({Size size = const Size(390, 844), double scale = 1.0}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          theme: _testTheme(),
          home: const SetupFlowScreen(),
        ),
      ),
    );
  }

  Future<void> goToPage(WidgetTester tester, int page) async {
    final dynamic pageView = tester.widget(find.byType(PageView));
    (pageView.controller as PageController).jumpToPage(page);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'демо показывает 4 настоящие карточки задач с реальным временем, '
    '3 из них помечены как просроченные',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      await goToPage(tester, _demoPage);
      expect(tester.takeException(), isNull);

      // Заголовки демо-задач (фиксированные seed-данные).
      expect(find.text('Lecture notes'), findsOneWidget);
      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.text('Read before bed'), findsOneWidget);
      // Задача пользователя пуста (экран 7 не пройден) → заглушка-подсказка.
      expect(find.text('e.g. Submit assignment, Call mom…'), findsOneWidget);

      // Реальные часы (не абстрактная анимация).
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('1:00 PM'), findsOneWidget);
      expect(find.text('5:00 PM'), findsOneWidget);
      expect(find.text('9:00 PM'), findsOneWidget);

      // 3 задачи «не успевают» по умолчанию.
      expect(find.text('Overdue'), findsNWidgets(3));

      // Карточка разбора — зеркалит MorningReviewCard.
      expect(find.text('Some tasks didn\'t make it'), findsOneWidget);
      expect(find.textContaining('3 tasks ran out of time today'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Move all to tomorrow'),
          findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    '«Перенести все на завтра» убирает overdue-метки и показывает успех',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      await goToPage(tester, _demoPage);

      // Контент демо-экрана (4 карточки + ember-баннер) выше дефолтного
      // тестового вьюпорта — кнопка может оказаться вне видимой области
      // скролла, ensureVisible прокручивает SingleChildScrollView к ней.
      final moveAllBtn = find.widgetWithText(FilledButton, 'Move all to tomorrow');
      await tester.ensureVisible(moveAllBtn);
      await tester.pump();
      await tester.tap(moveAllBtn);
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);

      // Overdue-метки исчезли, карточка разбора скрыта.
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('Some tasks didn\'t make it'), findsNothing);

      // Перенесённые задачи получают короткую метку «→ Tomorrow» (×3).
      expect(find.text('→ Tomorrow'), findsNWidgets(3));

      // Success-строка + Kai bubble с финальным сообщением.
      expect(find.text('Moved to top of tomorrow'), findsOneWidget);
      expect(
        find.text(
            'I rebuild the day around what matters and explain what went wrong.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('демо-экран переживает 320px / textScale 1.5', (tester) async {
    const size = Size(320, 760);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp(size: size, scale: 1.5));
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();

    await goToPage(tester, _demoPage);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('демо-экран переживает 320px / textScale 2.0', (tester) async {
    const size = Size(320, 760);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp(size: size, scale: 2.0));
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();

    await goToPage(tester, _demoPage);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
