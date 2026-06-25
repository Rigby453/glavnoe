// onboarding_steps_test.dart
// Покрывает три новых шага quiz-онбординга — уведомления, тон, тема — и
// итоговую сводку, на узкой ширине (320px) при крупном тексте (textScale 2.0).
//
// Методология (как в overflow_audit_test.dart): flutter_test бросает исключение
// при любом RenderFlex overflow во время pump → успешный pump = нет overflow.
// Дополнительно проверяем, что выбранный тон/тема пишутся через провайдеры
// без исключений и попадают в итоговую сводку.
//
// Навигация между страницами: PageView использует NeverScrollableScrollPhysics,
// поэтому прыгаем напрямую через его PageController (jumpToPage) — это надёжнее,
// чем прогонять весь флоу (страница «первая задача» требует ввода + вставки в БД).

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

// Тестовая тема — копия из overflow_audit_test.dart (избегаем GoogleFonts).
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

// Узкая ширина + предельный textScale a11y.
const Size _size = Size(320, 760);
const double _scale = 2.0;

// Индексы страниц новых шагов в PageView.
const int _notifPage = 10;
const int _tonePage = 11;
const int _themePage = 12;
const int _summaryPage = 13;

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

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: _size,
          textScaler: TextScaler.linear(_scale),
        ),
        child: MaterialApp(
          theme: _testTheme(),
          home: const SetupFlowScreen(),
        ),
      ),
    );
  }

  // Прыжок на нужную страницу через PageController (минуя физику свайпов).
  Future<void> goToPage(WidgetTester tester, int page) async {
    final dynamic pageView = tester.widget(find.byType(PageView));
    (pageView.controller as PageController).jumpToPage(page);
    await tester.pump(); // onPageChanged → setState
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
      'notif/tone/theme/summary steps render with no overflow at 320px, textScale 2.0',
      (tester) async {
    await tester.binding.setSurfaceSize(_size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(milliseconds: 50));
    // Стартовая страница (цели) — не предмет этого теста; сбрасываем её состояние
    // исключений, чтобы строго проверять только три новых шага ниже.
    tester.takeException();

    // --- Шаг уведомлений (index 10) ---
    await goToPage(tester, _notifPage);
    expect(tester.takeException(), isNull);
    expect(find.text('Reminders for your daily review?'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    // --- Шаг тона (index 11) ---
    await goToPage(tester, _tonePage);
    expect(tester.takeException(), isNull);
    expect(find.text('Gentle'), findsOneWidget);
    expect(find.text('Honest & blunt'), findsOneWidget);

    // Выбор «honest & blunt» — пишется в toneProvider. set() асинхронно пишет в
    // SharedPreferences, поэтому tap оборачиваем в runAsync (реальные таймеры),
    // иначе запись не успевает завершиться под фейковыми часами теста.
    // ensureVisible: при textScale 2.0 второй тайл может быть ниже сгиба.
    await tester.ensureVisible(find.text('Honest & blunt'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Honest & blunt'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(prefs.getString('tone_preference'), 'harsh');

    // --- Шаг темы (index 12) ---
    await goToPage(tester, _themePage);
    expect(tester.takeException(), isNull);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);

    // Выбор «Calm» — пишется в themeNotifierProvider (так же асинхронно).
    await tester.ensureVisible(find.text('Calm'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Calm'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(prefs.getString('app_theme_key'), 'calm');

    // --- Сводка (index 13): запускает 400ms таймер готовности ---
    await goToPage(tester, _summaryPage);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    // Выбранные тон и тема отражены в сводке.
    expect(find.text('Tone'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Honest & blunt'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);

    // Размонтируем, чтобы сбросить отложенные таймеры в теле теста.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
