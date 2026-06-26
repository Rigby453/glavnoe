// Виджет-тесты лимита maxValue у NumberInputDialog + helperText редактора.
//
// Баг: время отдыха вводилось, но молча обрезалось клампом — большие значения
// «не сохранялись» без объяснения. Фикс: диалог теперь ОТВЕРГАЕТ значения сверх
// maxValue (как и ниже minValue — возвращает null) и показывает лимит в
// helperText (локализованный ключ common.max_value_hint, en «Max 60 min»).
//
// context.s резолвится в en по умолчанию (локаль теста = en), отдельные
// l10n-делегаты не нужны — S — собственная система переводов приложения.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/number_input_dialog.dart';
import 'package:app/features/health/workout_editor_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Открывает [NumberInputDialog] с заданными границами и возвращает Future
/// результата (значение или null при отмене/невалидном вводе).
Future<int?> _openDialog(
  WidgetTester tester, {
  int minValue = 0,
  int? maxValue,
  String? maxValueHint,
}) async {
  int? result;
  var popped = false;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.focusTheme(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () async {
                result = await showDialog<int>(
                  context: ctx,
                  builder: (_) => NumberInputDialog(
                    title: 'Rest',
                    labelText: 'Rest',
                    suffixText: 's',
                    minValue: minValue,
                    maxValue: maxValue,
                    maxValueHint: maxValueHint,
                  ),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  // Возвращаем замыкание-геттер через побочный эффект: вызывающий код после
  // подтверждения/отмены и pumpAndSettle прочитает result.
  expect(popped, isFalse); // диалог ещё открыт
  return Future.value(result);
}

void main() {
  testWidgets('helperText показывает максимум (локализованный, en «Max 60 min»)',
      (tester) async {
    await _openDialog(
      tester,
      minValue: 15,
      maxValue: 3600,
      maxValueHint: 'Max 60 min',
    );

    expect(find.text('Max 60 min'), findsOneWidget);
  });

  testWidgets('ввод > maxValue → диалог возвращает null (молча НЕ обрезает)',
      (tester) async {
    int? captured = -999;
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.focusTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () async {
                  captured = await showDialog<int>(
                    context: ctx,
                    builder: (_) => const NumberInputDialog(
                      title: 'Rest',
                      labelText: 'Rest',
                      minValue: 15,
                      maxValue: 3600,
                      maxValueHint: 'Max 60 min',
                    ),
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    // Вводим 9999 (> 3600) и подтверждаем.
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(captured, isNull); // отвергнуто, а не обрезано до 3600
  });

  testWidgets('ввод в пределах [min, max] → возвращается как есть (1200)',
      (tester) async {
    int? captured = -999;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.focusTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () async {
                  captured = await showDialog<int>(
                    context: ctx,
                    builder: (_) => const NumberInputDialog(
                      title: 'Rest',
                      labelText: 'Rest',
                      minValue: 15,
                      maxValue: 3600,
                      maxValueHint: 'Max 60 min',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1200'); // 20 мин — раньше обрезалось
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(captured, 1200);
  });

  testWidgets('редактор упражнения: поле отдыха имеет helperText с лимитом '
      '(«Max 60 min»)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.focusTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => exerciseDialogForTest(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    // helperText лимита отдыха присутствует (en, лимит в минутах).
    expect(find.text('Max 60 min'), findsOneWidget);
  });
}
