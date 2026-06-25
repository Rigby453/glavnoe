// Виджет-тест интеграции пользовательских сессий в экран медитаций.
// Подменяем customMeditationsProvider тестовыми данными (без Drift) и проверяем,
// что пользовательская сессия появляется рядом со встроенными, её можно выбрать
// (открывается тот же плеер), и экран остаётся без overflow на 320px/1.5x.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/meditation_custom.dart';
import 'package:app/features/health/meditation_custom_providers.dart';
import 'package:app/features/health/meditation_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _testSession = CustomMeditation(
  id: 'med-1',
  name: 'My Evening Calm',
  steps: [
    MeditationStep(text: 'Sit down and relax your shoulders', seconds: 60),
    MeditationStep(text: 'Breathe out slowly', seconds: 90),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required double width,
  required double textScale,
  List<CustomMeditation> sessions = const [_testSession],
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customMeditationsProvider.overrideWith((ref) => Stream.value(sessions)),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MeditationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('пользовательская сессия видна рядом со встроенными',
      (tester) async {
    await _pumpScreen(tester, width: 360, textScale: 1.0);

    // Встроенная сессия (локализованное имя) видна сверху списка.
    expect(find.text('Body Scan'), findsOneWidget);

    // Пользовательская сессия и кнопка создания — ниже встроенных в ленивом
    // ListView; прокручиваем до конца (кнопка — последний элемент).
    await tester.scrollUntilVisible(
      find.text('New session'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Evening Calm'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('пользовательскую сессию можно выбрать — открывается плеер',
      (tester) async {
    await _pumpScreen(tester, width: 360, textScale: 1.0);

    await tester.scrollUntilVisible(
      find.text('My Evening Calm'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('My Evening Calm'));
    await tester.pump(); // строим маршрут плеера
    await tester.pump(const Duration(milliseconds: 50));

    // Плеер показывает СЫРОЙ текст первого шага и имя сессии в AppBar.
    expect(find.text('Sit down and relax your shoulders'), findsOneWidget);
    expect(find.text('End session'), findsOneWidget);

    // Закрываем плеер, чтобы dispose отменил таймер/анимацию (нет pending-таймеров).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('экран без overflow на 320px при textScale 1.5', (tester) async {
    await _pumpScreen(tester, width: 320, textScale: 1.5);
    // Прокрутка через все карточки до пользовательской — overflow на любом кадре
    // был бы пойман takeException ниже.
    await tester.scrollUntilVisible(
      find.text('My Evening Calm'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Evening Calm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
