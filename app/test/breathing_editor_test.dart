// Виджет-тест редактора пользовательской дыхательной техники.
// Проверяет: рендер, добавление/удаление фазы, изменение секунд степпером и —
// главное — отсутствие RenderFlex overflow на 320px при textScale 1.5.
// БД не нужна: Save не нажимаем, поэтому DAO-провайдер не читается.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/breathing_editor_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Карточки фаз — Container+hairline (не Material Card). Считаем по одной кнопке
// удаления (trash) на фазу. Степпер «+» секунд — IconButton (в отличие от
// ghost-кнопки «Add phase» = TextButton.icon).

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
        home: const BreathingEditorScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('редактор рендерится: имя + 2 дефолтные фазы', (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.trash()), findsNWidgets(2)); // дефолт Inhale + Exhale
    expect(find.text('Add phase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('добавление и удаление фазы меняет число карточек',
      (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    expect(find.byIcon(PhosphorIcons.trash()), findsNWidgets(2));

    // Добавить фазу → 3 карточки.
    await tester.ensureVisible(find.text('Add phase'));
    await tester.tap(find.text('Add phase'));
    await tester.pumpAndSettle();
    expect(find.byIcon(PhosphorIcons.trash()), findsNWidgets(3));

    // Удалить первую фазу → 2 карточки.
    await tester.tap(find.byIcon(PhosphorIcons.trash()).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(PhosphorIcons.trash()), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('степпер секунд увеличивает длительность фазы', (tester) async {
    await _pumpEditor(tester, width: 360, textScale: 1.0);
    // Обе дефолтные фазы по 4 секунды.
    expect(find.text('4 seconds'), findsNWidgets(2));

    // Плюс у первой фазы → 5 секунд.
    await tester.tap(find.widgetWithIcon(IconButton, PhosphorIcons.plus()).first);
    await tester.pumpAndSettle();
    expect(find.text('5 seconds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('нет overflow на 320px при textScale 1.5', (tester) async {
    await _pumpEditor(tester, width: 320, textScale: 1.5);
    // Добавляем ещё фазу, чтобы список вырос, и проверяем устойчивость.
    await tester.ensureVisible(find.text('Add phase'));
    await tester.tap(find.text('Add phase'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
