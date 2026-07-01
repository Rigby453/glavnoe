// DRAG-TO-CREATE: рисование новой задачи по ПУСТОЙ области сетки времени
// (time_grid.dart). Проверяем на настоящем DayTimeGrid:
//   • long-press (_kBlockPickupDelay) + тяга по пустому месту → открывается
//     AddTaskSheet с предзаполненными initialAt (снэпнутое начало) и
//     initialDurationMinutes (снэпнутая длительность диапазона);
//   • КОРОТКИЙ свайп без удержания НЕ создаёт задачу (лист не открывается) —
//     это обычный скролл/тап, а не рисование.
//
// AddTaskSheet — публичный виджет, поэтому читаем его поля initialAt/
// initialDurationMinutes напрямую (без мок-навигации). Жесты драйвим через
// startGesture + moveBy + up на фейковом клоке, как в time_grid_gesture_test.
// Размонтируем через pump(SizedBox), чтобы now-таймер (минутный) и нулевой
// Timer закрытия riverpod-стрима отменились/дренировались.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;
import 'package:app/features/today/widgets/add_task_sheet.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Зеркалит приватную _kBlockPickupDelay из time_grid.dart. Если меняешь порог
// подхвата в виджете — обнови и здесь.
const _kBlockPickupDelay = Duration(milliseconds: 120);

ThemeData _testTheme() => ThemeData.dark().copyWith(
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

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  const hourHeight = kHourHeight; // 56.0
  final day = DateTime(2026, 6, 24);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget harness() => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          selectedDayProvider.overrideWith((ref) => day),
        ],
        child: MaterialApp(
          theme: _testTheme(),
          // disableAnimations: убирает эфемерные таймеры лифт/sheet-анимаций под
          // фейковым клоком; логика жеста рисования от этого не меняется.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 700,
              child: DayTimeGrid(hourHeight: hourHeight),
            ),
          ),
        ),
      );

  // Пустая сетка: задач нет (seeding не нужен — рисуем по пустому месту).
  Future<void> pumpGrid(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // Y-координата (глобальная) для заданной минуты дня внутри колонки.
  // Колонка начинается в (gutter=44, 0) и проскроллена на 7 часов вниз
  // (_kDefaultScrollHour). На экране пиксель = (minute*hourHeight/60) - scroll.
  // Берём минуту так, чтобы она была видна (около 09:00 — в видимой зоне после
  // авто-скролла на 07:00), и считаем экранную Y через getRect Scrollable.
  double screenYForMinute(WidgetTester tester, int minuteOfDay) {
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    final scrollOffset = scrollable.controller?.offset ?? 0;
    final contentY = minuteOfDay * hourHeight / 60.0;
    return contentY - scrollOffset; // относительно верхнего края viewport (0)
  }

  testWidgets(
    'long-press + тяга по пустой области создаёт задачу с предзаполненными '
    'initialAt и длительностью',
    (tester) async {
      await pumpGrid(tester);

      // Старт около 09:00 (видно после авто-скролла на 07:00). Колонка слева
      // начинается на x=gutter(44); берём центр колонки.
      const startMinute = 9 * 60; // 09:00
      final startY = screenYForMinute(tester, startMinute);
      // Тянем вниз на 1 час (hourHeight) → 09:00–10:00, длительность 60 мин.
      const colCenterX = 44 + (360 - 44) / 2;
      final startPoint = Offset(colCenterX, startY);

      final gesture = await tester.startGesture(startPoint);
      // Ждём порог подхвата (long-press) на фейковом клоке.
      await tester.pump(_kBlockPickupDelay + const Duration(milliseconds: 50));
      // Тянем вниз на час несколькими шагами (onLongPressMoveUpdate).
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, hourHeight / 4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Скролл НЕ должен был сдвинуться — long-press выиграл арену у скролла.
      final scrollable =
          tester.widget<Scrollable>(find.byType(Scrollable).first);
      expect(scrollable.controller?.offset, kHourHeight * 7,
          reason: 'страница не проскроллилась — long-press взял рисование');

      // Лист добавления открыт с предзаполнением.
      final sheetFinder = find.byType(AddTaskSheet);
      expect(sheetFinder, findsOneWidget,
          reason: 'drag-to-create открыл AddTaskSheet');
      final sheet = tester.widget<AddTaskSheet>(sheetFinder);
      expect(sheet.initialAt, isNotNull);
      expect(sheet.initialAt!.hour, 9, reason: 'начало снэпнуто к 09:00');
      expect(sheet.initialAt!.minute, 0);
      expect(sheet.initialDurationMinutes, 60,
          reason: 'диапазон 09:00–10:00 = 60 минут (снэп 15)');

      // Закрываем лист, затем размонтируем (чистим таймеры).
      await tester.tap(find.byIcon(PhosphorIcons.x(PhosphorIconsStyle.regular)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'короткий свайп без удержания НЕ создаёт задачу (лист не открывается)',
    (tester) async {
      await pumpGrid(tester);

      const startMinute = 9 * 60;
      final startY = screenYForMinute(tester, startMinute);
      const colCenterX = 44 + (360 - 44) / 2;
      final startPoint = Offset(colCenterX, startY);

      // Быстрый свайп вниз БЕЗ удержания: палец сразу движется → арену
      // выигрывает скролл (или жест просто не превращается в long-press).
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Лист НЕ открыт — это был скролл/быстрый свайп, не рисование.
      expect(find.byType(AddTaskSheet), findsNothing,
          reason: 'быстрый свайп без удержания не создаёт задачу');

      await unmountAndFlush(tester);
    },
  );
}
