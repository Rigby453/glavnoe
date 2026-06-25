// Виджет-тест редактора пользовательской медитативной сессии.
// Проверяет: рендер, добавление/удаление шага, изменение текста + секунд,
// обновление превью суммарной длительности и — главное — отсутствие RenderFlex
// overflow на 320px при textScale 1.5.
// БД не нужна: Save не нажимаем, поэтому DAO-провайдер не читается.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/meditation_editor_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpEditor(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MeditationEditorScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('редактор рендерится: имя + 1 дефолтный шаг', (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    // Имя сессии + поле инструкции одного шага = 2 TextField.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(Card), findsOneWidget); // один дефолтный шаг
    expect(find.text('Add step'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('добавление и удаление шага меняет число карточек',
      (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    expect(find.byType(Card), findsOneWidget);

    // Добавить шаг → 2 карточки.
    await tester.ensureVisible(find.text('Add step'));
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNWidgets(2));

    // Удалить первый шаг → 1 карточка.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('степпер секунд увеличивает длительность и превью', (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    // Дефолтный шаг — 60 секунд; превью total 01:00.
    expect(find.text('60 seconds'), findsOneWidget);
    expect(find.textContaining('01:00'), findsOneWidget);

    // Плюс → +5 секунд = 65; превью обновляется на 01:05.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('65 seconds'), findsOneWidget);
    expect(find.textContaining('01:05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ввод текста инструкции отображается', (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    // Поле инструкции шага — второе TextField (первое — имя сессии).
    await tester.enterText(
        find.byType(TextField).at(1), 'Close your eyes and breathe');
    await tester.pumpAndSettle();
    expect(find.text('Close your eyes and breathe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('нет overflow на 320px при textScale 1.5', (tester) async {
    await _pumpEditor(tester, width: 320, textScale: 1.5);
    // Добавляем ещё шаг, чтобы список вырос, и проверяем устойчивость.
    await tester.ensureVisible(find.text('Add step'));
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
