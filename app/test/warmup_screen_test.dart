// Тесты фичи «Зарядка / растяжка».
//   1) смоук-рендер списка комплексов без краша;
//   2) открытие гайдед-плеера (первое упражнение) без краша;
//   3) overflow на 320px при textScale 1.5 (список и плеер);
//   4) загрузка 3 комплексов с непустыми упражнениями;
//   5) все l10n-ключи warmup имеют en + ru.

import 'package:app/core/l10n/strings/health_b.dart';
import 'package:app/core/l10n/strings/warmup.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/warmup_routines.dart';
import 'package:app/features/health/warmup_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpList(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.focusTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const WarmupScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('WarmupScreen — список', () {
    testWidgets('рендерит 2 комплекса без краша', (tester) async {
      await _pumpList(tester);

      // en-локаль по умолчанию → имена рутин из warmup.dart.
      expect(find.text('Morning warmup'), findsOneWidget);
      expect(find.text('Stretching'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('без overflow на 320px при textScale 1.5', (tester) async {
      await _pumpList(tester, width: 320, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });

  group('WarmupScreen — плеер', () {
    testWidgets('тап по комплексу открывает плеер (первое упражнение)',
        (tester) async {
      await _pumpList(tester);

      await tester.tap(find.text('Morning warmup'));
      await tester.pump(); // старт перехода
      await tester.pump(const Duration(milliseconds: 350)); // завершить переход

      // Первое упражнение «Утренней зарядки» — Neck rolls (таймер 30s).
      expect(find.text('Neck rolls'), findsOneWidget);
      expect(find.text('End routine'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Закрываем плеер, чтобы dispose отменил Timer.periodic.
      await tester.tap(find.text('End routine'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('плеер без overflow на 320px при textScale 1.5',
        (tester) async {
      await _pumpList(tester, width: 320, textScale: 1.5);

      await tester.tap(find.text('Stretching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('End routine'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('WarmupRoutine — данные', () {
    test('ровно 3 комплекса, у каждого непустые упражнения', () {
      expect(kWarmupRoutines.length, 3);
      for (final r in kWarmupRoutines) {
        expect(r.steps, isNotEmpty);
        expect(r.steps.length, greaterThanOrEqualTo(6));
        for (final s in r.steps) {
          // Ровно одно из seconds / reps задано.
          expect((s.seconds == null) != (s.reps == null), isTrue);
          expect(s.nameKey, isNotEmpty);
          expect(s.descKey, isNotEmpty);
        }
        expect(r.approxMinutes, greaterThanOrEqualTo(1));
      }
    });
  });

  group('l10n — warmup', () {
    test('каждый ключ имеет непустые en и ru', () {
      for (final entry in warmupStrings.entries) {
        final en = entry.value['en'];
        final ru = entry.value['ru'];
        expect(en, isNotNull, reason: 'нет en для ${entry.key}');
        expect(en, isNotEmpty, reason: 'пустой en для ${entry.key}');
        expect(ru, isNotNull, reason: 'нет ru для ${entry.key}');
        expect(ru, isNotEmpty, reason: 'пустой ru для ${entry.key}');
      }
    });

    test('все ключи рутин и упражнений присутствуют в warmupStrings', () {
      for (final r in kWarmupRoutines) {
        expect(warmupStrings, contains(r.nameKey));
        expect(warmupStrings, contains(r.descKey));
        for (final s in r.steps) {
          // Рутина 'posture' переиспользует ключи posture.*.name / posture.*.steps,
          // которые живут в healthBStrings (health_b.dart), а не в warmupStrings.
          // Runtime это ок: context.s() ищет по объединённой карте S._all.
          // В тесте мы явно указываем правильный источник для каждого ключа.
          final srcMap =
              s.nameKey.startsWith('posture.') ? healthBStrings : warmupStrings;
          expect(srcMap, contains(s.nameKey),
              reason: '${s.nameKey} не найден в нужной карте строк');
          expect(srcMap, contains(s.descKey),
              reason: '${s.descKey} не найден в нужной карте строк');
        }
      }
    });
  });
}
